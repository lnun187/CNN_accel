`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/19/2026 02:08:53 PM
// Design Name: 
// Module Name: computation_tb
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

module computation_tb;

    // ==========================================
    // 1. PARAMETERS (Đồng bộ với DUT)
    // ==========================================
    parameter WIDTH = 32;
    parameter ACC_WIDTH = 32;
    parameter PE_PER_PU = 12;
    parameter DEPTH = 11;
    parameter K = 3;        // K=3 để dễ theo dõi giống ifmap_cache
    parameter M = 2;        // Test với 2 PUs
    parameter PPDEPTH = 1792;
    parameter ADDR_WIDTH = 8;
    parameter FIFO_DEPTH = 12;
    
    parameter CLK_PERIOD = 2;

    // ==========================================
    // 2. SIGNALS DECLARATION
    // ==========================================
    reg clk;
    reg rst_n;

    // INSTRUCTION
    reg comp_ins_dw_i;
    reg [3:0] comp_ins_hf_i;
    reg [1:0] comp_ins_stride_i;
    reg [1:0] comp_ins_padding_i;
    reg [7:0] comp_ins_ifc_zp_i;
    reg [7:0] comp_ins_fltc_zp_i;

    // IFMAP BUFFER (Vào Cache)
    reg comp_ifbuf_vld_i;
    reg [K*WIDTH-1:0] comp_ifbuf_data_i;
    reg comp_ifbuf_tlast_i;
    reg comp_ifbuf_end_row_circle_i;
    reg comp_ifbuf_end_depth_i;
    reg comp_ifbuf_end_layer_i;
    wire comp_ifbuf_rdy_o;

    // FILTER BUFFER (Vào PU)
    reg [K*M-1:0] comp_fltbuf_vld_i;
    reg [WIDTH-1:0] comp_fltbuf_data_i;
    reg comp_fltbuf_done_pass_i;
    wire [M-1:0] comp_fltbuf_rdy_o;

    // OUTPUT BUFFER (Ra từ PU)
    reg [M-1:0] comp_ofbuf_rdy_i;
    wire [M-1:0] comp_ofbuf_vld_o;
    wire [M*ACC_WIDTH-1:0] comp_ofbuf_data_o;
    wire comp_pa_done_compute_o;

    // GLOBAL VARIABLES
    integer toggle_done;

    // ==========================================
    // 3. DUT INSTANTIATION
    // ==========================================
    computation #(
        .WIDTH(WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .PE_PER_PU(PE_PER_PU),
        .DEPTH(DEPTH),
        .K(K),
        .M(M),
        .PPDEPTH(PPDEPTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .comp_ins_dw_i(comp_ins_dw_i),
        .comp_ins_hf_i(comp_ins_hf_i),
        .comp_ins_stride_i(comp_ins_stride_i),
        .comp_ins_padding_i(comp_ins_padding_i),
        .comp_ins_ifc_zp_i(comp_ins_ifc_zp_i),
        .comp_ins_fltc_zp_i(comp_ins_fltc_zp_i),
        
        .comp_ifbuf_vld_i(comp_ifbuf_vld_i),
        .comp_ifbuf_data_i(comp_ifbuf_data_i),
        .comp_ifbuf_tlast_i(comp_ifbuf_tlast_i),
        .comp_ifbuf_end_row_circle_i(comp_ifbuf_end_row_circle_i),
        .comp_ifbuf_end_depth_i(comp_ifbuf_end_depth_i),
        .comp_ifbuf_end_layer_i(comp_ifbuf_end_layer_i),
        .comp_ifbuf_rdy_o(comp_ifbuf_rdy_o),

        .comp_fltbuf_vld_i(comp_fltbuf_vld_i),
        .comp_fltbuf_data_i(comp_fltbuf_data_i),
        .comp_fltbuf_done_pass_i(comp_fltbuf_done_pass_i),
        .comp_fltbuf_rdy_o(comp_fltbuf_rdy_o),

        .comp_ofbuf_rdy_i(comp_ofbuf_rdy_i),
        .comp_ofbuf_vld_o(comp_ofbuf_vld_o),
        .comp_ofbuf_data_o(comp_ofbuf_data_o),
        .comp_pa_done_compute_o(comp_pa_done_compute_o)
    );

    // ==========================================
    // 4. CLOCK & RESET
    // ==========================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        rst_n = 0;
        
        comp_ins_dw_i = 0;
        comp_ins_hf_i = 0;
        comp_ins_stride_i = 0;
        comp_ins_padding_i = 0;
        comp_ins_ifc_zp_i = 0;
        comp_ins_fltc_zp_i = 0;

        comp_ifbuf_vld_i = 0;
        comp_ifbuf_data_i = 0;
        comp_ifbuf_tlast_i = 0;
        comp_ifbuf_end_row_circle_i = 0;
        comp_ifbuf_end_depth_i = 0;
        comp_ifbuf_end_layer_i = 0;

        comp_fltbuf_vld_i = 0;
        comp_fltbuf_data_i = 0;
        comp_fltbuf_done_pass_i = 0;
        
        comp_ofbuf_rdy_i = {M{1'b1}}; // Luôn sẵn sàng nhận Data đầu ra
        toggle_done = 0;

        #20;
        rst_n = 1;
        
        #10;
        run_all_tests();
    end

    // ==========================================
    // 5. TASKS CHO FILTER (Dựa theo comp_pu_tb)
    // ==========================================
    task send_filter_pass;
        input integer num_filter;
        input integer base_value;
        integer total, i, j, m;
        reg [WIDTH-1:0] temp_val;
        reg [K*M-1:0] temp_vld;
        begin
            total = num_filter * comp_ins_hf_i * comp_ins_hf_i;
            for (m = 0; m < M; m = m + 1) begin
                for(j = 0; j < K; j = j + 1) begin
                    for(i = 0; i < total; i = i + 1) begin
                        
                        // Broadcast Filter Valid cho tất cả M PUs
                        temp_vld = 0;
                        
                        temp_vld[m*K + j] = 1'b1; 
                        
                        comp_fltbuf_vld_i = temp_vld;
                        
                        temp_val = base_value + i;
                        comp_fltbuf_data_i = temp_val;

                        if(toggle_done && i == total - 1 && j == K - 1 && m == M - 1)
                            comp_fltbuf_done_pass_i = 1'b1;
                        else
                            comp_fltbuf_done_pass_i = 1'b0;

                        @(posedge clk);
                        // Chờ tất cả M PUs sẵn sàng nhận filter
                        while(&comp_fltbuf_rdy_o !== 1'b1) begin
                            @(posedge clk);
                        end
                        #1;
                    end

                    if(!toggle_done && j == K - 1 && m == M - 1) begin
                        comp_fltbuf_vld_i = 0;
                        comp_fltbuf_done_pass_i = 1'b1;
                        @(posedge clk);
                        comp_fltbuf_done_pass_i = 1'b0;
                        #1;
                    end
                    
                    toggle_done = ~toggle_done;
                    comp_fltbuf_vld_i = 0;
                    comp_fltbuf_done_pass_i = 1'b0;
                end
            end
        end
    endtask

    // ==========================================
    // 6. TASKS CHO IFMAP (Dựa theo ifmap_cache_tb)
    // ==========================================
    task run_layer_ifmap;
        input integer W;         
        input integer P;         
        input integer S;         
        input integer K_filter;  
        input integer num_rows;  
        input integer num_chans;
        input integer pass;

        integer O_val;
        integer Pos_last;
        integer c, r, p, i;
        integer data_val;
        
        reg is_tlast, is_end_circle, is_end_depth, is_end_layer;
        begin
            O_val = ((W + 2*P - K_filter) / S) + 1;
            Pos_last = (O_val - 1) * S + (K_filter - 1);
            // @(negedge clk);
            comp_ifbuf_vld_i = 1'b1;
            for (r = 0; r < num_rows; r = r + 1) begin
                for (c = 0; c < num_chans; c = c + 1) begin
                    for(p = 0; p < pass; p = p + 1) begin
                        for(i = 0; i <= Pos_last; i = i + 1) begin
                        
                        // Xử lý Padding
                            if (i < P || i >= (W + P)) begin
                                data_val = 0;
                            end else begin
                                data_val = (i - P) % W;
                            end
                            comp_ifbuf_data_i = {K{data_val[WIDTH-1:0]}};

                            // Logic Cờ 
                            is_tlast = (i == Pos_last);
                            comp_ifbuf_tlast_i = is_tlast;

                            if (is_tlast) begin
                                is_end_circle = 1'b1;
                                is_end_depth  = is_end_circle && (c == num_chans - 1);
                                is_end_layer  = is_end_depth && (r == num_rows - 1);
                            end else begin
                                is_end_circle = 1'b0;
                                is_end_depth  = 1'b0;
                                is_end_layer  = 1'b0;
                            end

                            comp_ifbuf_end_row_circle_i = is_end_circle;
                            comp_ifbuf_end_depth_i = is_end_depth;
                            comp_ifbuf_end_layer_i = is_end_layer;

                            
                            while(comp_ifbuf_rdy_o !== 1'b1) begin
                                @(posedge clk);
                            end
                            @(negedge clk);
                        end
                    end
                    
                end
            end
            
            // Dọn dẹp cờ sau khi truyền xong IFMAP
            comp_ifbuf_vld_i = 1'b0;
            comp_ifbuf_tlast_i = 1'b0;
            comp_ifbuf_end_row_circle_i = 1'b0;
            comp_ifbuf_end_depth_i = 1'b0;
            comp_ifbuf_end_layer_i = 1'b0;
        end
    endtask

    // ==========================================
    // 7. TASK CHẠY TỔNG HỢP LAYER
    // ==========================================
    task run_layer;
        input integer W, P, S, K_filter, num_rows, num_chans;
        input integer pass, filter_parallel, base_filter;
        integer p, c, r;
        begin
            fork
                // LUỒNG 1: Truyền Filter Data
                begin
                    for(r = 0; r < num_rows; r = r + 1)
                        for(c = 0; c < num_chans; c = c + 1)
                            for(p = 0; p < pass; p = p + 1)
                                send_filter_pass(filter_parallel, base_filter + p*100 + c*1000);
                end
                
                // LUỒNG 2: Truyền Ifmap Data
                begin
                    run_layer_ifmap(W, P, S, K_filter, num_rows, num_chans, pass);
                end
            join
            
            // Chờ Computation hoàn tất 
            wait(comp_pa_done_compute_o == 1'b1);
            wait(comp_pa_done_compute_o == 1'b0);
            @(posedge clk);
        end
    endtask

    // ==========================================
    // 8. TEST CASES
    // ==========================================
    task test_computation;
        begin
            comp_ins_dw_i = 0;
            comp_ins_hf_i = 3;   // K_filter = 3
            comp_ins_stride_i = 2; // S = 2
            comp_ins_padding_i = 1; // P = 1

            // W=5, P=1, S=2, K=3. Num Rows=2, Num Chans=2. 
            // Pass=1, parallel=1, base=0
            $display(">>> Bắt đầu Test Computation: W=5, P=1, S=2, K=3, Rows=2, Chans=2");
            run_layer(5, 1, 2, 3, 2, 2, 1, 1, 0);
        end
    endtask

    task run_all_tests;
        begin
            test_computation();
            
            $display(">>> ALL TEST DONE <<<");
            #100 $finish;
        end
    endtask

    // ==========================================
    // 9. OUTPUT MONITOR
    // ==========================================
    integer o_idx;
    always @(posedge clk) begin
        // Quét qua toàn bộ M PUs xem PU nào có dữ liệu hợp lệ
        for (o_idx = 0; o_idx < M; o_idx = o_idx + 1) begin
            if(comp_ofbuf_vld_o[o_idx] && comp_ofbuf_rdy_i[o_idx]) begin
                $display("[Time=%0t] PU[%0d] Output = %d", 
                         $time, o_idx, comp_ofbuf_data_o[(o_idx+1)*WIDTH-1 -: WIDTH]);
            end
        end
    end

endmodule
