// SE Module 1x1 Convolution (Reduction: 16→4 channels)
module Conv2D_param #(
    parameter DATA_WIDTH = 16,
    parameter IN_HEIGHT = 1,      // After global avg pool
    parameter IN_WIDTH = 1,       // After global avg pool  
    parameter KERNEL_SIZE = 1,    // 1x1 convolution
    parameter STRIDE = 1,
    parameter IN_CHANNELS = 16,   // Input channels
    parameter OUT_CHANNELS = 4    // Reduced channels
) (
    input  logic clk,
    input  logic rst,
    input  logic load_kernel, // 1: load kernel, 0: process input
    input  logic [DATA_WIDTH-1:0] in_data, // input data or kernel data
    output logic [DATA_WIDTH-1:0] out_data,
    output logic out_valid
);
    // Kernel storage for 1x1 convolution (OUT_CHANNELS x IN_CHANNELS)
    (* ram_style = "distributed" *) logic signed [DATA_WIDTH-1:0] kernel [OUT_CHANNELS-1:0][IN_CHANNELS-1:0];
    
    // Input channel buffer (to store all 16 input channels)
    logic [DATA_WIDTH-1:0] input_channels [IN_CHANNELS-1:0];
    
    // State machine and counters
    typedef enum logic [1:0] {IDLE, LOAD_INPUTS, COMPUTE, OUTPUT} state_t;
    state_t state;
    
    logic [$clog2(IN_CHANNELS*OUT_CHANNELS)-1:0] kernel_cnt;
    logic [$clog2(OUT_CHANNELS)-1:0] k_ocnt, ocnt;
    logic [$clog2(IN_CHANNELS)-1:0] k_icnt, icnt, in_cnt;
    logic signed [31:0] acc;
    logic kernel_loaded;
    logic input_ready;

    // Kernel loading process
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            kernel_cnt <= 0;
            kernel_loaded <= 0;
            k_ocnt <= 0;
            k_icnt <= 0;
        end else if (load_kernel) begin
            // Load kernel weights for 1x1 convolution
            kernel[k_ocnt][k_icnt] <= in_data;
            
            if (kernel_cnt == IN_CHANNELS*OUT_CHANNELS-1) begin
                kernel_loaded <= 1;
                kernel_cnt <= 0;
                k_ocnt <= 0;
                k_icnt <= 0;
            end else begin
                kernel_cnt <= kernel_cnt + 1;
                // Update kernel loading indices
                if (k_icnt == IN_CHANNELS-1) begin
                    k_icnt <= 0;
                    if (k_ocnt == OUT_CHANNELS-1) 
                        k_ocnt <= 0;
                    else 
                        k_ocnt <= k_ocnt + 1;
                end else begin
                    k_icnt <= k_icnt + 1;
                end
            end
        end
    end

    // Input processing and 1x1 convolution
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            in_cnt <= 0;
            ocnt <= 0;
            icnt <= 0;
            acc <= 0;
            out_data <= 0;
            out_valid <= 0;
            input_ready <= 0;
            for (int i = 0; i < IN_CHANNELS; i++) begin
                input_channels[i] <= 0;
            end
        end else if (!load_kernel && kernel_loaded) begin
            case (state)
                IDLE: begin
                    in_cnt <= 0;
                    ocnt <= 0;
                    icnt <= 0;
                    acc <= 0;
                    out_valid <= 0;
                    input_ready <= 0;
                    state <= LOAD_INPUTS;
                end
                
                LOAD_INPUTS: begin
                    // Load input data for all channels (since we're after global avg pool)
                    input_channels[in_cnt] <= in_data;
                    
                    if (in_cnt == IN_CHANNELS-1) begin
                        in_cnt <= 0;
                        input_ready <= 1;
                        state <= COMPUTE;
                    end else begin
                        in_cnt <= in_cnt + 1;
                    end
                    out_valid <= 0;
                end
                
                COMPUTE: begin
                    // Perform 1x1 convolution: accumulate input_channels[icnt] * kernel[ocnt][icnt]
                    acc <= acc + (input_channels[icnt] * kernel[ocnt][icnt]);
                    
                    if (icnt == IN_CHANNELS-1) begin
                        icnt <= 0;
                        state <= OUTPUT;
                    end else begin
                        icnt <= icnt + 1;
                    end
                    out_valid <= 0;
                end
                
                OUTPUT: begin
                    out_data <= acc[DATA_WIDTH-1:0];
                    out_valid <= 1;
                    acc <= 0;
                    
                    // Move to next output channel or finish
                    if (ocnt == OUT_CHANNELS-1) begin
                        ocnt <= 0;
                        state <= IDLE;  // Go back to IDLE for next input set
                    end else begin
                        ocnt <= ocnt + 1;
                        state <= COMPUTE;
                    end
                end
            endcase
        end else begin
            out_valid <= 0;
        end
    end
endmodule 