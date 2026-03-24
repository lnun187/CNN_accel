`timescale 1ns / 1ps

module circle_fifo_bram #(
    parameter WIDTH = 8,
    parameter DEPTH = 300
)(
    input  wire clk,
    input  wire rst_n,
    input  wire wr_en,
    input  wire rd_en,
    input  wire clr,
    input  wire [WIDTH-1:0] din,
    output wire [WIDTH-1:0] dout,
    
    output wire full,
    output wire vld_o
);

    // ==========================================
    // 1. TÍN HIỆU VÀ THANH GHI NỘI BỘ
    // ==========================================
    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;
    reg [WIDTH-1:0] data_o;
    
    reg valid_out; 
    reg mem_empty;

    // Tính toán con trỏ kế tiếp (giữ nguyên tối ưu logic của bạn)
    wire [$clog2(DEPTH)-1:0] next_wr_ptr = (wr_ptr == DEPTH-1) ? 0 : wr_ptr + 1;
    wire [$clog2(DEPTH)-1:0] next_rd_ptr = (rd_ptr == DEPTH-1) ? 0 : rd_ptr + 1;
    
    assign full  = (next_wr_ptr == rd_ptr);
    assign vld_o = valid_out;
    assign dout  = {WIDTH{valid_out}} & data_o;

    // ==========================================
    // 2. KHỐI DATA PATH: BRAM MẪU CHUẨN (ÉP SYNTHESIS TOOL)
    // ==========================================
    // Dùng Attribute ram_style để ra lệnh bắt buộc tạo Block RAM
    (* ram_style = "block" *) reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [WIDTH-1:0] bram_dout;

    // Rút gọn điều kiện Đọc/Ghi thành các tín hiệu rành mạch
    wire ram_we = !clr && ((wr_en && !full && valid_out) || (rd_en && valid_out));
    wire [WIDTH-1:0] ram_din = (wr_en && !full && valid_out) ? din : data_o;
    
    // ĐỂ GIỮ TIMING FWFT: Ta cần dự đoán (prefetch) địa chỉ đọc tiếp theo
    wire [$clog2(DEPTH)-1:0] bram_rd_addr = (rd_en && valid_out) ? next_rd_ptr : rd_ptr;

    // Block BRAM cực kỳ sạch sẽ - Cấu hình WRITE_FIRST (Read Through)
    always @(posedge clk) begin
        if (ram_we) begin
            mem[wr_ptr] <= ram_din;
        end
        
        // Logic bypass chuẩn giúp tool hiểu đây là BRAM có thuộc tính Write-First
        if (ram_we && (wr_ptr == bram_rd_addr)) begin
            bram_dout <= ram_din;
        end else begin
            bram_dout <= mem[bram_rd_addr];
        end
    end

    // ==========================================
    // 3. KHỐI CONTROL LOGIC (Reset bất đồng bộ)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr    <= 0;
            rd_ptr    <= 0;
            valid_out <= 0;
            mem_empty <= 1'b1;
        end else begin
            if (clr) begin
                rd_ptr    <= wr_ptr;
                valid_out <= 0;
                mem_empty <= 1'b1;
            end else begin
                // Write Priority Logic (Nguyên bản của bạn)
                if (wr_en && !full) begin
                    if (!valid_out) begin 
                        valid_out <= 1'b1;
                    end else begin
                        wr_ptr    <= next_wr_ptr;
                        mem_empty <= 1'b0; 
                    end
                end
                // Circular Read Logic (Ghi ngược lại data khi pop)
                else if (rd_en && valid_out) begin
                    wr_ptr <= next_wr_ptr;
                    rd_ptr <= next_rd_ptr;
                end
            end
        end
    end

    // ==========================================
    // 4. KHỐI DATA PATH: Thanh ghi Output (FWFT Head)
    // ==========================================
    always @(posedge clk) begin
        if (!clr) begin
            if (wr_en && !full && !valid_out) begin
                data_o <= din;
            end
            else if (rd_en && valid_out && !mem_empty) begin
                // Lấy data đã được BRAM prefetch sẵn từ cycle trước
                data_o <= bram_dout;
            end
        end
    end

endmodule