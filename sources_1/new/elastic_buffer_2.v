`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/16/2026 11:57:04 AM
// Design Name: 
// Module Name: elastic_buffer_2
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


module elastic_buffer_2 #
(
    parameter WIDTH = 32
)
(
    input                  clk,
    input                  rst_n,

    input                  in_valid,
    output                 in_ready,
    input  [WIDTH-1:0]     in_data,

    output                 out_valid,
    input                  out_ready,
    output [WIDTH-1:0]     out_data
);

    reg [WIDTH-1:0] mem0;
    reg [WIDTH-1:0] mem1;

    reg             rd_ptr;
    reg             wr_ptr;
    reg [1:0]       count;

    wire            push;
    wire            pop;

    assign out_valid = (count != 2'd0);
    assign out_data  = (rd_ptr == 1'b0) ? mem0 : mem1;

    // Có thể nhận data nếu chưa full,
    // hoặc nếu cùng cycle đó downstream đang lấy ra 1 beat
    assign in_ready  = (count != 2'd2) || (out_valid && out_ready);

    assign push = in_valid && in_ready;
    assign pop  = out_valid && out_ready;

    always @(posedge clk) begin
            // Ghi data mới vào slot đang được trỏ bởi wr_ptr
        if (push) begin
            if (wr_ptr == 1'b0)
                mem0 <= in_data;
            else
                mem1 <= in_data;
        end
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            rd_ptr <= 1'b0;
            wr_ptr <= 1'b0;
            count  <= 2'd0;
        end
        else begin
            // Ghi data mới vào slot đang được trỏ bởi wr_ptr
            if (push) begin
                wr_ptr <= ~wr_ptr;
            end

            // Consume data ra output
            if (pop) begin
                rd_ptr <= ~rd_ptr;
            end

            // Update occupancy count
            case ({push, pop})
                2'b10: count <= count + 2'd1; // chỉ push
                2'b01: count <= count - 2'd1; // chỉ pop
                default: count <= count;      // push+pop hoặc idle
            endcase
        end
    end

endmodule
