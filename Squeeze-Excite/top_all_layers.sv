// SE (Squeeze-and-Excitation) Module - Fixed Multiple Driver Issues
module top_all_layers(
    input logic clk,
    input logic rst,
    input logic [15:0] in_data,          // Input stream
    input logic [15:0] mean1, mean2,     // BatchNorm parameters
    input logic [15:0] variance1, variance2,
    input logic [15:0] gamma1, gamma2,
    input logic [15:0] beta1, beta2,
    input logic load_kernel_conv_param,
    input logic load_kernel_conv_spec,
    output logic [15:0] out_data
);
    // SE Module Parameters
    localparam IN_CHANNELS = 16;
    localparam REDUCED_CHANNELS = 4;
    localparam POOL_SIZE = 64; // 8x8 spatial input
    
    // SE Module State Machine
    typedef enum logic [3:0] {
        IDLE, LOAD_KERNELS1, LOAD_KERNELS2, COLLECT_INPUT, 
        GLOBAL_POOL, BATCH_NORM1, RELU1, CONV1, 
        CONV2, BATCH_NORM2, HARD_SIGMOID, MULTIPLY, OUTPUT
    } se_state_t;
    se_state_t state;
    
    // Storage Arrays
    logic [15:0] input_buffer [IN_CHANNELS-1:0][POOL_SIZE-1:0];
    logic [15:0] pooled [IN_CHANNELS-1:0];
    logic [15:0] bn1_out [IN_CHANNELS-1:0];
    logic [15:0] relu_out [IN_CHANNELS-1:0];
    logic [15:0] conv1_out [REDUCED_CHANNELS-1:0];
    logic [15:0] conv2_out [IN_CHANNELS-1:0];
    logic [15:0] bn2_out [IN_CHANNELS-1:0];
    logic [15:0] hsigmoid_out [IN_CHANNELS-1:0];
    logic [15:0] original_input [IN_CHANNELS-1:0];
    
    // Convolution Kernels
    logic [15:0] kernel1 [REDUCED_CHANNELS-1:0][IN_CHANNELS-1:0];
    logic [15:0] kernel2 [IN_CHANNELS-1:0][REDUCED_CHANNELS-1:0];
    
    // Counters
    logic [$clog2(IN_CHANNELS)-1:0] ch_cnt;
    logic [$clog2(POOL_SIZE)-1:0] pix_cnt;
    logic [$clog2(IN_CHANNELS*REDUCED_CHANNELS)-1:0] k1_cnt;
    logic [$clog2(IN_CHANNELS*REDUCED_CHANNELS)-1:0] k2_cnt;
    
    // Kernel loading indices
    logic [$clog2(IN_CHANNELS)-1:0] k1_ic, k2_rc;
    logic [$clog2(REDUCED_CHANNELS)-1:0] k1_rc, k2_ic;
    
    // SE Module State Machine
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            ch_cnt <= 0;
            pix_cnt <= 0;
            k1_cnt <= 0;
            k2_cnt <= 0;
            out_data <= 0;
            k1_ic <= 0; k1_rc <= 0;
            k2_ic <= 0; k2_rc <= 0;
            
            // Initialize all arrays in reset to prevent X values
            for (int i = 0; i < IN_CHANNELS; i++) begin
                pooled[i] <= 0;
                bn1_out[i] <= 0;
                relu_out[i] <= 0;
                conv2_out[i] <= 0;
                bn2_out[i] <= 0;
                hsigmoid_out[i] <= 0;
                original_input[i] <= 0;
                for (int j = 0; j < POOL_SIZE; j++) begin
                    input_buffer[i][j] <= 0;
                end
                for (int k = 0; k < REDUCED_CHANNELS; k++) begin
                    kernel1[k][i] <= 0;
                    kernel2[i][k] <= 0;
                end
            end
            for (int i = 0; i < REDUCED_CHANNELS; i++) begin
                conv1_out[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    ch_cnt <= 0;
                    pix_cnt <= 0;
                    out_data <= 0;
                    if (load_kernel_conv_param) state <= LOAD_KERNELS1;
                    else if (load_kernel_conv_spec) state <= LOAD_KERNELS2;
                    else if (!load_kernel_conv_param && !load_kernel_conv_spec) state <= COLLECT_INPUT;
                end
                
                LOAD_KERNELS1: begin
                    kernel1[k1_rc][k1_ic] <= in_data;
                    k1_cnt <= k1_cnt + 1;
                    
                    if (k1_ic == IN_CHANNELS-1) begin
                        k1_ic <= 0;
                        if (k1_rc == REDUCED_CHANNELS-1) begin
                            k1_rc <= 0;
                            state <= IDLE;
                        end else k1_rc <= k1_rc + 1;
                    end else k1_ic <= k1_ic + 1;
                end
                
                LOAD_KERNELS2: begin
                    kernel2[k2_ic][k2_rc] <= in_data;
                    k2_cnt <= k2_cnt + 1;
                    
                    if (k2_rc == REDUCED_CHANNELS-1) begin
                        k2_rc <= 0;
                        if (k2_ic == IN_CHANNELS-1) begin
                            k2_ic <= 0;
                            state <= IDLE;
                        end else k2_ic <= k2_ic + 1;
                    end else k2_rc <= k2_rc + 1;
                end
                
                COLLECT_INPUT: begin
                    input_buffer[ch_cnt][pix_cnt] <= in_data;
                    
                    if (pix_cnt == POOL_SIZE-1) begin
                        pix_cnt <= 0;
                        if (ch_cnt == IN_CHANNELS-1) begin
                            ch_cnt <= 0;
                            state <= GLOBAL_POOL;
                        end else ch_cnt <= ch_cnt + 1;
                    end else pix_cnt <= pix_cnt + 1;
                end
                
                GLOBAL_POOL: begin
                    // Compute average for each channel
                    automatic logic [23:0] sum = 0;
                    for (int p = 0; p < POOL_SIZE; p++) begin
                        sum = sum + input_buffer[ch_cnt][p];
                    end
                    pooled[ch_cnt] <= sum[21:6]; // Divide by 64 using bit shift
                    original_input[ch_cnt] <= sum[21:6]; // Store for final multiply
                    
                    if (ch_cnt == IN_CHANNELS-1) begin
                        ch_cnt <= 0;
                        state <= BATCH_NORM1;
                    end else ch_cnt <= ch_cnt + 1;
                end
                
                BATCH_NORM1: begin
                    // BatchNorm with safe division
                    if (variance1 != 0 && variance1 != 16'hXXXX) begin
                        automatic logic signed [31:0] temp = ((pooled[ch_cnt] - mean1) * gamma1);
                        bn1_out[ch_cnt] <= temp[31:16] + beta1; // Use upper bits to avoid overflow
                    end else begin
                        bn1_out[ch_cnt] <= pooled[ch_cnt]; // Pass-through if variance is invalid
                    end
                    
                    if (ch_cnt == IN_CHANNELS-1) begin
                        ch_cnt <= 0;
                        state <= RELU1;
                    end else ch_cnt <= ch_cnt + 1;
                end
                
                RELU1: begin
                    relu_out[ch_cnt] <= (bn1_out[ch_cnt][15] == 1'b0) ? bn1_out[ch_cnt] : 16'h0000;
                    
                    if (ch_cnt == IN_CHANNELS-1) begin
                        ch_cnt <= 0;
                        state <= CONV1;
                    end else ch_cnt <= ch_cnt + 1;
                end
                
                CONV1: begin
                    // 1x1 Convolution: 16 → 4 channels
                    automatic logic [31:0] acc = 0;
                    for (int ic = 0; ic < IN_CHANNELS; ic++) begin
                        acc = acc + (relu_out[ic] * kernel1[ch_cnt][ic]);
                    end
                    conv1_out[ch_cnt] <= acc[23:8]; // Use middle bits to prevent overflow
                    
                    if (ch_cnt == REDUCED_CHANNELS-1) begin
                        ch_cnt <= 0;
                        state <= CONV2;
                    end else ch_cnt <= ch_cnt + 1;
                end
                
                CONV2: begin
                    // 1x1 Convolution: 4 → 16 channels
                    automatic logic [31:0] acc = 0;
                    for (int rc = 0; rc < REDUCED_CHANNELS; rc++) begin
                        acc = acc + (conv1_out[rc] * kernel2[ch_cnt][rc]);
                    end
                    conv2_out[ch_cnt] <= acc[23:8]; // Use middle bits to prevent overflow
                    
                    if (ch_cnt == IN_CHANNELS-1) begin
                        ch_cnt <= 0;
                        state <= BATCH_NORM2;
                    end else ch_cnt <= ch_cnt + 1;
                end
                
                BATCH_NORM2: begin
                    if (variance2 != 0 && variance2 != 16'hXXXX) begin
                        automatic logic signed [31:0] temp = ((conv2_out[ch_cnt] - mean2) * gamma2);
                        bn2_out[ch_cnt] <= temp[31:16] + beta2;
                    end else begin
                        bn2_out[ch_cnt] <= conv2_out[ch_cnt];
                    end
                    
                    if (ch_cnt == IN_CHANNELS-1) begin
                        ch_cnt <= 0;
                        state <= HARD_SIGMOID;
                    end else ch_cnt <= ch_cnt + 1;
                end
                
                HARD_SIGMOID: begin
                    // Hard Sigmoid: clip(x + 3, 0, 6) / 6
                    automatic logic signed [16:0] temp = bn2_out[ch_cnt] + 17'h0003;
                    if (temp[16] || temp < 0) begin
                        hsigmoid_out[ch_cnt] <= 0; // Negative -> 0
                    end else if (temp > 17'h0006) begin
                        hsigmoid_out[ch_cnt] <= 16'h2AAA; // Clamp to ~1.0 in fixed point
                    end else begin
                        hsigmoid_out[ch_cnt] <= {temp[15:0], 2'b00} / 6; // Scale properly
                    end
                    
                    if (ch_cnt == IN_CHANNELS-1) begin
                        ch_cnt <= 0;
                        state <= MULTIPLY;
                    end else ch_cnt <= ch_cnt + 1;
                end
                
                MULTIPLY: begin
                    // SE Final Output: original_input * hsigmoid_out
                    automatic logic [31:0] result = original_input[ch_cnt] * hsigmoid_out[ch_cnt];
                    out_data <= result[23:8]; // Scale result appropriately
                    
                    if (ch_cnt == IN_CHANNELS-1) begin
                        ch_cnt <= 0;
                        state <= OUTPUT;
                    end else ch_cnt <= ch_cnt + 1;
                end
                
                OUTPUT: begin
                    // Final output phase
                    automatic logic [31:0] final_result = original_input[ch_cnt] * hsigmoid_out[ch_cnt];
                    out_data <= final_result[23:8];
                    
                    if (ch_cnt == IN_CHANNELS-1) begin
                        ch_cnt <= 0;
                        state <= IDLE; // Return to IDLE when complete
                    end else ch_cnt <= ch_cnt + 1;
                end
            endcase
        end
    end
endmodule 