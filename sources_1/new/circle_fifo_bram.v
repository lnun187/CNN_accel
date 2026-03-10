`timescale 1ns / 1ps

module circle_fifo_bram #(
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
    reg [WIDTH-1:0] data_o;
    
    // Flag indicating if output register holds valid pre-fetched data
    reg valid_out; 
    
    // Internal RAM empty condition
    wire mem_empty = (wr_ptr == rd_ptr) || clr;

    assign full  = ( (wr_ptr + 1) % DEPTH ) == rd_ptr;
    assign empty = !valid_out;
    assign dout = valid_out ? data_o : {WIDTH{1'b0}};

    always @(posedge clk) begin
        if (!rst_n || clr) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            valid_out <= 0;
        end else begin
            // 1. Fill Logic (External Write)
            if (wr_en && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
            end
            // 2. Circular Read Logic & FWFT Prefetch
            // Using 'else if' prevents wr_ptr conflict if wr_en and rd_en are asserted simultaneously
            else if (rd_en && valid_out) begin
                // Write back current data to the tail of the FIFO
                mem[wr_ptr] <= data_o;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
                
                // Fetch next data
                if (!mem_empty) begin
                    data_o <= mem[rd_ptr];
                    rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
                    valid_out <= 1'b1;
                end else begin
                    // 1-element circular loop: output remains identical, just advance pointers
                    rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
                    valid_out <= 1'b1;
                end
            end 
            // 3. Standard FWFT Prefetch (Triggered when FIFO is idle but output is empty)
            else if (!valid_out && !mem_empty) begin
                data_o <= mem[rd_ptr];
                rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
                valid_out <= 1'b1;
            end
        end
    end
endmodule