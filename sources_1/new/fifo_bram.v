`timescale 1ns / 1ps

module fifo_bram #(
    parameter WIDTH = 8,
    parameter DEPTH = 224 * 12
)(
    input               clk,
    input               rst_n,
    input               wr_en,
    input               rd_en,
    input               clr,
    input   [WIDTH-1:0] din,
    output  [WIDTH-1:0] dout,
    output              full,
    output              vld_o,
    output              end_data
);

    // Thêm attribute để báo cho Synthesizer ép mảng này vào Block RAM
    (* ram_style = "block" *) 
    reg [WIDTH-1:0]         mem [0:DEPTH-1];
    
    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    
    // Flag indicating if data_out holds valid pre-fetched data
    reg                     valid_out;
    
    // --- CÁC TÍN HIỆU MỚI ĐỂ TÁCH BRAM VÀ BYPASS LOGIC ---
    wire [WIDTH-1:0]        data_out;
    reg  [WIDTH-1:0]        data_out_ram;
    reg  [WIDTH-1:0]        data_out_bypass;
    reg                     use_bypass;
    // -----------------------------------------------------

    // Tối ưu các phép toán tính địa chỉ tiếp theo
    wire [$clog2(DEPTH)-1:0] next_wr_ptr;
    wire [$clog2(DEPTH)-1:0] next_rd_ptr;
    wire mem_empty;

    assign next_wr_ptr = (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
    assign next_rd_ptr = (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
    
    // Internal RAM empty condition
    assign mem_empty = (wr_ptr == rd_ptr);
    assign full     = (next_wr_ptr == rd_ptr);
    assign vld_o    = valid_out;
    assign end_data = valid_out && mem_empty;
    
    // MUX chọn nguồn dữ liệu ra cho FWFT
    assign data_out = use_bypass ? data_out_bypass : data_out_ram;
    assign dout     = vld_o ? data_out : {WIDTH{1'b0}};

    // ==========================================
    // KHỐI CONTROL LOGIC (Giữ nguyên gốc)
    // ==========================================
    always @(posedge clk) begin
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
                    if (!mem_empty) begin
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
    // KHỐI DATA PATH 1: PURE BRAM INFERENCE (ĐÃ SỬA)
    // ==========================================
    // Tách các tín hiệu enable ra để Code rõ ràng hơn cho Synthesizer
    wire ram_we = wr_en && !full;
    wire ram_re = (rd_en || !valid_out) && !mem_empty;

    // Block 1: Chuyên xử lý việc ghi (Port A)
    always @(posedge clk) begin
        if (ram_we) begin
            mem[wr_ptr] <= din;
        end
    end

    // Block 2: Chuyên xử lý việc đọc (Port B)
    // Synthesizer sẽ nhận diện `data_out_ram` chính là ngõ ra của BRAM
    always @(posedge clk) begin
        if (ram_re) begin
            data_out_ram <= mem[rd_ptr];
        end
    end

    // ==========================================
    // KHỐI DATA PATH 2: BYPASS LOGIC (Giữ nguyên gốc)
    // ==========================================
    always @(posedge clk) begin
        // Lưu trữ dữ liệu ngõ vào khi rơi vào trường hợp Bypass
        if ((rd_en || !valid_out) && mem_empty && (wr_en && !full)) begin
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
            if (!mem_empty) begin
                use_bypass <= 1'b0; // FIFO có data -> dùng RAM
            end else if (wr_en && !full) begin
                use_bypass <= 1'b1; // FIFO rỗng nhưng đang ghi -> Bypass
            end
        end
    end

endmodule