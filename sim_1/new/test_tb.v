`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench cho test wrapper (Ifbuf + Computation)
// Đã cấu hình cho Layer Conv1: W=13, H=13, C_in=1, C_out=16
// - Sử dụng bộ nhớ giả lập DMA cho Ifmap
// - Filter stream do người dùng tự tính toán
//////////////////////////////////////////////////////////////////////////////////

module test_tb;

    // ==========================================
    // 1. PARAMETERS
    // ==========================================
    parameter DATA_WIDTH = 8;
    parameter K = 3;            
    parameter IFBUF_DEPTH = 300;
    parameter ACC_WIDTH = 32;
    parameter PE_PER_PU = 12;
    parameter COMP_DEPTH = 12;
    parameter M = 2;            
    parameter PPDEPTH = 640;
    parameter FIFO_DEPTH = 12;
    parameter CLK_PERIOD = 2;

    // ==========================================
    // 2. SIGNALS DECLARATION
    // ==========================================
    reg clk;
    reg rst_n;

    // Giao tiếp Instruction
    reg         ifbuf_ins_vld_i;
    reg [31:0]  ifbuf_ins_ifbaddr_i;
    reg [8:0]   ifbuf_ins_width_i;
    reg [10:0]  ifbuf_ins_channel_i; 
    reg [8:0]   ifbuf_ins_ifsize_i;  
    reg [10:0]  ifbuf_ins_ifblock_i; 
    reg [10:0]  ifbuf_ins_oftiles_i; 
    reg [10:0]  ifbuf_ins_iftiles_i; 
    reg [8:0]   ifbuf_ins_wp_i;      
    reg [7:0]   ifbuf_ins_ifc_zp_i;
    reg [1:0]   ifbuf_ins_padding_i;
    wire        ifbuf_ins_rdy_o;

    reg         comp_ins_dw_i;
    reg [3:0]   comp_ins_hf_i;
    reg [1:0]   comp_ins_stride_i;
    reg [1:0]   comp_ins_padding_i;
    reg [7:0]   comp_ins_ifc_zp_i_comp;
    reg [7:0]   comp_ins_fltc_zp_i;

    // Giao tiếp DMA
    reg                  ifbuf_dma_rdycfg_i;
    reg                  ifbuf_dma_vld_i;
    reg [DATA_WIDTH-1:0] ifbuf_dma_data_i;
    reg                  ifbuf_dma_tlast_i;
    wire                 ifbuf_dma_vldcfg_o;
    wire [8:0]           ifbuf_dma_burst_o;
    wire [31:0]          ifbuf_dma_baddr_o;
    wire                 ifbuf_dma_rdy_o;

    // Giao tiếp Filter Buffer
    reg [K*M-1:0]        comp_fltbuf_vld_i;
    reg [DATA_WIDTH-1:0] comp_fltbuf_data_i;
    reg                  comp_fltbuf_done_pass_i;
    wire [M-1:0]         comp_fltbuf_rdy_o;

    // Giao tiếp Output Buffer
    reg [M-1:0]          comp_ofbuf_rdy_i;
    wire [M-1:0]         comp_ofbuf_vld_o;
    wire [M*ACC_WIDTH-1:0] comp_ofbuf_data_o;
    wire                 comp_pa_done_compute_o;

    integer toggle_done;

    // ==========================================
    // 3. DUT INSTANTIATION
    // ==========================================
    test #(
        .DATA_WIDTH(DATA_WIDTH), .K(K), .IFBUF_DEPTH(IFBUF_DEPTH),
        .ACC_WIDTH(ACC_WIDTH), .PE_PER_PU(PE_PER_PU), .COMP_DEPTH(COMP_DEPTH),
        .M(M), .PPDEPTH(PPDEPTH), .FIFO_DEPTH(FIFO_DEPTH)
    ) uut (
        .clk(clk), .rst_n(rst_n),
        .ifbuf_ins_vld_i(ifbuf_ins_vld_i), .ifbuf_ins_ifbaddr_i(ifbuf_ins_ifbaddr_i),
        .ifbuf_ins_width_i(ifbuf_ins_width_i), .ifbuf_ins_channel_i(ifbuf_ins_channel_i),
        .ifbuf_ins_ifsize_i(ifbuf_ins_ifsize_i), .ifbuf_ins_ifblock_i(ifbuf_ins_ifblock_i),
        .ifbuf_ins_oftiles_i(ifbuf_ins_oftiles_i), .ifbuf_ins_iftiles_i(ifbuf_ins_iftiles_i),
        .ifbuf_ins_wp_i(ifbuf_ins_wp_i), .ifbuf_ins_ifc_zp_i(ifbuf_ins_ifc_zp_i),
        .ifbuf_ins_padding_i(ifbuf_ins_padding_i), .ifbuf_ins_rdy_o(ifbuf_ins_rdy_o),
        
        .comp_ins_dw_i(comp_ins_dw_i), .comp_ins_hf_i(comp_ins_hf_i),
        .comp_ins_stride_i(comp_ins_stride_i), .comp_ins_padding_i(comp_ins_padding_i),
        .comp_ins_ifc_zp_i(comp_ins_ifc_zp_i_comp), .comp_ins_fltc_zp_i(comp_ins_fltc_zp_i),
        
        .ifbuf_dma_rdycfg_i(ifbuf_dma_rdycfg_i), .ifbuf_dma_vld_i(ifbuf_dma_vld_i),
        .ifbuf_dma_data_i(ifbuf_dma_data_i), .ifbuf_dma_tlast_i(ifbuf_dma_tlast_i),
        .ifbuf_dma_vldcfg_o(ifbuf_dma_vldcfg_o), .ifbuf_dma_burst_o(ifbuf_dma_burst_o),
        .ifbuf_dma_baddr_o(ifbuf_dma_baddr_o), .ifbuf_dma_rdy_o(ifbuf_dma_rdy_o),
        
        .comp_fltbuf_vld_i(comp_fltbuf_vld_i), .comp_fltbuf_data_i(comp_fltbuf_data_i),
        .comp_fltbuf_done_pass_i(comp_fltbuf_done_pass_i), .comp_fltbuf_rdy_o(comp_fltbuf_rdy_o),
        
        .comp_ofbuf_rdy_i(comp_ofbuf_rdy_i), .comp_ofbuf_vld_o(comp_ofbuf_vld_o),
        .comp_ofbuf_data_o(comp_ofbuf_data_o), .comp_pa_done_compute_o(comp_pa_done_compute_o)
    );

    // ==========================================
    // 4. BỘ NHỚ GIẢ LẬP & DMA MASTER
    // ==========================================
    reg [DATA_WIDTH - 1:0] memory [0:65535];
    reg [31:0] current_fetch_addr;
    reg [8:0]  current_fetch_len;
    integer    dma_idx;

    always @(posedge clk) begin
        if (!rst_n) begin
            ifbuf_dma_rdycfg_i <= 1;
            ifbuf_dma_vld_i    <= 0;
            ifbuf_dma_tlast_i  <= 0;
            ifbuf_dma_data_i   <= 0;
        end else begin
            // Lắng nghe yêu cầu từ DUT
            if (ifbuf_dma_vldcfg_o && ifbuf_dma_rdycfg_i) begin
                current_fetch_addr = ifbuf_dma_baddr_o;
                current_fetch_len  = ifbuf_dma_burst_o;
                
                ifbuf_dma_rdycfg_i <= 0; // Kéo RDY xuống để báo bận
                
                // Bắn burst dữ liệu vào FIFO của DUT
                for (dma_idx = 0; dma_idx < current_fetch_len; dma_idx = dma_idx + 1) begin
                    @(posedge clk);
                    ifbuf_dma_vld_i  <= 1;
                    ifbuf_dma_data_i <= memory[current_fetch_addr + dma_idx];
                    
                    if (dma_idx == current_fetch_len - 1) begin
                        ifbuf_dma_tlast_i <= 1;
                    end else begin
                        ifbuf_dma_tlast_i <= 0;
                    end
                end
                
                // Trả DMA về trạng thái rảnh
                @(posedge clk);
                ifbuf_dma_vld_i    <= 0;
                ifbuf_dma_tlast_i  <= 0;
                ifbuf_dma_rdycfg_i <= 1;
            end
        end
    end

    task init_memory;
        input [31:0] base_addr;
        input [31:0] width;
        input [31:0] height;
        input [31:0] channel;
        integer c, h, w, align_w, addr;
        begin
            align_w = (width % 2 != 0) ? (width + 1) : width; // Logic align width
            for (c = 0; c < channel; c = c + 1) begin
                for (h = 0; h < height; h = h + 1) begin
                    for (w = 0; w < align_w; w = w + 1) begin
                        addr = base_addr + c * (height * align_w) + h * align_w + w;
                        if (w < width) begin
                            // Data giả lập để test
                            memory[addr] = {c[1:0], h[2:0], w[2:0]};
                        end else begin
                            memory[addr] = 8'hFF; // Padding data
                        end
                    end
                end
            end
        end
    endtask

    // ==========================================
    // 5. CLOCK & RESET
    // ==========================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst_n = 0;
        ifbuf_ins_vld_i = 0; ifbuf_ins_ifbaddr_i = 0; ifbuf_ins_width_i = 0;
        ifbuf_ins_channel_i = 0; ifbuf_ins_ifsize_i = 0; ifbuf_ins_ifblock_i = 0;
        ifbuf_ins_oftiles_i = 0; ifbuf_ins_iftiles_i = 0; ifbuf_ins_wp_i = 0;
        ifbuf_ins_ifc_zp_i = 0; ifbuf_ins_padding_i = 0;

        comp_ins_dw_i = 0; comp_ins_hf_i = 0; comp_ins_stride_i = 0;
        comp_ins_padding_i = 0; comp_ins_ifc_zp_i_comp = 0; comp_ins_fltc_zp_i = 0;

        comp_fltbuf_vld_i = 0; comp_fltbuf_data_i = 0; comp_fltbuf_done_pass_i = 0;
        
        comp_ofbuf_rdy_i = {M{1'b1}};
        toggle_done = 0;

        #20;
        rst_n = 1;
        #10;
        run_all_tests();
    end

    // ==========================================
    // 6. CẤU HÌNH INSTRUCTION
    // ==========================================
    task setup_instructions;
        begin
            comp_ins_dw_i = 0;
            comp_ins_hf_i = 3;       
            comp_ins_stride_i = 1;   
            comp_ins_padding_i = 1;  
            comp_ins_ifc_zp_i_comp = 0;
            comp_ins_fltc_zp_i = 0;

            ifbuf_ins_ifbaddr_i = 32'h1000; // Map với địa chỉ init_memory
            ifbuf_ins_width_i   = 13;   
            ifbuf_ins_ifblock_i = 1;   
            ifbuf_ins_channel_i = 1;    
            
            // Ifsize = Height * Aligned_Width = 13 * 14 = 182
            ifbuf_ins_ifsize_i  = 182;  
            
            ifbuf_ins_oftiles_i = 4;    
            ifbuf_ins_iftiles_i = 1;    
            
            ifbuf_ins_padding_i = 1;
            ifbuf_ins_wp_i      = 14;   
            
            ifbuf_ins_vld_i = 1'b1;
            @(posedge clk);
            while (!ifbuf_ins_rdy_o) @(posedge clk);
            ifbuf_ins_vld_i = 1'b0;
            @(posedge clk);
        end
    endtask

    // ==========================================
    // 7. TASK STREAM FILTER (BẠN TỰ CUSTOMIZE Ở ĐÂY)
    // ==========================================
    task send_filter_pass;
        input integer num_filter; 
        input integer num_chans;  
        input integer base_value;
        integer total, i, j, n;
        reg [DATA_WIDTH-1:0] temp_val;
        reg [K*M-1:0] temp_vld;
        begin
            total = comp_ins_hf_i * comp_ins_hf_i;
            for(j = 0; j < num_chans; j = j + 1) begin 
                for(n = 0; n < num_filter; n = n + 1) begin
                    for(i = 0; i < total; i = i + 1) begin
                        temp_vld = 0;
                        temp_vld[n*K + j] = 1'b1; 
                        comp_fltbuf_vld_i = temp_vld;
                        
                        // [CHỖ BẠN CẦN TÍNH LẠI CÔNG THỨC FILTER]
                        temp_val = base_value + n + i; 
                        comp_fltbuf_data_i = temp_val;
                        
                        if(toggle_done && i == total - 1 && j == num_chans - 1 && n == num_filter - 1)
                            comp_fltbuf_done_pass_i = 1'b1;
                        else
                            comp_fltbuf_done_pass_i = 1'b0;
                            
                        @(posedge clk);
                        while(&comp_fltbuf_rdy_o !== 1'b1) begin
                            @(posedge clk);
                        end
                    end

                    if(!toggle_done && j == num_chans - 1 && n == num_filter - 1) begin
                        comp_fltbuf_vld_i = 0;
                        comp_fltbuf_done_pass_i = 1'b1;
                        @(posedge clk);
                        comp_fltbuf_done_pass_i = 1'b0;
                    end
                    toggle_done = ~toggle_done;
                    comp_fltbuf_vld_i = 0;
                    comp_fltbuf_done_pass_i = 1'b0;
                end
            end
        end
    endtask

    // ==========================================
    // 8. TỔNG HỢP LAYER
    // ==========================================
    task run_layer;
        integer h;
        begin
            // 1. Khởi tạo dữ liệu vào bộ nhớ
            init_memory(32'h1000, 13, 13, 1);
            
            // 2. Chốt Instruction
            setup_instructions();
            
            $display("[%0t] Khởi động tiến trình xử lý Layer...", $time);
            // Kích hoạt nạp Filter. Nhờ tín hiệu DMA config từ DUT, Ifmap sẽ tự động chạy song song.
            for(h = 0; h < 13; h = h + 1) begin
                send_filter_pass(4, 1, 100);
            end
            
            $display("[%0t] Đang chờ khối PA tính toán hoàn tất...", $time);
            wait(comp_pa_done_compute_o == 1'b1);
            wait(comp_pa_done_compute_o == 1'b0);
            @(posedge clk);
        end
    endtask

    // ==========================================
    // 9. TEST CASES
    // ==========================================
    task run_all_tests;
        begin
            $display(">>> Bắt đầu Test Wrapper cho Conv1");
            run_layer();
            $display(">>> ALL TEST DONE <<<\n");
            #100 $finish;
        end
    endtask

    // ==========================================
    // 10. OUTPUT MONITOR
    // ==========================================
    integer o_idx;
    always @(posedge clk) begin
        for (o_idx = 0; o_idx < M; o_idx = o_idx + 1) begin
            if(comp_ofbuf_vld_o[o_idx] && comp_ofbuf_rdy_i[o_idx]) begin
                $display("[Time=%0t] PU[%0d] Output = %d", 
                         $time, o_idx, comp_ofbuf_data_o[(o_idx+1)*ACC_WIDTH-1 -: ACC_WIDTH]); 
            end
        end
    end

endmodule