module MAC
    #(
        parameter INPUT_BITWIDTH = 16,
        parameter OUTPUT_BITWIDTH = 2*INPUT_BITWIDTH 
    )

    (
        input  [INPUT_BITWIDTH - 1:0] a_in,
        input  [INPUT_BITWIDTH - 1:0] w_in,
        input  [INPUT_BITWIDTH - 1:0] sum_in,
        input  enable, clk,
        output logic [OUTPUT_BITWIDTH - 1:0] out 
    );

    logic [OUTPUT_BITWIDTH - 1:0] mult_out;

    always_ff@(posedge clk)begin
        if(enable)begin
            mult_out = a_in * w_in; //combinational block
            out <= mult_out + sum_in //non-blocking will be updated at next clock edge
        end
    end
endmodule