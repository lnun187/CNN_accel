`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/03/2026 10:12:44 PM
// Design Name: 
// Module Name: comp_pu
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


module comp_pu #(
    parameter WIDTH = 8,
    parameter PE_PER_PU = 12,
    parameter DEPTH = 11,
    parameter K = 7,
    parameter PPDEPTH = 8192
)(
    input clk,
    input rst_n,
    input en,

    //from instruction
    input pu_ins_dw_i,
    input [3:0] pu_ins_hf_i,
    input [1:0] pu_ins_stride_i,
    input [1:0] pu_ins_padding_i,

    //from ifmap cache
    input pu_ifc_end_row_circle_i,
    input pu_ifc_end_row_i,
    input pu_ifc_end_depth_i,
    input pu_ifc_end_layer_i,
    input pu_ifc_end_height_i,
    input pu_ifc_vld_i,
    input [K*WIDTH-1:0] pu_ifc_data_i,
    output pu_ifc_rdy_o,
    //from and to filter buf
    input pu_fltbuf_vld_i,
    input [K*WIDTH-1:0] pu_fltbuf_data_i,
    input pu_fltbuf_done_pass_i,
    output pu_fltbuf_rdy_o,

    //from and to ofbuf
    input pu_ofbuf_rdy_i,
    output pu_ofbuf_vld_o,
    output [WIDTH-1:0] pu_ofbuf_data_o,
    output pu_pa_done_compute_o
    );

    wire clr_ch_flt;
    reg pu_ifc_end_height_i_reg;
    reg pu_ifc_end_layer_i_reg;
    reg pp_id;
    wire swap_en;
    
    assign pu_fltbuf_rdy_o = fltc_fltbuf_rdy_o;
    assign pu_ifc_rdy_o = pe_ifc_fltc_rdy_o[0];
    assign pu_ofbuf_vld_o = cwc_ofbuf_vld_o;
    assign pu_ofbuf_data_o = cwc_ofbuf_data_o;
    assign pu_pa_done_compute_o = cwc_pu_done_compute_o;

    // assign swap_en = en && & pp_pe_empty_o && (!pu_ins_dw_i && pu_ifc_end_depth_i || pu_ins_dw_i && pu_ifc_end_row_circle_i );
    assign swap_en = en && (&pp_pe_empty_o) && pu_ifc_end_depth_i && pu_ifc_vld_i && fltc_pe_vld_o && pe_ifc_fltc_rdy_o[0];
    // assign clr_ch_flt = ((pu_ifc_end_row_i && !pu_ins_dw_i) || (pu_ifc_end_height_i && pu_ins_dw_i)) && pu_ifc_vld_i && fltc_pe_vld_o && pe_ifc_fltc_rdy_o[0];
    assign clr_ch_flt = pu_ifc_end_row_i && pu_ifc_vld_i && fltc_pe_vld_o && pe_ifc_fltc_rdy_o[0];
    
    always @(posedge clk) begin
        if(!rst_n || cwc_pu_done_compute_o) begin
            pp_id <= 0;
            pu_ifc_end_height_i_reg <= 0;
            pu_ifc_end_layer_i_reg <= 0;
        end else if(swap_en) begin
            pp_id <= ~pp_id;
            pu_ifc_end_height_i_reg <= pu_ifc_end_height_i;
            pu_ifc_end_layer_i_reg <= pu_ifc_end_layer_i;
        end
    end
    
    wire fltc_fltbuf_vld_i;
    wire [K*WIDTH-1:0] fltc_fltbuf_data_i;
    wire [K-1:0] fltc_fltbuf_rdy_o;
    wire [3:0] fltc_ins_hf_i;
    wire fltc_fltbuf_done_pass_i;
    wire fltc_pe_rdy_i;
    wire fltc_pu_clr_ch_flt_i;
    wire [K*PE_PER_PU-1:0] fltc_pe_vld_flat_o;
    reg [PE_PER_PU-1:0] fltc_pe_vld_o;
    wire [K*PE_PER_PU*WIDTH-1:0] fltc_pe_data_o;

    assign fltc_fltbuf_vld_i = pu_fltbuf_vld_i;
    assign fltc_fltbuf_done_pass_i = pu_fltbuf_done_pass_i;
    assign fltc_fltbuf_data_i = pu_fltbuf_data_i;
    assign fltc_ins_hf_i = pu_ins_hf_i;
    assign fltc_pu_clr_ch_flt_i = clr_ch_flt;
    assign fltc_pe_rdy_i = pe_ifc_fltc_rdy_o[0];
    genvar j;
    generate
        for(j = 0; j < K; j = j + 1) begin: gen_fltc
            filter_cache #(
            .WIDTH(WIDTH),
            .DEPTH(11),
            .PE_PER_PU(PE_PER_PU)
        ) flt_cache_uut (
            .clk(clk),
            .rst_n(rst_n),
            .en(en),
            .fltc_fltbuf_vld_i(fltc_fltbuf_vld_i),
            .fltc_fltbuf_done_pass_i(fltc_fltbuf_done_pass_i),
            .fltc_fltbuf_data_i(fltc_fltbuf_data_i[j*WIDTH +: WIDTH]),
            .fltc_fltbuf_rdy_o(fltc_fltbuf_rdy_o[j]),
            .pu_ifc_end_layer_i(pu_ifc_end_layer_i)
            .fltc_ins_hf_i(fltc_ins_hf_i),
            
            .fltc_pe_rdy_i(fltc_pe_rdy_i),
            .fltc_pu_clr_ch_flt_i(fltc_pu_clr_ch_flt_i),
            .fltc_pe_vld_o(fltc_pe_vld_flat_o[j*PE_PER_PU +: PE_PER_PU]),
            .fltc_pe_data_o(fltc_pe_data_o[j*PE_PER_PU*WIDTH +: PE_PER_PU*WIDTH])
        );
        end
    endgenerate
    integer t;
    always @(*) begin
        fltc_pe_vld_o = 0;
        for(t = 0; t < K; t = t + 1) begin
            fltc_pe_vld_o = fltc_pe_vld_o | fltc_pe_vld_flat_o[t* PE_PER_PU +: PE_PER_PU];
        end
    end

    wire pe_ins_dw_i;
    wire [3:0] pe_ins_hf_i;
    wire pe_ifc_end_row_circle_i;
    wire pe_ifc_end_depth_i;
    wire pe_ifc_end_layer_i;
    wire pe_ifc_end_height_i;
    wire pe_ifc_vld_i;
    wire [K*WIDTH-1:0] pe_ifc_data_i;
    wire [PE_PER_PU-1:0] pe_fltc_vld_i;
    wire [K*PE_PER_PU*WIDTH-1:0] pe_fltc_data_i;
    wire [PE_PER_PU*WIDTH-1:0] pe_pp_pre_data_i;
    wire [PE_PER_PU-1:0] pe_ifc_fltc_rdy_o;
    wire [PE_PER_PU-1:0] pe_pp_pre_rd_o;
    wire [PE_PER_PU*WIDTH-1:0] pe_pp_cur_data_i;
    wire [PE_PER_PU-1:0] pe_pp_cur_rd_o;
    wire pe_pp_empty_i;
    wire [PE_PER_PU-1:0] pe_pp_wr_o;
    wire [PE_PER_PU*WIDTH-1:0] pe_pp_data_o;

    assign pe_ins_dw_i = pu_ins_dw_i;
    assign pe_ins_hf_i = pu_ins_hf_i;
    assign pe_ifc_end_row_circle_i = pu_ifc_end_row_circle_i;
    assign pe_ifc_end_depth_i = pu_ifc_end_depth_i;
    assign pe_ifc_end_layer_i = pu_ifc_end_layer_i;
    assign pe_ifc_end_height_i = pu_ifc_end_height_i;
    assign pe_ifc_vld_i = pu_ifc_vld_i;
    assign pe_ifc_data_i = pu_ifc_data_i;
    assign pe_fltc_vld_i = fltc_pe_vld_o;
    // assign pe_fltc_data_i = fltc_pe_data_o;
    assign pe_pp_pre_data_i = pp_pe_cwc_data_b_o;
    assign pe_pp_cur_data_i = pp_pe_data_a_o;
    assign pe_pp_empty_i = &pp_pe_empty_o;
    genvar pe, k;
    generate
        for(pe = 0; pe < PE_PER_PU; pe = pe + 1) begin : gen_pe
            for(k = 0; k < K; k = k + 1) begin : gen_k
                assign pe_fltc_data_i[(pe * K + k)*WIDTH +: WIDTH] = fltc_pe_data_o[(k * PE_PER_PU + pe)*WIDTH +: WIDTH];
            end
        end
    endgenerate
    wire pp_pu_id_i;
    wire [PE_PER_PU-1:0] pp_pe_wr_en_i;
    wire [PE_PER_PU-1:0] pp_pe_rd_ena_i;
    wire [PE_PER_PU-1:0] pp_pe_rd_enb_i;
    wire [PE_PER_PU-1:0] pp_cwc_clr_i;
    wire [WIDTH*PE_PER_PU-1:0] pp_pe_data_i;
    wire [WIDTH*PE_PER_PU-1:0] pp_pe_data_a_o;
    wire [PE_PER_PU-1:0] pp_pe_empty_o;
    wire [WIDTH*PE_PER_PU-1:0] pp_pe_cwc_data_b_o;
    wire [PE_PER_PU-1:0] pp_cwc_end_data_o;

    assign pp_pu_id_i = pp_id;
    assign pp_pe_wr_en_i = pe_pp_wr_o;
    assign pp_pe_rd_ena_i = pe_pp_cur_rd_o;
    assign pp_pe_rd_enb_i = {1'b0, pe_pp_pre_rd_o[PE_PER_PU - 1 : 1]} | cwc_pp_rdy_o;
    assign pp_cwc_clr_i = cwc_pp_clear_o;
    assign pp_pe_data_i = pe_pp_data_o;
    genvar i;
    generate
        for (i = 0; i < PE_PER_PU; i = i + 1) begin : comp_pe_array
            wire [WIDTH-1:0] pre_data_tmp;

        // Xử lý riêng logic tránh index âm
            if (i == 0) begin
                assign pre_data_tmp = {WIDTH{1'b0}};
            end else begin
                assign pre_data_tmp = pe_pp_pre_data_i[(i-1)*WIDTH +: WIDTH];
            end
            comp_pe #(
                .ID(i),
                .WIDTH(WIDTH),
                .K(K)
            ) comp_pe_uut (
                .clk(clk),
                .rst_n(rst_n),
                .en(en),

                .pe_ins_dw_i(pe_ins_dw_i),
                .pe_ins_hf_i(pe_ins_hf_i), 

                .pe_ifc_end_row_circle_i(pe_ifc_end_row_circle_i),
                .pe_ifc_end_depth_i(pe_ifc_end_depth_i),
                .pe_ifc_end_layer_i(pe_ifc_end_layer_i),
                .pe_ifc_end_height_i(pe_ifc_end_height_i),
                .pe_ifc_vld_i(pe_ifc_vld_i),
                .pe_ifc_data_i(pe_ifc_data_i),

                .pe_fltc_vld_i(pe_fltc_vld_i[i]),
                .pe_fltc_data_i(pe_fltc_data_i[i*K*WIDTH +: K*WIDTH]),
                .pe_ifc_fltc_rdy_o(pe_ifc_fltc_rdy_o[i]),

                .pe_pp_pre_data_i(pre_data_tmp),
                .pe_pp_pre_rd_o(pe_pp_pre_rd_o[i]),
                .pe_pp_cur_data_i(pe_pp_cur_data_i[i*WIDTH +: WIDTH]),
                .pe_pp_cur_rd_o(pe_pp_cur_rd_o[i]),
                .pe_pp_empty_i(pe_pp_empty_i),
                .pe_pp_wr_o(pe_pp_wr_o[i]),
                .pe_pp_data_o(pe_pp_data_o[i*WIDTH +: WIDTH])
            );

            pu_ping_pong_fifo #(
                .WIDTH(WIDTH),
                .DEPTH(PPDEPTH)
            ) pp_uut (
                .clk(clk),
                .rst_n(rst_n),
                .pp_pu_id_i(pp_pu_id_i),
                .pp_pe_wr_en_i(pp_pe_wr_en_i[i]),
                .pp_pe_rd_ena_i(pp_pe_rd_ena_i[i]),
                .pp_pe_rd_enb_i(pp_pe_rd_enb_i[i]),
                .pp_cwc_clr_i(pp_cwc_clr_i[i]),
                .pp_pe_data_i(pp_pe_data_i[i*WIDTH +: WIDTH]),
                .pp_pe_data_a_o(pp_pe_data_a_o[i*WIDTH +: WIDTH]),
                .pp_pe_cwc_data_b_o(pp_pe_cwc_data_b_o[i*WIDTH +: WIDTH]),
                .pp_pe_empty_o(pp_pe_empty_o[i]),
                .pp_cwc_end_data_o(pp_cwc_end_data_o[i])
            );
        end
    endgenerate

    wire cwc_ins_dw_i;
    wire [3:0] cwc_ins_hf_i;
    wire [1:0] cwc_ins_stride_i;
    wire [1:0] cwc_ins_padding_i;
    wire cwc_pu_end_height_i;
    wire cwc_pu_end_height_nxt_i;
    wire cwc_pu_end_layer_i;
    wire cwc_pu_end_layer_nxt_i;
    wire [WIDTH*PE_PER_PU-1:0] cwc_pp_data_i;
    wire [PE_PER_PU-1:0] cwc_pp_vld_i;
    wire [PE_PER_PU-1:0] cwc_pp_end_data_i;
    wire [PE_PER_PU-1:0] cwc_pp_rdy_o;
    wire [PE_PER_PU-1:0] cwc_pp_clear_o;
    wire cwc_pu_swap_en_i;
    wire cwc_ofbuf_rdy_i;
    wire cwc_ofbuf_vld_o;
    wire [WIDTH-1:0] cwc_ofbuf_data_o;
    wire cwc_pu_done_compute_o;

    assign cwc_ins_dw_i = pu_ins_dw_i;
    assign cwc_ins_hf_i = pu_ins_hf_i;
    assign cwc_ins_stride_i = pu_ins_stride_i;
    assign cwc_ins_padding_i = pu_ins_padding_i;
    assign cwc_pu_end_height_i = pu_ifc_end_height_i_reg;
    assign cwc_pu_end_height_nxt_i = pu_ifc_end_height_i;
    assign cwc_pu_end_layer_i = pu_ifc_end_layer_i_reg;
    assign cwc_pu_end_layer_nxt_i = pu_ifc_end_layer_i;
    assign cwc_pp_data_i = pp_pe_cwc_data_b_o;
    assign cwc_pp_vld_i = ~pp_pe_empty_o;
    assign cwc_pp_end_data_i = pp_cwc_end_data_o;
    assign cwc_pu_swap_en_i = swap_en;
    assign cwc_ofbuf_rdy_i = pu_ofbuf_rdy_i;
    
    comp_wr_ctrl #(
        .WIDTH(WIDTH),
        .PE_PER_PU(PE_PER_PU)
    ) cwc_uut (
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
        
        .cwc_pp_data_i(cwc_pp_data_i),
        .cwc_pp_vld_i(cwc_pp_vld_i),
        .cwc_pp_end_data_i(cwc_pp_end_data_i),
        .cwc_pp_rdy_o(cwc_pp_rdy_o),
        .cwc_pp_clear_o(cwc_pp_clear_o),

        .cwc_pu_swap_en_i(cwc_pu_swap_en_i),
        
        .cwc_ofbuf_rdy_i(cwc_ofbuf_rdy_i),
        .cwc_ofbuf_vld_o(cwc_ofbuf_vld_o),
        .cwc_ofbuf_data_o(cwc_ofbuf_data_o),
        .cwc_pu_done_compute_o(cwc_pu_done_compute_o)
    );
endmodule
