module mux_2_to_1
    #(
        parameter INPUT_BITWIDTH = 16
    )
    (
        input [INPUT_BITWIDTH - 1:0] a_in,
        input [INPUT_BITWIDTH - 1:0] b_in,
        input                        sel,
        output [OUTPUT_BITWIDTH - 1:0] out
    );

    assign out = sel? a_in : b_in;
endmodule