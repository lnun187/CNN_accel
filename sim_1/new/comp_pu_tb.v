`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/04/2026 10:32:20 PM
// Design Name: 
// Module Name: comp_pu_tb
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


`timescale 1ns / 1ps

module comp_pu_tb;

    // --- Các tham số cấu hình ---
    parameter WIDTH = 8;
    parameter PE_PER_PU = 12;
    parameter DEPTH = 11;
    parameter CLK_PERIOD = 2;

    // --- Tín hiệu Clock và Reset ---
    reg clk;
    reg rst_n;
    reg en;

    // --- Tín hiệu Instruction ---
    reg pu_ins_dw_i;
    reg [3:0] pu_ins_hf_i;
    reg [1:0] pu_ins_stride_i;
    reg [1:0] pu_ins_padding_i;

    // --- Tín hiệu từ IFMap Cache ---
    reg pu_ifc_end_row_circle_i;
    reg pu_ifc_end_row_i;
    reg pu_ifc_end_depth_i;
    reg pu_ifc_end_layer_i;
    reg pu_ifc_end_height_i;
    reg pu_ifc_vld_i;
    reg [WIDTH-1:0] pu_ifc_data_i;
    wire pu_ifc_rdy_o;

    // --- Tín hiệu từ/tới Filter Buffer ---
    reg pu_fltbuf_vld_i;
    reg [WIDTH-1:0] pu_fltbuf_data_i;
    reg pu_fltbuf_done_pass_i;
    wire pu_fltbuf_rdy_o;

    // --- Tín hiệu từ/tới Output Buffer ---
    reg pu_ofbuf_rdy_i;
    wire pu_ofbuf_vld_o;
    wire [WIDTH-1:0] pu_ofbuf_data_o;
    wire pu_pa_done_compute_o;
    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // --- Instance: comp_pu (Unit Under Test) ---
    comp_pu #(
        .WIDTH(WIDTH),
        .PE_PER_PU(PE_PER_PU),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),

        // Instruction
        .pu_ins_dw_i(pu_ins_dw_i),
        .pu_ins_hf_i(pu_ins_hf_i),
        .pu_ins_stride_i(pu_ins_stride_i),
        .pu_ins_padding_i(pu_ins_padding_i),

        // IFMap Cache
        .pu_ifc_end_row_circle_i(pu_ifc_end_row_circle_i),
        .pu_ifc_end_row_i(pu_ifc_end_row_i),
        .pu_ifc_end_depth_i(pu_ifc_end_depth_i),
        .pu_ifc_end_layer_i(pu_ifc_end_layer_i),
        .pu_ifc_end_height_i(pu_ifc_end_height_i),
        .pu_ifc_vld_i(pu_ifc_vld_i),
        .pu_ifc_data_i(pu_ifc_data_i),
        .pu_ifc_rdy_o(pu_ifc_rdy_o),

        // Filter Buffer
        .pu_fltbuf_vld_i(pu_fltbuf_vld_i),
        .pu_fltbuf_data_i(pu_fltbuf_data_i),
        .pu_fltbuf_done_pass_i(pu_fltbuf_done_pass_i),
        .pu_fltbuf_rdy_o(pu_fltbuf_rdy_o),

        // Output Buffer
        .pu_ofbuf_rdy_i(pu_ofbuf_rdy_i),
        .pu_ofbuf_vld_o(pu_ofbuf_vld_o),
        .pu_ofbuf_data_o(pu_ofbuf_data_o),
        .pu_pa_done_compute_o(pu_pa_done_compute_o)
    );

    // --- Stimulus ---
    integer i;
    integer j;
    integer k;
    initial begin
        $display("--- STAGE: Configure ---");
        // 1. Khởi tạo tín hiệu
        rst_n = 0;
        en = 0;
        
        // Cấu hình Instruction (Ví dụ: Depthwise, Filter 3x3, Stride 1, Pad 1)
        pu_ins_dw_i = 1; 
        pu_ins_hf_i = 3; 
        pu_ins_stride_i = 1; 
        pu_ins_padding_i = 1;

        // Reset các cờ IFMap
        pu_ifc_end_row_circle_i = 0;
        pu_ifc_end_row_i = 0;
        pu_ifc_end_depth_i = 0;
        pu_ifc_end_layer_i = 0;
        pu_ifc_end_height_i = 0;
        pu_ifc_vld_i = 0;
        pu_ifc_data_i = 0;

        // Reset Filter tín hiệu
        pu_fltbuf_vld_i = 0;
        pu_fltbuf_data_i = 0;
        pu_fltbuf_done_pass_i = 0;

        // Output Buffer luôn sẵn sàng nhận dữ liệu
        pu_ofbuf_rdy_i = 1;

        #(CLK_PERIOD * 2) rst_n = 1; en = 1;
        #(CLK_PERIOD * 2);
    end

    initial begin
        #(CLK_PERIOD * 5);
        // ---------------------------------------------------------
        $display("--- STAGE: Load Filter Data ---");
        // ---------------------------------------------------------
        // Bơm một vài giá trị weight (filter) vào filter cache
        //First Pass
        pu_fltbuf_vld_i = 1;
        for (i = 0; i < 9; i = i + 1) begin // Giả sử load filter 3x3
            wait(pu_fltbuf_rdy_o == 1'b1);
            @(negedge clk);
            pu_fltbuf_data_i = i + 8'h01; // Data = 1, 2, 3...
            if(i == 8) pu_fltbuf_done_pass_i = 1;
            else pu_fltbuf_done_pass_i = 0;
            $display("Time %t: Sent Data = %d", $time, pu_fltbuf_data_i);
        end
        //Second Pass
        pu_fltbuf_vld_i = 1;
        for (i = 0; i < 9; i = i + 1) begin // Giả sử load filter 3x3
            wait(pu_fltbuf_rdy_o == 1'b1);
            @(negedge clk);
            pu_fltbuf_data_i = i + 8'h11; // Data = 1, 2, 3...
            if(i == 8) pu_fltbuf_done_pass_i = 1;
            else pu_fltbuf_done_pass_i = 0;
            $display("Time %t: Sent Data = %d", $time, pu_fltbuf_data_i);
        end
        //Third Pass
        pu_fltbuf_vld_i = 1;
        for (i = 0; i < 9; i = i + 1) begin // Giả sử load filter 3x3
            wait(pu_fltbuf_rdy_o == 1'b1);
            @(negedge clk);
            pu_fltbuf_data_i = i + 8'h02; // Data = 1, 2, 3...
            if(i == 8) pu_fltbuf_done_pass_i = 1;
            else pu_fltbuf_done_pass_i = 0;
            $display("Time %t: Sent Data = %d", $time, pu_fltbuf_data_i);
        end
        //Fourth Pass
        pu_fltbuf_vld_i = 1;
        for (i = 0; i < 9; i = i + 1) begin // Giả sử load filter 3x3
            wait(pu_fltbuf_rdy_o == 1'b1);
            @(negedge clk);
            pu_fltbuf_data_i = i + 8'h12; // Data = 1, 2, 3...
            if(i == 8) pu_fltbuf_done_pass_i = 1;
            else pu_fltbuf_done_pass_i = 0;
            $display("Time %t: Sent Data = %d", $time, pu_fltbuf_data_i);
        end
        //Fifth Pass
        pu_fltbuf_vld_i = 1;
        for (i = 0; i < 9; i = i + 1) begin // Giả sử load filter 3x3
            wait(pu_fltbuf_rdy_o == 1'b1);
            @(negedge clk);
            pu_fltbuf_data_i = i + 8'h03; // Data = 1, 2, 3...
            if(i == 8) pu_fltbuf_done_pass_i = 1;
            else pu_fltbuf_done_pass_i = 0;
            $display("Time %t: Sent Data = %d", $time, pu_fltbuf_data_i);
        end
        //Sixth Pass
        pu_fltbuf_vld_i = 1;
        for (i = 0; i < 9; i = i + 1) begin // Giả sử load filter 3x3
            wait(pu_fltbuf_rdy_o == 1'b1);
            @(negedge clk);
            pu_fltbuf_data_i = i + 8'h13; // Data = 1, 2, 3...
            if(i == 8) pu_fltbuf_done_pass_i = 1;
            else pu_fltbuf_done_pass_i = 0;
            $display("Time %t: Sent Data = %d", $time, pu_fltbuf_data_i);
        end
        //Seventh Pass
        pu_fltbuf_vld_i = 1;
        for (i = 0; i < 9; i = i + 1) begin // Giả sử load filter 3x3
            wait(pu_fltbuf_rdy_o == 1'b1);
            @(negedge clk);
            pu_fltbuf_data_i = i + 8'h04; // Data = 1, 2, 3...
            if(i == 8) pu_fltbuf_done_pass_i = 1;
            else pu_fltbuf_done_pass_i = 0;
            $display("Time %t: Sent Data = %d", $time, pu_fltbuf_data_i);
        end
        //Eighth Pass
        pu_fltbuf_vld_i = 1;
        for (i = 0; i < 9; i = i + 1) begin // Giả sử load filter 3x3
            wait(pu_fltbuf_rdy_o == 1'b1);
            @(negedge clk);
            pu_fltbuf_data_i = i + 8'h14; // Data = 1, 2, 3...
            if(i == 8) pu_fltbuf_done_pass_i = 1;
            else pu_fltbuf_done_pass_i = 0;
            $display("Time %t: Sent Data = %d", $time, pu_fltbuf_data_i);
        end
        @(negedge clk);
        pu_fltbuf_done_pass_i = 0;
    end

    integer c, r, rep, d;
    initial begin
        #(CLK_PERIOD * 5);
        // ---------------------------------------------------------
        $display("--- STAGE: Feed Input Feature Map (IFMap) Data ---");
        // ---------------------------------------------------------
        // Giả lập việc đưa pixel vào cho PE xử lý
         // Khai báo các biến đếm (nếu chưa khai báo)

    // Khởi tạo tín hiệu mặc định ban đầu
        pu_ifc_vld_i = 1;
        pu_ifc_end_row_i = 0;
        pu_ifc_end_row_circle_i = 0;
        pu_ifc_end_height_i = 0;
        pu_ifc_end_depth_i = 0;
        pu_ifc_end_layer_i = 0;

    // 1. Vòng lặp Channel (2 channels)
        for (c = 0; c < 2; c = c + 1) begin
            // 2. Vòng lặp Row (2 rows mỗi channel)
            for (r = 0; r < 2; r = r + 1) begin
                // 3. Vòng lặp Repeat (Mỗi row gửi lặp lại 2 lần)
                for (rep = 0; rep < 2; rep = rep + 1) begin
                    // 4. Vòng lặp Data (6 data mỗi row)
                    for (d = 0; d < 6; d = d + 1) begin
                        
                        // Chờ hardware sẵn sàng (ready = 1)
                        wait(pu_ifc_rdy_o == 1'b1);
                        @(negedge clk);

                        // --- 1. Gán Dữ liệu ---
                        // Công thức data này giúp bạn dễ debug trên waveform: 
                        // Ví dụ: Ch1, Row0, Data5 -> 8'h15
                        pu_ifc_data_i = {c[3:0], r[3:0]} * 10 + d; 

                        // --- 2. Gán các cờ Control (Chỉ bật ở data cuối cùng của row: d == 5) ---
                        if (d == 5) begin
                            pu_ifc_end_row_i = 1; // Luôn bật khi hết 1 row (đủ 6 data)
                            
                            // Nếu đang ở lần lặp thứ 2 (rep == 1)
                            if (rep == 1) begin
                                pu_ifc_end_row_circle_i = 1; 
                                if (c == 1) begin
                                        pu_ifc_end_depth_i = 1;
                                end
                                // Nếu đang ở row cuối cùng của channel (r == 1)
                                if (r == 1) begin
                                    pu_ifc_end_height_i = 1;
                                    // Nếu đang ở channel cuối cùng (c == 1)
                                    if (c == 1) begin
                                        pu_ifc_end_layer_i = 1;
                                    end
                                end
                            end
                        end else begin
                            // Đảm bảo các cờ bị tắt nếu không phải data cuối
                            pu_ifc_end_row_i = 0;
                            pu_ifc_end_row_circle_i = 0;
                            pu_ifc_end_height_i = 0;
                            pu_ifc_end_depth_i = 0;
                            pu_ifc_end_layer_i = 0;
                        end
                    end // Kết thúc vòng lặp Data
                    
                    // Đảm bảo hạ các cờ xuống ngay sau khi rời khỏi data cuối cùng của row
                    // (Để chuẩn bị cho cycle của data đầu tiên của row tiếp theo)
                    pu_ifc_end_row_i = 0;
                    pu_ifc_end_row_circle_i = 0;
                    pu_ifc_end_height_i = 0;
                    pu_ifc_end_depth_i = 0;
                    pu_ifc_end_layer_i = 0;

                end // Kết thúc vòng lặp Repeat
            end // Kết thúc vòng lặp Row
        end // Kết thúc vòng lặp Channel

    // Clear toàn bộ tín hiệu sau khi gửi xong tất cả
    @(posedge clk);
    #1;
    pu_ifc_vld_i = 0;
    pu_ifc_data_i = 8'h00;
    end

    initial begin
        wait(pu_pa_done_compute_o == 1'b1);
        $display("Status: PU da hoan thanh compute!");
        $finish;
    end
    // --- Monitor Output ---
    always @(posedge clk) begin
        if (pu_ofbuf_vld_o && pu_ofbuf_rdy_i) begin
            $display("Time: %0t | Output Valid! Data = %h", $time, pu_ofbuf_data_o);
        end
    end

endmodule
