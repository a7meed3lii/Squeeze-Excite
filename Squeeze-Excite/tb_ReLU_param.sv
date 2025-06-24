// Testbench for serial ReLU_param
module tb_ReLU_param;
    logic clk, rst;
    logic signed [15:0] in_data;
    logic [15:0] out_data;
    logic out_valid;

    ReLU_param #(.DATA_WIDTH(16)) uut (
        .clk(clk), .rst(rst), .in_data(in_data), .out_data(out_data), .out_valid(out_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        in_data = 0;
        #20;
        rst = 0;
        // Feed 4 test values
        in_data = -5; @(negedge clk);
        in_data = 0; @(negedge clk);
        in_data = 7; @(negedge clk);
        in_data = -2; @(negedge clk);
        // Wait for output
        repeat (4) @(negedge clk);
        if (out_valid) $display("Output: %d", out_data);
        $finish;
    end
endmodule 