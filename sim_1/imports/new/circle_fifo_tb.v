`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 11:30:58 AM
// Design Name: 
// Module Name: circle_fifo_tb
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


module circle_fifo_tb;
    parameter WIDTH = 8;
    parameter DEPTH = 11;

    reg clk;
    reg rst_n;
    reg wr_en;
    reg rd_en;
    reg clr;
    reg [WIDTH-1:0] din;
    wire [WIDTH-1:0] dout;
    wire full;
    wire empty;

    circle_fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .clr(clr),
        .din(din),
        .dout(dout),
        .full(full),
        .empty(empty)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Clock period 10 time units
    end

    initial begin
        // Initialize signals
        rst_n = 0; wr_en = 0; rd_en = 0; clr = 0; din = 0;
        #15;
        
        // Release reset
        rst_n = 1;
        #10;

        // Write some data
        // repeat (3) begin
        //     @(negedge clk);
        //     wr_en = 1;
        //     din = $random % 256; // Random data
        //     @(negedge clk);
        //     wr_en = 0;
        // end

        // Read some data
        repeat (5) begin
            @(negedge clk);
            rd_en = 1;
            @(negedge clk);
            rd_en = 0;
        end

        // Clear FIFO
        @(negedge clk);
        clr = 1;
        @(negedge clk);
        clr = 0;

        // Finish simulation
        #50;
        $finish;
    end
endmodule
