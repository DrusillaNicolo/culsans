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
    typedef logic [7:0] reg_addr_t;
    typedef logic [31:0] reg_data_t;
    typedef logic [3:0]  reg_strb_t;
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
            reg_req.addr  = axi_req_i.aw.addr[7:0]; 
            
            // ==========================================
            // IL MUX SALVAVITA (Lane Steering AXI)
            // ==========================================
            if (axi_req_i.aw.addr[2] == 1'b1) begin
                // Indirizzo finisce per 4 o C (es. 0x54 END_FLAG)
                reg_req.wdata = axi_req_i.w.data[63:32];
                reg_req.wstrb = axi_req_i.w.strb[7:4];
            end else begin
                // Indirizzo finisce per 0 o 8 (es. 0x50 START)
                reg_req.wdata = axi_req_i.w.data[31:0];
                reg_req.wstrb = axi_req_i.w.strb[3:0];
            end
            
        end else if (read_trans) begin
            reg_req.valid = 1'b1;
            reg_req.write = 1'b0;
            reg_req.addr  = axi_req_i.ar.addr[7:0];
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
                if (axi_req_i.ar.addr[2] == 1'b1)
                axi_resp_o.r.data <= {reg_rsp.rdata, 32'h0};  // upper half
            else
                axi_resp_o.r.data <= {32'h0, reg_rsp.rdata};  // lower half
            
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

 localparam logic [31:0] CACHE_LINE_SIZE = 32'd16; // 16 Byte = 128 bit
    logic [31:0] curr_addr_q, curr_addr_d;

    // =========================================================================
    //  FSM
    // =========================================================================
    typedef enum logic [2:0] {
        IDLE,
        SEND,
        WAIT_AR,
        WAIT_R,
        SEND_INTERMEDIATE,
        WAIT_END
    } state_t;

    state_t curr_state, next_state;
    logic [$clog2(NUM_ENTRIES+1)-1:0] entry_idx, next_entry_idx;

    // 1. FLIP-FLOP Sequenziali
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            curr_state  <= IDLE;
            entry_idx   <= '0;
            curr_addr_q <= '0; // Reset del contatore indirizzo
        end else begin
            curr_state  <= next_state;
            entry_idx   <= next_entry_idx;
            curr_addr_q <= curr_addr_d; // Aggiornamento indirizzo
        end
    end

    // 2. Logica Combinatoria FSM
    always_comb begin
        next_state     = curr_state;
        next_entry_idx = entry_idx;
        curr_addr_d    = curr_addr_q; // Di default mantiene l'indirizzo attuale

        hw2reg = '0;

        case (curr_state)
            IDLE: begin
                next_entry_idx = '0;
                if (reg2hw.start.q == 1'b1) begin
                    next_state = SEND;
                    // PRE-CARICO l'indirizzo iniziale della primissima entry
                    curr_addr_d = reg2hw.start_addr[0].q;
                end
            end

            SEND: begin
                if (entry_idx == NUM_ENTRIES) begin
                    next_state = WAIT_END;
                    hw2reg.start.d  = 1'b0;
                    hw2reg.start.de = 1'b1;
                    hw2reg.end_flag.d  = 1'b1;
                    hw2reg.end_flag.de = 1'b1;
                    
                // ---> FIX: Salta la entry se NON è valida, o NON è dirty, o NON è shared
                end else if (!(reg2hw.valid[entry_idx].q == 1'b1 && reg2hw.dirty[entry_idx].q == 1'b1 && reg2hw.shared[entry_idx].q == 1'b1)) begin
                    
                    // Entry ignorata: salta alla prossima
                    next_entry_idx = entry_idx + 1;
                    
                    // Pre-carica l'indirizzo della entry successiva (se esiste)
                    if (entry_idx < NUM_ENTRIES - 1) begin
                        curr_addr_d = reg2hw.start_addr[entry_idx + 1].q;
                    end
                    
                end else begin
                    // Entry perfetta (Valid, Dirty e Shared tutti a 1): faccio la richiesta
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
                if (ace_resp_i.r_valid && ace_resp_i.r.last) begin
                    // Invalidazione completata. Andiamo a vedere se dobbiamo incrementare!
                    next_state = SEND_INTERMEDIATE; 
                end
            end

            SEND_INTERMEDIATE: begin
                // Controllo se sommando 16 sforo la fine del range stabilito
                if ((curr_addr_q + CACHE_LINE_SIZE) <= reg2hw.end_addr[entry_idx].q) begin
                    // 1. SONO ANCORA NEL RANGE:
                    // Incremento l'indirizzo, tengo lo stesso entry_idx e torno a SEND
                    curr_addr_d = curr_addr_q + CACHE_LINE_SIZE;
                    next_state  = SEND;
                    
                end else begin
                    // 2. RANGE FINITO:
                    // Passo alla entry successiva
                    hw2reg.shared[entry_idx].d  = 1'b0; 
                    hw2reg.shared[entry_idx].de = 1'b1; 
                    next_entry_idx = entry_idx + 1;
                    
                    // Pre-carico il nuovo start_addr per la prossima entry
                    if (entry_idx < NUM_ENTRIES - 1) begin
                        curr_addr_d = reg2hw.start_addr[entry_idx + 1].q;
                    end
                    
                    next_state = SEND;
                end
            end

            WAIT_END: begin
                if(reg2hw.end_flag.q == 1'b0)
                    next_state = IDLE;
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
        // Valori di default
        ace_req_o = '0;
        ace_req_o.ac_ready = 1'b1;
        ace_req_o.cr_valid = cr_valid_q;
        ace_req_o.cr_resp  = 5'b00000;
        
        ace_req_o.rack = rack_q; 
        ace_req_o.wack = 1'b0;

        case (curr_state)
            SEND: begin
                if (entry_idx < NUM_ENTRIES && reg2hw.valid[entry_idx].q == 1'b1 && reg2hw.dirty[entry_idx].q == 1'b1 && reg2hw.shared[entry_idx].q == 1'b1) begin
                    ace_req_o.ar_valid  = 1'b1;
                    
                    // ---> FIX: Usiamo l'indirizzo dinamico calcolato dalla FSM!
                    ace_req_o.ar.addr   = curr_addr_q; 
                    
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
                
                // ---> FIX: Anche qui dobbiamo mantenere l'indirizzo dinamico!
                ace_req_o.ar.addr   = curr_addr_q; 
                
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
            
            // SEND_INTERMEDIATE non è elencato qui. 
            // Questo fa sì che ar_valid scenda a 0 (tramite i valori di default)
            // permettendo un handshake ACE corretto!
            default: ;
        endcase
    end

endmodule