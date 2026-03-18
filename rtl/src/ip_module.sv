module ip_module (
    input  logic clk_i,
    input  logic rst_ni,

    // slave for axibar to receive data from core0
    input  culsans_pkg::req_slv_t  axi_req_i,
    output culsans_pkg::resp_slv_t axi_resp_o,

    // master for CCU to send invalidations
    output ariane_axi::req_t       ace_req_o,
    input  ariane_axi::resp_t      ace_resp_i

);

//QUA BISOGNSA METTERE LA LOGICA E LA FSM