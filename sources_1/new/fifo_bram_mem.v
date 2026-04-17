`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/15/2026 09:15:26 PM
// Design Name: 
// Module Name: fifo_bram_mem
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


`timescale 1ns / 1ps

module fifo_bram_mem #(
    parameter integer WIDTH  = 8,
    parameter integer DEPTH  = 224 * 12,
    parameter integer ADDR_W = (DEPTH <= 2) ? 1 : $clog2(DEPTH)
) (
    input  wire              clk,
    input  wire              we,
    input  wire [ADDR_W-1:0] waddr,
    input  wire [WIDTH-1:0]  din,
    input  wire              re,
    input  wire [ADDR_W-1:0] raddr,
    output reg  [WIDTH-1:0]  dout
);

    (* ram_style = "block" *) reg [WIDTH-1:0] mem [0:DEPTH-1];

    always @(posedge clk) begin
        if (we)
            mem[waddr] <= din;

        if (re)
            dout <= mem[raddr];
    end

endmodule
