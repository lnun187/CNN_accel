`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/12/2026 08:30:56 PM
// Design Name: 
// Module Name: add_data_tb
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


module comp_pe_tb;
    // Parameters
    parameter ID = 1; // Chọn ID = 3 để test logic % hf
    parameter WIDTH = 32;

    // Inputs
    reg clk;
    reg rst_n;
    reg en;
    reg dw;
    reg [3:0] hf;
    reg end_row;
    reg end_depth;
    reg end_layer;
    reg end_height;
    reg if_vld_i;
    reg [WIDTH-1:0] if_data_i;
    reg flt_vld_i;
    reg [WIDTH-1:0] flt_data_i;
    reg [WIDTH-1:0] pre_fifo_i;
    reg [WIDTH-1:0] cur_fifo_i;
    reg empty_i;

    // Outputs
    wire flt_clr_o;
    wire rdy_o;
    wire pre_rd_o;
    wire cur_rd_o;
    wire swap_o;
    wire wr_o;
    wire [WIDTH-1:0] data_o;

    // Instantiate the Unit Under Test (UUT)
    comp_pe #(
        .ID(ID),
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .dw(dw),
        .hf(hf),
        .end_row(end_row),
        .end_depth(end_depth),
        .end_layer(end_layer),
        .end_height(end_height),
        .if_vld_i(if_vld_i),
        .if_data_i(if_data_i),
        .flt_vld_i(flt_vld_i),
        .flt_data_i(flt_data_i),
        .flt_clr_o(flt_clr_o),
        .rdy_o(rdy_o),
        .pre_fifo_i(pre_fifo_i),
        .pre_rd_o(pre_rd_o),
        .cur_fifo_i(cur_fifo_i),
        .cur_rd_o(cur_rd_o),
        .empty_i(empty_i),
        .swap_o(swap_o),
        .wr_o(wr_o),
        .data_o(data_o)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period
    end

    // Helper Task: Send one data packet
    task send_packet;
        input [WIDTH-1:0] if_val;
        input [WIDTH-1:0] flt_val;
        input [WIDTH-1:0] pre_val; // Giả lập dữ liệu từ PE trước
        input [WIDTH-1:0] cur_val;
        input is_last_in_row;
        input is_last_in_depth;
        input is_last_in_layer;
        input is_last_in_height;
    begin
        // Setup inputs
        if_vld_i = 1;
        flt_vld_i = 1;
        empty_i = 1; // Giả sử FIFO luôn có data/chỗ trống để rdy_o = 1
        
        if_data_i = if_val;
        flt_data_i = flt_val;
        pre_fifo_i = pre_val; 
        cur_fifo_i = cur_val;
        // Control flags
        end_row = is_last_in_row;
        end_depth = is_last_in_depth;
        end_layer = is_last_in_layer;
        end_height = is_last_in_height;

        // Wait for clock
        @(posedge clk);
        #1; // Delay nhỏ để check output sau clock edge
        
        // Reset flags cho chu kỳ sau (mặc định)
        if_vld_i = 0;
        flt_vld_i = 0;
        end_row = 0;
        end_depth = 0;
        end_layer = 0;
        end_height = 0;
    end
    endtask

    // --- MAIN TEST SCENARIO ---
//    initial begin
//        // Initialize Inputs
//        rst_n = 0;
//        en = 0;
//        dw = 0;
//        hf = 3;
//        if_vld_i = 0; if_data_i = 0;
//        flt_vld_i = 0; flt_data_i = 0;
//        pre_fifo_i = 0; cur_fifo_i = 0;
//        empty_i = 1;
//        end_row=0; end_depth=0; end_layer=0; end_height=0;

//        // Reset Sequence
//        #20 rst_n = 1;
//        #10 en = 1;

//        // Cấu hình Standard Conv
//        // Filter Weights: 0, 1, 2 cho cả 2 channel
//        hf = 3; 
//        dw = 0;

//        // ============================================================
//        // ROW 0 CALCULATION (Indices 0, 1, 2 | 3, 4, 5)
//        // ============================================================
        
//        $display("\n================ ROW 0 ================");

//        // --- CHANNEL 0 (0, 1, 2) ---
//        // PE Head (ID=3, hf=3) -> Tự reset về 0 đầu chu kỳ, không dùng pre_fifo.
//        $display("--- Ch0: Start Fresh ---");
        
//        // Index 0: In=0, W=0. Exp: 0*0 = 0
//        send_packet(0, 0, 0, 0, 0, 0, 0, 0); 

//        // Index 1: In=1, W=1. Exp: 1*1 + 0 = 1
//        send_packet(1, 1, 0, 0, 0, 0, 0, 0);

//        // Index 2: In=2, W=2. Exp: 2*2 + 1 = 5
//        // Flags: end_row=1 (Theo đề bài)
//        send_packet(2, 2, 0, 0, 1, 0, 0, 0); 
//        $display("-> Result Ch0_Row0: %d (Expected: 5). WR: %b", data_o, wr_o);


//        // --- CHANNEL 1 (3, 4, 5) ---
//        // Not Ch0 -> Accumulate with cur_fifo_i
//        $display("--- Ch1: Accumulate with Ch0 Result (5) ---");

//        // Index 3: In=3, W=0. 
//        // Input Cur_FIFO = 5 (Kết quả của Ch0). Exp: 3*0 + 5 = 5.
//        send_packet(3, 0, 0, 5, 0, 0, 0, 0);

//        // Index 4: In=4, W=1. Exp: 4*1 + 5 = 9.
//        send_packet(4, 1, 0, 0, 0, 0, 0, 0);

//        // Index 5: In=5, W=2. Exp: 5*2 + 9 = 19.
//        // Flags: end_row=1, end_depth=1 (Theo đề bài)
//        // end_depth=1 sẽ set is_channel_0 <= 1 ở clock tiếp theo.
//        send_packet(5, 2, 0, 0, 1, 1, 0, 0);
//        $display("-> Result Final_Row0: %d (Expected: 19). WR: %b", data_o, wr_o);


//        // ============================================================
//        // ROW 1 CALCULATION (Indices 6, 7, 8 | 9, 10, 11)
//        // ============================================================
        
//        $display("\n================ ROW 1 ================");

//        // --- CHANNEL 0 (6, 7, 8) ---
//        // is_channel_0 đã được reset lên 1 do end_depth ở trên -> Start Fresh
//        $display("--- Ch0: Start Fresh ---");

//        // Index 6: In=6, W=0. Exp: 6*0 = 0.
//        send_packet(6, 0, 0, 0, 0, 0, 0, 0);

//        // Index 7: In=7, W=1. Exp: 7*1 + 0 = 7.
//        send_packet(7, 1, 0, 0, 0, 0, 0, 0);

//        // Index 8: In=8, W=2. Exp: 8*2 + 7 = 23.
//        // Flags: end_row=1
//        send_packet(8, 2, 0, 0, 1, 0, 0, 0);
//        $display("-> Result Ch0_Row1: %d (Expected: 23). WR: %b", data_o, wr_o);


//        // --- CHANNEL 1 (9, 10, 11) ---
//        $display("--- Ch1: Accumulate with Ch0 Result (23) ---");
        
//        // Index 9: In=9, W=0. 
//        // Input Cur_FIFO = 23. Exp: 9*0 + 23 = 23.
//        send_packet(9, 0, 0, 23, 0, 0, 0, 0);

//        // Index 10: In=10, W=1. Exp: 10*1 + 23 = 33.
//        send_packet(10, 1, 0, 0, 0, 0, 0, 0);

//        // Index 11: In=11, W=2. Exp: 11*2 + 33 = 55.
//        // Flags: end_row=1, end_depth=1
//        send_packet(11, 2, 0, 0, 1, 1, 0, 0);
//        $display("-> Result Final_Row1: %d (Expected: 55). WR: %b", data_o, wr_o);


//        // ============================================================
//        // ROW 2 CALCULATION (Indices 12, 13, 14 | 15, 16, 17)
//        // ============================================================

//        $display("\n================ ROW 2 ================");

//        // --- CHANNEL 0 (12, 13, 14) ---
//        $display("--- Ch0: Start Fresh ---");
        
//        // Index 12: In=12, W=0. Exp: 0.
//        send_packet(12, 0, 0, 0, 0, 0, 0, 0);

//        // Index 13: In=13, W=1. Exp: 13.
//        send_packet(13, 1, 0, 0, 0, 0, 0, 0);

//        // Index 14: In=14, W=2. Exp: 14*2 + 13 = 41.
//        // Flags: end_row=1, end_height=1 (Cuối chiều cao 1 kênh)
//        send_packet(14, 2, 0, 0, 1, 0, 0, 1);
//        $display("-> Result Ch0_Row2: %d (Expected: 41). WR: %b", data_o, wr_o);


//        // --- CHANNEL 1 (15, 16, 17) ---
//        $display("--- Ch1: Accumulate with Ch0 Result (41) ---");
        
//        // Index 15: In=15, W=0. 
//        // Input Cur_FIFO = 41. Exp: 41.
//        send_packet(15, 0, 0, 41, 0, 0, 0, 0);

//        // Index 16: In=16, W=1. Exp: 16*1 + 41 = 57.
//        send_packet(16, 1, 0, 0, 0, 0, 0, 0);

//        // Index 17: In=17, W=2. Exp: 17*2 + 57 = 91.
//        // Flags: end_row=1, end_depth=1, end_height=1, end_layer=1
//        // Tại đây tất cả cờ đều lên 1.
//        send_packet(17, 2, 0, 0, 1, 1, 1, 1);
//        $display("-> Result Final_Row2: %d (Expected: 91). WR: %b", data_o, wr_o);

        
//        #100;
//        $finish;
//    end

// Task cấp cao: Thực hiện tính toán cho trọn vẹn 1 hàng (3 phần tử)
    task calculate_row_3len;
        // Inputs dữ liệu
        input [WIDTH-1:0] if0, if1, if2;       // 3 giá trị ifmap của hàng
        input [WIDTH-1:0] w0, w1, w2;          // 3 giá trị filter
        input [WIDTH-1:0] fifo_val;            // Giá trị FIFO (pre hoặc cur tùy context)
        
        // Inputs cờ điều khiển
        input is_ch0;         // Có phải channel 0 không? (để biết dùng pre hay cur fifo)
        input is_row_end;     // Cờ end_row
        input is_depth_end;   // Cờ end_depth
        input is_height_end;  // Cờ end_height
        input is_layer_end;   // Cờ end_layer
    begin
        // --- Cycle 1 (Count = 0) ---
        // Logic: Nếu là Ch0 và là Body PE -> dùng fifo_val làm pre_fifo
        //        Nếu không phải Ch0 -> dùng fifo_val làm cur_fifo
        if (is_ch0) begin
            // Đang ở Channel 0:
            // Body PE sẽ lấy pre_fifo_i.
            // Head PE sẽ ignore (nhưng ta cứ gán vào pre cho tổng quát, logic RTL tự lọc).
            pre_fifo_i = fifo_val; 
            cur_fifo_i = 0; // Don't care
        end else begin
            // Đang ở Channel khác: Luôn lấy cur_fifo_i
            pre_fifo_i = 0; // Don't care
            cur_fifo_i = fifo_val;
        end

        // Gửi phần tử 1 (Count 0)
        send_packet(if0, w0, pre_fifo_i, cur_fifo_i, 0, 0, 0, 0);

        // --- Cycle 2 (Count = 1) ---
        // Gửi phần tử 2. Các cờ end đều là 0.
        send_packet(if1, w1, 0, 0, 0, 0, 0, 0);

        // --- Cycle 3 (Count = 2 / Cuối hàng) ---
        // Gửi phần tử 3. Kèm theo các cờ kết thúc hàng/depth/layer...
        send_packet(if2, w2, 0, 0, is_row_end, is_depth_end, is_layer_end, is_height_end);
        
        // In ra kết quả kiểm tra ngay sau khi xong hàng
        $display("-> Output: %d. (Wr: %b, Flt_Clr: %b)", data_o, wr_o, flt_clr_o);
    end
    endtask
    initial begin
        // 1. Khởi tạo
        rst_n = 0; en = 0; dw = 1; hf = 1;
        if_vld_i = 0; if_data_i = 0; flt_vld_i = 0; flt_data_i = 0;
        pre_fifo_i = 0; cur_fifo_i = 0; empty_i = 1;
        end_row=0; end_depth=0; end_layer=0; end_height=0;

        #20 rst_n = 1;
        #10 en = 1;

        $display("\n================ TEST CASE: BODY PE (ID=4, hf=3) ================");
        $display("Filter weights: 3, 4, 5");
        $display("Pre_fifo input (simulating result from PE_Head): 100, 200, 300 for 3 rows");

        // ================= ROW 0 =================
        $display("\n--- ROW 0 ---");
        
        // [CHANNEL 0] Inputs: 0, 1, 2. Weights: 3, 4, 5. 
        // Pre_FIFO: 40 (Giả sử kết quả từ hàng trên).
        // Logic Body PE (ID%hf!=0): Tại Ch0, Count0 -> Add_data = Pre_FIFO.
        // Calculation: (0*3 + 1*4 + 2*5) + 0 = 14.
        calculate_row_3len(
            0, 1, 2,      // Ifmap
            3, 4, 5,      // Filter
            40,          // FIFO Val (Vào Pre_FIFO vì là Ch0)
            1,            // is_ch0 = YES
            1, 0, 0, 0    // end_row=1
        );

        // [CHANNEL 1] Inputs: 3, 4, 5. Weights: 3, 4, 5.
        // Cur_FIFO: 14 (Kết quả từ Ch0).
        // Logic: Tại Ch1 -> Add_data = Cur_FIFO.
        // Calculation: (3*3 + 4*4 + 5*5) + 14 = 50 + 14 = 64.
        calculate_row_3len(
            3, 4, 5,      // Ifmap
            3, 4, 5,      // Filter
            14,          // FIFO Val (Vào Cur_FIFO vì là Ch1)
            0,            // is_ch0 = NO
            1, 1, 0, 0    // end_row=1, end_depth=1
        );


        // ================= ROW 1 =================
        $display("\n--- ROW 1 ---");
        // Lưu ý: Sau end_depth ở trên, is_channel_0 đã tự reset về 1 bên trong RTL.

        // [CHANNEL 0] Inputs: 6, 7, 8. Weights: 3, 4, 5.
        // Pre_FIFO: 19 (Giả sử kết quả từ hàng trên của hàng này).
        // Calc: (6*3 + 7*4 + 8*5) + 19 = (18+28+40) + 19 = 86 + 19 = 105.
        calculate_row_3len(
            6, 7, 8, 
            3, 4, 5, 
            19,          // Pre_FIFO
            1,            // is_ch0
            1, 0, 0, 0    // end_row
        );

        // [CHANNEL 1] Inputs: 9, 10, 11. Weights: 3, 4, 5.
        // Cur_FIFO: 105.
        // Calc: (9*3 + 10*4 + 11*5) + 105 = (27+40+55) + 105 = 122 + 105 = 227.
        calculate_row_3len(
            9, 10, 11, 
            3, 4, 5, 
            105,          // Cur_FIFO
            0,            // is_ch0
            1, 1, 1, 1    // end_row, end_depth
        );

        hf = 3;
        // ================= ROW 2 =================
        $display("\n--- ROW 2 ---");

        // [CHANNEL 0] Inputs: 12, 13, 14. Weights: 3, 4, 5.
        // Pre_FIFO: 55.
        // Calc: (12*3 + 13*4 + 14*5) + 55 = (36+52+70) + 55 = 158 + 55 = 213.
        calculate_row_3len(
            12, 13, 14, 
            3, 4, 5, 
            55,          // Pre_FIFO
            1, 
            1, 0, 1, 0    // end_row, end_height
        );

        // [CHANNEL 1] Inputs: 15, 16, 17. Weights: 3, 4, 5.
        // Cur_FIFO: 213.
        // Calc: (15*3 + 16*4 + 17*5) + 213 = (45+64+85) + 213 = 194 + 213 = 407.
        calculate_row_3len(
            15, 16, 17, 
            3, 4, 5, 
            213,          // Cur_FIFO
            0, 
            1, 1, 1, 1    // end_row, end_depth, end_layer, end_height
        );

        #100;
        $finish;
    end
endmodule
