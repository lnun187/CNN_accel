`timescale 1ns / 1ps

module fifo #(
    parameter WIDTH = 8,
    parameter DEPTH = 16
)(
    input                  clk,
    input                  rst_n,
    input                  wr_en,
    input                  rd_en,
    input                  clr,
    input  [3:0]           ins_hf_i, // Port này giữ nguyên theo interface của bạn (hiện chưa dùng tới)
    input  [WIDTH-1:0]     din,
    input  [WIDTH-1:0]     zp,
    output [WIDTH-1:0]     dout,
    output wire            full,
    output wire            vld_o,
    output wire            end_data
);

    // Tính toán số bit cần thiết cho con trỏ (pointer)
    localparam ADDR_W = $clog2(DEPTH);

    // Khai báo bộ nhớ
    // Cố ý không dùng pragma BRAM vì cấu trúc đọc tổ hợp (combinatorial read)
    reg [WIDTH-1:0] mem [0:DEPTH-1];

    // Khai báo con trỏ và biến đếm
    reg [ADDR_W-1:0] wr_ptr;
    reg [ADDR_W-1:0] rd_ptr;
    reg [ADDR_W:0]   count;  // Biến đếm cần nhiều hơn 1 bit để đếm đến DEPTH

    // Các cờ trạng thái nội bộ
    wire empty = (count == 0);
    assign full  = (count == DEPTH);

    // Điều kiện thực thi đọc/ghi
    wire do_write = wr_en && !full;
    wire do_read  = rd_en && !empty;

    // =========================================================
    // CONTROL: Quản lý Pointers và Count
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {ADDR_W{1'b0}};
            rd_ptr <= {ADDR_W{1'b0}};
            count  <= 0;
        end else if (clr) begin
            wr_ptr <= {ADDR_W{1'b0}};
            rd_ptr <= {ADDR_W{1'b0}};
            count  <= 0;
        end else begin
            // Cập nhật Write Pointer
            if (do_write) begin
                wr_ptr <= (wr_ptr == DEPTH - 1) ? {ADDR_W{1'b0}} : wr_ptr + 1'b1;
            end
            
            // Cập nhật Read Pointer
            if (do_read) begin
                rd_ptr <= (rd_ptr == DEPTH - 1) ? {ADDR_W{1'b0}} : rd_ptr + 1'b1;
            end
            
            // Cập nhật Count (Số lượng data đang có trong FIFO)
            case ({do_write, do_read})
                2'b10: count <= count + 1'b1; // Chỉ ghi
                2'b01: count <= count - 1'b1; // Chỉ đọc
                default: count <= count;      // Ghi đọc đồng thời hoặc không làm gì
            endcase
        end
    end

    // =========================================================
    // DATA PATH: Ghi vào RAM
    // =========================================================
    always @(posedge clk) begin
        if (do_write) begin
            mem[wr_ptr] <= din;
        end
    end

    // =========================================================
    // OUTPUT ASSIGNMENTS
    // =========================================================
    
    // Xuất trực tiếp dữ liệu theo đúng yêu cầu
    assign dout = vld_o ? mem[rd_ptr] : zp;
    
    // Dữ liệu hợp lệ khi FIFO không rỗng
    assign vld_o = !empty;
    
    // end_data: Báo hiệu đây là data cuối cùng trong FIFO (chỉ còn 1 phần tử)
    assign end_data = (count == 1);

endmodule