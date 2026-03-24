`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2026 08:23:31 PM
// Design Name: 
// Module Name: fifo
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


module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 224 * 12
)(
    input clk,
    input rst_n,
    input wr_en_i,
    input rd_en_i,
    input clr,
    input [WIDTH-1:0] din,
    output [WIDTH-1:0] dout,
    output wire full,
    output wire empty,
    output wire end_data
    );
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    assign full  = ( (wr_ptr + 1) % DEPTH ) == rd_ptr;
    assign empty = (wr_ptr == rd_ptr) || clr;
    assign end_data = (rd_ptr == wr_ptr - 1);
    assign dout = empty ? {WIDTH{1'b0}} : mem[rd_ptr];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
        end else begin
            // Write Logic
            if(clr) begin
                wr_ptr <= 0;
                rd_ptr <= 0;
            end else begin
                if (wr_en_i && !full) begin
                    mem[wr_ptr] <= din;
                    wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
                end
                // Read Logic
                if (rd_en_i && !empty) begin
                    rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
                end
            end
            
        end
    end
endmodule
