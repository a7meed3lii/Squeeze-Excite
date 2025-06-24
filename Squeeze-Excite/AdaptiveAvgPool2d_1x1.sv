// Area-efficient serial AdaptiveAvgPool2d(1x1)
module AdaptiveAvgPool2d_1x1 #(
    parameter DATA_WIDTH = 16,
    parameter IN_HEIGHT = 8,
    parameter IN_WIDTH = 8,
    parameter CHANNELS = 1
) (
    input  logic clk,
    input  logic rst,
    input  logic [DATA_WIDTH-1:0] in_data,
    output logic [DATA_WIDTH-1:0] out_data,
    output logic out_valid
);
    // Internal state
    localparam TOTAL_PIXELS = IN_HEIGHT * IN_WIDTH;
    localparam TOTAL_INPUTS = CHANNELS * TOTAL_PIXELS;
    logic [DATA_WIDTH+7:0] sum [CHANNELS-1:0];
    logic [$clog2(TOTAL_PIXELS)-1:0] pix_cnt;
    logic [$clog2(CHANNELS)-1:0] ch_cnt;
    logic [$clog2(TOTAL_INPUTS):0] total_cnt;
    integer i;

    // Reset and accumulation logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < CHANNELS; i = i + 1)
                sum[i] <= 0;
            pix_cnt <= 0;
            ch_cnt <= 0;
            total_cnt <= 0;
            out_data <= 0;
            out_valid <= 0;
        end else begin
            // Accumulate input
            sum[ch_cnt] <= sum[ch_cnt] + in_data;
            // Update counters
            if (pix_cnt == TOTAL_PIXELS-1) begin
                pix_cnt <= 0;
                // Output average for this channel
                out_data <= sum[ch_cnt] / TOTAL_PIXELS;
                out_valid <= 1;
                sum[ch_cnt] <= 0; // Reset for next frame
                if (ch_cnt == CHANNELS-1)
                    ch_cnt <= 0;
                else
                    ch_cnt <= ch_cnt + 1;
            end else begin
                pix_cnt <= pix_cnt + 1;
                out_valid <= 0;
            end
            total_cnt <= total_cnt + 1;
        end
    end
endmodule 