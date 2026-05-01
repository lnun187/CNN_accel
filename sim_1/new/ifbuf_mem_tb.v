`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/23/2026 08:41:53 AM
// Design Name: 
// Module Name: ifbuf_mem_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Updated Testbench for modified ifbuf_mem interface
// 
//////////////////////////////////////////////////////////////////////////////////

module ifbuf_mem_tb();

    // -------------------------------------------------------------------------
    // 1. Khai báo Parameters và Signals
    // -------------------------------------------------------------------------
    parameter DATA_WIDTH = 12;
    parameter DEPTH      = 300;
    parameter K          = 8;

    reg         clk;
    reg         rst_n;

    // Các tín hiệu inftruction Input (Đã update theo module mới)
    reg         ifbuf_inf_vld_i;
    reg  [31:0] ifbuf_inf_ifbaddr_i;
    reg  [8:0]  ifbuf_inf_width_i;
    reg  [10:0] ifbuf_inf_channel_i;
    reg  [8:0]  ifbuf_inf_ifsize_i;
    reg  [10:0] ifbuf_inf_ifblock_i;

    // Các tín hiệu giao tiếp DMA
    reg         swap_en;
    reg         ifbuf_dma_rdycfg_i;
    wire        ifbuf_dma_vldcfg_o;
    wire [31:0] ifbuf_dma_baddr_o; // Đã sửa thành [31:0] cho khớp DUT
    wire        ifbuf_inf_rdy_o;
    wire [8:0]  ifbuf_dma_burst_o;

    // Các biến cho quá trình test
    integer TEST_WIDTH  = 5; // Để số lẻ để test logic tự động align
    integer TEST_CHANNEL = 12;
    integer TEST_BLOCK   = 2;
    
    integer ALIGNED_WIDTH;
    integer TEST_IFSIZE;

    // -------------------------------------------------------------------------
    // 2. Khởi tạo DUT (Device Under Test)
    // -------------------------------------------------------------------------
    ifbuf_mem #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(DEPTH),
        .K(K)
    ) dut (
        .clk                 (clk),
        .rst_n               (rst_n),
        .ifbuf_inf_vld_i     (ifbuf_inf_vld_i),
        .ifbuf_inf_ifbaddr_i (ifbuf_inf_ifbaddr_i),
        .ifbuf_inf_width_i  (ifbuf_inf_width_i),
        .ifbuf_inf_channel_i (ifbuf_inf_channel_i),
        .ifbuf_inf_ifsize_i  (ifbuf_inf_ifsize_i),
        .ifbuf_inf_ifblock_i (ifbuf_inf_ifblock_i),
        
        .swap_en             (swap_en),
        .ifbuf_dma_rdycfg_i     (ifbuf_dma_rdycfg_i),
        .ifbuf_dma_vldcfg_o     (ifbuf_dma_vldcfg_o),
        .ifbuf_dma_baddr_o   (ifbuf_dma_baddr_o),
        
        .ifbuf_inf_rdy_o     (ifbuf_inf_rdy_o),
        .ifbuf_dma_burst_o   (ifbuf_dma_burst_o)
    );

    // -------------------------------------------------------------------------
    // 3. Khối giả lập Memory và DMA Reader (Có tín hiệu tlast)
    // -------------------------------------------------------------------------
    reg [DATA_WIDTH - 1:0] memory [0:65535]; // Bộ nhớ giả lập 64KB
    
    // Output của khối đọc Memory
    reg [DATA_WIDTH - 1:0] m_axis_tdata;
    reg       m_axis_tvalid;
    reg       m_axis_tlast;

    reg [31:0] current_fetch_addr;
    reg [8:0]  current_fetch_len;
    integer    i;

    // Logic giả lập DMA Master đọc từ Memory
    always @(posedge clk) begin
        if (!rst_n) begin
            ifbuf_dma_rdycfg_i <= 1;
            m_axis_tvalid   <= 0;
            m_axis_tlast    <= 0;
            m_axis_tdata    <= 0;
        end else begin
            // Bắt đầu nhận yêu cầu từ DUT
            if (ifbuf_dma_vldcfg_o && ifbuf_dma_rdycfg_i) begin
                current_fetch_addr = ifbuf_dma_baddr_o;
                current_fetch_len  = ifbuf_dma_burst_o;
                
                // Kéo RDY xuống để báo bận, đang xử lý dữ liệu
                ifbuf_dma_rdycfg_i <= 0; 
                
                // Vòng lặp bắn dữ liệu ra như một chuẩn AXI Stream
                for (i = 0; i < current_fetch_len; i = i + 1) begin
                    @(posedge clk);
                    m_axis_tvalid <= 1;
                    m_axis_tdata  <= memory[current_fetch_addr + i];
                    
                    // Tạo tín hiệu tlast tại byte cuối cùng của burst
                    if (i == current_fetch_len - 1) begin
                        m_axis_tlast <= 1;
                    end else begin
                        m_axis_tlast <= 0;
                    end
                end
                
                // Kết thúc burst
                @(posedge clk);
                m_axis_tvalid   <= 0;
                m_axis_tlast    <= 0;
                ifbuf_dma_rdycfg_i <= 1; // Sẵn sàng nhận yêu cầu tiếp theo
            end
        end
    end

    // Giả lập tín hiệu swap_en để duy trì pipeline (DUT tắt en_config sau mỗi cụm)
    always @(posedge clk) begin
        if (!rst_n) begin
            swap_en <= 0;
        end else begin
            // Đơn giản hóa: Cấp swap_en khi DUT rảnh rỗi hoặc ngưng xuất VLD
            if (!ifbuf_dma_vldcfg_o && ifbuf_dma_rdycfg_i) begin
                swap_en <= 1;
            end else begin
                swap_en <= 0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // 4. Task Khởi tạo Dữ liệu Bộ nhớ (Align 1 byte nếu lẻ)
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
                            // Ghi data có ý nghĩa để dễ debug: [Channel_Height_width]
                            memory[addr] = {c[3:0], h[3:0], w[3:0]}; 
                        end else begin
                            // Ghi 0 vào ô padding
                            memory[addr] = 12'h00; 
                        end
                    end
                end
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // 5. Khối tạo xung Clock và Stimulus
    // -------------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Chu kỳ 10ns
    end

    initial begin
        // Init signals
        rst_n               = 0;
        ifbuf_inf_vld_i     = 0;
        ifbuf_inf_ifbaddr_i = 0;
        ifbuf_inf_width_i  = 0;
        ifbuf_inf_channel_i = 0;
        ifbuf_inf_ifsize_i  = 0;
        ifbuf_inf_ifblock_i = 0;

        // Reset
        #20 rst_n = 1;
        #20;

        // Tính toán ifsize theo đúng logic: height * ALIGNED_WIDTH
        // Ép kiểu về 9 bit để fit với tín hiệu đầu vào
        ALIGNED_WIDTH = (TEST_WIDTH % 2 != 0) ? (TEST_WIDTH + 1) : TEST_WIDTH;
        TEST_IFSIZE    = TEST_WIDTH * ALIGNED_WIDTH;

        // Khởi tạo bộ nhớ tại địa chỉ base = 32'h1000
        init_memory(32'h1000, TEST_WIDTH, TEST_WIDTH, TEST_CHANNEL);

        // Chờ DUT rảnh rỗi và bắn inftruction vào
        wait(ifbuf_inf_rdy_o);
        @(posedge clk);
        ifbuf_inf_vld_i     <= 1;
        ifbuf_inf_ifbaddr_i <= 32'h1000;
        ifbuf_inf_width_i  <= TEST_WIDTH;
        ifbuf_inf_channel_i <= TEST_CHANNEL;
        ifbuf_inf_ifsize_i  <= TEST_IFSIZE[8:0]; 
        ifbuf_inf_ifblock_i <= TEST_BLOCK;
        

        // Chạy thêm một khoảng thời gian để quan sát tín hiệu trên waveform
        #20000;
        $finish;
    end

endmodule