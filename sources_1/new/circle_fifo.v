`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/11/2026 11:26:57 AM
// Design Name: 
// Module Name: circle_fifo
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


module circle_fifo#(
    parameter WIDTH = 8,
    parameter DEPTH = 11
)(
    input clk,
    input rst_n,
    input wr_en,
    input rd_en,
    input clr,
    input [WIDTH-1:0] din,
    output [WIDTH-1:0] dout,
    output wire full,
    output wire empty
    );
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    assign full  = ( (wr_ptr + 1) % DEPTH ) == rd_ptr;
    assign empty = (wr_ptr == rd_ptr);
    assign dout = mem[rd_ptr];
    always @(posedge clk) begin
        if (!rst_n || clr) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            // Write Logic
            if (wr_en && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
            end
            // Read Logic
            if (rd_en && !empty) begin
                mem[wr_ptr] <= dout;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
                rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
            end
        end
    end
endmodule
