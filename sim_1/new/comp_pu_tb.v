`timescale 1ns/1ps

module comp_pu_tb;

    // ==========================================
    // 1. PARAMETERS
    // ==========================================
    parameter WIDTH = 32;
    parameter PE_PER_PU = 12;
    parameter DEPTH = 11;
    parameter K = 1;
    parameter CLK_PERIOD = 2;

    // ==========================================
    // 2. SIGNALS DECLARATION
    // ==========================================
    reg clk;
    reg rst_n;

    // infTRUCTION
    reg pu_inf_dw_i;
    reg [3:0] pu_inf_hf_i;
    reg [1:0] pu_inf_stride_i;
    reg [1:0] pu_inf_padding_i;

    // IFMAP CACHE
    reg pu_ifc_vld_i;
    reg [K*WIDTH-1:0] pu_ifc_data_i;
    reg pu_ifc_end_row_i;
    reg pu_ifc_end_row_circle_i;
    reg pu_ifc_end_depth_i;
    reg pu_ifc_end_height_i;
    reg pu_ifc_end_layer_i;
    reg [7:0] pu_inf_ifc_zp_i;
    reg [7:0] pu_inf_fltc_zp_i;
    wire pu_ifc_rdy_o;

    // FILTER BUFFER
    reg [K-1:0] pu_fltbuf_vld_i;
    reg [WIDTH-1:0] pu_fltbuf_data_i;
    reg pu_fltbuf_done_pass_i;
    wire pu_fltbuf_rdy_o;

    // OUTPUT
    reg pu_ofbuf_rdy_i;
    wire pu_ofbuf_vld_o;
    wire [WIDTH-1:0] pu_ofbuf_data_o;
    wire pu_pa_done_compute_o;

    // GLOBAL TEST VARIABLES
    integer toggle_done;

    // ==========================================
    // 3. DUT infTANTIATION
    // ==========================================
    comp_pu #(
        .WIDTH(WIDTH),
        .ACC_WIDTH(32),
        .PE_PER_PU(PE_PER_PU),
        .DEPTH(DEPTH),
        .K(K)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .pu_inf_dw_i(pu_inf_dw_i),
        .pu_inf_hf_i(pu_inf_hf_i),
        .pu_inf_stride_i(pu_inf_stride_i),
        .pu_inf_padding_i(pu_inf_padding_i),
        .pu_ifc_end_row_circle_i(pu_ifc_end_row_circle_i),
        .pu_ifc_end_row_i(pu_ifc_end_row_i),
        .pu_ifc_end_depth_i(pu_ifc_end_depth_i),
        .pu_ifc_end_layer_i(pu_ifc_end_layer_i),
        .pu_ifc_vld_i(pu_ifc_vld_i),
        .pu_ifc_data_i(pu_ifc_data_i),
        .pu_ifc_rdy_o(pu_ifc_rdy_o),
        .pu_inf_ifc_zp_i(pu_inf_ifc_zp_i),   // Map Zero Point
        .pu_inf_fltc_zp_i(pu_inf_fltc_zp_i), // Map Zero Point
        .pu_fltbuf_vld_i(pu_fltbuf_vld_i),
        .pu_fltbuf_data_i(pu_fltbuf_data_i),
        .pu_fltbuf_done_pass_i(pu_fltbuf_done_pass_i),
        .pu_fltbuf_rdy_o(pu_fltbuf_rdy_o),
        .pu_ofbuf_rdy_i(pu_ofbuf_rdy_i),
        .pu_ofbuf_vld_o(pu_ofbuf_vld_o),
        .pu_ofbuf_data_o(pu_ofbuf_data_o),
        .pu_pa_done_compute_o(pu_pa_done_compute_o)
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
        pu_ifc_vld_i = 0;
        pu_fltbuf_vld_i = 0;
        pu_ofbuf_rdy_i = 1;
        pu_inf_ifc_zp_i = 0;
        pu_inf_fltc_zp_i = 0;
        // Initialize global variables to avoid 'x' state
        toggle_done = 0; 

        #20;
        rst_n = 1;

        #10;
        run_all_tests();
    end

    // ==========================================
    // 5. TASKS
    // ==========================================
    task send_filter_pass;
        input integer num_filter;
        input integer base_value;
        integer total;
        integer i;
        integer j;
        reg [WIDTH-1:0] temp_val; // Biến tạm tránh lỗi bit-width
        begin
            total = num_filter * pu_inf_hf_i * pu_inf_hf_i;
            for(j = 0; j < K; j = j + 1) begin
                for(i = 0; i < total; i = i + 1) begin
                
                // Đưa tín hiệu lên bus
                    pu_fltbuf_vld_i = 1 << j;
                    temp_val = base_value + i;
                    pu_fltbuf_data_i = {{temp_val}};

                    // Cập nhật cờ done
                    if(toggle_done && i == total - 1 && j == K - 1)
                        pu_fltbuf_done_pass_i = 1'b1;
                    else
                        pu_fltbuf_done_pass_i = 1'b0;

                    // CHỜ HANDSHAKE THEO XUNG CLOCK
                    @(posedge clk);
                    while(pu_fltbuf_rdy_o !== 1'b1) begin
                        @(posedge clk);
                    end
                    #1; // Delay Clock-to-Q mô phỏng để waveform đẹp hơn
                end

                // Xử lý gửi nhịp done nếu pass trước chưa kết thúc
                if(!toggle_done && j == K - 1) begin
                    pu_fltbuf_vld_i = {K{1'b0}};
                    pu_fltbuf_done_pass_i = 1'b1;
                    @(posedge clk);
                    pu_fltbuf_done_pass_i = 1'b0;
                    #1;
                end
                
                toggle_done = ~toggle_done;
                pu_fltbuf_vld_i = {K{1'b0}};
                pu_fltbuf_done_pass_i = 1'b0;
            end 
        end
            
    endtask

    task send_ifmap;
        input integer data;
        input end_row;
        input end_row_circle;
        input end_depth;
        input end_height;
        input end_layer;
        reg [WIDTH-1:0] temp_data;
        begin
            temp_data = data;
            
            // Đưa tín hiệu lên bus
            pu_ifc_vld_i = 1'b1;
            pu_ifc_data_i = {K{temp_data}};
            pu_ifc_end_row_i = end_row;
            pu_ifc_end_row_circle_i = end_row_circle;
            pu_ifc_end_depth_i = end_depth;
            pu_ifc_end_height_i = end_height;
            pu_ifc_end_layer_i = end_layer;

            // CHỜ HANDSHAKE THEO XUNG CLOCK
            @(posedge clk);
            while(pu_ifc_rdy_o !== 1'b1) begin
                @(posedge clk);
            end
            // #1; // Delay Clock-to-Q
        end
    endtask

    task send_ifmap_row_auto;
        input integer row_data [0:127]; // Passing array requires SystemVerilog
        input integer row_len;
        input integer hf;
        input integer stride;
        input integer num_pass;
        input last_row;
        input last_channel;
        input last_layer;

        integer start;
        integer pass;
        integer i;
        reg end_row;
        reg end_circle;
        reg end_depth;
        reg end_height;
        reg end_layer;

        begin
            for(pass = 0; pass < num_pass; pass = pass + 1) begin
                for(start = 0; start + hf <= row_len; start = start + stride) begin
                    for(i = 0; i < hf; i = i + 1) begin
                        end_row = (i == hf - 1) && (start + stride + hf > row_len);
                        end_circle = end_row && (pass == num_pass - 1);
                        end_depth = end_circle && last_channel;
                        end_height = end_circle && last_row;
                        end_layer = end_circle && last_row && last_channel && last_layer;

                        send_ifmap(row_data[start+i], end_row, end_circle, end_depth, end_height, end_layer);
                    end
                end
            end
        end
    endtask

    task run_layer;
        input integer pass;
        input integer filter_parallel;
        input integer channel;
        input integer row;
        input integer base_filter;
        
        integer p, c, r;
        integer pi, ci, ri;
        integer row_data [0:127]; 

        begin
            fork
                // ------------------ Filter Thread ------------------
                begin
                    for(r = 0; r < row; r = r + 1)
                        for(c = 0; c < channel; c = c + 1)
                            for(p = 0; p < pass; p = p + 1)
                                send_filter_pass(filter_parallel, base_filter + p*100 + c*1000);
                end

                // ------------------ IFMAP Thread ------------------
                begin
                    for(ri = 0; ri < row; ri = ri + 1) begin
                        for(ci = 0; ci < channel; ci = ci + 1) begin
                            /* example padded row */
                            row_data[0] = 0;
                            row_data[1] = 1;
                            row_data[2] = 2;
                            row_data[3] = 3;
                            row_data[4] = 4;
                            row_data[5] = 5;
                            row_data[6] = 0;

                            send_ifmap_row_auto(row_data, 7, pu_inf_hf_i, pu_inf_stride_i, pass, (ri == row - 1), (ci == channel - 1), 1);
                        end
                    end
                end
            join
            
            // Hạ toàn bộ cờ giao tiếp IFMAP xuống 0 sau khi hoàn thành chạy song song
            pu_ifc_vld_i = 1'b0;
            pu_ifc_end_row_i = 1'b0;
            pu_ifc_end_row_circle_i = 1'b0;
            pu_ifc_end_depth_i = 1'b0;
            pu_ifc_end_height_i = 1'b0;
            pu_ifc_end_layer_i = 1'b0;

            // Chờ PU báo done (Lên 1)
            wait(pu_pa_done_compute_o == 1'b1);
            // Chờ PU hạ cờ done xuống (Về 0) để dọn sạch kết quả
            wait(pu_pa_done_compute_o == 1'b0);
            @(posedge clk);
        end
    endtask

    // ==========================================
    // 6. TEST CASES
    // ==========================================
    task test_std_conv;
        begin
            pu_inf_dw_i = 0;
            pu_inf_hf_i = 3;
            pu_inf_stride_i = 2;
            pu_inf_padding_i = 1;
            run_layer(1, 2, 2, 2, 0);
        end
    endtask

    task test_multi_pass;
        begin
            pu_inf_dw_i = 0;
            pu_inf_hf_i = 3;
            pu_inf_stride_i = 2;
            pu_inf_padding_i = 1;
            run_layer(2, 1, 2, 2, 200);
        end
    endtask

    task test_depthwise;
        begin
            pu_inf_dw_i = 1;
            pu_inf_hf_i = 3;
            pu_inf_stride_i = 1;
            pu_inf_padding_i = 1;
            run_layer(1, 1, 3, 2, 400);
        end
    endtask

    task test_pointwise;
        begin
            pu_inf_dw_i = 0;
            pu_inf_hf_i = 1;
            pu_inf_stride_i = 1;
            pu_inf_padding_i = 0;
            run_layer(1, 4, 3, 2, 600);
        end
    endtask

    task test_large_filter;
        begin
            pu_inf_dw_i = 0;
            pu_inf_hf_i = 7;
            pu_inf_stride_i = 2;
            pu_inf_padding_i = 1;
            run_layer(2, 1, 2, 7, 800);
        end
    endtask

    task run_all_tests;
        begin
            $display("STD CONV");
            test_std_conv();
            
            $display("MULTI PASS");
            test_multi_pass();
            
            $display("DEPTHWISE");
            test_depthwise();
            
            $display("POINTWISE");
            test_pointwise();
            
            $display("LARGE FILTER");
            test_large_filter();
            
            $display("ALL TEST DONE");
            #100 $finish;
        end
    endtask

    // ==========================================
    // 7. OUTPUT MONITOR
    // ==========================================
    always @(posedge clk) begin
        if(pu_ofbuf_vld_o && pu_ofbuf_rdy_i)
            $display("time=%0t output=%d", $time, pu_ofbuf_data_o);
    end

endmodule