`timescale 1ns / 1ps

module comp_wr_ctrl_tb;

    // Các tham số cấu hình
    parameter WIDTH = 8;
    parameter PE_PER_PU = 12;
    parameter DEPTH = 11;
    parameter CLK_PERIOD = 2;

    // Tín hiệu Clock và Reset
    reg clk;
    reg rst_n;

    // --- Tín hiệu cho comp_wr_ctrl ---
    reg en;
    reg cwc_ins_dw_i;
    reg [3:0] cwc_ins_hf_i;
    reg [1:0] cwc_ins_stride_i;
    reg [1:0] cwc_ins_padding_i;
    reg cwc_pu_end_height_i;
    reg cwc_pu_end_height_nxt_i;
    reg cwc_pu_end_layer_i;
    reg cwc_pu_end_layer_nxt_i;
    reg cwc_pu_swap_en_i;
    reg cwc_ofbuf_rdy_i;

    wire [PE_PER_PU-1:0] cwc_pp_rdy_o;
    wire [PE_PER_PU-1:0] cwc_pp_clear_o;
    wire cwc_ofbuf_vld_o;
    wire [WIDTH-1:0] cwc_ofbuf_data_o;

    // --- Tín hiệu điều khiển FIFO (Phía PE/Testbench) ---
    reg  pp_pu_id_i; 
    reg  [PE_PER_PU-1:0] fifo_wr_en;
    reg  [WIDTH-1:0] fifo_data_in [0:PE_PER_PU-1];
    
    wire [PE_PER_PU*WIDTH-1:0] flat_fifo_data_ob;
    wire [PE_PER_PU-1:0] fifo_empty;
    wire [PE_PER_PU-1:0] fifo_end_data;
    wire [PE_PER_PU-1:0] pp_data_vld_i;

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // --- Instance: Controller ---
    comp_wr_ctrl #(
        .WIDTH(WIDTH),
        .PE_PER_PU(PE_PER_PU)
    ) u_comp_wr_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .cwc_ins_dw_i(cwc_ins_dw_i),
        .cwc_ins_hf_i(cwc_ins_hf_i),
        .cwc_ins_stride_i(cwc_ins_stride_i),
        .cwc_ins_padding_i(cwc_ins_padding_i),
        .cwc_pu_end_height_i(cwc_pu_end_height_i),
        .cwc_pu_end_height_nxt_i(cwc_pu_end_height_nxt_i),
        .cwc_pu_end_layer_i(cwc_pu_end_layer_i),
        .cwc_pu_end_layer_nxt_i(cwc_pu_end_layer_nxt_i),
        
        .cwc_pp_data_i(flat_fifo_data_ob),
        .cwc_pp_vld_i(pp_data_vld_i),
        .cwc_pp_end_data_i(fifo_end_data),
        
        .cwc_pp_rdy_o(cwc_pp_rdy_o),
        .cwc_pp_clear_o(cwc_pp_clear_o),

        .cwc_pu_swap_en_i(cwc_pu_swap_en_i),
        .cwc_ofbuf_rdy_i(cwc_ofbuf_rdy_i),
        .cwc_ofbuf_vld_o(cwc_ofbuf_vld_o),
        .cwc_ofbuf_data_o(cwc_ofbuf_data_o)
    );

    // --- Instance: 12 Ping-Pong FIFOs (Cập nhật interface mới) ---
    genvar i;
    generate
        for (i = 0; i < PE_PER_PU; i = i + 1) begin : gen_fifos
            wire [WIDTH-1:0] current_ob;
            assign flat_fifo_data_ob[i*WIDTH +: WIDTH] = current_ob;
            assign pp_data_vld_i[i] = ~fifo_empty[i];

            pu_ping_pong_fifo #(
                .WIDTH(WIDTH),
                .DEPTH(DEPTH)
            ) u_fifo (
                .clk(clk),
                .rst_n(rst_n),
                .pp_pu_id_i(pp_pu_id_i),
                .pp_pe_wr_en_i(fifo_wr_en[i]),
                .pp_pe_rd_ena_i(1'b0),            // PE không đọc mặt A trong test này
                .pp_pe_rd_enb_i(cwc_pp_rdy_o[i]), // Controller đọc mặt B
                .pp_cwc_clr_i(cwc_pp_clear_o[i]), // Controller xóa FIFO
                .pp_pe_data_i(fifo_data_in[i]),
                .pp_pe_data_a_o(),                // Bỏ trống đầu ra mặt A
                .pp_pe_cwc_data_b_o(current_ob),
                .pp_pe_empty_o(fifo_empty[i]),
                .pp_cwc_end_data_o(fifo_end_data[i])
            );
        end
    endgenerate

    // --- Stimulus ---
    integer j;
    initial begin
        // Init
        rst_n = 0; en = 1; cwc_ins_dw_i = 1; cwc_ins_hf_i = 4;
        cwc_ins_stride_i = 2; cwc_ins_padding_i = 2;
        cwc_pu_end_height_i = 0; cwc_pu_end_height_nxt_i = 0;
        cwc_pu_end_layer_i = 0; cwc_pu_end_layer_nxt_i = 0;
        cwc_pu_swap_en_i = 0; cwc_ofbuf_rdy_i = 1; 
        
        pp_pu_id_i = 1; // Khởi đầu FIFO id = 1
        fifo_wr_en = 0;
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = 0;

        #(CLK_PERIOD * 2) rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("--- STAGE 1: Writing data to FIFOs ---");
        @(negedge clk);
        fifo_wr_en = {PE_PER_PU{1'b1}};
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = j + 8'h10;
        @(negedge clk);
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = j + 8'h20;
        @(negedge clk);
        fifo_wr_en = 0;

        $display("--- STAGE 2: Swap Buffers and Controller Starts ---");
        @(negedge clk);
        cwc_pu_swap_en_i = 1;
        @(posedge clk);
        pp_pu_id_i = 0; // Đảo ID để dữ liệu sang Background
        @(negedge clk);
        cwc_pu_swap_en_i = 0;
        fifo_wr_en = {PE_PER_PU{1'b1}};
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = j + 8'h30;
        @(negedge clk);
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = j + 8'h40;
        @(negedge clk);
        fifo_wr_en = 0;
        #(CLK_PERIOD * 20);

        $display("--- STAGE 3: Swap Buffers Again ---");
        @(negedge clk);
        cwc_pu_swap_en_i = 1;
        // cwc_pu_end_layer_nxt_i = 1;

        cwc_pu_end_height_nxt_i = 1;
        @(posedge clk);
        pp_pu_id_i = 1; // Đảo ID để dữ liệu sang Background
        // cwc_pu_end_layer_i = 1;

        cwc_pu_end_height_i = 1;
        @(negedge clk);
        cwc_pu_swap_en_i = 0;
        cwc_pu_end_height_nxt_i = 0;
        fifo_wr_en = {PE_PER_PU{1'b1}};
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = j + 8'h50;
        @(negedge clk);
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = j + 8'h60;
        @(negedge clk);
        fifo_wr_en = 0;
        // cwc_pu_end_height_nxt_i = 0;
        #(CLK_PERIOD * 20);
        $display("--- STAGE 4: Swap Buffers Again ---");
        @(negedge clk);
        cwc_pu_swap_en_i = 1;
        @(posedge clk);
        pp_pu_id_i = 0; // Đảo ID để dữ liệu sang Background
        cwc_pu_end_height_i = 0;
        @(negedge clk);
        cwc_pu_swap_en_i = 0;
        fifo_wr_en = {PE_PER_PU{1'b1}};
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = j + 8'h70;
        @(negedge clk);
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = j + 8'h80;
        @(negedge clk);
        fifo_wr_en = 0;
        #(CLK_PERIOD * 20);
        $display("--- STAGE 5: Swap Buffers Again ---");
        @(negedge clk);
        cwc_pu_swap_en_i = 1;
        @(posedge clk);
        pp_pu_id_i = 1; // Đảo ID để dữ liệu sang Background
        cwc_pu_end_height_i = 0;
        @(negedge clk);
        cwc_pu_swap_en_i = 0;
        fifo_wr_en = {PE_PER_PU{1'b1}};
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = j + 8'h90;
        @(negedge clk);
        for (j = 0; j < PE_PER_PU; j = j + 1) fifo_data_in[j] = j + 8'hA0;
        @(negedge clk);
        fifo_wr_en = 0;
        #(CLK_PERIOD * 20);
        $display("--- STAGE 6: Swap Buffers Again with End Signals ---");
        @(negedge clk);
        cwc_pu_swap_en_i = 1;
        cwc_pu_end_layer_nxt_i = 1;

        cwc_pu_end_height_nxt_i = 1;
        @(posedge clk);
        pp_pu_id_i = 0; // Đảo ID để dữ liệu sang Background
        cwc_pu_end_layer_i = 1;

        cwc_pu_end_height_i = 1;
        @(negedge clk);
        cwc_pu_swap_en_i = 0;
        cwc_pu_end_layer_nxt_i = 0;
        cwc_pu_end_height_nxt_i = 0;
        #(CLK_PERIOD * 20);
        $display("--- SIMULATION FINISHED ---");
        $finish;
    end

endmodule