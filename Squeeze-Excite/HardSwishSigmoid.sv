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
            in_reg <= in_data;
            relu6_reg <= (in_data + 3 < 0) ? 0 : ((in_data + 3 > 6) ? 6 : in_data + 3);
            hsigmoid_reg <= relu6_reg / 6;
            hswish_reg <= (in_data * relu6_reg) / 6;
            valid_reg <= 1;
        end
    end
    assign hsigmoid_out = hsigmoid_reg;
    assign hswish_out = hswish_reg;
    assign out_valid = valid_reg;
endmodule 