`timescale 1ns / 1ps

module fifo_bram_3stage #(
    parameter WIDTH = 8,
    parameter DEPTH = 224 * 12
)(
    input                  clk,
    input                  rst_n,
    input                  wr_en,
    input                  rd_en,
    input                  clr,
    input  [WIDTH-1:0]     din,
    output [WIDTH-1:0]     dout,
    output wire            full,
    output wire            vld_o,
    output wire            end_data
);

    // Ép Synthesizer sử dụng Block RAM
    (* ram_style = "block" *) reg [WIDTH-1:0] mem [0:DEPTH-1];

    reg [$clog2(DEPTH)-1:0] wr_ptr, rd_ptr;

    // =========================================================
    // SỬA ĐỔI STAGE GIỮA: Tách RAM data và bypass logic
    // =========================================================
    reg [WIDTH-1:0] ram_dout;      // Thanh ghi đọc RAM chuẩn (không reset)
    reg             mid_vld;
    reg             mid_is_bypass; // Cờ nhớ xem data ở mid đến từ đâu

    // mid_data giờ là tổ hợp (combinational) nhưng vẫn giữ đúng timing pipeline
     reg [WIDTH-1:0] bypass_data_ff;
    wire [WIDTH-1:0] mid_data = mid_is_bypass ? bypass_data_ff : ram_dout;

    // Stage cuối: output visible ra ngoài module.
    reg [WIDTH-1:0] out_data_r;
    reg             out_vld_r;

    // FF cho bypass-enable để fix timing.
    reg             bypass_req_ff;
   

    wire [$clog2(DEPTH)-1:0] next_wr_ptr = (wr_ptr == DEPTH-1) ? {($clog2(DEPTH)){1'b0}} : (wr_ptr + 1'b1);
    wire [$clog2(DEPTH)-1:0] next_rd_ptr = (rd_ptr == DEPTH-1) ? {($clog2(DEPTH)){1'b0}} : (rd_ptr + 1'b1);

    wire mem_empty = (wr_ptr == rd_ptr);
    assign full = (next_wr_ptr == rd_ptr);

    wire do_write = wr_en && !full;

    // Consumer pop ở stage cuối.
    wire out_pop = rd_en && out_vld_r;

    // Chuyển mid -> out khi out trống hoặc đang bị consume.
    wire mid_to_out = mid_vld && (!out_vld_r || out_pop);

    // mid có thể nhận thêm data mới nếu hiện đang trống, hoặc
    // nếu word hiện tại của mid sẽ được đẩy sang out ngay chu kỳ này.
    // bypass_req_ff là 1 nghĩa là chu kỳ này mid sẽ được fill bởi bypass pending,
    // nên không được fetch thêm từ RAM / bypass nữa.
    wire mid_can_take_new = (!mid_vld && !bypass_req_ff) || mid_to_out;

    // Quyết định lấy word mới cho mid.
    wire ram_fetch    = mid_can_take_new && !mem_empty;
    wire bypass_fetch = mid_can_take_new && mem_empty && do_write;

    // =========================================================
    // CONTROL: cập nhật con trỏ RAM
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= {($clog2(DEPTH)){1'b0}};
            rd_ptr <= {($clog2(DEPTH)){1'b0}};
        end else if (clr) begin
            wr_ptr <= {($clog2(DEPTH)){1'b0}};
            rd_ptr <= {($clog2(DEPTH)){1'b0}};
        end else begin
            if (do_write) begin
                wr_ptr <= next_wr_ptr;
            end
            if (ram_fetch || bypass_fetch) begin
                rd_ptr <= next_rd_ptr;
            end
        end
    end

    // =========================================================
    // RAM READ / WRITE (Đảm bảo BRAM inference)
    // =========================================================
    always @(posedge clk) begin
        if (do_write) begin
            mem[wr_ptr] <= din;
        end
        
        // Đọc đồng bộ thuần túy, KHÔNG reset, KHÔNG logic phụ
        if (ram_fetch) begin
            ram_dout <= mem[rd_ptr];
        end
    end

    // =========================================================
    // Pending bypass FF: enable logic được flop hóa ở đây để fix timing
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bypass_req_ff  <= 1'b0;
            bypass_data_ff <= {WIDTH{1'b0}};
        end else if (clr) begin
            bypass_req_ff  <= 1'b0;
            bypass_data_ff <= {WIDTH{1'b0}};
        end else begin
            bypass_req_ff <= bypass_fetch;
            if (bypass_fetch) begin
                bypass_data_ff <= din;
            end
        end
    end

    // =========================================================
    // MID STAGE CONTROL (Chỉ quản lý cờ Valid và cờ Bypass)
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mid_vld       <= 1'b0;
            mid_is_bypass <= 1'b0;
        end else if (clr) begin
            mid_vld       <= 1'b0;
            mid_is_bypass <= 1'b0;
        end else begin
            if (bypass_req_ff) begin
                mid_vld       <= 1'b1;
                mid_is_bypass <= 1'b1;
            end else if (ram_fetch) begin
                mid_vld       <= 1'b1;
                mid_is_bypass <= 1'b0;
            end else if (mid_to_out) begin
                mid_vld       <= 1'b0;
            end
        end
    end

    // =========================================================
    // OUTPUT STAGE
    // =========================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_data_r <= {WIDTH{1'b0}};
            out_vld_r  <= 1'b0;
        end else if (clr) begin
            out_data_r <= {WIDTH{1'b0}};
            out_vld_r  <= 1'b0;
        end else begin
            if (mid_to_out) begin
                out_data_r <= mid_data;
                out_vld_r  <= 1'b1;
            end else if (out_pop) begin
                out_vld_r  <= 1'b0;
            end
        end
    end

    assign dout     = out_vld_r ? out_data_r : {WIDTH{1'b0}};
    assign vld_o    = out_vld_r;
    // Word ở output là word cuối khi phía sau nó không còn gì nữa
    assign end_data = out_vld_r && !mid_vld && !bypass_req_ff && mem_empty;

endmodule