// Testbench for serial HardSwishSigmoid
module tb_HardSwishSigmoid;
    logic clk, rst;
    logic signed [15:0] in_data;
    logic signed [15:0] hsigmoid_out, hswish_out;
    logic out_valid;

    HardSwishSigmoid #(.DATA_WIDTH(16)) uut (
        .clk(clk), .rst(rst), .in_data(in_data), .hsigmoid_out(hsigmoid_out), .hswish_out(hswish_out), .out_valid(out_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        in_data = 0;
        #20;
        rst = 0;
        // Feed 4 test values
        in_data = -3; @(negedge clk);
        in_data = 0; @(negedge clk);
        in_data = 3; @(negedge clk);
        in_data = 6; @(negedge clk);
        // Wait for output
        repeat (4) @(negedge clk);
        if (out_valid) $display("hsigmoid: %d, hswish: %d", hsigmoid_out, hswish_out);
        $finish;
    end
endmodule 