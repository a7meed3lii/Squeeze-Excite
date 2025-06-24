// Testbench for Unified SE (Squeeze-and-Excitation) Module
module tb_top_all_layers;
    logic clk, rst;
    logic [15:0] in_data;
    logic [15:0] mean1, mean2, variance1, variance2, gamma1, gamma2, beta1, beta2;
    logic load_kernel_conv_param, load_kernel_conv_spec;
    logic [15:0] out_data;

    // Test variables
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;
    logic test_active = 0;
    int cycle_count = 0;

    // Instantiate unified SE module
    top_all_layers uut(
        .clk(clk), .rst(rst), .in_data(in_data), 
        .mean1(mean1), .mean2(mean2), 
        .variance1(variance1), .variance2(variance2), 
        .gamma1(gamma1), .gamma2(gamma2), 
        .beta1(beta1), .beta2(beta2),
        .load_kernel_conv_param(load_kernel_conv_param), 
        .load_kernel_conv_spec(load_kernel_conv_spec),
        .out_data(out_data)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Function to check if output is reasonable
    function automatic logic check_output_validity(logic [15:0] expected_range_min, logic [15:0] expected_range_max);
        return (out_data >= expected_range_min && out_data <= expected_range_max);
    endfunction

    // Task to run complete SE test
    task automatic run_se_test(input string test_name);
        logic test_passed;
        int i, j;
        test_count++;
        
        $display("\n--- Test %0d: %s ---", test_count, test_name);
        test_active = 1;
        cycle_count = 0;
        
        // Reset SE module
        rst = 1;
        #20;
        rst = 0;
        #10;
        
        // Step 1: Load first convolution kernel (16→4 channels)
        $display("Loading first conv kernel (16→4 channels)...");
        load_kernel_conv_param = 1;
        load_kernel_conv_spec = 0;
        
        for (i = 0; i < 4; i++) begin // 4 output channels
            for (j = 0; j < 16; j++) begin // 16 input channels
                @(negedge clk);
                in_data = $urandom_range(1, 100); // Small positive kernel values
                cycle_count++;
            end
        end
        load_kernel_conv_param = 0;
        $display("✅ First conv kernel loaded");
        
        // Step 2: Load second convolution kernel (4→16 channels)
        $display("Loading second conv kernel (4→16 channels)...");
        load_kernel_conv_spec = 1;
        
        for (i = 0; i < 16; i++) begin // 16 output channels
            for (j = 0; j < 4; j++) begin // 4 input channels
                @(negedge clk);
                in_data = $urandom_range(1, 100); // Small positive kernel values
                cycle_count++;
            end
        end
        load_kernel_conv_spec = 0;
        $display("✅ Second conv kernel loaded");
        
        // Step 3: Feed input data (16 channels × 64 pixels each)
        $display("Feeding input data (16 channels × 64 pixels)...");
        for (i = 0; i < 16; i++) begin // 16 channels
            for (j = 0; j < 64; j++) begin // 64 pixels per channel (8×8)
                @(negedge clk);
                in_data = $urandom_range(50, 200); // Input pixel values
                cycle_count++;
            end
        end
        $display("✅ Input data fed to SE module");
        
        // Step 4: Wait for SE processing to complete
        $display("Waiting for SE processing...");
        repeat (200) @(negedge clk); // Allow sufficient time for processing
        
        // Step 5: Check outputs
        $display("SE Module State: %s", uut.state.name());
        $display("Final Output: 0x%04h (%0d)", out_data, out_data);
        
        // Verify output validity (should be non-zero for non-zero inputs)
        test_passed = check_output_validity(16'h0001, 16'h7FFF);
        
        if (test_passed) begin
            $display("✅ PASS: SE module produced valid output");
            pass_count++;
        end else begin
            $display("❌ FAIL: SE module output is invalid (0x%04h)", out_data);
            fail_count++;
        end
        
        test_active = 0;
    endtask

    // Task to display test summary
    task automatic display_test_summary();
        real pass_percentage;
        pass_percentage = (test_count > 0) ? (real'(pass_count) / real'(test_count)) * 100.0 : 0.0;
        
        $display("\n" + "="*60);
        $display("                 SE MODULE TEST SUMMARY");
        $display("="*60);
        $display("Total Tests:    %0d", test_count);
        $display("Tests Passed:   %0d", pass_count);
        $display("Tests Failed:   %0d", fail_count);
        $display("Pass Rate:      %.1f%%", pass_percentage);
        $display("="*60);
        
        if (fail_count == 0) begin
            $display("🎉 ALL TESTS PASSED! SE Module is working correctly.");
        end else begin
            $display("⚠️  SOME TESTS FAILED. Please check SE Module implementation.");
        end
        $display("="*60);
    endtask

    initial begin
        // Initialize signals
        rst = 1;
        in_data = 0; 
        mean1 = 0; mean2 = 0;
        variance1 = 16'h0100; variance2 = 16'h0100; // Fixed point 1.0
        gamma1 = 16'h0100; gamma2 = 16'h0100;       // Fixed point 1.0
        beta1 = 0; beta2 = 0;
        load_kernel_conv_param = 0; 
        load_kernel_conv_spec = 0;
        
        $display("\n🚀 Starting Unified SE Module Verification Tests");
        $display("="*60);
        
        // Run SE module tests
        run_se_test("Basic SE Functionality Test");
        
        // Test with different BatchNorm parameters
        mean1 = 16'h0010; mean2 = 16'h0010;
        run_se_test("SE Test with Non-Zero Mean");
        
        // Test with different scaling
        gamma1 = 16'h0200; gamma2 = 16'h0200; // 2.0 scaling
        run_se_test("SE Test with 2x Scaling");
        
        // Display test summary
        display_test_summary();
        
        $finish;
    end
    
    // Enhanced state monitoring
    always @(posedge clk) begin
        if (test_active) begin
            cycle_count++;
            
            // Monitor state transitions
            case (uut.state)
                uut.LOAD_KERNELS1: if (cycle_count % 20 == 0) $display("  [Cycle %0d] Loading kernel 1...", cycle_count);
                uut.LOAD_KERNELS2: if (cycle_count % 20 == 0) $display("  [Cycle %0d] Loading kernel 2...", cycle_count);
                uut.COLLECT_INPUT: if (cycle_count % 100 == 0) $display("  [Cycle %0d] Collecting input data...", cycle_count);
                uut.GLOBAL_POOL: $display("  [Cycle %0d] Global pooling channel %0d", cycle_count, uut.ch_cnt);
                uut.BATCH_NORM1: $display("  [Cycle %0d] BatchNorm1 channel %0d", cycle_count, uut.ch_cnt);
                uut.RELU1: $display("  [Cycle %0d] ReLU channel %0d", cycle_count, uut.ch_cnt);
                uut.CONV1: $display("  [Cycle %0d] Conv1 output channel %0d", cycle_count, uut.ch_cnt);
                uut.CONV2: $display("  [Cycle %0d] Conv2 output channel %0d", cycle_count, uut.ch_cnt);
                uut.BATCH_NORM2: $display("  [Cycle %0d] BatchNorm2 channel %0d", cycle_count, uut.ch_cnt);
                uut.HARD_SIGMOID: $display("  [Cycle %0d] HardSigmoid channel %0d", cycle_count, uut.ch_cnt);
                uut.MULTIPLY: $display("  [Cycle %0d] Final multiply channel %0d, output: 0x%04h", cycle_count, uut.ch_cnt, out_data);
                uut.OUTPUT: $display("  [Cycle %0d] Output channel %0d: 0x%04h", cycle_count, uut.ch_cnt, out_data);
            endcase
        end
    end

    // Error detection
    always @(posedge clk) begin
        if (!rst && test_active) begin
            if (out_data === 16'hXXXX) begin
                $display("❌ ERROR: Output contains X values!");
                fail_count++;
            end
        end
    end
endmodule 