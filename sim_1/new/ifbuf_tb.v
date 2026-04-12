`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/24/2026 04:30:31 PM
// Design Name: 
// Module Name: ifbuf_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module ifbuf_tb();

    // -------------------------------------------------------------------------
    // 1. Khai báo Parameters và Signals
    // -------------------------------------------------------------------------
    parameter DATA_WIDTH = 12;
    parameter DEPTH      = 300;
    parameter K          = 8;

    reg         clk;
    reg         rst_n;

    // Các tín hiệu Instruction Input
    reg         ifbuf_ins_vld_i;
    reg  [31:0] ifbuf_ins_ifbaddr_i;
    reg  [8:0]  ifbuf_ins_width_i;
    reg  [10:0] ifbuf_ins_channel_i;
    reg  [3:0]  ifbuf_ins_ifparr_i;
    reg  [3:0]  ifbuf_ins_ifparr_tail_i;
    reg  [7:0]  ifbuf_ins_ifsize_i;
    reg  [6:0]  ifbuf_ins_ifblock_i;
    reg  [3:0]  ifbuf_ins_oftiles_i;
    reg  [3:0]  ifbuf_ins_oftiles_tail_i;
    reg  [6:0]  ifbuf_ins_iftiles_i;
    reg  [8:0]  ifbuf_ins_wp_i;
    reg  [1:0]  ifbuf_ins_padding_i;
    reg  [7:0]  ifbuf_ins_ifc_zp_i;
    wire        ifbuf_ins_rdy_o;

    // Các tín hiệu giao tiếp DMA (từ giả lập Memory/DMA tới DUT)
    reg         ifbuf_dma_rdycfg_i;
    reg         ifbuf_dma_vld_i;
    reg  [DATA_WIDTH-1:0] ifbuf_dma_data_i;
    reg         ifbuf_dma_tlast_i;
    wire        ifbuf_dma_vldcfg_o;
    wire [8:0]  ifbuf_dma_burst_o;
    wire [31:0] ifbuf_dma_baddr_o;
    wire        ifbuf_dma_rdy_o;

    // Các tín hiệu giao tiếp với khối khác (Downstream Consumer)
    reg         ifbuf_comp_rdy_i;
    wire        ifbuf_comp_vld_o;
    wire [K*DATA_WIDTH-1:0] ifbuf_comp_data_o;
    wire        ifbuf_comp_end_row_o;
    wire        ifbuf_comp_end_row_circle_o;
    wire        ifbuf_comp_end_depth_o;
    wire        ifbuf_comp_end_layer_o;

    // Các biến cho quá trình test
    integer TEST_WIDTH    = 5; // Để số lẻ để test logic tự động align
    integer TEST_CHANNEL  = 9; // Giảm xuống 4 cho mô phỏng nhanh
    integer TEST_BLOCK    = 2;
    integer TEST_OFTILES  = 2;
    integer TEST_IFTILES  = 3;
    integer TEST_PADDING  = 1;
    integer TEST_HF = 3;
    integer TEST_IFPARR = 4;
    integer TEST_IFPARR_TAIL = 1;
    integer TEST_OFTILES_TAIL = 1;
    integer TEST_IFC_ZP = 8'h00;
    integer TEST_STRIDE = 1;
    integer ALIGNED_WIDTH;
    integer TEST_IFSIZE;
    integer TEST_WP;
    
    // -------------------------------------------------------------------------
    // 2. Khởi tạo DUT (Device Under Test)
    // -------------------------------------------------------------------------
    ifbuf #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .K(K)
    ) dut (
        .clk                    (clk),
        .rst_n                  (rst_n),
        
        // Giao tiếp Instruction
        .ifbuf_ins_vld_i        (ifbuf_ins_vld_i),
        .ifbuf_ins_ifbaddr_i    (ifbuf_ins_ifbaddr_i),
        .ifbuf_ins_width_i      (ifbuf_ins_width_i),
        .ifbuf_ins_channel_i    (ifbuf_ins_channel_i),
        .ifbuf_ins_ifparr_i     (ifbuf_ins_ifparr_i),
        .ifbuf_ins_ifparr_tail_i(ifbuf_ins_ifparr_tail_i),
        .ifbuf_ins_ifsize_i     (ifbuf_ins_ifsize_i),
        .ifbuf_ins_ifblock_i    (ifbuf_ins_ifblock_i),
        .ifbuf_ins_oftiles_i    (ifbuf_ins_oftiles_i),
        .ifbuf_ins_oftiles_tail_i(ifbuf_ins_oftiles_tail_i),
        .ifbuf_ins_iftiles_i    (ifbuf_ins_iftiles_i),
        .ifbuf_ins_wp_i         (ifbuf_ins_wp_i),
        .ifbuf_ins_padding_i    (ifbuf_ins_padding_i),
        .ifbuf_ins_ifc_zp_i     (ifbuf_ins_ifc_zp_i),
        .ifbuf_ins_rdy_o        (ifbuf_ins_rdy_o),

        // Tín hiệu DMA
        .ifbuf_dma_rdycfg_i     (ifbuf_dma_rdycfg_i),
        .ifbuf_dma_vld_i        (ifbuf_dma_vld_i),
        .ifbuf_dma_data_i       (ifbuf_dma_data_i),
        .ifbuf_dma_tlast_i      (ifbuf_dma_tlast_i),
        .ifbuf_dma_vldcfg_o     (ifbuf_dma_vldcfg_o),
        .ifbuf_dma_burst_o      (ifbuf_dma_burst_o),
        .ifbuf_dma_baddr_o      (ifbuf_dma_baddr_o),
        .ifbuf_dma_rdy_o        (ifbuf_dma_rdy_o),

        // Tín hiệu giao tiếp với khối khác
        .ifbuf_comp_rdy_i       (ifbuf_comp_rdy_i),
        .ifbuf_comp_vld_o       (ifbuf_comp_vld_o),
        .ifbuf_comp_data_o      (ifbuf_comp_data_o),
        .ifbuf_comp_end_row_o   (ifbuf_comp_end_row_o),
        .ifbuf_comp_end_row_circle_o(ifbuf_comp_end_row_circle_o),
        .ifbuf_comp_end_depth_o (ifbuf_comp_end_depth_o),
        .ifbuf_comp_end_layer_o (ifbuf_comp_end_layer_o)
    );

    // -------------------------------------------------------------------------
    // 3. Khối giả lập Memory và DMA Reader 
    // -------------------------------------------------------------------------
    reg [DATA_WIDTH - 1:0] memory [0:65535]; // Bộ nhớ giả lập 64KB

    reg [31:0] current_fetch_addr;
    reg [8:0]  current_fetch_len;
    integer    i;

    // Logic giả lập DMA Master đọc từ Memory đẩy vào DUT
    always @(posedge clk) begin
        if (!rst_n) begin
            ifbuf_dma_rdycfg_i <= 1;
            ifbuf_dma_vld_i    <= 0;
            ifbuf_dma_tlast_i  <= 0;
            ifbuf_dma_data_i   <= 0;
        end else begin
            // Bắt đầu nhận yêu cầu từ DUT
            if (ifbuf_dma_vldcfg_o && ifbuf_dma_rdycfg_i) begin
                current_fetch_addr = ifbuf_dma_baddr_o;
                current_fetch_len  = ifbuf_dma_burst_o;
                
                // Kéo RDY xuống để báo bận
                ifbuf_dma_rdycfg_i <= 0; 
                
                // Bắn dữ liệu vào FIFO của DUT
                for (i = 0; i < current_fetch_len; i = i + 1) begin
                    @(posedge clk);
                    ifbuf_dma_vld_i  <= 1;
                    ifbuf_dma_data_i <= memory[current_fetch_addr + i];
                    
                    // Tạo tín hiệu tlast tại byte cuối cùng của burst
                    if (i == current_fetch_len - 1) begin
                        ifbuf_dma_tlast_i <= 1;
                    end else begin
                        ifbuf_dma_tlast_i <= 0;
                    end
                end
                
                // Kết thúc burst
                @(posedge clk);
                ifbuf_dma_vld_i    <= 0;
                ifbuf_dma_tlast_i  <= 0;
                ifbuf_dma_rdycfg_i <= 1; // DMA sẵn sàng cấu hình tiếp
            end
        end
    end

    // -------------------------------------------------------------------------
    // 4. Khối giả lập Downstream Consumer (Rút data ra khỏi ifbuf)
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rst_n) begin
            ifbuf_comp_rdy_i <= 0;
        end else begin
            // Consumer luôn sẵn sàng nhận dữ liệu (hoặc bạn có thể toggle random để test stall)
            ifbuf_comp_rdy_i <= 1;
        end
    end

    // -------------------------------------------------------------------------
    // 5. Task Khởi tạo Dữ liệu Bộ nhớ (Align 1 byte nếu lẻ)
    // -------------------------------------------------------------------------
    task init_memory;
        input [31:0] base_addr;
        input [31:0] width;
        input [31:0] height;
        input [31:0] channel;
        
        integer c, h, w;
        integer align_w;
        integer addr;
        begin
            // Tính toán width đã được align
            align_w = (width % 2 != 0) ? (width + 1) : width;
            
            // Xếp theo width -> Height -> Channel
            for (c = 0; c < channel; c = c + 1) begin
                for (h = 0; h < height; h = h + 1) begin
                    for (w = 0; w < align_w; w = w + 1) begin
                        addr = base_addr + c * (height * align_w) + h * align_w + w;
                        if (w < width) begin
                            // Ghi data 8-bit có ý nghĩa để dễ debug: {C[2:0], H[1:0], W[2:0]}
                            memory[addr] = {c[3:0], h[3:0], w[3:0]}; 
                        end else begin
                            // Ghi 0 vào ô padding
                            memory[addr] = 8'hFF; 
                        end
                    end
                end
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // 6. Khối tạo xung Clock và Stimulus
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Chu kỳ 10ns
    end

    initial begin
        // Init signals
        rst_n               = 0;
        
        // Cấu hình Ins
        ifbuf_ins_vld_i     = 0;
        ifbuf_ins_ifbaddr_i = 0;
        ifbuf_ins_width_i   = 0;
        ifbuf_ins_channel_i = 0;
        ifbuf_ins_ifparr_i = 0;
        ifbuf_ins_ifparr_tail_i = 0;
        ifbuf_ins_ifsize_i  = 0;
        ifbuf_ins_ifblock_i = 0;
        ifbuf_ins_oftiles_i = 0;
        ifbuf_ins_oftiles_tail_i = 0;
        ifbuf_ins_iftiles_i = 0;
        ifbuf_ins_wp_i      = 0;
        ifbuf_ins_padding_i = 0;
        ifbuf_ins_ifc_zp_i = 0;

        // Reset
        #20 rst_n = 1;
        #20;

        // Tính toán ifsize theo logic: height * ALIGNED_WIDTH
        ALIGNED_WIDTH = (TEST_WIDTH % 2 != 0) ? (TEST_WIDTH + 1) : TEST_WIDTH;
        TEST_IFSIZE   = TEST_WIDTH * ALIGNED_WIDTH; // Giả sử height = width
        TEST_WP       = ((TEST_WIDTH + 2*TEST_PADDING - TEST_HF) / TEST_STRIDE) * TEST_STRIDE + TEST_HF - 1;
        // Khởi tạo bộ nhớ tại địa chỉ base = 32'h1000
        init_memory(32'h1000, TEST_WIDTH, TEST_WIDTH, TEST_CHANNEL);

        // Chờ DUT rảnh rỗi và bắn Instruction vào
        wait(ifbuf_ins_rdy_o);
        @(posedge clk);
        ifbuf_ins_vld_i     <= 1;
        ifbuf_ins_ifbaddr_i <= 32'h1000;
        ifbuf_ins_width_i   <= TEST_WIDTH;
        ifbuf_ins_channel_i <= TEST_CHANNEL;
        ifbuf_ins_ifparr_i  <= TEST_IFPARR[3:0];
        ifbuf_ins_ifparr_tail_i <= TEST_IFPARR_TAIL[3:0];
        ifbuf_ins_ifsize_i  <= TEST_IFSIZE[7:0]; 
        ifbuf_ins_ifblock_i <= TEST_BLOCK;
        
        // Thêm các thông số mới cho ifbuf
        ifbuf_ins_oftiles_i <= TEST_OFTILES[3:0];
        ifbuf_ins_oftiles_tail_i <= TEST_OFTILES_TAIL[3:0];
        ifbuf_ins_iftiles_i <= TEST_IFTILES[6:0];
        ifbuf_ins_wp_i      <= TEST_WP;
        ifbuf_ins_padding_i <= TEST_PADDING;
        ifbuf_ins_ifc_zp_i <= TEST_IFC_ZP[7:0];

        // Kéo vld xuống sau 1 clock
        @(posedge clk);
        ifbuf_ins_vld_i     <= 0;

        // Chạy một khoảng thời gian để quan sát tín hiệu trên waveform
        #20000;
        $finish;
    end

endmodule
