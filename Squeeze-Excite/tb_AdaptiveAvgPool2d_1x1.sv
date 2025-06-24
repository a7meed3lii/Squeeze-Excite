// Testbench for serial AdaptiveAvgPool2d_1x1
module tb_AdaptiveAvgPool2d_1x1;
    logic clk, rst;
    logic [15:0] in_data;
    logic [15:0] out_data;
    logic out_valid;

    AdaptiveAvgPool2d_1x1 #(.DATA_WIDTH(16), .IN_HEIGHT(2), .IN_WIDTH(2), .CHANNELS(1)) uut (
        .clk(clk), .rst(rst), .in_data(in_data), .out_data(out_data), .out_valid(out_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        in_data = 0;
        #20;
        rst = 0;
        // Feed 4 values for 2x2 input
        in_data = 16'd4; @(negedge clk);
        in_data = 16'd8; @(negedge clk);
        in_data = 16'd12; @(negedge clk);
        in_data = 16'd16; @(negedge clk);
        // Wait for output
        repeat (4) @(negedge clk);
        if (out_valid) $display("Output: %d", out_data);
        $finish;
    end
endmodule 