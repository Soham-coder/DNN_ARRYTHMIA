module SPad 
    #(
        parameter DATA_BITWIDTH = 16,
        parameter ADDR_BITWIDTH = 9
    )
    (
        input clk,
        input reset,
        input read_request,
        input write_enable,
        input [ADDR_BITWIDTH - 1:0] read_addr;
        input [ADDR_BITWIDTH - 1:0] write_addr; 
    )