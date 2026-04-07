// VERSIONE FUNZIONANTE, CON AUTO-CLEAR HARDWARE, FIX ARLEN=1, FIX R.LAST E FIX ARCACHE=4'b1111
`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

module ip_module #(
    parameter int unsigned NUM_ENTRIES = 4
)(
    input  logic clk_i,
    input  logic rst_ni,

    // slave: Core0 scrive gli indirizzi
    input  culsans_pkg::req_slv_t  axi_req_i,
    output culsans_pkg::resp_slv_t axi_resp_o,

    // master ACE: manda MAKE_INVALID alla CCU
    output ariane_ace::req_t       ace_req_o,
    input  ariane_ace::resp_t      ace_resp_i
);

    // =========================================================================
    // 1. TIPI E BYPASS AXI -> REG
    // =========================================================================
    typedef logic [5:0] reg_addr_t;
    typedef logic [63:0] reg_data_t;
    typedef logic [7:0]  reg_strb_t;
    `REG_BUS_TYPEDEF_ALL(reg_bus, reg_addr_t, reg_data_t, reg_strb_t)

    reg_bus_req_t reg_req;
    reg_bus_rsp_t reg_rsp;

    logic write_trans;
    logic read_trans;

   
    assign write_trans = axi_req_i.aw_valid & axi_req_i.w_valid;
    assign read_trans  = axi_req_i.ar_valid;

  
    always_comb begin
        reg_req = '0;
        if (write_trans) begin
            reg_req.valid = 1'b1;
            reg_req.write = 1'b1;
            reg_req.addr  = axi_req_i.aw.addr[5:0]; 
            reg_req.wdata = axi_req_i.w.data;
            reg_req.wstrb = axi_req_i.w.strb;
        end else if (read_trans) begin
            reg_req.valid = 1'b1;
            reg_req.write = 1'b0;
            reg_req.addr  = axi_req_i.ar.addr[5:0];
        end
    end

    
    assign axi_resp_o.aw_ready = reg_rsp.ready & axi_req_i.w_valid;
    assign axi_resp_o.w_ready  = reg_rsp.ready & axi_req_i.aw_valid;
    assign axi_resp_o.ar_ready = reg_rsp.ready & (~write_trans); 

    // =========================================================================
    // FSM FOR THE HANDSHAKE OF RESPONSES (B VALID PER WRITE, R VALID PER READ)
    // =========================================================================
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            axi_resp_o.b_valid <= 1'b0;
            axi_resp_o.b       <= '0;
            axi_resp_o.r_valid <= 1'b0;
            axi_resp_o.r       <= '0;
        end else begin
            
            if (axi_resp_o.b_valid && axi_req_i.b_ready) begin
                axi_resp_o.b_valid <= 1'b0; 
            end else if (write_trans && reg_rsp.ready) begin
                axi_resp_o.b_valid <= 1'b1; 
                axi_resp_o.b.id    <= axi_req_i.aw.id;
                axi_resp_o.b.resp  <= reg_rsp.error ? 2'b10 : 2'b00;
                axi_resp_o.b.user  <= '0;
            end

            if (axi_resp_o.r_valid && axi_req_i.r_ready) begin
                axi_resp_o.r_valid <= 1'b0; 
            end else if (read_trans && reg_rsp.ready && !write_trans) begin
                axi_resp_o.r_valid <= 1'b1;
                axi_resp_o.r.id    <= axi_req_i.ar.id;
                axi_resp_o.r.data  <= reg_rsp.rdata;
                axi_resp_o.r.resp  <= reg_rsp.error ? 2'b10 : 2'b00;
                axi_resp_o.r.last  <= 1'b1;
                axi_resp_o.r.user  <= '0;
            end
        end
    end
    

    // =========================================================================
    //  REGTOOL
    // =========================================================================
    addr_table_reg_pkg::addr_table_reg2hw_t reg2hw;
    addr_table_reg_pkg::addr_table_hw2reg_t hw2reg;
    
    addr_table_reg_top #(
        .reg_req_t ( reg_bus_req_t ),
        .reg_rsp_t ( reg_bus_rsp_t )
    ) u_reg (
        .clk_i      ( clk_i     ),
        .rst_ni     ( rst_ni    ),
        .reg_req_i  ( reg_req   ),
        .reg_rsp_o  ( reg_rsp   ),
        .reg2hw     ( reg2hw    ),
        .hw2reg     ( hw2reg    ),
        .devmode_i  ( 1'b1      )
    );

    // =========================================================================
    //  FSM
    // =========================================================================
    typedef enum logic [1:0] {
        IDLE,
        SEND,
        WAIT_AR,
        WAIT_R
    } state_t;

    state_t curr_state, next_state;
    logic [$clog2(NUM_ENTRIES+1)-1:0] entry_idx, next_entry_idx;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            curr_state <= IDLE;
            entry_idx  <= '0;
        end else begin
            curr_state <= next_state;
            entry_idx  <= next_entry_idx;
        end
    end

    always_comb begin
        next_state     = curr_state;
        next_entry_idx = entry_idx;

        hw2reg = '0;

        case (curr_state)
            IDLE: begin
                next_entry_idx = '0;
                if (reg2hw.start.q == 1'b1)
                    next_state = SEND;
            end

            SEND: begin
                if (entry_idx == NUM_ENTRIES) begin
                    next_state = IDLE;
                    
                    hw2reg.start.d  = 1'b0;
                    hw2reg.start.de = 1'b1;
                    
                end else if (reg2hw.valid[entry_idx].q == 1'b0) begin
                    next_entry_idx = entry_idx + 1;
                end else begin
                    if (ace_resp_i.ar_ready)
                        next_state = WAIT_R;
                    else
                        next_state = WAIT_AR;
                end
            end

            WAIT_AR: begin
                if (ace_resp_i.ar_ready)
                    next_state = WAIT_R;
            end

            WAIT_R: begin
                // <-- FIX: r.last scritto corretto
                if (ace_resp_i.r_valid && ace_resp_i.r.last) begin
                    next_entry_idx = entry_idx + 1;
                    next_state     = SEND;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // =========================================================================
    //  SNOOP RESPONDER
    // =========================================================================
    logic cr_valid_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cr_valid_q <= 1'b0;
        end else if (ace_resp_i.ac_valid) begin
            cr_valid_q <= 1'b1;
        end else if (ace_resp_i.cr_ready) begin
            cr_valid_q <= 1'b0;
        end
    end

    // =========================================================================
    // RACK SIGNAL(OPTIONAL?)
    // =========================================================================
    logic rack_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rack_q <= 1'b0;
        end else begin
            
            if (curr_state == WAIT_R && ace_resp_i.r_valid && ace_resp_i.r.last) begin
                rack_q <= 1'b1;
            end else begin
                rack_q <= 1'b0;
            end
        end
    end
 

    // =========================================================================
    // OUTPUT LOGIC
    // =========================================================================
    always_comb begin
        ace_req_o = '0;
        ace_req_o.ac_ready = 1'b1;
        ace_req_o.cr_valid = cr_valid_q;
        ace_req_o.cr_resp  = 5'b00000;
        
        ace_req_o.rack = rack_q; 
        
        ace_req_o.wack = 1'b0;

        case (curr_state)
            SEND: begin
                if (entry_idx < NUM_ENTRIES && reg2hw.valid[entry_idx].q == 1'b1) begin
                    ace_req_o.ar_valid  = 1'b1;
                    ace_req_o.ar.addr   = reg2hw.data[entry_idx].q;
                    ace_req_o.ar.snoop  = 4'b1011; // COD.B CLEAN UNIQUE
                    ace_req_o.ar.domain = 2'b01;
                    ace_req_o.ar.len    = 8'h01;   
                    ace_req_o.ar.size   = 3'b011;
                    ace_req_o.ar.burst  = 2'b01;
                    ace_req_o.ar.id     = '0;
                    ace_req_o.ar.bar    = '0;
                    ace_req_o.ar.lock   = '0;
                    ace_req_o.ar.cache  = 4'b1111; // Cacheable
                end
            end
            WAIT_AR: begin
                ace_req_o.ar_valid  = 1'b1;
                ace_req_o.ar.addr   = reg2hw.data[entry_idx].q;
                ace_req_o.ar.snoop  = 4'b1011; // COD.B CLEAN UNIQUE
                ace_req_o.ar.domain = 2'b01;
                ace_req_o.ar.len    = 8'h01;  
                ace_req_o.ar.size   = 3'b011;
                ace_req_o.ar.burst  = 2'b01;
                ace_req_o.ar.id     = '0;
                ace_req_o.ar.bar    = '0;
                ace_req_o.ar.lock   = '0;
                ace_req_o.ar.cache  = 4'b1111; // Cacheable
            end
            WAIT_R: begin
                ace_req_o.r_ready = 1'b1; 
            end
            default: ;
        endcase
    end

endmodule