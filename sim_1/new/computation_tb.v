`timescale 1ns / 1ps

module computation_tb;

    // ==========================================
    // 1. PARAMETERS (Đồng bộ với DUT)
    // ==========================================
    parameter WIDTH       = 32;
    parameter ACC_WIDTH   = 32;
    parameter PE_PER_PU   = 12;
    parameter DEPTH       = 11;
    parameter K           = 3;
    parameter M           = 2;
    parameter PPDEPTH     = 1792;
    parameter FIFO_DEPTH  = 12;
    parameter CLK_PERIOD  = 2;
    parameter TEST_TIMEOUT_CYCLES = 5000;
    parameter VERBOSE     = 1;

    // ==========================================
    // 2. SIGNALS DECLARATION
    // ==========================================
    reg clk;
    reg rst_n;

    // INSTRUCTION
    reg               comp_ins_dw_i;
    reg [3:0]         comp_ins_hf_i;
    reg [2:0]         comp_ins_stride_i;
    reg [1:0]         comp_ins_padding_i;
    reg [7:0]         comp_ins_ifc_zp_i;
    reg [7:0]         comp_ins_fltc_zp_i;

    // IFMAP BUFFER (Vào Cache)
    reg               comp_ifbuf_vld_i;
    reg [K*WIDTH-1:0] comp_ifbuf_data_i;
    reg               comp_ifbuf_tlast_i;
    reg               comp_ifbuf_end_row_circle_i;
    reg               comp_ifbuf_end_depth_i;
    reg               comp_ifbuf_end_layer_i;
    wire              comp_ifbuf_rdy_o;

    // FILTER BUFFER (Vào PU)
    reg [K*M-1:0]         comp_fltbuf_vld_i;
    reg [K*M*WIDTH-1:0]   comp_fltbuf_data_i;
    reg                   comp_fltbuf_done_pass_i;
    wire [M-1:0]          comp_fltbuf_rdy_o;

    // OUTPUT BUFFER (Ra từ PU)
    reg [M-1:0]            comp_ofbuf_rdy_i;
    wire [M-1:0]           comp_ofbuf_vld_o;
    wire [M*ACC_WIDTH-1:0] comp_ofbuf_data_o;
    wire                   comp_pa_done_compute_o;

    // ==========================================
    // 3. SCOREBOARD / STATISTICS
    // ==========================================
    integer total_test_cnt;
    integer passed_test_cnt;
    integer failed_test_cnt;

    integer cur_test_error;
    integer cur_ifmap_accept_cnt;
    integer cur_filter_accept_cnt;
    integer cur_cache_to_pu_cnt;
    integer cur_output_accept_cnt;
    integer cur_done_pulse_cnt;

    integer global_output_cnt;
    integer global_done_cnt;

    integer mon_idx;
    integer pu_idx;
    integer lane_idx;

    // ==========================================
    // 4. DUT INSTANTIATION
    // ==========================================
    computation #(
        .WIDTH(WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .PE_PER_PU(PE_PER_PU),
        .DEPTH(DEPTH),
        .K(K),
        .M(M),
        .PPDEPTH(PPDEPTH),
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
    // 5. CLOCK / DUMP
    // ==========================================
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    initial begin
        $dumpfile("computation_tb_rewrite.vcd");
        $dumpvars(0, computation_tb);
    end

    // ==========================================
    // 6. COMMON TASKS
    // ==========================================
    task clear_inputs;
    begin
        comp_ins_dw_i                 = 0;
        comp_ins_hf_i                 = 0;
        comp_ins_stride_i             = 0;
        comp_ins_padding_i            = 0;
        comp_ins_ifc_zp_i             = 0;
        comp_ins_fltc_zp_i            = 0;

        comp_ifbuf_vld_i              = 0;
        comp_ifbuf_data_i             = 0;
        comp_ifbuf_tlast_i            = 0;
        comp_ifbuf_end_row_circle_i   = 0;
        comp_ifbuf_end_depth_i        = 0;
        comp_ifbuf_end_layer_i        = 0;

        comp_fltbuf_vld_i             = 0;
        comp_fltbuf_data_i            = 0;
        comp_fltbuf_done_pass_i       = 0;

        comp_ofbuf_rdy_i              = {M{1'b1}};
    end
    endtask

    task reset_scoreboard_for_test;
    begin
        cur_test_error         = 0;
        cur_ifmap_accept_cnt   = 0;
        cur_filter_accept_cnt  = 0;
        cur_cache_to_pu_cnt    = 0;
        cur_output_accept_cnt  = 0;
        cur_done_pulse_cnt     = 0;
    end
    endtask

    task start_test;
        input [8*64-1:0] test_name;
    begin
        total_test_cnt = total_test_cnt + 1;
        reset_scoreboard_for_test();
        $display("\n============================================================");
        $display("[TEST %0d START] %0s", total_test_cnt, test_name);
        $display("============================================================");
    end
    endtask

    task check_true;
        input condition;
        input [8*96-1:0] msg;
    begin
        if (!condition) begin
            cur_test_error = 1;
            $display("[ERROR][%0t] %0s", $time, msg);
        end
    end
    endtask

    task finish_test;
        input [8*64-1:0] test_name;
    begin
        $display("[TEST %0d SUMMARY] %0s", total_test_cnt, test_name);
        $display("  ifmap accepted      = %0d", cur_ifmap_accept_cnt);
        $display("  filter accepted     = %0d", cur_filter_accept_cnt);
        $display("  cache->PU accepted  = %0d", cur_cache_to_pu_cnt);
        $display("  output accepted     = %0d", cur_output_accept_cnt);
        $display("  done pulses         = %0d", cur_done_pulse_cnt);

        if (cur_test_error == 0) begin
            passed_test_cnt = passed_test_cnt + 1;
            $display("[TEST %0d PASS] %0s", total_test_cnt, test_name);
        end else begin
            failed_test_cnt = failed_test_cnt + 1;
            $display("[TEST %0d FAIL] %0s", total_test_cnt, test_name);
        end
    end
    endtask

    task apply_reset;
    begin
        clear_inputs();
        rst_n = 1'b0;
        repeat (10) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);
        $display("[INFO][%0t] Reset released", $time);
    end
    endtask

    task configure_instruction;
        input integer dw;
        input integer hf;
        input integer stride;
        input integer padding;
        input integer ifc_zp;
        input integer fltc_zp;
    begin
        comp_ins_dw_i      = dw;
        comp_ins_hf_i      = hf[3:0];
        comp_ins_stride_i  = stride[2:0];
        comp_ins_padding_i = padding[1:0];
        comp_ins_ifc_zp_i  = ifc_zp[7:0];
        comp_ins_fltc_zp_i = fltc_zp[7:0];

        $display("[INFO][%0t] Configure instruction: dw=%0d hf=%0d stride=%0d padding=%0d ifc_zp=%0d fltc_zp=%0d",
                 $time, dw, hf, stride, padding, ifc_zp, fltc_zp);
    end
    endtask

    task clear_filter_bus;
    begin
        comp_fltbuf_vld_i       = 0;
        comp_fltbuf_data_i      = 0;
        comp_fltbuf_done_pass_i = 0;
    end
    endtask

    task send_one_filter_word;
        input integer pu_sel;
        input integer lane_sel;
        input integer value;
        input integer done_pass;
        integer flat_idx;
    begin
        flat_idx = pu_sel*K + lane_sel;

        while (comp_fltbuf_rdy_o[pu_sel] !== 1'b1) begin
            @(posedge clk);
        end

        comp_fltbuf_vld_i       = 0;
        comp_fltbuf_data_i      = 0;
        comp_fltbuf_done_pass_i = done_pass;
        comp_fltbuf_vld_i[flat_idx] = 1'b1;
        comp_fltbuf_data_i[flat_idx*WIDTH +: WIDTH] = value[WIDTH-1:0];

        @(posedge clk);
        #1;

        if (VERBOSE) begin
            $display("[FLT ][%0t] pu=%0d lane=%0d value=%0d done_pass=%0d rdy=%0b",
                     $time, pu_sel, lane_sel, value, done_pass, comp_fltbuf_rdy_o[pu_sel]);
        end

        clear_filter_bus();
    end
    endtask

    task pulse_done_pass_only;
    begin
        comp_fltbuf_done_pass_i = 1'b1;
        @(posedge clk);
        #1;
        comp_fltbuf_done_pass_i = 1'b0;
        if (VERBOSE) begin
            $display("[FLT ][%0t] pulse done_pass only", $time);
        end
    end
    endtask

    task send_filter_pass;
        input integer num_filter;
        input integer base_value;
        integer total;
        integer pu_sel;
        integer lane_sel;
        integer i;
        integer done_last_word;
        integer value;
    begin
        total = num_filter * comp_ins_hf_i * comp_ins_hf_i;
        for (pu_sel = 0; pu_sel < M; pu_sel = pu_sel + 1) begin
            for (lane_sel = 0; lane_sel < K; lane_sel = lane_sel + 1) begin
                for (i = 0; i < total; i = i + 1) begin
                    value = base_value + (pu_sel*10000) + (lane_sel*1000) + i;
                    done_last_word = (pu_sel == M-1) && (lane_sel == K-1) && (i == total-1);
                    send_one_filter_word(pu_sel, lane_sel, value, done_last_word);
                end
            end
        end

        if (total == 0) begin
            pulse_done_pass_only();
        end
    end
    endtask

    task send_ifmap_beat;
        input integer data_value;
        input integer is_tlast;
        input integer is_end_circle;
        input integer is_end_depth;
        input integer is_end_layer;
    begin
        while (comp_ifbuf_rdy_o !== 1'b1) begin
            @(posedge clk);
        end

        @(negedge clk);
        comp_ifbuf_vld_i            = 1'b1;
        comp_ifbuf_data_i           = {K{data_value[WIDTH-1:0]}};
        comp_ifbuf_tlast_i          = is_tlast;
        comp_ifbuf_end_row_circle_i = is_end_circle;
        comp_ifbuf_end_depth_i      = is_end_depth;
        comp_ifbuf_end_layer_i      = is_end_layer;

        if (VERBOSE) begin
            $display("[IFM ][%0t] data=%0d tlast=%0d end_circle=%0d end_depth=%0d end_layer=%0d",
                     $time, data_value, is_tlast, is_end_circle, is_end_depth, is_end_layer);
        end

        @(posedge clk);
        #1;
    end
    endtask

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
        integer c;
        integer r;
        integer p;
        integer i;
        integer data_val;
        reg is_tlast;
        reg is_end_circle;
        reg is_end_depth;
        reg is_end_layer;
    begin
        O_val = ((W + 2*P - K_filter) / S) + 1;
        Pos_last = (O_val - 1) * S + (K_filter - 1);

        for (r = 0; r < num_rows; r = r + 1) begin
            for (c = 0; c < num_chans; c = c + 1) begin
                for (p = 0; p < pass; p = p + 1) begin
                    for (i = 0; i <= Pos_last; i = i + 1) begin
                        if (i < P || i >= (W + P))
                            data_val = 0;
                        else
                            data_val = (i - P) % W;

                        is_tlast      = (i == Pos_last);
                        is_end_circle = is_tlast;
                        is_end_depth  = is_tlast && (c == num_chans - 1);
                        is_end_layer  = is_end_depth && (r == num_rows - 1);

                        send_ifmap_beat(data_val, is_tlast, is_end_circle, is_end_depth, is_end_layer);
                    end
                end
            end
        end

        @(negedge clk);
        comp_ifbuf_vld_i            = 1'b0;
        comp_ifbuf_data_i           = 0;
        comp_ifbuf_tlast_i          = 1'b0;
        comp_ifbuf_end_row_circle_i = 1'b0;
        comp_ifbuf_end_depth_i      = 1'b0;
        comp_ifbuf_end_layer_i      = 1'b0;
    end
    endtask

    task wait_done_with_timeout;
        input integer timeout_cycles;
        integer cyc;
    begin
        cyc = 0;
        while ((comp_pa_done_compute_o !== 1'b1) && (cyc < timeout_cycles)) begin
            @(posedge clk);
            cyc = cyc + 1;
        end

        if (cyc >= timeout_cycles) begin
            cur_test_error = 1;
            $display("[ERROR][%0t] Timeout waiting for comp_pa_done_compute_o", $time);
        end else begin
            $display("[INFO ][%0t] Done asserted after %0d cycles", $time, cyc);
            while (comp_pa_done_compute_o === 1'b1) begin
                @(posedge clk);
            end
            @(posedge clk);
        end
    end
    endtask

    task run_layer;
        input integer W;
        input integer P;
        input integer S;
        input integer K_filter;
        input integer num_rows;
        input integer num_chans;
        input integer pass;
        input integer filter_parallel;
        input integer base_filter;

        integer p;
        integer c;
        integer r;
    begin
        fork
            begin : filter_thread
                for (r = 0; r < num_rows; r = r + 1)
                    for (c = 0; c < num_chans; c = c + 1)
                        for (p = 0; p < pass; p = p + 1)
                            send_filter_pass(filter_parallel, base_filter + p*100 + c*1000 + r*10000);
            end
            begin : ifmap_thread
                run_layer_ifmap(W, P, S, K_filter, num_rows, num_chans, pass);
            end
        join

        wait_done_with_timeout(TEST_TIMEOUT_CYCLES);
    end
    endtask

    // ==========================================
    // 7. TEST CASES
    // ==========================================
    task test_reset_idle;
    begin
        start_test("reset_and_idle");
        apply_reset();
        repeat (10) @(posedge clk);

        check_true(comp_ifbuf_rdy_o !== 1'bx, "comp_ifbuf_rdy_o bi X sau reset");
        check_true(comp_ofbuf_vld_o == {M{1'b0}}, "comp_ofbuf_vld_o phai = 0 khi idle");
        check_true(comp_pa_done_compute_o == 1'b0, "done phai = 0 khi idle");

        finish_test("reset_and_idle");
    end
    endtask

    task test_computation_basic;
    begin
        start_test("basic_single_pass");
        apply_reset();
        configure_instruction(0, 3, 2, 1, 0, 0);

        $display("[CASE ] Basic: W=5 P=1 S=2 K=3 rows=2 chans=2 pass=1 parallel=1");
        run_layer(5, 1, 2, 3, 2, 2, 1, 1, 0);

        check_true(cur_ifmap_accept_cnt > 0, "Khong co ifmap beat nao duoc accept");
        check_true(cur_filter_accept_cnt > 0, "Khong co filter beat nao duoc accept");
        check_true(cur_cache_to_pu_cnt > 0, "Khong co beat nao di tu cache sang PU");
        check_true(cur_output_accept_cnt > 0, "Khong co output nao duoc tao ra");
        check_true(cur_done_pulse_cnt > 0, "Khong co done pulse nao");

        finish_test("basic_single_pass");
    end
    endtask

    task test_computation_multi_pass;
    begin
        start_test("multi_pass_multi_channel");
        apply_reset();
        configure_instruction(0, 3, 1, 1, 0, 0);

        $display("[CASE ] Multi-pass: W=6 P=1 S=1 K=3 rows=2 chans=2 pass=2 parallel=1");
        run_layer(6, 1, 1, 3, 2, 2, 2, 1, 100);

        check_true(cur_ifmap_accept_cnt >= 10, "So beat ifmap qua it cho bai test multi-pass");
        check_true(cur_filter_accept_cnt >= 10, "So beat filter qua it cho bai test multi-pass");
        check_true(cur_output_accept_cnt > 0, "Khong co output trong bai test multi-pass");
        check_true(cur_done_pulse_cnt > 0, "Khong co done pulse trong bai test multi-pass");

        finish_test("multi_pass_multi_channel");
    end
    endtask

    task test_output_backpressure;
    begin
        start_test("output_backpressure");
        apply_reset();
        configure_instruction(0, 3, 2, 1, 0, 0);

        fork
            begin
                run_layer(5, 1, 2, 3, 2, 2, 1, 1, 200);
            end
            begin
                repeat (25) @(posedge clk);
                comp_ofbuf_rdy_i = {M{1'b0}};
                $display("[CASE ][%0t] Force output backpressure", $time);
                repeat (12) @(posedge clk);
                comp_ofbuf_rdy_i = {M{1'b1}};
                $display("[CASE ][%0t] Release output backpressure", $time);
            end
        join

        check_true(cur_output_accept_cnt > 0, "Khong co output sau khi nha backpressure");
        check_true(cur_done_pulse_cnt > 0, "Khong co done pulse trong test backpressure");

        finish_test("output_backpressure");
    end
    endtask

    task run_all_tests;
    begin
        test_reset_idle();
        test_computation_basic();
        test_computation_multi_pass();
        test_output_backpressure();

        $display("\n================ FINAL SUMMARY ================");
        $display("Total tests  : %0d", total_test_cnt);
        $display("Passed tests : %0d", passed_test_cnt);
        $display("Failed tests : %0d", failed_test_cnt);
        $display("Global output: %0d", global_output_cnt);
        $display("Global done  : %0d", global_done_cnt);
        $display("===============================================\n");

        #20;
        $finish;
    end
    endtask

    // ==========================================
    // 8. MONITORS / ASSERTIONS
    // ==========================================
    always @(posedge clk) begin
        if (!rst_n)
            ;
        else begin
            if (comp_ifbuf_vld_i && comp_ifbuf_rdy_o) begin
                cur_ifmap_accept_cnt = cur_ifmap_accept_cnt + 1;
            end

            for (pu_idx = 0; pu_idx < M; pu_idx = pu_idx + 1) begin
                for (lane_idx = 0; lane_idx < K; lane_idx = lane_idx + 1) begin
                    if (comp_fltbuf_vld_i[pu_idx*K + lane_idx] && comp_fltbuf_rdy_o[pu_idx]) begin
                        cur_filter_accept_cnt = cur_filter_accept_cnt + 1;
                    end
                end
            end

            if (uut.ifc_pu_vld_w && uut.pu_ifc_rdy_w) begin
                cur_cache_to_pu_cnt = cur_cache_to_pu_cnt + 1;
                if (VERBOSE) begin
                    $display("[C2PU][%0t] data=%h end_row=%0b end_circle=%0b end_depth=%0b end_layer=%0b",
                             $time,
                             uut.ifc_pu_data_w,
                             uut.ifc_pu_end_row_w,
                             uut.ifc_pu_end_row_circle_w,
                             uut.ifc_pu_end_depth_w,
                             uut.ifc_pu_end_layer_w);
                end
            end

            for (mon_idx = 0; mon_idx < M; mon_idx = mon_idx + 1) begin
                if (comp_ofbuf_vld_o[mon_idx] && comp_ofbuf_rdy_i[mon_idx]) begin
                    cur_output_accept_cnt = cur_output_accept_cnt + 1;
                    global_output_cnt     = global_output_cnt + 1;
                    if ((^comp_ofbuf_data_o[(mon_idx+1)*ACC_WIDTH-1 -: ACC_WIDTH]) === 1'bx) begin
                        cur_test_error = 1;
                        $display("[ERROR][%0t] Output PU[%0d] chua X/Z", $time, mon_idx);
                    end
                    $display("[OUT ][%0t] PU[%0d] output=%0d (0x%0h)",
                             $time,
                             mon_idx,
                             comp_ofbuf_data_o[(mon_idx+1)*ACC_WIDTH-1 -: ACC_WIDTH],
                             comp_ofbuf_data_o[(mon_idx+1)*ACC_WIDTH-1 -: ACC_WIDTH]);
                end else if (comp_ofbuf_vld_o[mon_idx] && !comp_ofbuf_rdy_i[mon_idx] && VERBOSE) begin
                    $display("[STALL][%0t] PU[%0d] output valid but ofbuf not ready", $time, mon_idx);
                end
            end

            if (comp_pa_done_compute_o) begin
                cur_done_pulse_cnt = cur_done_pulse_cnt + 1;
                global_done_cnt    = global_done_cnt + 1;
                $display("[DONE][%0t] comp_pa_done_compute_o asserted", $time);
            end
        end
    end

    // ==========================================
    // 9. MAIN SEQUENCE
    // ==========================================
    initial begin
        total_test_cnt   = 0;
        passed_test_cnt  = 0;
        failed_test_cnt  = 0;
        global_output_cnt = 0;
        global_done_cnt   = 0;
        clear_inputs();
        rst_n = 1'b0;

        repeat (2) @(posedge clk);
        run_all_tests();
    end

endmodule
