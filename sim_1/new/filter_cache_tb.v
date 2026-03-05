`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 01:18:15 PM
// Design Name: 
// Module Name: filter_cache_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: Updated Testbench for filter_cache
// 
//////////////////////////////////////////////////////////////////////////////////

module filter_cache_tb;
    // =========================================================
    // 1. Parameters & Signals
    // =========================================================
    parameter WIDTH = 8;
    parameter DEPTH = 11;
    parameter PE_PER_PU = 4; // Giảm xuống 4 để dễ quan sát Waveform hơn

    // Inputs
    reg clk;
    reg rst_n;
    reg en;
    reg fltbuf_vld_i;
    reg [WIDTH-1:0] fltbuf_data_i;
    reg [3:0] hf;
    reg done_pass;
    reg comp_rdy_i;
    reg comp_clr_i;

    // Outputs
    wire fltbuf_rdy_o;
    wire [PE_PER_PU-1:0] comp_vld_o;       // Đã sửa: Phải là vector nhiều bit
    wire [PE_PER_PU*WIDTH-1:0] comp_data_o;

    // Internal Variables for Verification
    integer i;

    // =========================================================
    // 2. Instantiate the Unit Under Test (UUT)
    // =========================================================
    filter_cache #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .PE_PER_PU(PE_PER_PU)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .fltc_fltbuf_vld_i(fltbuf_vld_i),       // Đã sửa tên port khớp với RTL
        .fltc_fltbuf_data_i(fltbuf_data_i),     // Đã sửa tên port khớp với RTL
        .fltc_fltbuf_rdy_o(fltbuf_rdy_o),       // Đã sửa tên port khớp với RTL
        .fltc_ins_hf_i(hf),                     // Đã sửa tên port khớp với RTL
        .fltc_fltbuf_done_pass_i(done_pass),    // Đã sửa tên port khớp với RTL
        .fltc_pe_rdy_i(comp_rdy_i),             // Đã sửa tên port khớp với RTL
        .fltc_pu_clr_ch_flt_i(comp_clr_i),      // Đã sửa tên port khớp với RTL
        .fltc_pe_vld_o(comp_vld_o),             // Đã sửa tên port khớp với RTL
        .fltc_pe_data_o(comp_data_o)            // Đã sửa tên port khớp với RTL
        // Xóa empty_o vì nó không phải là output port của module filter_cache
    );

    // =========================================================
    // 3. Clock Generation
    // =========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Chu kỳ 10ns (100MHz)
    end

    // =========================================================
    // 4. Test Sequence
    // =========================================================
    initial begin
        // --- Giai đoạn 1: Khởi tạo ---
        $display("=== Bat dau mo phong ===");
        rst_n = 0;
        en = 0;
        fltbuf_vld_i = 0;
        fltbuf_data_i = 0;
        hf = 3;         // Filter size 3x3
        comp_rdy_i = 0;
        comp_clr_i = 0;
        done_pass = 0;
        
        // --- Giai đoạn 2: Reset ---
        #20;
        rst_n = 1;
        #10;
        en = 1;
        $display("Status: Reset released, Module Enabled");

        // --- Giai đoạn 3: Nạp dữ liệu vào Cache (Write) ---
        $display("Status: Bat dau nap du lieu (Filter 3x3) lan 1");
        for (i = 0; i < 9; i = i + 1) begin
            // Chờ cho đến khi module sẵn sàng nhận (Ready = 1)
            wait(fltbuf_rdy_o == 1);
            
            @(posedge clk);
            fltbuf_vld_i = 1;
            fltbuf_data_i = i + 1; // Data là 1, 2, 3... 9
            
            $display("Time %t: Sent Data = %d", $time, fltbuf_data_i);
        end
        done_pass = 1; // Giả lập hoàn thành nạp dữ liệu
        @(posedge clk & fltbuf_rdy_o);
        fltbuf_vld_i = 0;
        done_pass = 0;
        $display("Status: Bat dau nap du lieu (Filter 3x3) lan 2");
        for (i = 0; i < 9; i = i + 1) begin
            // Chờ cho đến khi module sẵn sàng nhận (Ready = 1)
            wait(fltbuf_rdy_o == 1);
            
            @(posedge clk);
            fltbuf_vld_i = 1;
            fltbuf_data_i = i + 1; // Data là 1, 2, 3... 9
            
            $display("Time %t: Sent Data = %d", $time, fltbuf_data_i);
        end
        done_pass = 1; // Giả lập hoàn thành nạp dữ liệu
        @(posedge clk & fltbuf_rdy_o);
        fltbuf_vld_i = 1;
        done_pass = 0;
        $display("Status: Da nap xong 9 phan tu.");

        // --- Giai đoạn 4: Đọc dữ liệu ra (Read / Compute) ---
        wait(comp_vld_o[0] == 1'b1); // Đã sửa: Check bit 0 của vector comp_vld_o
        $display("Status: Bat dau doc du lieu (Consumer Ready)");
        comp_rdy_i = 1; // Giả lập consumer sẵn sàng nhận dữ liệu
        
        // Đọc vài chu kỳ
        repeat (5) @(posedge clk);
        
        comp_rdy_i = 0;
        
        // --- Giai đoạn 5: Clear và kết thúc ---
        #20;
        comp_clr_i = 1;
        #10;
        comp_clr_i = 0;
        for (i = 0; i < 9; i = i + 1) begin
            // Chờ cho đến khi module sẵn sàng nhận (Ready = 1)
            // wait(fltbuf_rdy_o == 1);
            
            @(posedge clk);
            fltbuf_vld_i = 1;
            fltbuf_data_i = i + 1; // Data là 1, 2, 3... 9
            
            $display("Time %t: Sent Data = %d", $time, fltbuf_data_i);
        end
        done_pass = 1; // Giả lập hoàn thành nạp dữ liệu
        @(posedge clk & fltbuf_rdy_o);
        fltbuf_vld_i = 0;
        done_pass = 0;
        
        #50;
        $display("=== Ket thuc mo phong ===");
        $finish;
    end

endmodule