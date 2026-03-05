`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/12/2026 04:41:58 PM
// Design Name: 
// Module Name: add_data
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


module comp_pe#(
    parameter ID = 0,
    parameter WIDTH = 8
)(
    input clk,
    input rst_n,
    input en,

    input pe_ins_dw_i,
    input [3:0] pe_ins_hf_i, 

    input pe_ifc_end_row_circle_i,
    input pe_ifc_end_depth_i,
    input pe_ifc_end_layer_i,
    input pe_ifc_end_height_i,
    input pe_ifc_vld_i,
    input [WIDTH-1:0] pe_ifc_data_i,

    input pe_fltc_vld_i,
    input [WIDTH-1:0] pe_fltc_data_i,
    // output flt_done_o,
    output pe_ifc_fltc_rdy_o,

    input [WIDTH-1:0] pe_pp_pre_data_i,
    output reg pe_pp_pre_rd_o,
    input [WIDTH-1:0] pe_pp_cur_data_i,
    output reg pe_pp_cur_rd_o,
    input pe_pp_empty_i,
    output pe_pp_wr_o,
    output [WIDTH-1:0] pe_pp_data_o
);
    reg [3:0] count;
    reg [3:0] count_nxt;
    reg is_channel_0;
    reg is_row_0;
    reg swap;
    reg [WIDTH-1:0] data;
    wire [WIDTH-1:0] data_nxt;
    wire [3:0]id;
    reg [WIDTH-1:0] add_data;
    assign id = ID;
    assign data_nxt = pe_ifc_data_i * pe_fltc_data_i + add_data;
    assign pe_pp_wr_o = en && count == (pe_ins_hf_i - 1) && pe_ifc_vld_i && pe_fltc_vld_i && pe_ifc_fltc_rdy_o;
    assign pe_pp_data_o = data_nxt;
    // assign flt_done_o = ((pe_ifc_end_row_circle_i && !pe_ins_dw_i) || (pe_ifc_end_height_i && pe_ins_dw_i)) && pe_ifc_vld_i && pe_fltc_vld_i && pe_ifc_fltc_rdy_o;
    assign pe_ifc_fltc_rdy_o = en && pe_fltc_vld_i && pe_ifc_vld_i && (pe_pp_empty_i && (!pe_ins_dw_i && pe_ifc_end_depth_i || pe_ins_dw_i && pe_ifc_end_row_circle_i ) || pe_ins_dw_i && !pe_ifc_end_row_circle_i || !pe_ins_dw_i && !pe_ifc_end_depth_i);
    always @(*) begin
        pe_pp_pre_rd_o = 0;
        pe_pp_cur_rd_o = 0;
        casex({count == 0, is_row_0, is_channel_0, id % pe_ins_hf_i == 0})
            4'b100x: begin 
                add_data = pe_pp_cur_data_i;
                pe_pp_cur_rd_o = 1;
            end
            4'b0xxx: begin
                add_data = data;
            end
            4'b11xx: begin
                add_data = 0;
            end
            4'b1011: begin
                add_data = 0;
            end
            4'b1010: begin
                add_data = pe_pp_pre_data_i;
                pe_pp_pre_rd_o = 1;
            end
            default: add_data = 0;
        endcase
    end
    always @(posedge clk) begin
        if(!rst_n || pe_ifc_end_depth_i) begin
            is_channel_0 <= 1'b1;
        end else if(en && pe_ifc_end_row_circle_i && !pe_ins_dw_i)begin
            is_channel_0 <= 0;
        end
    end
    always @(posedge clk) begin
        if(!rst_n || pe_ifc_end_layer_i) begin
            is_row_0 <= 1'b1;
        end else if(en && pe_ifc_end_row_circle_i)begin
            is_row_0 <= 0;
        end
    end
    always @(posedge clk) begin
        if(!rst_n || count == pe_ins_hf_i - 1) begin
            count <= 0;
        end else if(en && pe_ifc_vld_i && pe_fltc_vld_i && pe_ifc_fltc_rdy_o)begin
            count <= count + 1;
            data <= data_nxt;
        end
    end
endmodule
