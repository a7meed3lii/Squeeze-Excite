// Testbench for serial Conv2D_param
module tb_Conv2D_param;
    logic clk, rst;
    logic [15:0] in_data;
    logic load_kernel;
    logic [15:0] out_data;
    logic out_valid;

    Conv2D_param #(
        .DATA_WIDTH(16), .IN_HEIGHT(2), .IN_WIDTH(2), .KERNEL_SIZE(2), .STRIDE(1), .IN_CHANNELS(1), .OUT_CHANNELS(1)
    ) uut (
        .clk(clk), .rst(rst), .load_kernel(load_kernel), .in_data(in_data), .out_data(out_data), .out_valid(out_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst = 1;
        in_data = 0; load_kernel = 0;
        #20;
        rst = 0;
        // Load kernel (4 values for 2x2)
        load_kernel = 1;
        in_data = 1; @(negedge clk);
        in_data = 1; @(negedge clk);
        in_data = 1; @(negedge clk);
        in_data = 1; @(negedge clk);
        load_kernel = 0;
        // Feed input (4 values for 2x2)
        in_data = 2; @(negedge clk);
        in_data = 2; @(negedge clk);
        in_data = 2; @(negedge clk);
        in_data = 2; @(negedge clk);
        // Wait for output
        repeat (4) @(negedge clk);
        if (out_valid) $display("Output: %d", out_data);
        $finish;
    end
endmodule 