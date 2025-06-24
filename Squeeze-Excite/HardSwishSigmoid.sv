// Fully serial, area-minimal Hard Sigmoid and Hard Swish
module HardSwishSigmoid #(
    parameter DATA_WIDTH = 16
) (
    input  logic clk,
    input  logic rst,
    input  logic signed [DATA_WIDTH-1:0] in_data,
    output logic signed [DATA_WIDTH-1:0] hsigmoid_out,
    output logic signed [DATA_WIDTH-1:0] hswish_out,
    output logic out_valid
);
    logic signed [DATA_WIDTH-1:0] in_reg, relu6_reg;
    logic signed [DATA_WIDTH-1:0] hsigmoid_reg, hswish_reg;
    logic valid_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            in_reg <= 0;
            relu6_reg <= 0;
            hsigmoid_reg <= 0;
            hswish_reg <= 0;
            valid_reg <= 0;
        end else begin
            // Hard sigmoid: (x + 3).clamp(0,6) / 6 using Q8.8 fixed point
            in_reg <= in_data;
            automatic logic signed [DATA_WIDTH-1:0] temp;
            temp = in_data + 16'sd768; // add 3.0
            if (temp < 0)
                relu6_reg <= 0;
            else if (temp > 16'sd1536)
                relu6_reg <= 16'sd1536; // clamp to 6.0
            else
                relu6_reg <= temp;
            hsigmoid_reg <= relu6_reg / 6;
            hswish_reg <= (in_data * relu6_reg) / 6;
            valid_reg <= 1;
        end
    end
    assign hsigmoid_out = hsigmoid_reg;
    assign hswish_out = hswish_reg;
    assign out_valid = valid_reg;
endmodule 
