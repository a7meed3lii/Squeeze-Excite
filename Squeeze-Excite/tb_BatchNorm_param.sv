// Testbench for serial BatchNorm_param
module tb_BatchNorm_param;
    logic clk, rst;
    logic signed [15:0] in_data, mean, variance, gamma, beta;
    logic signed [15:0] out_data;
    logic out_valid;

    BatchNorm_param #(.DATA_WIDTH(16)) uut (
        .clk(clk), .rst(rst), .in_data(in_data), .mean(mean), .variance(variance), .gamma(gamma), .beta(beta), .out_data(out_data), .out_valid(out_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        in_data = 0; mean = 0; variance = 1; gamma = 1; beta = 0;
        #20;
        rst = 0;
        // Feed 4 values and parameters
        in_data = 10; mean = 5; variance = 2; gamma = 1; beta = 0; @(negedge clk);
        in_data = 20; mean = 10; variance = 2; gamma = 1; beta = 0; @(negedge clk);
        in_data = 30; mean = 15; variance = 2; gamma = 1; beta = 0; @(negedge clk);
        in_data = 40; mean = 20; variance = 2; gamma = 1; beta = 0; @(negedge clk);
        // Wait for output
        repeat (4) @(negedge clk);
        if (out_valid) $display("Output: %d", out_data);
        $finish;
    end
endmodule 