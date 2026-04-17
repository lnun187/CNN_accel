`timescale 1ns / 1ps

module fifo_bram_zp #(
    parameter WIDTH = 8,
    parameter DEPTH = 224 * 12
)(
    input clk,
    input rst_n,
    input wr_en,
    input rd_en,
    input clr,
    input [WIDTH-1:0] din,
    input [WIDTH-1:0] zp,
    output [WIDTH-1:0] dout,
  
    output wire full,
    output wire vld_o,
    output wire end_data
);

    reg [WIDTH-1:0] mem_zp [0:DEPTH-1];
    
    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    
    // Flag indicating if data_out holds valid pre-fetched data
    reg valid_out; 
    
    // --- CÁC TÍN HIỆU MỚI ĐỂ TÁCH BRAM VÀ BYPASS LOGIC ---
    wire [WIDTH-1:0] data_out;
    reg  [WIDTH-1:0] data_out_ram;
    reg  [WIDTH-1:0] data_out_bypass;
    reg  use_bypass;
    // -----------------------------------------------------

    // Tối ưu các phép toán tính địa chỉ tiếp theo
    wire [$clog2(DEPTH)-1:0] next_wr_ptr = (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
    wire [$clog2(DEPTH)-1:0] next_rd_ptr = (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;

    // Internal RAM empty condition
    wire mem_zp_empty = (wr_ptr == rd_ptr);

    assign full     = (next_wr_ptr == rd_ptr);
    assign vld_o    = valid_out; 
    assign end_data = valid_out && mem_zp_empty;
    
    // MUX chọn nguồn dữ liệu ra cho FWFT
    assign data_out = use_bypass ? data_out_bypass : data_out_ram;
    assign dout     = valid_out ? data_out : zp;

    // ==========================================
    // KHỐI CONTROL LOGIC (Giữ nguyên gốc của bạn)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;
            valid_out <= 0;
        end else begin
            if (clr) begin
                wr_ptr    <= 0;
                rd_ptr    <= 0;
                valid_out <= 0;
            end else begin
                // 1. Write Pointer Logic
                if (wr_en && !full) begin
                    wr_ptr <= next_wr_ptr;
                end

                // 2. FWFT Read, Prefetch & BYPASS Control Logic
                if (rd_en || !valid_out) begin
                    if (!mem_zp_empty) begin
                        rd_ptr    <= next_rd_ptr;
                        valid_out <= 1'b1;
                    end else if (wr_en && !full) begin
                        rd_ptr    <= next_rd_ptr;
                        valid_out <= 1'b1;
                    end else if (rd_en) begin
                        valid_out <= 1'b0;
                    end
                end
            end
        end
    end

    // ==========================================
    // KHỐI DATA PATH 1: PURE BRAM INFERENCE
    // ==========================================
    always @(posedge clk) begin
        // Ghi vào BRAM
        if (wr_en && !full) begin
            mem_zp[wr_ptr] <= din;
        end
        
        // Đọc từ BRAM: Sạch sẽ, không dính logic điều kiện phức tạp của Bypass
        if ((rd_en || !valid_out) && !mem_zp_empty) begin
            data_out_ram <= mem_zp[rd_ptr];
        end
    end

    // ==========================================
    // KHỐI DATA PATH 2: BYPASS LOGIC (Nằm ngoài BRAM)
    // ==========================================
    always @(posedge clk) begin
        // Lưu trữ dữ liệu ngõ vào khi rơi vào trường hợp Bypass
        if ((rd_en || !valid_out) && mem_zp_empty && (wr_en && !full)) begin
            data_out_bypass <= din; 
        end
    end

    // Thanh ghi cờ xác định xem ta đang xuất data từ RAM hay từ bộ Bypass
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            use_bypass <= 1'b0;
        end else if (clr) begin
            use_bypass <= 1'b0;
        end else if (rd_en || !valid_out) begin
            if (!mem_zp_empty) begin
                use_bypass <= 1'b0; // FIFO có data -> dùng RAM
            end else if (wr_en && !full) begin
                use_bypass <= 1'b1; // FIFO rỗng nhưng đang ghi -> Bypass
            end
        end
    end

endmodule