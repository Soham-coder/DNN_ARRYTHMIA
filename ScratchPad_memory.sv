module ScratchPad_Memory 
    #(
        parameter DATA_BITWIDTH = 16,
        parameter ADDRESS_BITWIDTH = 9
    )
    (
        input clk,
        input reset,
        input read_request,
        input write_enable,
        input [ADDR_BITWIDTH - 1:0] read_address,
        input [ADDR_BITWIDTH - 1:0] write_address,
        input [DATA_BITWIDTH - 1:0] write_data,
        output logic [DATA_BITWIDTH - 1:0] read_data 
    );

    logic [DATA_BITWIDTH - 1:0] memory [0: (1 << ADDRESS_BITWIDTH) -1]; //scratchpad memory 2^AADR_WIDTH locations
                                                                     //Each location is 16 bits width
    //default - 512(2^9) 16-bit memory. Total size = 1kB

    logic [DATA_BITWIDTH - 1:0] data;

    always@(posedge clk)
    begin : READ
        if(reset)begin
        data <= 0;
        end
        else begin
            if(read_request)begin
                data <= memory[read_address];
                $display("Read address given to SPad: %d", read_address);
                $display("Read data fetched from read address: %d", data);
            end
            else begin
                data <= 10101; //Fixed data at data bus when read is not requested
            end
        end
    end

    assign read_data = data; //send the local variable to the output

    always@(posedge clk)
    begin : WRITE
        if(write_enable && !reset)begin //if write enable is high and block not reset
            memory[write_address] <= write_data; //put write data to scratchpad memory write address
        end
    end

endmodule
