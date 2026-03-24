`timescale 1ns / 1ps

module ifmap_cache_tb;

    // ==========================================
    // 1. PARAMETERS
    // ==========================================
    parameter DATA_WIDTH = 8;      
    parameter FIFO_DEPTH = 12;
    parameter K = 1;               // Để K=1 cho dễ quan sát log test
    parameter CLK_PERIOD = 2;

    // ==========================================
    // 2. SIGNALS DECLARATION
    // ==========================================
    reg clk;
    reg rst_n;

    // INSTRUCTION
    reg [3:0] ifc_ins_hf_i;
    reg [1:0] ifc_ins_stride_i;

    // IFMAP BUFFER (INPUT)
    reg [K*DATA_WIDTH-1:0] ifc_ifbuf_data_i;
    reg ifc_ifbuf_tlast_i;
    reg ifc_ifbuf_end_row_circle_i;
    reg ifc_ifbuf_end_depth_i;
    reg ifc_ifbuf_end_layer_i;
    reg ifc_ifbuf_vld_i;
    wire ifc_ifbuf_rdy_o;

    // PROCESSING UNIT (OUTPUT)
    reg ifc_pu_rdy_i;
    wire ifc_pu_vld_o;     
    wire [K*DATA_WIDTH - 1:0] ifc_pu_data_o;
    wire ifc_pu_end_row_o;         // NEW SIGNAL
    wire ifc_pu_end_row_circle_o;
    wire ifc_pu_end_depth_o;
    wire ifc_pu_end_layer_o;

    // ==========================================
    // 3. DUT INSTANTIATION
    // ==========================================
    ifmap_cache #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .K(K)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .ifc_ins_hf_i(ifc_ins_hf_i),
        .ifc_ins_stride_i(ifc_ins_stride_i),
        .ifc_ifbuf_data_i(ifc_ifbuf_data_i),
        .ifc_ifbuf_tlast_i(ifc_ifbuf_tlast_i),
        .ifc_ifbuf_end_row_circle_i(ifc_ifbuf_end_row_circle_i),
        .ifc_ifbuf_end_depth_i(ifc_ifbuf_end_depth_i),
        .ifc_ifbuf_end_layer_i(ifc_ifbuf_end_layer_i),
        .ifc_ifbuf_vld_i(ifc_ifbuf_vld_i),
        .ifc_ifbuf_rdy_o(ifc_ifbuf_rdy_o),
        
        .ifc_pu_rdy_i(ifc_pu_rdy_i),
        .ifc_pu_vld_o(ifc_pu_vld_o),
        .ifc_pu_data_o(ifc_pu_data_o),
        .ifc_pu_end_row_o(ifc_pu_end_row_o), // NEW SIGNAL CONNECTED
        .ifc_pu_end_row_circle_o(ifc_pu_end_row_circle_o),
        .ifc_pu_end_depth_o(ifc_pu_end_depth_o),
        .ifc_pu_end_layer_o(ifc_pu_end_layer_o)
    );

    // ==========================================
    // 4. CLOCK & RESET / INITIAL STIMULUS
    // ==========================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        // Initialize signals
        rst_n = 0;
        ifc_ins_hf_i = 0;
        ifc_ins_stride_i = 0;
        
        ifc_ifbuf_vld_i = 0;
        ifc_ifbuf_data_i = 0;
        ifc_ifbuf_tlast_i = 0;
        ifc_ifbuf_end_row_circle_i = 0;
        ifc_ifbuf_end_depth_i = 0;
        ifc_ifbuf_end_layer_i = 0;

        ifc_pu_rdy_i = 1; // Luôn sẵn sàng nhận data từ ifmap_cache ở ngõ ra

        #20;
        rst_n = 1;

        #10;
        run_all_tests();
    end

    // ==========================================
    // 5. TASKS
    // ==========================================
    
    // Task tự động tính Pos_last, thêm padding và set cờ
    task run_layer_test;
        input integer W;         // Chiều rộng input thực tế
        input integer P;         // Padding
        input integer S;         // Stride
        input integer K_filter;  // Kích thước Kernel (hf)
        input integer num_rows;  // Số hàng muốn test
        input integer num_chans; // Số kênh muốn test

        integer O_val;
        integer Pos_last;
        integer c, r, i;
        integer data_val;
        
        reg is_tlast;
        reg is_end_circle;
        reg is_end_depth;
        reg is_end_layer;

        begin
            // 1. Tính toán O và Pos_last theo công thức bạn cung cấp
            O_val = ((W + 2*P - K_filter) / S) + 1;
            Pos_last = (O_val - 1) * S + (K_filter - 1);

            $display(">>> Start Layer: W=%0d, P=%0d, S=%0d, K=%0d | Output Width=%0d, Pos_last=%0d", 
                     W, P, S, K_filter, O_val, Pos_last);

            // Cập nhật tín hiệu instruction
            ifc_ins_hf_i = K_filter[3:0];
            ifc_ins_stride_i = S[1:0];
            @(posedge clk); 

            // Bật Valid xuyên suốt quá trình truyền
            ifc_ifbuf_vld_i = 1'b1;
            for (r = 0; r < num_rows; r = r + 1) begin
                for (c = 0; c < num_chans; c = c + 1) begin
                    // Quét dọc theo hàng (chỉ quét tới Pos_last)
                    for(i = 0; i <= Pos_last; i = i + 1) begin
                        // ----------------------------------------------------
                        // A. LOGIC DATA (PADDING)
                        // ----------------------------------------------------
                        // Từ 0 -> P-1 (Left Padding) hoặc từ W+P -> W+2P-1 (Right Padding)
                        if (i < P || i >= (W + P)) begin
                            data_val = 0;
                        end else begin
                            // Data thật
                            data_val = (i - P) % W; 
                        end
                        ifc_ifbuf_data_i = {K{data_val[DATA_WIDTH-1:0]}};

                        // ----------------------------------------------------
                        // B. LOGIC CỜ KẾT THÚC (FLAGS)
                        // ----------------------------------------------------
                        is_tlast = (i == Pos_last);
                        ifc_ifbuf_tlast_i = is_tlast;

                        // Chỉ định giá trị cờ, chỉ bật khi tlast = 1
                        if (is_tlast) begin
                            is_end_circle = 1'b1; // Kết thúc 1 hàng
                            is_end_depth  = is_end_circle && (c == num_chans - 1);
                            is_end_layer  = is_end_depth && (r == num_rows - 1);
                        end else begin
                            is_end_circle = 1'b0;
                            is_end_depth  = 1'b0;
                            is_end_layer  = 1'b0;
                        end

                        ifc_ifbuf_end_row_circle_i = is_end_circle;
                        ifc_ifbuf_end_depth_i = is_end_depth;
                        ifc_ifbuf_end_layer_i = is_end_layer;

                        // ----------------------------------------------------
                        // C. HANDSHAKE CHỜ READY
                        // ----------------------------------------------------
                        @(posedge clk);
                        while(ifc_ifbuf_rdy_o !== 1'b1) begin
                            @(posedge clk);
                        end
                    end
                end
            end
            
            // Kết thúc gói, dọn dẹp bus
            ifc_ifbuf_vld_i = 1'b0;
            ifc_ifbuf_tlast_i = 1'b0;
            ifc_ifbuf_end_row_circle_i = 1'b0;
            ifc_ifbuf_end_depth_i = 1'b0;
            ifc_ifbuf_end_layer_i = 1'b0;

            // Chờ trước khi chạy test case khác
            #30; 
        end
    endtask

    // ==========================================
    // 6. TEST CASES
    // ==========================================
    task run_all_tests;
        begin
            // Test 1: Khớp chính xác với ví dụ tính toán của bạn
            // W=5, P=1, S=2, K=3. 
            // Pos_last mong đợi là 6. Test 1 hàng, 1 kênh.
            $display("--------------------------------");
            run_layer_test(5, 1, 2, 3, 1, 1);
            
            // Test 2: Chạy thử W dài hơn, có 2 channel, 2 rows để test cờ end_depth, end_layer
            // W=10, P=2, S=1, K=3 -> O_val = (10+4-3)/1 + 1 = 12 -> Pos_last = 11*1 + 2 = 13
            $display("--------------------------------");
            run_layer_test(10, 2, 1, 3, 2, 2);

            $display("--------------------------------");
            $display("ALL TEST DONE");
            #100 $finish;
        end
    endtask

    // ==========================================
    // 7. OUTPUT MONITOR
    // ==========================================
    always @(posedge clk) begin
        if(ifc_pu_vld_o && ifc_pu_rdy_i) begin
            $display("[Time=%0t] PU Nhan: Data=%0d | end_row(tlast)=%b | end_circle=%b | end_depth=%b | end_layer=%b", 
                     $time, 
                     ifc_pu_data_o[DATA_WIDTH-1:0], 
                     ifc_pu_end_row_o, 
                     ifc_pu_end_row_circle_o, 
                     ifc_pu_end_depth_o, 
                     ifc_pu_end_layer_o);
        end
    end

endmodule