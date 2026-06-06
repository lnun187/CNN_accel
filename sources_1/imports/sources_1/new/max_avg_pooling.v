`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05/27/2026 01:33:57 PM
// Design Name: 
// Module Name: max_avg_pooling
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


module max_avg_pooling#(
    parameter DATA_WIDTH = 8, //Data dua vao FIFO
    parameter POOL_DEPTH = 896 //do sau FIFO
)(
    input                           clk,
    input                           rst_n,

    // Giao tiếp info layer
    input                           pool_inf_vld_i,
    input       [7:0]               pool_inf_ofwidth_i,        //chieu dai va chieu rong cua channel
    input                           pool_inf_is_use_pool_i,
    input                           pool_inf_is_max_pool_i, //1 if use max, 0 if use avg
    input       [4:0]               pool_inf_pool_size_i, // equal 3 if pool window is 3x3
    input       [9:0]               pool_inf_square_pool_size_i, // equal 9 if pool window is 3x3
    input                           pool_inf_is_stride_over_i, //just use two value, = 1 if pool size = pool stride, = 0 if pool size = pool stride + 1
    output                          pool_inf_rdy_o,            

    // Tín hiệu giao tiếp với khối Scale & ReLU
    input                           pool_scale_vld_i,           
    output                          pool_scale_rdy_o,           
    input  signed   [7:0]           pool_scale_data_i,
    input                           pool_scale_done_compute_layer_i,
    input                           pool_scale_done_compute_i,          
    
    output                          pool_ofbuf_vld_o, 
    input                           pool_ofbuf_rdy_i, 
    output signed   [7:0]           pool_ofbuf_data_o
    );

    // assign pool_scale_rdy_o = pool_ofbuf_rdy_i;
    // assign pool_ofbuf_vld_o = pool_scale_vld_i;
    // assign pool_ofbuf_data_o = pool_scale_data_i;
    reg                 inf_rdy_reg;
    reg         [7:0]   ofwidth_reg;
    reg                 is_use_pool_reg;
    reg                 is_max_pool_reg;
    reg         [4:0]   pool_size_reg;
    reg         [9:0]   square_pool_size_reg;
    reg                 is_stride_over_reg;
    reg                 done_compute_layer_reg;
    reg                 done_compute_reg;

    reg         [7:0]   count_height_reg;
    reg         [7:0]   count_row_reg;
    reg         [4:0]   slidex_counter_reg;
    reg         [4:0]   slidey_counter_reg;
    reg         [12:0]  count_element_reg;
    reg         [12:0]  count_ofelement_rd_reg;
    reg                 end_row_reg;
    reg         [4:0]   num_filter_cur_pass_reg;
    reg         [4:0]   count_filter_reg;
    reg signed  [15:0]  processed_reg;
    reg signed  [7:0]   dup_reg;   
    reg                 fifo_wr_reg;
    reg                 dup_fifo_wr_reg;
    reg                 fifo_complete_almost_full_q;
    wire                complete_fifo_wr_dly;
    wire signed [15:0]  complete_fifo_data_dly_i;
    wire                fifo_wr_d;
    wire                dup_fifo_wr_d;
    wire                fifo_wr;
    wire                fifo_rd;
    wire                complete_fifo_wr;
    wire                complete_fifo_wr_eff;
    wire                complete_fifo_rd;
    wire                dup_fifo_wr;
    wire                dup_fifo_rd;
    wire        [7:0]   count_height_d;
    wire        [7:0]   count_row_d;
    wire        [4:0]   slidex_counter_d;
    wire        [4:0]   slidey_counter_d;
    wire        [12:0]  count_element_d;
    wire                count_element_en;
    wire        [12:0]  count_ofelement_rd_d;
    wire                count_ofelement_rd_en;
    wire                count_height_en_dly;
    wire                count_height_delay_busy;
    wire                count_height_en_eff;
    wire                fifo_ofbuf_cfg_wr_raw;
    wire                fifo_ofbuf_cfg_wr_dly;
    wire                fifo_ofbuf_cfg_wr_delay_busy;
    wire                fifo_ofbuf_cfg_wr_eff;
    wire                avg_pool_div_busy;
    wire                avg_pool_pipeline_busy;
    wire        [4:0]   num_filter_cur_pass_d;
    wire                num_filter_cur_pass_en;
    wire        [4:0]   count_filter_d;
    wire                count_filter_en;
    wire                end_row_d;
    wire                end_height_d;
    wire                count_row_en;
    wire                count_height_en;
    // wire                fifo_rdy;
    wire                fifo_full;
    wire                dup_fifo_full;
    wire                fifo_complete_full;
    wire                fifo_complete_almost_full;
    wire                fifo_complete_vld;
    wire                rdy_case_pool;
    wire        [12:0]  num_element_cur_pass;
    wire signed  [15:0] processed_d;
    wire                processed_en;
    wire signed  [7:0]  dup_d;
    wire                dup_en;
    wire signed  [15:0] choose_data;
    wire signed  [15:0] data_max_pool;
    wire signed  [15:0] data_avg_pool;
    wire signed  [15:0] choose_data_fifo;
    wire signed  [15:0] data_max_pool_fifo;
    wire signed  [15:0] data_avg_pool_fifo;
    wire signed  [15:0]  fifo_data_o;
    wire signed  [15:0]  dup_fifo_data_o;
    wire signed  [15:0]   complete_fifo_data_o;
    wire signed  [15:0]  fifo_data_i;
    wire signed  [15:0]  dup_fifo_data_i;
    wire signed  [15:0]  complete_fifo_data_i;
    wire                 fifo_ofbuf_cfg_empty;
    // assign pool_ofbuf_data_o        = is_use_pool_reg ? (is_max_pool_reg ? complete_fifo_data_o : complete_fifo_data_o) : pool_scale_data_i;
    // assign pool_ofbuf_data_o        = is_use_pool_reg ? (is_max_pool_reg ? complete_fifo_data_o : complete_fifo_data_o) : pool_scale_data_i;
    assign pool_ofbuf_data_o        = is_use_pool_reg ? complete_fifo_data_o : pool_scale_data_i;
    assign fifo_rd                  = fifo_wr_reg && |slidey_counter_reg && !(slidey_counter_reg == 1 && count_height_reg != 1 && !is_stride_over_reg);
    assign dup_fifo_rd              = fifo_wr_reg && (slidey_counter_reg == 1 && count_height_reg != 1 && !is_stride_over_reg);
    assign complete_fifo_rd         = pool_ofbuf_rdy_i && (count_ofelement_rd_reg != num_element_cur_pass);
    assign fifo_wr_d                = end_row_d || (slidex_counter_reg == pool_size_reg - 1);
    assign dup_fifo_wr_d            = fifo_wr_d && !is_stride_over_reg;
    assign fifo_wr                  = fifo_wr_reg && (slidey_counter_reg != pool_size_reg - 1) && (count_height_reg != ofwidth_reg - 1);
    assign complete_fifo_wr         = fifo_wr_reg && (slidey_counter_reg == pool_size_reg - 1 || (count_height_reg == ofwidth_reg - 1));
    assign complete_fifo_wr_eff     = is_max_pool_reg ? complete_fifo_wr : complete_fifo_wr_dly;
    assign avg_pool_pipeline_busy   = !is_max_pool_reg && (avg_pool_div_busy || count_height_delay_busy || fifo_ofbuf_cfg_wr_delay_busy);
    assign dup_fifo_wr              = dup_fifo_wr_reg && (slidey_counter_reg == pool_size_reg - 1) && (count_height_reg != ofwidth_reg - 1);
    assign choose_data_fifo         = (|slidey_counter_reg) ? 
                                        ((slidey_counter_reg == 1 && count_height_reg != 1 && !is_stride_over_reg) ? 
                                            dup_fifo_data_o : fifo_data_o) :
                                        (is_max_pool_reg ? -13'sd128: 13'h0) ;
                                        // -13'sd128 ;
    assign data_max_pool_fifo       = (processed_reg > choose_data_fifo) ? processed_reg : choose_data_fifo;
    assign data_avg_pool_fifo       = processed_reg + choose_data_fifo;
    assign fifo_data_i              = is_max_pool_reg ? data_max_pool_fifo : data_avg_pool_fifo;
    // assign fifo_data_i              = data_max_pool_fifo;
    assign dup_fifo_data_i          = processed_reg;
    assign complete_fifo_data_i     = fifo_data_i;
    assign choose_data              = (|slidex_counter_reg) ? 
                                        ((slidex_counter_reg == 1 && count_row_reg != 1 && !is_stride_over_reg) ? 
                                            dup_reg : processed_reg) :
                                        (is_max_pool_reg ? -13'sd128: 13'h0) ;
                                        // -13'sd128 ;
    assign data_max_pool            = (pool_scale_data_i > choose_data) ? pool_scale_data_i : choose_data;
    assign data_avg_pool            = pool_scale_data_i + choose_data;
    assign processed_d              = is_max_pool_reg ? data_max_pool : data_avg_pool;
    // assign processed_d              = data_max_pool;
    assign processed_en             = pool_scale_rdy_o && pool_scale_vld_i;
    assign dup_d                    = pool_scale_data_i;
    assign dup_en                   = processed_en;
    assign rdy_case_pool            = !fifo_complete_almost_full_q || slidey_counter_reg != (pool_size_reg - 1);
    assign pool_scale_rdy_o         = is_use_pool_reg ? rdy_case_pool : pool_ofbuf_rdy_i;
    assign pool_ofbuf_vld_o         = (pool_scale_vld_i && !is_use_pool_reg) || (fifo_complete_vld && !fifo_ofbuf_cfg_empty);
    assign pool_inf_rdy_o           = inf_rdy_reg;
    assign count_row_en             = rdy_case_pool && pool_scale_vld_i;
    assign count_height_en          = end_row_reg && ((|count_height_reg) ? (count_filter_reg == num_filter_cur_pass_reg - 1) : done_compute_reg);
    assign end_row_d                = (count_row_reg == (ofwidth_reg - 1)) && count_row_en;
    assign end_height_d             = (count_height_reg == ofwidth_reg - 1) && count_height_en;
    assign count_height_en_eff      = is_max_pool_reg ? count_height_en : count_height_en_dly;
    assign fifo_ofbuf_cfg_wr_raw    = count_height_en && ((slidey_counter_reg == pool_size_reg - 1) || end_height_d);
    assign fifo_ofbuf_cfg_wr_eff    = is_max_pool_reg ? fifo_ofbuf_cfg_wr_raw : fifo_ofbuf_cfg_wr_dly;
    assign slidex_counter_d         = end_row_d ? 0 : ((slidex_counter_reg == pool_size_reg - 1) ? !is_stride_over_reg : slidex_counter_reg + 1);
    assign count_row_d              = (count_row_reg == ofwidth_reg - 1) ? 0 : count_row_reg + 1;
    assign slidey_counter_d         = end_height_d ? 0 : ((slidey_counter_reg == pool_size_reg - 1) ? !is_stride_over_reg : slidey_counter_reg + 1);
    assign count_height_d           = (count_height_reg == ofwidth_reg - 1) ? 0 : count_height_reg + 1;
    assign num_filter_cur_pass_d    = end_height_d ? 0 : num_filter_cur_pass_reg + 1;
    assign num_filter_cur_pass_en   = !(|count_height_reg) && end_row_reg || end_height_d;
    assign count_filter_d           = ((num_filter_cur_pass_reg == count_filter_reg + 1) || !(|count_height_reg)) ? 0 : count_filter_reg + 1;
    assign count_filter_en          = (|count_height_reg) && end_row_reg;
    assign count_element_d          = count_height_en_eff ? 13'd0 : count_element_reg + 13'd1;
    assign count_element_en         = (complete_fifo_wr_eff && !fifo_complete_almost_full_q) || count_height_en_eff;
    assign count_ofelement_rd_d     = (count_ofelement_rd_reg + 1 == num_element_cur_pass) ? 13'd0 : count_ofelement_rd_reg + 13'd1;
    assign count_ofelement_rd_en    = fifo_complete_vld && count_ofelement_rd_reg != num_element_cur_pass && pool_ofbuf_rdy_i;
    fifo_n
       #(
       .DATA_WIDTH(13),
       .FF_TYPE(0),
       .FIFO_DEPTH(8)
       ) fifo_ofbuf_cfg_uut (
        .clk(clk),
        .data_i(count_element_reg + 13'd1),
        .data_o(num_element_cur_pass),
        .rd_valid_i((count_ofelement_rd_reg + 1 == num_element_cur_pass) && count_ofelement_rd_en),
        .wr_valid_i(fifo_ofbuf_cfg_wr_eff),
        .clr_rd_i(1'b0),
        .clr_ff_i(1'b0),
        .empty_o(fifo_ofbuf_cfg_empty),
        .full_o(),
        .almost_empty_o(),
        .almost_full_o(),
        .counter(),
        .rst_n(rst_n)
       );

    always @(posedge clk) begin
        if(inf_rdy_reg) begin
            ofwidth_reg             <= pool_inf_ofwidth_i;
            is_use_pool_reg         <= pool_inf_is_use_pool_i;
            is_max_pool_reg         <= pool_inf_is_max_pool_i;
            pool_size_reg           <= pool_inf_pool_size_i;
            square_pool_size_reg    <= pool_inf_square_pool_size_i;
            is_stride_over_reg      <= pool_inf_is_stride_over_i;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            inf_rdy_reg <= 1;
        end else begin
            if(done_compute_layer_reg && !(|count_height_reg) && !fifo_complete_vld && fifo_ofbuf_cfg_empty && !avg_pool_pipeline_busy) begin
                inf_rdy_reg <= 1;
            end else if(pool_inf_vld_i) begin
                inf_rdy_reg <= 0;
            end
        end
    end

    always @(posedge clk) begin
        if(inf_rdy_reg) begin
            slidex_counter_reg  <= 0;
            slidey_counter_reg  <= 0;
            count_height_reg    <= 0;
            count_row_reg       <= 0;
            count_element_reg   <= 0;
            done_compute_reg    <= 0;
            num_filter_cur_pass_reg <= 0;
            count_filter_reg        <= 0;
            count_ofelement_rd_reg  <= 0;
            fifo_wr_reg             <= 0;
            dup_fifo_wr_reg         <= 0;
            fifo_complete_almost_full_q <= 0;
            end_row_reg             <= 0;
            // done_compute_layer_reg  <= 0;
        end else begin
            fifo_complete_almost_full_q <= fifo_complete_almost_full;
            if(is_use_pool_reg) begin
                if(count_row_en) begin
                    slidex_counter_reg  <= slidex_counter_d;
                    count_row_reg       <= count_row_d;
                end
                if(count_height_en) begin
                    slidey_counter_reg  <= slidey_counter_d;
                    count_height_reg    <= count_height_d;
                end
                
                if(pool_scale_done_compute_i) done_compute_reg   <= 1'b1;
                else if(end_row_reg) done_compute_reg <= 1'b0;
                
                if(num_filter_cur_pass_en)  num_filter_cur_pass_reg     <= num_filter_cur_pass_d;
                if(count_filter_en)         count_filter_reg            <= count_filter_d;
                if(count_element_en)        count_element_reg           <= count_element_d;
                if(count_ofelement_rd_en)   count_ofelement_rd_reg      <= count_ofelement_rd_d;
                fifo_wr_reg             <= fifo_wr_d;
                dup_fifo_wr_reg         <= dup_fifo_wr_d;
                end_row_reg             <= end_row_d;
            end
            // done_compute_layer_reg  <= pool_scale_done_compute_layer_i;
        end
    end
    always @(posedge clk) begin
        if(inf_rdy_reg || done_compute_layer_reg && !(|count_height_reg) && !fifo_complete_vld && fifo_ofbuf_cfg_empty && !avg_pool_pipeline_busy)begin
            done_compute_layer_reg  <= 0;
        end else if(pool_scale_done_compute_layer_i) begin
            done_compute_layer_reg  <= 1;
        end
    end
    always @(posedge clk) begin
        if(is_use_pool_reg) begin
            if(processed_en)            processed_reg               <= processed_d;
            if(dup_en)                  dup_reg                     <= dup_d;
        end
    end
    avg_pool_div_pipeline avg_pool_div_pipeline_uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(complete_fifo_wr),
        .data_i(complete_fifo_data_i),
        .divisor_i(square_pool_size_reg),
        .valid_o(complete_fifo_wr_dly),
        .data_o(complete_fifo_data_dly_i),
        .busy_o(avg_pool_div_busy)
    );
    avg_pool_valid_delay #(
        .LATENCY(16)
    ) avg_pool_count_height_delay_uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(count_height_en),
        .valid_o(count_height_en_dly),
        .busy_o(count_height_delay_busy)
    );
    avg_pool_valid_delay #(
        .LATENCY(16)
    ) avg_pool_cfg_wr_delay_uut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_i(fifo_ofbuf_cfg_wr_raw),
        .valid_o(fifo_ofbuf_cfg_wr_dly),
        .busy_o(fifo_ofbuf_cfg_wr_delay_busy)
    );
    fifo_bram #(
        .WIDTH(16),
        .DEPTH(POOL_DEPTH)
    ) process_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(fifo_wr),
        .rd_en(fifo_rd),
        .clr(1'b0),
        .din(fifo_data_i),
        .dout(fifo_data_o),
        .full(fifo_full),
        .almost_full(),
        .vld_o(),
        .end_data()
    );
    fifo_bram #(
        .WIDTH(8),
        .DEPTH(POOL_DEPTH)
    ) complete_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(complete_fifo_wr_eff),
        .rd_en(complete_fifo_rd),
        .clr(1'b0),
        .din(is_max_pool_reg ? complete_fifo_data_i : complete_fifo_data_dly_i),
        .dout(complete_fifo_data_o),
        .full(fifo_complete_full),
        .almost_full(fifo_complete_almost_full),
        .vld_o(fifo_complete_vld),
        .end_data()
    );
    fifo_bram #(
        .WIDTH(16),
        .DEPTH(POOL_DEPTH)
    ) dup_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(dup_fifo_wr),
        .rd_en(dup_fifo_rd),
        .clr(1'b0),
        .din(dup_fifo_data_i),
        .dout(dup_fifo_data_o),
        .full(dup_fifo_full),
        .almost_full(),
        .vld_o(),
        .end_data()
    );
endmodule

module avg_pool_valid_delay #(
    parameter LATENCY = 16
)(
    input       clk,
    input       rst_n,
    input       valid_i,
    output      valid_o,
    output      busy_o
);

    reg [LATENCY:0] valid_pipe;

    assign valid_o = valid_pipe[LATENCY];
    assign busy_o  = |valid_pipe;

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_pipe <= {(LATENCY+1){1'b0}};
        end else begin
            valid_pipe <= {valid_pipe[LATENCY-1:0], valid_i};
        end
    end

endmodule

module avg_pool_div_pipeline #(
    parameter DATA_WIDTH = 16,
    parameter DIV_WIDTH  = 10
)(
    input                           clk,
    input                           rst_n,
    input                           valid_i,
    input signed [DATA_WIDTH-1:0]   data_i,
    input        [DIV_WIDTH-1:0]    divisor_i,
    output                          valid_o,
    output signed [DATA_WIDTH-1:0]  data_o,
    output                          busy_o
);

    localparam REM_WIDTH = DATA_WIDTH + 1;

    reg                         valid_pipe [0:DATA_WIDTH];
    reg                         sign_pipe  [0:DATA_WIDTH];
    reg                         div_zero_pipe [0:DATA_WIDTH];
    reg [DATA_WIDTH-1:0]        dividend_pipe [0:DATA_WIDTH];
    reg [DATA_WIDTH-1:0]        divisor_pipe  [0:DATA_WIDTH];
    reg [DATA_WIDTH-1:0]        quotient_pipe [0:DATA_WIDTH];
    reg [REM_WIDTH-1:0]         rem_pipe      [0:DATA_WIDTH];

    wire [DATA_WIDTH-1:0] dividend_abs_w;
    wire [DATA_WIDTH-1:0] quotient_abs_w;
    wire [DATA_WIDTH-1:0] quotient_signed_w;
    wire [DATA_WIDTH:0]   valid_pipe_vec;

    assign dividend_abs_w    = data_i[DATA_WIDTH-1] ? (~data_i + {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : data_i;
    assign quotient_abs_w    = div_zero_pipe[DATA_WIDTH] ? {DATA_WIDTH{1'b0}} : quotient_pipe[DATA_WIDTH];
    assign quotient_signed_w = sign_pipe[DATA_WIDTH] ? (~quotient_abs_w + {{(DATA_WIDTH-1){1'b0}}, 1'b1}) : quotient_abs_w;
    assign valid_o           = valid_pipe[DATA_WIDTH];
    assign data_o            = quotient_signed_w;
    assign busy_o            = |valid_pipe_vec;

    genvar valid_idx;
    generate
        for (valid_idx = 0; valid_idx <= DATA_WIDTH; valid_idx = valid_idx + 1) begin : gen_valid_vec
            assign valid_pipe_vec[valid_idx] = valid_pipe[valid_idx];
        end
    endgenerate

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_pipe[0]    <= 1'b0;
            sign_pipe[0]     <= 1'b0;
            div_zero_pipe[0] <= 1'b0;
            dividend_pipe[0] <= {DATA_WIDTH{1'b0}};
            divisor_pipe[0]  <= {DATA_WIDTH{1'b0}};
            quotient_pipe[0] <= {DATA_WIDTH{1'b0}};
            rem_pipe[0]      <= {REM_WIDTH{1'b0}};
        end else begin
            valid_pipe[0]    <= valid_i;
            sign_pipe[0]     <= data_i[DATA_WIDTH-1];
            div_zero_pipe[0] <= (divisor_i == {DIV_WIDTH{1'b0}});
            dividend_pipe[0] <= dividend_abs_w;
            divisor_pipe[0]  <= {{(DATA_WIDTH-DIV_WIDTH){1'b0}}, divisor_i};
            quotient_pipe[0] <= {DATA_WIDTH{1'b0}};
            rem_pipe[0]      <= {REM_WIDTH{1'b0}};
        end
    end

    genvar div_stage;
    generate
        for (div_stage = 1; div_stage <= DATA_WIDTH; div_stage = div_stage + 1) begin : gen_div_stage
            wire [REM_WIDTH-1:0] rem_shift_w;
            wire [REM_WIDTH-1:0] divisor_ext_w;
            wire                 sub_en_w;
            wire [DATA_WIDTH-1:0] quotient_bit_w;

            assign rem_shift_w   = {rem_pipe[div_stage-1][REM_WIDTH-2:0], dividend_pipe[div_stage-1][DATA_WIDTH-div_stage]};
            assign divisor_ext_w = {1'b0, divisor_pipe[div_stage-1]};
            assign sub_en_w      = !div_zero_pipe[div_stage-1] && (rem_shift_w >= divisor_ext_w);
            assign quotient_bit_w = {{(DATA_WIDTH-1){1'b0}}, 1'b1} << (DATA_WIDTH-div_stage);

            always @(posedge clk) begin
                if (!rst_n) begin
                    valid_pipe[div_stage]    <= 1'b0;
                    sign_pipe[div_stage]     <= 1'b0;
                    div_zero_pipe[div_stage] <= 1'b0;
                    dividend_pipe[div_stage] <= {DATA_WIDTH{1'b0}};
                    divisor_pipe[div_stage]  <= {DATA_WIDTH{1'b0}};
                    quotient_pipe[div_stage] <= {DATA_WIDTH{1'b0}};
                    rem_pipe[div_stage]      <= {REM_WIDTH{1'b0}};
                end else begin
                    valid_pipe[div_stage]    <= valid_pipe[div_stage-1];
                    sign_pipe[div_stage]     <= sign_pipe[div_stage-1];
                    div_zero_pipe[div_stage] <= div_zero_pipe[div_stage-1];
                    dividend_pipe[div_stage] <= dividend_pipe[div_stage-1];
                    divisor_pipe[div_stage]  <= divisor_pipe[div_stage-1];

                    if (sub_en_w) begin
                        rem_pipe[div_stage]      <= rem_shift_w - divisor_ext_w;
                        quotient_pipe[div_stage] <= quotient_pipe[div_stage-1] | quotient_bit_w;
                    end else begin
                        rem_pipe[div_stage]      <= rem_shift_w;
                        quotient_pipe[div_stage] <= quotient_pipe[div_stage-1];
                    end
                end
            end
        end
    endgenerate

endmodule
