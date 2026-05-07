`timescale 1ns/1ps

module fifo_tb;
    localparam int DATA_WIDTH = 8;
    localparam int FIFO_DEPTH = 4;
    localparam int FF_NUM     = 2;
    localparam int ADDR_WIDTH = $clog2(FIFO_DEPTH);

    logic clk;
    logic rst_n;

    // DUT0: mode 0
    logic [DATA_WIDTH-1:0] data_i_0;
    logic [DATA_WIDTH-1:0] data_o_0;
    logic wr_valid_0, rd_valid_0, clr_rd_0, clr_ff_0;
    logic empty_0, full_0, almost_empty_0, almost_full_0;
    logic [ADDR_WIDTH:0] counter_0;

    // DUT1: mode 1
    logic [DATA_WIDTH-1:0] data_i_1;
    logic [DATA_WIDTH-1:0] data_o_1;
    logic wr_valid_1, rd_valid_1, clr_rd_1, clr_ff_1;
    logic empty_1, full_1, almost_empty_1, almost_full_1;
    logic [ADDR_WIDTH:0] counter_1;

    // DUT2: mode 2
    logic [DATA_WIDTH-1:0] data_i_2;
    logic [DATA_WIDTH-1:0] data_o_2;
    logic wr_valid_2, rd_valid_2, clr_rd_2, clr_ff_2;
    logic empty_2, full_2, almost_empty_2, almost_full_2;
    logic [ADDR_WIDTH:0] counter_2;

    integer fail_count = 0;

    fifo_n #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .FF_TYPE    (0),
        .FF_NUM     (FF_NUM),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut_mode0 (
        .clk            (clk),
        .data_i         (data_i_0),
        .data_o         (data_o_0),
        .wr_valid_i     (wr_valid_0),
        .rd_valid_i     (rd_valid_0),
        .clr_rd_i       (clr_rd_0),
        .clr_ff_i       (clr_ff_0),
        .empty_o        (empty_0),
        .full_o         (full_0),
        .almost_empty_o (almost_empty_0),
        .almost_full_o  (almost_full_0),
        .counter        (counter_0),
        .rst_n          (rst_n)
    );

    fifo_n #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .FF_TYPE    (1),
        .FF_NUM     (FF_NUM),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut_mode1 (
        .clk            (clk),
        .data_i         (data_i_1),
        .data_o         (data_o_1),
        .wr_valid_i     (wr_valid_1),
        .rd_valid_i     (rd_valid_1),
        .clr_rd_i       (clr_rd_1),
        .clr_ff_i       (clr_ff_1),
        .empty_o        (empty_1),
        .full_o         (full_1),
        .almost_empty_o (almost_empty_1),
        .almost_full_o  (almost_full_1),
        .counter        (counter_1),
        .rst_n          (rst_n)
    );

    fifo_n #(
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .FF_TYPE    (2),
        .FF_NUM     (FF_NUM),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) dut_mode2 (
        .clk            (clk),
        .data_i         (data_i_2),
        .data_o         (data_o_2),
        .wr_valid_i     (wr_valid_2),
        .rd_valid_i     (rd_valid_2),
        .clr_rd_i       (clr_rd_2),
        .clr_ff_i       (clr_ff_2),
        .empty_o        (empty_2),
        .full_o         (full_2),
        .almost_empty_o (almost_empty_2),
        .almost_full_o  (almost_full_2),
        .counter        (counter_2),
        .rst_n          (rst_n)
    );

    always #5 clk = ~clk;

    task automatic expect1(input logic cond, input string msg);
        if (!cond) begin
            fail_count = fail_count + 1;
            $display("[FAIL] %s @ t=%0t", msg, $time);
        end
        else begin
            $display("[PASS] %s", msg);
        end
    endtask

    task automatic drive0(
        input logic [DATA_WIDTH-1:0] din,
        input logic wr,
        input logic rd,
        input logic clr_rd,
        input logic clr_ff
    );
        @(negedge clk);
        data_i_0   = din;
        wr_valid_0 = wr;
        rd_valid_0 = rd;
        clr_rd_0   = clr_rd;
        clr_ff_0   = clr_ff;
        @(posedge clk);
        #1;
        data_i_0   = '0;
        wr_valid_0 = 1'b0;
        rd_valid_0 = 1'b0;
        clr_rd_0   = 1'b0;
        clr_ff_0   = 1'b0;
    endtask

    task automatic drive1(
        input logic [DATA_WIDTH-1:0] din,
        input logic wr,
        input logic rd,
        input logic clr_rd,
        input logic clr_ff
    );
        @(negedge clk);
        data_i_1   = din;
        wr_valid_1 = wr;
        rd_valid_1 = rd;
        clr_rd_1   = clr_rd;
        clr_ff_1   = clr_ff;
        @(posedge clk);
        #1;
        data_i_1   = '0;
        wr_valid_1 = 1'b0;
        rd_valid_1 = 1'b0;
        clr_rd_1   = 1'b0;
        clr_ff_1   = 1'b0;
    endtask

    task automatic drive2(
        input logic [DATA_WIDTH-1:0] din,
        input logic wr,
        input logic rd,
        input logic clr_rd,
        input logic clr_ff
    );
        @(negedge clk);
        data_i_2   = din;
        wr_valid_2 = wr;
        rd_valid_2 = rd;
        clr_rd_2   = clr_rd;
        clr_ff_2   = clr_ff;
        @(posedge clk);
        #1;
        data_i_2   = '0;
        wr_valid_2 = 1'b0;
        rd_valid_2 = 1'b0;
        clr_rd_2   = 1'b0;
        clr_ff_2   = 1'b0;
    endtask

    task automatic global_reset;
        begin
            clk = 1'b0;
            rst_n = 1'b0;
            data_i_0 = '0; wr_valid_0 = 0; rd_valid_0 = 0; clr_rd_0 = 0; clr_ff_0 = 0;
            data_i_1 = '0; wr_valid_1 = 0; rd_valid_1 = 0; clr_rd_1 = 0; clr_ff_1 = 0;
            data_i_2 = '0; wr_valid_2 = 0; rd_valid_2 = 0; clr_rd_2 = 0; clr_ff_2 = 0;
            repeat (2) begin
                @(posedge clk);
                #1;
            end
            @(negedge clk);
            rst_n = 1'b1;
            @(posedge clk);
            #1;
        end
    endtask

    task automatic test_mode0;
        begin
            $display("\n=== TEST MODE 0 ===");
            expect1(empty_0 === 1'b1 && counter_0 === '0, "M0 reset state");

            drive0(8'h11, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(empty_0 === 1'b0 && counter_0 === 1 && data_o_0 === 8'h11, "M0 single write visible");

            drive0('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(empty_0 === 1'b1 && counter_0 === 0, "M0 single read back to empty");

            drive0(8'h21, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(almost_empty_0 === 1'b1, "M0 almost_empty after first write");
            drive0(8'h22, 1'b1, 1'b0, 1'b0, 1'b0);
            drive0(8'h23, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(almost_full_0 === 1'b1 && counter_0 === 3 && data_o_0 === 8'h21, "M0 almost_full and front data");
            drive0(8'h24, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(full_0 === 1'b1 && counter_0 === 4 && data_o_0 === 8'h21, "M0 full and front data");

            drive0('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(data_o_0 === 8'h22 && counter_0 === 3, "M0 read order item 2");
            drive0('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(data_o_0 === 8'h23 && counter_0 === 2, "M0 read order item 3");
            drive0('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(data_o_0 === 8'h24 && counter_0 === 1, "M0 read order item 4");
            drive0('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(empty_0 === 1'b1 && counter_0 === 0, "M0 drain to empty");

            // start fresh before clr tests
            drive0('0, 1'b0, 1'b0, 1'b0, 1'b1);
            drive0('0, 1'b0, 1'b0, 1'b0, 1'b0);
            drive0(8'h31, 1'b1, 1'b0, 1'b0, 1'b0);
            drive0(8'h32, 1'b1, 1'b0, 1'b0, 1'b0);
            drive0(8'h33, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(data_o_0 === 8'h31 && counter_0 === 3, "M0 before clr_rd");
            drive0('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(data_o_0 === 8'h32 && counter_0 === 2, "M0 after one read before clr_rd");
            drive0('0, 1'b0, 1'b0, 1'b1, 1'b0);
            expect1(data_o_0 === 8'h31 && counter_0 === 3, "M0 clr_rd replay from addr 0");
            drive0('0, 1'b0, 1'b0, 1'b0, 1'b1);
            expect1(empty_0 === 1'b1 && counter_0 === 0, "M0 clr_ff reset");
        end
    endtask

    task automatic test_mode1;
        begin
            $display("\n=== TEST MODE 1 ===");
            expect1(empty_1 === 1'b1 && counter_1 === '0, "M1 reset state");

            drive1(8'h11, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(empty_1 === 1'b0 && counter_1 === 1 && data_o_1 === 8'h11, "M1 single write behaves like mode0");

            drive1('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(empty_1 === 1'b1 && counter_1 === 0, "M1 single read back to empty");

            drive1(8'h21, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(almost_empty_1 === 1'b1, "M1 almost_empty after first write");
            drive1(8'h22, 1'b1, 1'b0, 1'b0, 1'b0);
            drive1(8'h23, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(almost_full_1 === 1'b1 && counter_1 === 3 && data_o_1 === 8'h21, "M1 almost_full and front data");
            drive1(8'h24, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(full_1 === 1'b1 && counter_1 === 4 && data_o_1 === 8'h21, "M1 full and front data");

            drive1('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(data_o_1 === 8'h22 && counter_1 === 3, "M1 read order item 2");
            drive1('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(data_o_1 === 8'h23 && counter_1 === 2, "M1 read order item 3");
            drive1('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(data_o_1 === 8'h24 && counter_1 === 1, "M1 read order item 4");
            drive1('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(empty_1 === 1'b1 && counter_1 === 0, "M1 drain to empty");

            // start fresh before clr tests
            drive1('0, 1'b0, 1'b0, 1'b0, 1'b1);
            drive1('0, 1'b0, 1'b0, 1'b0, 1'b0);
            drive1(8'h31, 1'b1, 1'b0, 1'b0, 1'b0);
            drive1(8'h32, 1'b1, 1'b0, 1'b0, 1'b0);
            drive1(8'h33, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(data_o_1 === 8'h31 && counter_1 === 3, "M1 before clr_rd");
            drive1('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(data_o_1 === 8'h32 && counter_1 === 2, "M1 after one read before clr_rd");
            drive1('0, 1'b0, 1'b0, 1'b1, 1'b0);
            expect1(empty_1 === 1'b1 && counter_1 === 3, "M1 clr_rd clears fetched FF but keeps unread count");
            drive1('0, 1'b0, 1'b0, 1'b0, 1'b0);
            expect1(empty_1 === 1'b0 && data_o_1 === 8'h31 && counter_1 === 3, "M1 clr_rd replay from addr 0");
            drive1('0, 1'b0, 1'b0, 1'b0, 1'b1);
            expect1(empty_1 === 1'b1 && counter_1 === 0, "M1 clr_ff reset");
        end
    endtask

    task automatic test_mode2;
        begin
            $display("\n=== TEST MODE 2 ===");
            expect1(empty_2 === 1'b1 && counter_2 === '0, "M2 reset state");

            // Spec: visible delay = FF_NUM + 1 = 3 cycles for FF_NUM=2
            drive2(8'h11, 1'b1, 1'b0, 1'b0, 1'b0);
            expect1(empty_2 === 1'b1 && counter_2 === 1, "M2 after write still empty");
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b0);
            expect1(empty_2 === 1'b1 && counter_2 === 1, "M2 cycle+1 still empty");
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b0);
            expect1(empty_2 === 1'b1 && counter_2 === 1, "M2 cycle+2 still empty");
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b0);
            expect1(empty_2 === 1'b0 && data_o_2 === 8'h11 && counter_2 === 1, "M2 cycle+3 first data visible");
            drive2('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(empty_2 === 1'b1 && counter_2 === 0, "M2 read back to empty");

            // start fresh before clr tests
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b1);
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b0);
            drive2(8'h31, 1'b1, 1'b0, 1'b0, 1'b0);
            drive2(8'h32, 1'b1, 1'b0, 1'b0, 1'b0);
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b0);
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b0);
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b0);
            expect1(empty_2 === 1'b0 && data_o_2 === 8'h31, "M2 before clr_rd first visible data");
            drive2('0, 1'b0, 1'b1, 1'b0, 1'b0);
            expect1(data_o_2 === 8'h32, "M2 second visible data before clr_rd");
            drive2('0, 1'b0, 1'b0, 1'b1, 1'b0);
            expect1(empty_2 === 1'b1 && counter_2 === 2, "M2 clr_rd clears all fetched FFs");
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b0);
            expect1(empty_2 === 1'b1, "M2 clr_rd cycle+1 still empty");
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b0);
            expect1(empty_2 === 1'b1, "M2 clr_rd cycle+2 still empty");
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b0);
            expect1(empty_2 === 1'b0 && data_o_2 === 8'h31, "M2 clr_rd replay after full FF_NUM+1 latency");
            drive2('0, 1'b0, 1'b0, 1'b0, 1'b1);
            expect1(empty_2 === 1'b1 && counter_2 === 0, "M2 clr_ff reset");
        end
    endtask

    initial begin
        global_reset();
        test_mode0();
        test_mode1();
        test_mode2();

        $display("\n====================================");
        if (fail_count == 0) begin
            $display("TB PASS: all FIFO mode tests passed");
            $finish;
        end
        else begin
            $display("TB FAIL: %0d checks failed", fail_count);
            $fatal(1, "fifo tb failed");
        end
    end
endmodule
