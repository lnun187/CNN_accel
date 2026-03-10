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
// Description: Hoan thien Testbench va fix loi zzz ở data bus - Chạy 2 Layers
// 
// Dependencies: 
// 
// Revision:
// Revision 0.03 - Thêm vòng lặp test 2 layers liên tiếp
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module comp_pu_tb;

    // --- Các tham số cấu hình ---
    parameter WIDTH = 32;
    parameter PE_PER_PU = 12;
    parameter DEPTH = 11;
    parameter CLK_PERIOD = 2;
    parameter K = 1;
    
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
    reg [K*WIDTH-1:0] pu_ifc_data_i;
    wire pu_ifc_rdy_o;

    // --- Tín hiệu từ/tới Filter Buffer ---
    reg pu_fltbuf_vld_i;
    reg [K*WIDTH-1:0] pu_fltbuf_data_i;
    reg pu_fltbuf_done_pass_i;
    wire pu_fltbuf_rdy_o;

    // --- Tín hiệu từ/tới Output Buffer ---
    reg pu_ofbuf_rdy_i;
    wire pu_ofbuf_vld_o;
    wire [WIDTH-1:0] pu_ofbuf_data_o;
    wire pu_pa_done_compute_o;

    // --- Khai báo biến ---
    integer i, j, k;
    integer pass;
    reg [WIDTH - 1:0] base_val;
    integer c, r, rep, d;
    integer layer; // [ADDED] Thêm biến chạy vòng lặp layer
    
    // [FIXED] Khai báo các biến tạm để tránh lỗi bit-width khi nhân bản
    reg [WIDTH - 1:0] temp_flt_data;
    reg [WIDTH - 1:0] temp_ifc_data;

    // --- Clock Generation ---
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // --- Instance: comp_pu (Unit Under Test) ---
    comp_pu #(
        .WIDTH(WIDTH),
        .PE_PER_PU(PE_PER_PU),
        .DEPTH(DEPTH),
        .K(K)
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

    // --- Stimulus: Configure ---
    initial begin
        $display("--- STAGE: Configure ---");
        // 1. Khởi tạo tín hiệu
        rst_n = 0;
        en = 0;
        
        // Cấu hình Instruction (Ví dụ: Depthwise, Filter 3x3, Stride 1, Pad 1)
        pu_ins_dw_i = 0; 
        pu_ins_hf_i = 1; 
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

    // --- Stimulus: Load Filter Data ---
    initial begin
        #(CLK_PERIOD * 5);
        $display("--- STAGE: Load Filter Data ---");
        
        // [ADDED] Vòng lặp 2 Layers cho Filter
        for (layer = 0; layer < 2; layer = layer + 1) begin
            $display("--- Starting Filter Load for LAYER %0d ---", layer + 1);
            
            // Vòng lặp chạy qua 8 Pass
            for (pass = 0; pass < 8; pass = pass + 1) begin
                // Xác định base data cho từng Pass
                case(pass)
                    0: base_val = 32'h01;
                    1: base_val = 32'h11;
                    2: base_val = 32'h01;
                    3: base_val = 32'h11;
                    4: base_val = 32'h01;
                    5: base_val = 32'h11;
                    6: base_val = 32'h01;
                    7: base_val = 32'h11;
                endcase
                
                $display("--- Starting Layer %0d - Pass %0d ---", layer + 1, pass + 1);
                
                // Gửi 9 giá trị filter (3x3)
                for (i = 8; i < 9; i = i + 1) begin
                    @(negedge clk); 
                    
                    // Đợi khối PU báo ready = 1
                    while (pu_fltbuf_rdy_o === 1'b0) begin
                        @(negedge clk);
                    end
                    
                    pu_fltbuf_vld_i = 1'b1;
                    
                    // [FIXED] Tính toán dữ liệu ra biến tạm trước khi nhân bản
                    temp_flt_data = base_val + i[7:0];
                    pu_fltbuf_data_i = {K{temp_flt_data}}; 
                    
                    pu_fltbuf_done_pass_i = (i == 8) ? 1'b1 : 1'b0;
                    
                    $display("Time %t: Sent Filter Data = %h", $time, pu_fltbuf_data_i);
                end
                
                @(negedge clk);
                pu_fltbuf_vld_i = 1'b0;
                pu_fltbuf_done_pass_i = 1'b0;
            end
        end
    end

    // --- Stimulus: Feed IFMap Data ---
    initial begin
        #(CLK_PERIOD * 5);
        $display("--- STAGE: Feed Input Feature Map (IFMap) Data ---");

        // Khởi tạo tín hiệu mặc định ban đầu
        pu_ifc_vld_i = 0;
        pu_ifc_end_row_i = 0;
        pu_ifc_end_row_circle_i = 0;
        pu_ifc_end_height_i = 0;
        pu_ifc_end_depth_i = 0;
        pu_ifc_end_layer_i = 0;
        pu_ifc_data_i = 0;
        
        // [ADDED] Vòng lặp 2 Layers cho IFMap
        for (layer = 0; layer < 2; layer = layer + 1) begin
            $display("--- Starting IFMap Feed for LAYER %0d ---", layer + 1);
            
            // 1. Vòng lặp Row (2 rows mỗi channel)
            for (r = 0; r < 2; r = r + 1) begin
                // 2. Vòng lặp Channel (2 channels)
                for (c = 0; c < 2; c = c + 1) begin
                    // 3. Vòng lặp Repeat (Mỗi row gửi lặp lại 2 lần)
                    for (rep = 0; rep < 2; rep = rep + 1) begin
                        // 4. Vòng lặp Data (6 data mỗi row)
                        for (d = 0; d < 6; d = d + 1) begin
                            
                            // Bước 1: Bơm Valid và Data lên bus
                            pu_ifc_vld_i = 1'b1;
                            
                            // [FIXED] Tránh ghép integer, thay bằng phép toán số học vào biến tạm
                            // Dữ liệu sẽ có định dạng để dễ debug: VD c=1, r=1, d=5 -> 115
                            temp_ifc_data = (c * 100) + (r * 10) + d;
                            pu_ifc_data_i = {K{temp_ifc_data}}; 

                            // Xử lý cờ Control (đưa lên bus cùng lúc)
                            if (d == 5) begin
                                pu_ifc_end_row_i = 1;
                                if (rep == 1) begin
                                    pu_ifc_end_row_circle_i = 1; 
                                    if (c == 1) pu_ifc_end_depth_i = 1;
                                    if (r == 1) begin
                                        pu_ifc_end_height_i = 1;
                                        if (c == 1) pu_ifc_end_layer_i = 1;
                                    end
                                end
                            end else begin
                                pu_ifc_end_row_i = 0;
                                pu_ifc_end_row_circle_i = 0;
                                pu_ifc_end_height_i = 0;
                                pu_ifc_end_depth_i = 0;
                                pu_ifc_end_layer_i = 0;
                            end

                            // Vòng lặp chờ rdy 
                            @(posedge clk);
                            while (pu_ifc_rdy_o !== 1'b1) begin
                                @(posedge clk);
                            end
                            
                            // Bước 3: Đã qua sườn dương mà rdy == 1 -> Giao dịch thành công!
                            #1; // Delay Clock-to-Q mô phỏng
                            
                        end // d loop
                    end // rep loop
                end // c loop
            end // r loop
            
            // Tạm thời hạ cờ layer xuống sau khi kết thúc 1 layer để ready cho vòng lặp tiếp theo
            pu_ifc_end_layer_i = 0; 
        end // layer loop

        // Logic dọn dẹp: Kéo Valid xuống sau khi chạy xong toàn bộ dữ liệu
        pu_ifc_vld_i = 1'b0;

        // Clear toàn bộ tín hiệu sau khi gửi xong tất cả
        @(posedge clk);
        #1;
        pu_ifc_data_i = 0;
        pu_ifc_end_row_i = 0;
        pu_ifc_end_row_circle_i = 0;
        pu_ifc_end_height_i = 0;
        pu_ifc_end_depth_i = 0;
        pu_ifc_end_layer_i = 0;
    end

    // --- End of Simulation ---
    initial begin
        // [ADDED] Lặp lại chờ done 2 lần tương ứng với 2 layers
        repeat(2) begin
            @(posedge pu_pa_done_compute_o);
            $display("Time: %0t | Status: PU da hoan thanh compute 1 layer!", $time);
        end
        $display("Time: %0t | Status: PU da hoan thanh compute TOAN BO 2 layers! KET THUC SIMULATION.", $time);
        #(CLK_PERIOD * 5); // Đợi thêm một chút để lấy hết log xuất ra (nếu có)
        $finish;
    end
    
    // --- Monitor Output ---
    always @(posedge clk) begin
        if (pu_ofbuf_vld_o && pu_ofbuf_rdy_i) begin
            $display("Time: %0t | Output Valid! Data = %h", $time, pu_ofbuf_data_o);
        end
    end

endmodule