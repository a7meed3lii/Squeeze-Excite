// Fully serial, area-minimal ReLU
module ReLU_param #(
    parameter DATA_WIDTH = 16
) (
    input  logic clk,
    input  logic rst,
    input  logic signed [DATA_WIDTH-1:0] in_data,
    output logic [DATA_WIDTH-1:0] out_data,
    output logic out_valid
);
    logic signed [DATA_WIDTH-1:0] in_reg;
    logic [DATA_WIDTH-1:0] out_reg;
    logic valid_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            in_reg <= 0;
            out_reg <= 0;
            valid_reg <= 0;
        end else begin
            in_reg <= in_data;
            out_reg <= (in_data > 0) ? in_data : 0;
            valid_reg <= 1;
        end
    end

    assign out_data = out_reg;
    assign out_valid = valid_reg;
endmodule
