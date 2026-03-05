`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 11:40:36 AM
// Design Name: 
// Module Name: ping_pong_circle_fifo
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


module ping_pong_circle_fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 11
)(
    input clk,
    input rst_n,
    input id_i,
    input wr_en,
    input rd_en,
    input clr_i,
    input [WIDTH-1:0] data_i,
    output [WIDTH-1:0] data_o,
    output wire empty_o
    );
    wire [WIDTH-1:0] data_o1, data_o2;
    wire [WIDTH-1:0] data_i1, data_i2;
    wire wr_en1, wr_en2;
    wire rd_en1, rd_en2;
    wire clr1, clr2;
    wire empty1, empty2;

    assign rd_en1 = rd_en & ~id_i;
    assign rd_en2 = rd_en & id_i;
    assign clr1 = clr_i & ~id_i;
    assign clr2 = clr_i & id_i;
    assign wr_en1 = wr_en & id_i; // Cho phep ghi vao fifo1 khi id_i=1
    assign wr_en2 = wr_en & ~id_i;  // Cho phep ghi vao fifo2 khi id_i=0
    assign data_i1 = data_i; // Du lieu vao fifo1 la data_i khi ghi, la data_o1 khi doc
    assign data_i2 = data_i; // Du lieu vao fifo2 la data_i khi ghi, la data_o2 khi doc
    assign data_o = id_i ? data_o2 : data_o1;
    assign empty_o = id_i ? empty2 : empty1;
    circle_fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) fifo1 (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en1),
        .rd_en(rd_en1),
        .clr(clr1),
        .din(data_i1),
        .dout(data_o1),
        .full(),
        .empty(empty1)
    );
    circle_fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) fifo2 (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en2),
        .rd_en(rd_en2),
        .clr(clr2),
        .din(data_i2),
        .dout(data_o2),
        .full(),
        .empty(empty2)
    );
endmodule

