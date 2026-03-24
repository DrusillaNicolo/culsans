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
    // 1. TIPI E BRIDGE AXI -> REG
    // =========================================================================
    typedef logic [5:0]  reg_addr_t;
    typedef logic [63:0] reg_data_t;
    typedef logic [7:0]  reg_strb_t;
    `REG_BUS_TYPEDEF_ALL(reg_bus, reg_addr_t, reg_data_t, reg_strb_t)

    reg_bus_req_t reg_req;
    reg_bus_rsp_t reg_rsp;

    axi_to_reg #(
        .ADDR_WIDTH ( 64                          ),
        .DATA_WIDTH ( 64                          ),
        .ID_WIDTH   ( culsans_pkg::IdWidthSlave   ),
        .USER_WIDTH ( culsans_pkg::UserWidth      ),
        .axi_req_t  ( culsans_pkg::req_slv_t      ),
        .axi_rsp_t  ( culsans_pkg::resp_slv_t     ),
        .reg_req_t  ( reg_bus_req_t               ),
        .reg_rsp_t  ( reg_bus_rsp_t               )
    ) i_axi_to_reg (
        .clk_i      ( clk_i      ),
        .rst_ni     ( rst_ni     ),
        .testmode_i ( 1'b0       ),
        .axi_req_i  ( axi_req_i  ),
        .axi_rsp_o  ( axi_resp_o ),
        .reg_req_o  ( reg_req    ),
        .reg_rsp_i  ( reg_rsp    )
    );

    // =========================================================================
    // 2. REGISTRI GENERATI DA REGTOOL
    // =========================================================================
    addr_table_reg_pkg::addr_table_reg2hw_t reg2hw;

    addr_table_reg_top #(
        .reg_req_t ( reg_bus_req_t ),
        .reg_rsp_t ( reg_bus_rsp_t )
    ) u_reg (
        .clk_i      ( clk_i    ),
        .rst_ni     ( rst_ni   ),
        .reg_req_i  ( reg_req  ),
        .reg_rsp_o  ( reg_rsp  ),
        .reg2hw     ( reg2hw   ),
        .devmode_i  ( 1'b1     )
    );

    // =========================================================================
    // 3. FSM
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

        case (curr_state)
            IDLE: begin
                next_entry_idx = '0;
                if (reg2hw.start.q == 1'b1)
                    next_state = SEND;
            end

            SEND: begin
                if (entry_idx == NUM_ENTRIES) begin
                    next_state = IDLE;
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
                if (ace_resp_i.r_valid) begin
                    next_entry_idx = entry_idx + 1;
                    next_state     = SEND;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // =========================================================================
    // 3.5 SNOOP RESPONDER (LOGICA SEQUENZIALE COMPATTA)
    // =========================================================================
    logic cr_valid_q;

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            cr_valid_q <= 1'b0;
        end else if (ace_resp_i.ac_valid) begin
            cr_valid_q <= 1'b1;         // Accendi la risposta quando arriva lo snoop
        end else if (ace_resp_i.cr_ready) begin
            cr_valid_q <= 1'b0;         // Spegnila SOLO quando la CCU l'ha letta
        end
    end

    // =========================================================================
    // 4. LOGICA USCITE
    // =========================================================================
    always_comb begin
        ace_req_o = '0;

        // ---------------------------------------------------------------------
        // SNOOP RESPONDER
        // La CCU manda ac_valid quando vuole snoopare il nostro modulo.
        // Registriamo la richiesta e teniamo cr_valid alto finché non riceve cr_ready.
        // ---------------------------------------------------------------------
        ace_req_o.ac_ready = 1'b1;
        ace_req_o.cr_valid = cr_valid_q;
        ace_req_o.cr_resp  = 5'b00000;

        ace_req_o.rack = 1'b0;
        ace_req_o.wack = 1'b0;

        // ---------------------------------------------------------------------
        // FSM - MakeInvalid
        // ---------------------------------------------------------------------
        case (curr_state)
            SEND: begin
                if (entry_idx < NUM_ENTRIES &&
                    reg2hw.valid[entry_idx].q == 1'b1) begin
                    ace_req_o.ar_valid  = 1'b1;
                    ace_req_o.ar.addr   = reg2hw.data[entry_idx].q;
                    ace_req_o.ar.snoop  = 4'b1101;
                    ace_req_o.ar.domain = 2'b10;
                    ace_req_o.ar.len    = '0;
                    ace_req_o.ar.size   = 3'b011;
                    ace_req_o.ar.burst  = 2'b01;
                    ace_req_o.ar.id     = '0;
                    ace_req_o.ar.bar    = '0;
                    ace_req_o.ar.lock   = '0;
                    ace_req_o.ar.cache  = 4'b0010;
                end
            end

            WAIT_AR: begin
                ace_req_o.ar_valid  = 1'b1;
                ace_req_o.ar.addr   = reg2hw.data[entry_idx].q;
                ace_req_o.ar.snoop  = 4'b1101;
                ace_req_o.ar.domain = 2'b10;
                ace_req_o.ar.len    = '0;
                ace_req_o.ar.size   = 3'b011;
                ace_req_o.ar.burst  = 2'b01;
                ace_req_o.ar.id     = '0;
                ace_req_o.ar.bar    = '0;
                ace_req_o.ar.lock   = '0;
                ace_req_o.ar.cache  = 4'b0010;
            end

            WAIT_R: begin
                ace_req_o.r_ready = 1'b1;
            end

            default: ;
        endcase
    end

endmodule