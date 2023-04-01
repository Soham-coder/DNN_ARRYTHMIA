module Processing_Element
    #(
        parameter DATA_WIDTH = 16,
        parameter ADDRESS_WIDTH = 9,
        
        parameter WEIGHT_READ_ADDRESS = 0,
        parameter ACTIVATION_READ_ADDRESS = 100,

        parameter WEIGHT_LOAD_ADDRESS = 0,
        parameter ACTIVATION_LOAD_ADDRESS = 100,

        parameter PARTIAL_SUM_ADDRESS = 500,

        parameter int kernel_size = 3,
        parameter int activation_size = 5

    )

    (
        input clk, 
        
        input reset,
        
        input [DATA_WIDTH-1:0] activation_input,
        input [DATA_WIDTH-1:0] filter_input,
        
        input load_enable_weight,
        input load_enable_activation,

        input start, //Control signals

        output logic [DATA_WIDTH-1:0] processingelement_out,

        output logic compute_done, //Status signals
        output logic load_done

    );

    //States

    enum logic [2:0]
    {
        IDLE = 3'b000,
        READ_WEIGHTS = 3'b001,
        READ_ACTIVATIONS = 3'b010,
        COMPUTE = 3'b011,
        WRITE_TO_SPAD = 3'b100,
        LOAD_WEIGHTS = 3'b101,
        LOAD_ACTIVATIONS = 3'b110
    }
    state;

    //Scratchpad Instantiation
    logic read_enable;
    logic write_enable;

    logic [ADDRESS_WIDTH - 1:0] write_address;
    logic [ADDRESS_WIDTH - 1:0] read_address;

    logic [DATA_WIDTH - 1:0] read_data;
    logic [DATA_WIDTH - 1:0] write_data;

    SratchPad_Memory SPAD_PE0
        (
            .clk(clk),
            .reset(reset),
            .read_request(read_enable),
            .write_enable(write_enable),
            .read_address(read_address),
            .write_address(write_address),
            .write_data(write_data),
            .read_data(read_data) 
        );
    
    // MAC Instantiation 
    logic [DATA_WIDTH-1:0] partial_sum_reg;
    logic [DATA_WIDTH-1:0] sum_input;

    logic [DATA_WIDTH-1:0] activation_input_reg;
    logic [DATA_WIDTH-1:0] filter_input_reg;

    logic mac_enable;

    MAC
        #(
            .INPUT_BITWIDTH(DATA_WIDTH),
            .OUTPUT_BITWIDTH(DATA_WIDTH) 
        )
    MAC_0
        (
            .a_in(activation_input_reg),
            .w_in(filter_input_reg),
            .sum_in(sum_input),
            .clk(clk),
            .enable(mac_enable)
            .out(partial_sum_reg) 
        );
        
    logic sum_input_mux_sel;
    
    mux_2_to_1
            #(
                .INPUT_BITWIDTH(DATA_WIDTH)
            )
    mux_2_to_1_0
            (
                .a_in(partial_sum_reg),
                .b_in(16'b0), //fixed to 0
                .sel(sum_input_mux_sel),
                .out(sum_input)
            );
    
    logic [7:0] filter_count;
    logic [2:0] iterations;

    // FSM for Processing Element

    always@(posedge clk) begin

        $display("State : %s", state.name());
        //Display state of PE at every clock edge
        if(reset)begin
            
            //Initialize registers
            filter_count <= 0;
            sum_input_mux_sel <= 0;

            //Initialize scratchpad inputs
            write_address <= WEIGHT_READ_ADDRESS;
            read_address <= WEIGHT_READ_ADDRESS;
            write_data <= 0;
            write_enable <= 0;
            read_enable <= 0;
            
            //Initialize outputs
            compute_done <= 0;
            load_done <= 0;
            
            //Initialize MAC signals
            mac_enable <= 0;
            iterations <= 0;
            
            //State -> IDLE
            state <= IDLE;
        end
        else begin
            case(state)
                IDLE: begin
                    if(start) begin
                        if (iterations == (activation_size - kernel_size + 1))begin
                            //Iterations complete
                            iterations <= 0;
                            //State -> IDLE
                            state <= IDLE;
                        end else begin
                            //If Iterations not complete
                            read_address <= ACTIVATION_READ_ADDRESS + iterations * activation_size;
                            filter_count <= 0;
                            sum_input_mux_sel <= 0;
                            read_enable <= 1;

                            //State -> READ_WEIGHTS
                            
                            state <= READ_WEIGHTS;
                        end
                    end else begin
                        if(load_enable_weight)begin
                            write_address <= WEIGHT_LOAD_ADDRESS; 
                            //Loading of weights starts at index 0
                            write_data <= filter_input;
                            write_enable <= 1;
                            filter_count <= 0;
                            
                            //State -> LOAD_WEIGHTS
                            state <= LOAD_WEIGHTS;
                        end else if (load_enable_activation)begin
                            write_enable <= 1;
                            write_address <= ACTIVATION_LOAD_ADDRESS;
                            //Loading of activations starts at 100
                            write_data <= activation_input;

                            //State -> LOAD_ACTIVATIONS
                            state <= LOAD_ACTIVATIONS;
                        end else begin
                            //Output status signals
                            load_done <= 0;
                            compute_done <= 0;
                            
                            //State -> IDLE
                            state <= IDLE;
                        end
                    end
                end

                READ_WEIGHTS: begin
                    filter_input_reg <= read_data;
                    read_enable <= 1;
                    filter_count <= filter_count + 1;

                    $display("Weight read : %d from address : %d", read_data, read_address);
                    $display("Read Enable: %d", read_enable);
                    
                    //State -> READ_ACTIVATIONS
                    state <= READ_ACTIVATIONS;
                end

                READ_ACTIVATIONS: begin
                    
                    $display("Activation read: %d from address: %d", read_data, read_address);
                    $display("Read Enable: %d", read_enable);
                    
                    activation_input_reg <= read_data;
                    read_enable <= 1;

                    read_address <= WEIGHT_READ_ADDRESS + filter_count;
                    mac_enable <= 1;

                    //State -> COMPUTE
                    state <= COMPUTE;
                end

                COMPUTE : begin
                    
                    $display("Weight taken in register: %d | Activation takem in register: %d", filter_input_reg, activation_input_reg);
                    $display("MAC output: %d", partial_sum_reg);

                    mac_enable <= 0;

                    if(filter_count == kernel_size)begin
                        activation_input_reg <= read_data;
                        read_enable <= 0;

                        write_address <= PARTIAL_SUM_ADDRESS + iterations;
                        write_enable <= 1;

                        //State -> WRITE_TO_SPAD
                        state <= WRITE_TO_SPAD;
                    end else begin
                        if(filter_count == 0)begin
                            sum_input_mux_sel <= 0; //Provide 16'b0 to the input
                        end else begin
                            sum_input_mux_sel <= 1;
                        end

                        read_address <= ACTIVATION_READ_ADDRESS + filter_count + iterations * activation_size;
                        
                        //State -> READ_WEIGHTS
                        state <= READ_WEIGHTS;
                    end
                end

                WRITE_TO_SPAD: begin
                    write_data <= partial_sum_reg;
                    read_address <= WEIGHT_READ_ADDRESS;
                    read_enable <= 1;
                    iterations <= iterations + 1;
                    //output status signal
                    compute_done <= 1;

                    //State -> IDLE
                    state <= IDLE;
                end

                LOAD_WEIGHTS: begin
                    
                    $display("Weight write: %d to address: %d", filter_input, write_address);
                    $display("Write Enable: %d", write_enable);

                    if(filter_count == (kernel_size**2 - 1))begin
                        filter_count <= 0;
                        //output status signal
                        load_done <= 1;

                        //State -> IDLE
                        state <= IDLE;
                    end else begin
                        write_data <= activation_input;
                        write_address <= write_address + 1;
                        filter_count <= filter_count + 1;

                        //State -> LOAD_ACTIVATIONS
                        state <= LOAD_ACTIVATIONS;
                    end
                end
            endcase
        end
    end

    assign processingelement_out = partial_sum_reg;

endmodule

