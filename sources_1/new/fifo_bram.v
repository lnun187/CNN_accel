`timescale 1ns / 1ps

module fifo_bram #(
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
    reg [WIDTH-1:0] data_out;
    
    // Flag indicating if data_out holds valid pre-fetched data
    reg valid_out; 
    
    // Internal RAM empty condition
    wire mem_empty;
    assign mem_empty = (wr_ptr == rd_ptr);

    assign full  = ( (wr_ptr + 1) % DEPTH ) == rd_ptr;
    
    // FIFO is externally empty only when the output register has no valid data
    assign empty = !valid_out || clr; 
    
    assign dout = valid_out ? data_out : {WIDTH{1'b0}};

    // end_data is true when the very last item is in data_out and RAM is empty
    assign end_data = valid_out && mem_empty;

    always @(posedge clk) begin
        if (!rst_n || clr) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            valid_out <= 0;
        end else begin
            // Write Logic
            if (wr_en_i && !full) begin
                mem[wr_ptr] <= din;
                wr_ptr <= (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
            end

            // FWFT Read & Prefetch Logic
            // Triggers if a read is requested OR if the output register needs to be filled
            if (rd_en_i || !valid_out) begin
                if (!mem_empty) begin
                    data_out <= mem[rd_ptr];
                    rd_ptr <= (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
                    valid_out <= 1'b1;
                end else begin
                    // Clear valid flag if RAM is empty and the last data is being read
                    if (rd_en_i) valid_out <= 1'b0;
                end
            end
        end
    end
endmodule