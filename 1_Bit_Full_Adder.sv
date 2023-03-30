module Full_Adder
    (
        input A_in,
        input B_in,
        input C_in,
        output logic S_out,
        output logic C_out
    );

    assign {C_out, S_out} = A_in + B_in + C_in;

endmodule