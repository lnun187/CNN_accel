`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/02/2026 10:01:44 AM
// Design Name: 
// Module Name: ofbuf
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


module ofbuf#(
    parameter DATA_WIDTH = 8, //Data dua vao FIFO
    parameter DEPTH = 300, //do sau FIFO
    parameter M = 2 //So luong FIFO
)(
    input  wire clk,
    input  wire rst_n,
    
    // Giao tiếp inftructions
    input  wire ofbuf_inf_vld_i,
    input  wire [23:0] ofbuf_inf_ofbaddr_i, //dia chi bat dau store ofmap cua layer. Khi nap het channel o block cuoi
    input  wire [7:0]  ofbuf_inf_width_i,//chieu dai va chieu rong cua channel
    input  wire [10:0] ofbuf_inf_channel_i,//so channel tong trong 1 luot tai (kich thuoc data tong la so data nhan width) //tao nghi khong can xai toi
    input  wire [7:0] ofbuf_inf_ofparr_i,//so channel ofmap song song o block khong phai oftile cuoi cua block cuoi
    input  wire [7:0] ofbuf_inf_ofparr_tail_i,//so channel ofmap song song o oftile cuoi cua block cuoi
    input  wire [3:0] ofbuf_inf_oftiles_i, //so oftile khong o block cuoi
    input  wire [3:0] ofbuf_inf_oftiles_tail_i, //so oftile o block cuoi
    input  wire [7:0]  ofbuf_inf_ofsize_i,//kich thuoc mot channel (width align*width)
    input  wire [7:0]  ofbuf_inf_block_i,//kich thuoc mot channel (width align*width)
    output wire ofbuf_inf_rdy_o,//Khi nap het channel o block cuoi thi rdy len 1 hoac luc moi khoi dong

    // Tín hiệu DMA
    input  wire ofbuf_dma_rdycfg_i,
    output wire ofbuf_dma_vldcfg_o,
    output reg [8:0]  ofbuf_dma_burst_o, 
    output wire [23:0] ofbuf_dma_baddr_o,
    output  wire ofbuf_dma_vld_o,
    output  wire [DATA_WIDTH-1:0] ofbuf_dma_data_o,
    output  wire ofbuf_dma_tlast_o,
    input  wire ofbuf_dma_rdy_i,

    // Tín hiệu giao tiếp với khối khác
    input  wire [M-1:0] ofbuf_comp_vld_i, //2 khoi FIFO trong ofbuf nhan gia tri tuong ung
    output wire [M-1:0] ofbuf_comp_rdy_o, //2 khoi FIFO trong ofbuf gui gia tri tuong ung
    input wire [M*DATA_WIDTH-1:0] ofbuf_comp_data_i, //2 khoi FIFO trong ofbuf nhan gia tri tuong ung
    input  wire is_last_block_i //len mot khi la block cuoi cung //neu duoc thi dung xai, tao chua cung cap interface nay do so violate timing
    );
    //2FIFO moi FIOFO 896 bytes
endmodule
