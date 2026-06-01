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
    reg signed  [12:0]  processed_reg;
    reg signed  [7:0]   dup_reg;   
    reg                 fifo_wr_reg;
    reg                 dup_fifo_wr_reg;
    
    wire                fifo_wr_d;
    wire                dup_fifo_wr_d;
    wire                fifo_wr;
    wire                fifo_rd;
    wire                complete_fifo_wr;
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
    wire        [4:0]   num_filter_cur_pass_d;
    wire                num_filter_cur_pass_en;
    wire        [4:0]   count_filter_d;
    wire                count_filter_en;
    wire                end_row_d;
    wire                end_height_d;
    wire                count_row_en;
    wire                count_height_en;
    wire                fifo_rdy;
    wire                fifo_full;
    wire                dup_fifo_full;
    wire                fifo_complete_full;
    wire                fifo_complete_vld;
    wire                rdy_case_pool;
    wire        [12:0]  num_element_cur_pass;
    wire signed  [12:0] processed_d;
    wire                processed_en;
    wire signed  [7:0]  dup_d;
    wire                dup_en;
    wire signed  [12:0] choose_data;
    wire signed  [12:0] data_max_pool;
    wire signed  [12:0] data_avg_pool;
    wire signed  [12:0] choose_data_fifo;
    wire signed  [12:0] data_max_pool_fifo;
    wire signed  [12:0] data_avg_pool_fifo;
    wire signed  [12:0]  fifo_data_o;
    wire signed  [12:0]  dup_fifo_data_o;
    wire signed  [12:0]   complete_fifo_data_o;
    wire signed  [12:0]  fifo_data_i;
    wire signed  [12:0]  dup_fifo_data_i;
    wire signed  [12:0]  complete_fifo_data_i;

    assign pool_ofbuf_data_o        = is_use_pool_reg ? (is_max_pool_reg ? complete_fifo_data_o : complete_fifo_data_o / square_pool_size_reg) : pool_scale_data_i;
    assign fifo_rd                  = fifo_wr_reg && |slidey_counter_reg && !(slidey_counter_reg == 1 && count_height_reg != 1 && !is_stride_over_reg);
    assign dup_fifo_rd              = fifo_wr_reg && (slidey_counter_reg == 1 && count_height_reg != 1 && !is_stride_over_reg);
    assign complete_fifo_rd         = pool_ofbuf_rdy_i && (count_ofelement_rd_reg != num_element_cur_pass);
    assign fifo_wr_d                = end_row_d || (slidex_counter_reg == pool_size_reg - 1);
    assign dup_fifo_wr_d            = fifo_wr_d && !is_stride_over_reg;
    assign fifo_wr                  = fifo_wr_reg && (slidey_counter_reg != pool_size_reg - 1) && !end_height_d;
    assign complete_fifo_wr         = fifo_wr_reg && (slidey_counter_reg == pool_size_reg - 1 || end_height_d);
    assign dup_fifo_wr              = dup_fifo_wr_reg && (slidey_counter_reg != pool_size_reg - 1) && !end_height_d;
    assign choose_data_fifo         = (|slidey_counter_reg) ? 
                                        ((slidey_counter_reg == 1 && count_height_reg != 1 && !is_stride_over_reg) ? 
                                            dup_fifo_data_o : fifo_data_o) :
                                        (is_max_pool_reg ? -13'sd128: 13'h0) ;
    assign data_max_pool_fifo       = (processed_reg > choose_data_fifo) ? processed_reg : choose_data_fifo;
    assign data_avg_pool_fifo       = processed_reg + choose_data_fifo;
    assign fifo_data_i              = is_max_pool_reg ? data_max_pool_fifo : data_avg_pool_fifo;
    assign dup_fifo_data_i          = processed_reg;
    assign complete_fifo_data_i     = fifo_data_i;
    assign choose_data              = (|slidex_counter_reg) ? 
                                        ((slidex_counter_reg == 1 && count_row_reg != 1 && !is_stride_over_reg) ? 
                                            dup_reg : processed_reg) :
                                        (is_max_pool_reg ? -13'sd128: 13'h0) ;
    assign data_max_pool            = (pool_scale_data_i > choose_data) ? pool_scale_data_i : choose_data;
    assign data_avg_pool            = pool_scale_data_i + choose_data;
    assign processed_d              = is_max_pool_reg ? data_max_pool : data_avg_pool;
    assign processed_en             = pool_scale_rdy_o && pool_scale_vld_i;
    assign dup_d                    = pool_scale_data_i;
    assign dup_en                   = processed_en;
    assign fifo_rdy                 = !fifo_full && !dup_fifo_full;
    assign rdy_case_pool            = fifo_rdy && (!fifo_complete_full || slidey_counter_reg != (pool_size_reg - 1));
    assign pool_scale_rdy_o         = is_use_pool_reg ? rdy_case_pool : pool_ofbuf_rdy_i;
    assign pool_ofbuf_vld_o         = (pool_scale_vld_i && !is_use_pool_reg) || (fifo_complete_vld && count_ofelement_rd_reg != num_element_cur_pass);
    assign pool_inf_rdy_o           = inf_rdy_reg;
    assign count_row_en             = rdy_case_pool && pool_scale_vld_i;
    assign count_height_en          = end_row_reg && ((|count_height_reg) ? (count_filter_reg == num_filter_cur_pass_reg - 1) : done_compute_reg);
    assign end_row_d                = (count_row_reg == (ofwidth_reg - 1)) && count_row_en;
    assign end_height_d             = (count_height_reg == ofwidth_reg - 1) && count_height_en;
    assign slidex_counter_d         = end_row_d ? 0 : ((slidex_counter_reg == pool_size_reg - 1) ? !is_stride_over_reg : slidex_counter_reg + 1);
    assign count_row_d              = (count_row_reg == ofwidth_reg - 1) ? 0 : count_row_reg + 1;
    assign slidey_counter_d         = end_height_d ? 0 : ((slidey_counter_reg == pool_size_reg - 1) ? !is_stride_over_reg : slidey_counter_reg + 1);
    assign count_height_d           = (count_height_reg == ofwidth_reg - 1) ? 0 : count_height_reg + 1;
    assign num_filter_cur_pass_d    = count_filter_reg + 1;
    assign num_filter_cur_pass_en   = !(|count_height_reg) && done_compute_reg && end_row_reg;
    assign count_filter_d           = ((num_filter_cur_pass_reg == count_filter_reg + 1) || !(|count_height_reg)) ? 0 : count_filter_reg + 1;
    assign count_filter_en          = (|count_height_reg) && end_row_reg;
    assign count_element_d          = count_height_en ? 13'd0 : count_element_reg + 13'd1;
    assign count_element_en         = (complete_fifo_wr && !fifo_complete_full) || count_height_en;
    assign count_ofelement_rd_d     = (count_ofelement_rd_reg == num_element_cur_pass) ? 13'd0 : count_ofelement_rd_reg + 13'd1;
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
        .rd_valid_i(count_ofelement_rd_reg == num_element_cur_pass),
        .wr_valid_i(count_height_en && ((slidey_counter_reg == pool_size_reg - 1) || end_height_d)),
        .clr_rd_i(1'b0),
        .clr_ff_i(1'b0),
        .empty_o(),
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
            if(done_compute_layer_reg && !(|count_height_reg) && !fifo_complete_vld) begin
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
            end_row_reg             <= 0;
            done_compute_layer_reg  <= 0;
        end else begin
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
            done_compute_layer_reg  <= pool_scale_done_compute_layer_i;
        end
    end

    always @(posedge clk) begin
        if(is_use_pool_reg) begin
            if(processed_en)            processed_reg               <= processed_d;
            if(dup_en)                  dup_reg                     <= dup_d;
        end
    end
    fifo_bram #(
        .WIDTH(13),
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
        .vld_o(),
        .end_data()
    );
    fifo_bram #(
        .WIDTH(13),
        .DEPTH(POOL_DEPTH)
    ) complete_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(complete_fifo_wr),
        .rd_en(complete_fifo_rd),
        .clr(1'b0),
        .din(complete_fifo_data_i),
        .dout(complete_fifo_data_o),
        .full(fifo_complete_full),
        .vld_o(fifo_complete_vld),
        .end_data()
    );
    fifo_bram #(
        .WIDTH(13),
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
        .vld_o(),
        .end_data()
    );
endmodule
