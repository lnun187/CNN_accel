`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/29/2026 11:10:00 PM
// Design Name: 
// Module Name: layer_info
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


module layer_info #(
    parameter DATA_WIDTH = 8
)(
    input                               clk,
    input                               rst_n,

    input                               inf_table_vld_i,
    output                              inf_table_rdy_o,
    input           [3:0]               inf_table_hidx_i,
    input           [3:0]               inf_table_ciidx_i,
    input           [3:0]               inf_table_coidx_i,
    input           [3:0]               inf_table_hf_i,
    input           [2:0]               inf_table_stride_i,
    input           [1:0]               inf_table_padding_i,
    input           [2:0]               inf_table_ifparr_i,
    input           [1:0]               inf_table_oftile_i,
    input           [4:0]               inf_table_ofparr_i,
    input           [23:0]              inf_table_ifbaddr_i,
    input           [23:0]              inf_table_fltbaddr_i,
    input           [23:0]              inf_table_bias_baddr_i,
    input           [23:0]              inf_table_ofbaddr_i,
    input  signed   [DATA_WIDTH-1:0]    inf_table_ifc_zp_i,
    input  signed   [DATA_WIDTH-1:0]    inf_table_fltc_zp_i,
    input  signed   [31:0]              inf_table_mult_i,
    input           [5:0]               inf_table_mult_shift_i,
    input  signed   [31:0]              inf_table_alphamult_i,
    input           [5:0]               inf_table_alphamult_shift_i,
    input  signed   [7:0]               inf_table_zpy_i,
    input  signed   [7:0]               inf_table_qmin_i,
    input  signed   [7:0]               inf_table_qmax_i,
    input                               inf_table_is_leaky_ReLU_i,

    //ifbuf info
    input                               inf_ifbuf_rdy_i,
    output                              inf_ifbuf_vld_o,
    output          [31:0]              inf_ifbuf_ifbaddr_o,
    output          [7:0]               inf_ifbuf_ifwidth_o,
    output          [10:0]              inf_ifbuf_channel_o,
    output          [3:0]               inf_ifbuf_ifparr_o,
    output          [15:0]              inf_ifbuf_ifsize_o,
    output          [6:0]               inf_ifbuf_ifblock_o,
    output          [3:0]               inf_ifbuf_oftiles_o,
    output          [3:0]               inf_ifbuf_oftiles_tail_o,
    output          [6:0]               inf_ifbuf_iftiles_o,
    output          [8:0]               inf_ifbuf_wp_o,
    output          [1:0]               inf_ifbuf_padding_o,
    output          [DATA_WIDTH-1:0]    inf_ifbuf_ifc_zp_o,
    
    //fltbuf info
    input                               inf_fltbuf_rdy_i,
    output                              inf_fltbuf_vld_o,
    output          [23:0]              inf_fltbuf_fltbaddr_o,
    output          [3:0]               inf_fltbuf_ifparr_o,
    output          [3:0]               inf_fltbuf_ifparr_tail_o,
    output          [6:0]               inf_fltbuf_fltsize_o,
    output          [6:0]               inf_fltbuf_ifblock_o,
    output          [4:0]               inf_fltbuf_ofparr_o,
    output          [4:0]               inf_fltbuf_ofparr_tail_o,
    output          [3:0]               inf_fltbuf_oftiles_o,
    output          [3:0]               inf_fltbuf_oftiles_tail_o,
    output          [6:0]               inf_fltbuf_iftiles_o,
    
    //bias buf info
    input                               inf_bias_rdy_i,
    output                              inf_bias_vld_o,
    output          [23:0]              inf_bias_bias_baddr_o,
    output          [7:0]               inf_bias_ofwidth_o,
    output          [10:0]              inf_bias_ofchannel_o,
    output          [4:0]               inf_bias_burstlen_o,
    output          [4:0]               inf_bias_burstlen_tail_o,
    output          [4:0]               inf_bias_burstlen_lane0_o,
    output          [4:0]               inf_bias_burstlen_tail_lane0_o,

    //comp info
    input                               comp_inf_rdy_i,
    output                              comp_inf_vld_o,
    output          [3:0]               comp_inf_hf_o,
    output          [2:0]               comp_inf_stride_o,
    output          [1:0]               comp_inf_padding_o,
    output          [DATA_WIDTH-1:0]    comp_inf_ifc_zp_o,
    output          [DATA_WIDTH-1:0]    comp_inf_fltc_zp_o,
    output          [7:0]               comp_inf_ofwidth_o,
    output signed   [31:0]              comp_inf_mult_o,
    output          [5:0]               comp_inf_mult_shift_o,
    output signed   [31:0]              comp_inf_alphamult_o,
    output          [5:0]               comp_inf_alphamult_shift_o,
    output signed   [7:0]               comp_inf_zpy_o,
    output signed   [7:0]               comp_inf_qmin_o,
    output signed   [7:0]               comp_inf_qmax_o,
    output                              comp_inf_is_leaky_ReLU_o,

    //ofbuf info - coming soon
    );



endmodule
