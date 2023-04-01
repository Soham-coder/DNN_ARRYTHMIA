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