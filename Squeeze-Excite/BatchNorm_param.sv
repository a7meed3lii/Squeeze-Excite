// Fully serial, area-minimal Batch Normalization
module BatchNorm_param #(
    parameter DATA_WIDTH = 16
) (
    input  logic clk,
    input  logic rst,
    input  logic signed [DATA_WIDTH-1:0] in_data,
    input  logic signed [DATA_WIDTH-1:0] mean,
    input  logic signed [DATA_WIDTH-1:0] variance,
    input  logic signed [DATA_WIDTH-1:0] gamma,
    input  logic signed [DATA_WIDTH-1:0] beta,
    output logic signed [DATA_WIDTH-1:0] out_data,
    output logic out_valid
);
    // Internal registers for pipelining
    logic signed [DATA_WIDTH-1:0] in_reg, mean_reg, var_reg, gamma_reg, beta_reg;
    logic signed [DATA_WIDTH-1:0] out_reg;
    logic valid_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            in_reg   <= 0;
            mean_reg <= 0;
            var_reg  <= 0;
            gamma_reg<= 0;
            beta_reg <= 0;
            out_reg  <= 0;
            valid_reg<= 0;
        end else begin
            in_reg   <= in_data;
            mean_reg <= mean;
            var_reg  <= variance;
            gamma_reg<= gamma;
            beta_reg <= beta;
            automatic logic signed [31:0] num;
            automatic logic signed [15:0] denom;
            num = (in_data - mean) * gamma;
            denom = (variance != 0) ? variance : 16'sd1;
            out_reg <= (num / denom) + beta;
            valid_reg <= 1;
        end
    end
    assign out_data = out_reg;
    assign out_valid = valid_reg;
endmodule 
