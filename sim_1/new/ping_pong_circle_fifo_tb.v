`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 11:42:54 AM
// Design Name: 
// Module Name: ping_pong_circle_fifo_tb
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


module ping_pong_circle_fifo_tb;
    parameter WIDTH = 8;
    parameter DEPTH = 11;

    reg clk;
    reg rst_n;
    reg id_i;
    reg wr_en;
    reg rd_en;
    reg clr_i;
    reg [WIDTH-1:0] data_i;
    wire [WIDTH-1:0] data_o;
    wire empty_o;

    ping_pong_circle_fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .id_i(id_i),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .clr_i(clr_i),
        .data_i(data_i),
        .data_o(data_o),
        .empty_o(empty_o)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns clock period
    end

    initial begin
        // Initialize inputs
        rst_n = 0;
        id_i = 0;
        wr_en = 0;
        rd_en = 0;
        clr_i = 0;
        data_i = 0;

        // Release reset
        #15;
        rst_n = 1;

        // Test sequence
        // Write to FIFO 1
        id_i = 0;
        wr_en = 1;
        data_i = 8'hA5;
        #10;
        data_i = 8'h5A;
        #10;
        wr_en = 0;
    // Read from FIFO 0
        rd_en = 1;
        #10;
        rd_en = 0;
        #10;
        rd_en = 1;
        #10;
        rd_en = 0;
         #10;
        rd_en = 1;
        #10;
        rd_en = 0;
        // Write to FIFO 0
        id_i = 1;
        wr_en = 1;
        data_i = 8'hFF;
        #10;
        data_i = 8'h00;
        #10;
        wr_en = 0;

        // Read from FIFO 1
        rd_en = 1;
        #10;
        rd_en = 0;
        #10;
        rd_en = 1;
        #10;
        rd_en = 0;
         #10;
        rd_en = 1;
        #10;
        rd_en = 0;
        // Finish simulation
        #50;
        $finish;
    end
endmodule

