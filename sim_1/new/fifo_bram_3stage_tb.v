`timescale 1ns / 1ps

module fifo_bram_3stage_tb;
    localparam WIDTH = 8;
    localparam DEPTH = 4;
    localparam AW    = $clog2(DEPTH);

    reg                 clk;
    reg                 rst_n;
    reg                 wr_en;
    reg                 rd_en;
    reg                 clr;
    reg  [WIDTH-1:0]    din;
    wire [WIDTH-1:0]    dout;
    wire                full;
    wire                vld_o;
    wire                end_data;

    fifo_bram #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .wr_en    (wr_en),
        .rd_en    (rd_en),
        .clr      (clr),
        .din      (din),
        .dout     (dout),
        .full     (full),
        .vld_o    (vld_o),
        .end_data (end_data)
    );

    // =========================================================
    // Reference model (cycle-accurate with DUT RTL behavior)
    // =========================================================
    reg [WIDTH-1:0] mem_m [0:DEPTH-1];
    reg [AW-1:0]    wr_ptr_m, rd_ptr_m;
    reg             valid_out_m;
    reg [WIDTH-1:0] data_out_ram_m;
    reg [WIDTH-1:0] data_out_bypass_m;
    reg             bypass_req_ff_m;
    reg [WIDTH-1:0] din_bypass_ff_m;
    reg [WIDTH-1:0] dout_r_m;
    reg             load_word_d1_m, load_word_d2_m;
    reg             bypass_sel_d2_m;
    reg             valid_d1_m, valid_d2_m;
    reg             end_d1_m, end_d2_m;

    integer         i;
    integer         cycle_count;

    reg [WIDTH-1:0] exp_dout;
    reg             exp_full;
    reg             exp_vld_o;
    reg             exp_end_data;

    // Clock: 100 MHz
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function [AW-1:0] f_next_ptr;
        input [AW-1:0] ptr;
        begin
            if (ptr == DEPTH-1)
                f_next_ptr = {AW{1'b0}};
            else
                f_next_ptr = ptr + 1'b1;
        end
    endfunction

    task model_reset;
        integer k;
        begin
            wr_ptr_m         = {AW{1'b0}};
            rd_ptr_m         = {AW{1'b0}};
            valid_out_m      = 1'b0;
            data_out_ram_m   = {WIDTH{1'b0}};
            data_out_bypass_m= {WIDTH{1'b0}};
            bypass_req_ff_m  = 1'b0;
            din_bypass_ff_m  = {WIDTH{1'b0}};
            dout_r_m         = {WIDTH{1'b0}};
            load_word_d1_m   = 1'b0;
            load_word_d2_m   = 1'b0;
            bypass_sel_d2_m  = 1'b0;
            valid_d1_m       = 1'b0;
            valid_d2_m       = 1'b0;
            end_d1_m         = 1'b0;
            end_d2_m         = 1'b0;
            for (k = 0; k < DEPTH; k = k + 1)
                mem_m[k] = {WIDTH{1'b0}};
        end
    endtask

    task model_step;
        input                 wr_i;
        input                 rd_i;
        input                 clr_i;
        input [WIDTH-1:0]     din_i;

        reg [AW-1:0] old_wr_ptr, old_rd_ptr;
        reg          old_valid_out;
        reg [WIDTH-1:0] old_data_out_ram, old_data_out_bypass;
        reg          old_bypass_req_ff;
        reg [WIDTH-1:0] old_din_bypass_ff;
        reg [WIDTH-1:0] old_dout_r;
        reg          old_load_word_d1, old_load_word_d2;
        reg          old_bypass_sel_d2;
        reg          old_valid_d1, old_valid_d2;
        reg          old_end_d1, old_end_d2;
        reg [WIDTH-1:0] old_mem_rd_data;

        reg [AW-1:0] next_wr_ptr_m;
        reg [AW-1:0] next_rd_ptr_m;
        reg          mem_empty_m;
        reg          full_m;
        reg          do_write_m;
        reg          need_fetch_m;
        reg          ram_fetch_m;
        reg          bypass_fetch_m;
        reg          load_word_m;
        reg          end_core_m;
        integer      idx;
        begin
            old_wr_ptr         = wr_ptr_m;
            old_rd_ptr         = rd_ptr_m;
            old_valid_out      = valid_out_m;
            old_data_out_ram   = data_out_ram_m;
            old_data_out_bypass= data_out_bypass_m;
            old_bypass_req_ff  = bypass_req_ff_m;
            old_din_bypass_ff  = din_bypass_ff_m;
            old_dout_r         = dout_r_m;
            old_load_word_d1   = load_word_d1_m;
            old_load_word_d2   = load_word_d2_m;
            old_bypass_sel_d2  = bypass_sel_d2_m;
            old_valid_d1       = valid_d1_m;
            old_valid_d2       = valid_d2_m;
            old_end_d1         = end_d1_m;
            old_end_d2         = end_d2_m;
            old_mem_rd_data    = mem_m[rd_ptr_m];

            if (!rst_n) begin
                model_reset();
            end else if (clr_i) begin
                wr_ptr_m         = {AW{1'b0}};
                rd_ptr_m         = {AW{1'b0}};
                valid_out_m      = 1'b0;
                bypass_req_ff_m  = 1'b0;
                din_bypass_ff_m  = {WIDTH{1'b0}};
                load_word_d1_m   = 1'b0;
                load_word_d2_m   = 1'b0;
                bypass_sel_d2_m  = 1'b0;
                valid_d1_m       = 1'b0;
                valid_d2_m       = 1'b0;
                end_d1_m         = 1'b0;
                end_d2_m         = 1'b0;
                dout_r_m         = {WIDTH{1'b0}};
            end else begin
                next_wr_ptr_m = f_next_ptr(old_wr_ptr);
                next_rd_ptr_m = f_next_ptr(old_rd_ptr);
                mem_empty_m   = (old_wr_ptr == old_rd_ptr);
                full_m        = (next_wr_ptr_m == old_rd_ptr);
                do_write_m    = wr_i && !full_m;
                need_fetch_m  = rd_i || !old_valid_out;
                ram_fetch_m   = need_fetch_m && !mem_empty_m;
                bypass_fetch_m= need_fetch_m && mem_empty_m && do_write_m;
                load_word_m   = ram_fetch_m || bypass_fetch_m;
                end_core_m    = old_valid_out && mem_empty_m;

                // control logic
                if (do_write_m)
                    wr_ptr_m = next_wr_ptr_m;

                if (need_fetch_m) begin
                    if (!mem_empty_m) begin
                        rd_ptr_m    = next_rd_ptr_m;
                        valid_out_m = 1'b1;
                    end else if (do_write_m) begin
                        rd_ptr_m    = next_rd_ptr_m;
                        valid_out_m = 1'b1;
                    end else if (rd_i) begin
                        valid_out_m = 1'b0;
                    end
                end

                // RAM path
                if (do_write_m)
                    mem_m[old_wr_ptr] = din_i;
                if (ram_fetch_m)
                    data_out_ram_m = old_mem_rd_data;

                // BYPASS path
                bypass_req_ff_m = bypass_fetch_m;
                if (bypass_fetch_m)
                    din_bypass_ff_m = din_i;
                if (old_bypass_req_ff)
                    data_out_bypass_m = old_din_bypass_ff;

                // Output pipeline
                load_word_d1_m  = load_word_m;
                load_word_d2_m  = old_load_word_d1;
                bypass_sel_d2_m = old_bypass_req_ff;
                valid_d1_m      = old_valid_out;
                valid_d2_m      = old_valid_d1;
                end_d1_m        = end_core_m;
                end_d2_m        = old_end_d1;
                if (old_load_word_d2)
                    dout_r_m = old_bypass_sel_d2 ? old_data_out_bypass : old_data_out_ram;
            end

            exp_full     = (f_next_ptr(wr_ptr_m) == rd_ptr_m);
            exp_vld_o    = valid_d2_m;
            exp_end_data = end_d2_m;
            exp_dout     = valid_d2_m ? dout_r_m : {WIDTH{1'b0}};
        end
    endtask

    task check_outputs;
        begin
            if ((dout !== exp_dout) ||
                (full !== exp_full) ||
                (vld_o !== exp_vld_o) ||
                (end_data !== exp_end_data)) begin
                $display("[FAIL] cycle=%0d time=%0t", cycle_count, $time);
                $display("       in : wr_en=%0b rd_en=%0b clr=%0b din=0x%02h rst_n=%0b", wr_en, rd_en, clr, din, rst_n);
                $display("       exp: dout=0x%02h full=%0b vld_o=%0b end_data=%0b", exp_dout, exp_full, exp_vld_o, exp_end_data);
                $display("       got: dout=0x%02h full=%0b vld_o=%0b end_data=%0b", dout, full, vld_o, end_data);
                $fatal(1);
            end
        end
    endtask

    task step;
        input             wr_i;
        input             rd_i;
        input             clr_i;
        input [WIDTH-1:0] din_i;
        begin
            @(negedge clk);
            wr_en = wr_i;
            rd_en = rd_i;
            clr   = clr_i;
            din   = din_i;

            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            model_step(wr_i, rd_i, clr_i, din_i);
            check_outputs();
        end
    endtask

    task run_reset;
        begin
            rst_n = 1'b0;
            wr_en = 1'b0;
            rd_en = 1'b0;
            clr   = 1'b0;
            din   = {WIDTH{1'b0}};
            model_reset();
            exp_full     = 1'b0;
            exp_vld_o    = 1'b0;
            exp_end_data = 1'b0;
            exp_dout     = {WIDTH{1'b0}};

            repeat (3) begin
                @(posedge clk);
                #1;
                cycle_count = cycle_count + 1;
                model_step(1'b0, 1'b0, 1'b0, {WIDTH{1'b0}});
                check_outputs();
            end

            @(negedge clk);
            rst_n = 1'b1;
            wr_en = 1'b0;
            rd_en = 1'b0;
            clr   = 1'b0;
            din   = {WIDTH{1'b0}};

            @(posedge clk);
            #1;
            cycle_count = cycle_count + 1;
            model_step(1'b0, 1'b0, 1'b0, {WIDTH{1'b0}});
            check_outputs();
        end
    endtask

    initial begin
        cycle_count = 0;
        run_reset();

        $display("[TB] Directed test 1: bypass path on empty FIFO");
        step(1'b1, 1'b0, 1'b0, 8'hA1);
        step(1'b0, 1'b0, 1'b0, 8'h00);
        step(1'b0, 1'b0, 1'b0, 8'h00);
        step(1'b0, 1'b1, 1'b0, 8'h00);
        step(1'b0, 1'b0, 1'b0, 8'h00);

        $display("[TB] Directed test 2: fill, full flag, and ordered readback");
        step(1'b1, 1'b0, 1'b0, 8'h11);
        step(1'b1, 1'b0, 1'b0, 8'h22);
        step(1'b1, 1'b0, 1'b0, 8'h33);
        step(1'b1, 1'b0, 1'b0, 8'h44); // should be blocked when full
        step(1'b0, 1'b1, 1'b0, 8'h00);
        step(1'b0, 1'b1, 1'b0, 8'h00);
        step(1'b0, 1'b1, 1'b0, 8'h00);
        step(1'b0, 1'b1, 1'b0, 8'h00);
        step(1'b0, 1'b0, 1'b0, 8'h00);
        step(1'b0, 1'b0, 1'b0, 8'h00);

        $display("[TB] Directed test 3: simultaneous write/read activity");
        step(1'b1, 1'b0, 1'b0, 8'h51);
        step(1'b1, 1'b0, 1'b0, 8'h52);
        step(1'b1, 1'b1, 1'b0, 8'h53);
        step(1'b1, 1'b1, 1'b0, 8'h54);
        step(1'b0, 1'b1, 1'b0, 8'h00);
        step(1'b0, 1'b1, 1'b0, 8'h00);
        step(1'b0, 1'b0, 1'b0, 8'h00);
        step(1'b0, 1'b0, 1'b0, 8'h00);

        $display("[TB] Directed test 4: synchronous clear flushes pipeline/state");
        step(1'b1, 1'b0, 1'b0, 8'hC1);
        step(1'b0, 1'b0, 1'b0, 8'h00);
        step(1'b0, 1'b0, 1'b1, 8'h00);
        step(1'b0, 1'b0, 1'b0, 8'h00);
        step(1'b0, 1'b0, 1'b0, 8'h00);

        $display("[TB] Random regression");
        for (i = 0; i < 200; i = i + 1) begin
            step($random & 1'b1,
                 $random & 1'b1,
                 (($random % 20) == 0),
                 $random);
        end

        $display("[PASS] All directed and random checks completed successfully.");
        $finish;
    end
endmodule
