`timescale 1ns / 1ps

module ifmap_cache #(
    parameter DATA_WIDTH = 8,        
    parameter FIFO_DEPTH = 12,
    parameter K = 7
)(
    input wire clk,
    input wire rst_n,              
    input wire [3:0] ifc_ins_hf_i,
    input wire [1:0] ifc_ins_stride_i,
    input wire [K*DATA_WIDTH-1:0] ifc_ifbuf_data_i,
    input wire ifc_ifbuf_tlast_i,
    input wire ifc_ifbuf_end_row_circle_i,
    input wire ifc_ifbuf_end_depth_i,
    input wire ifc_ifbuf_end_layer_i,
    input wire ifc_ifbuf_vld_i,
    output reg ifc_ifbuf_rdy_o,  // Đã đổi thành reg (Flip-Flop)
    
    input wire ifc_pu_rdy_i,
    output wire ifc_pu_vld_o,    
    output wire [K*DATA_WIDTH - 1:0] ifc_pu_data_o,
    output wire ifc_pu_end_row_o,
    output wire ifc_pu_end_row_circle_o,
    output wire ifc_pu_end_depth_o,
    output wire ifc_pu_end_layer_o
);

    // ==========================================
    // Khai báo tín hiệu nội bộ
    // ==========================================
    reg [3:0] prefill_cnt; 
    reg [3:0] window_cnt;  
    reg is_begin;
    wire [K*DATA_WIDTH + 3:0] fifo_dout;
    wire fifo_wr_en;
    wire [K*DATA_WIDTH + 3:0] fifo_din;
    wire window_active;              
    wire [K*DATA_WIDTH + 3:0] combined_data_in;
    
    // Các tín hiệu Look-ahead
    wire [3:0] prefill_cnt_nxt;
    wire [3:0] window_cnt_nxt;
    wire window_active_nxt;
    
    assign combined_data_in = {ifc_ifbuf_tlast_i, ifc_ifbuf_end_row_circle_i, ifc_ifbuf_end_depth_i, ifc_ifbuf_end_layer_i, ifc_ifbuf_data_i};
    assign window_active = (prefill_cnt == (|(ifc_ins_hf_i - ifc_ins_stride_i) ? (ifc_ins_hf_i - ifc_ins_stride_i) : 1));

    // ==========================================
    // 1. Logic Look-ahead (Tính toán chu kỳ tiếp theo)
    // ==========================================
    assign prefill_cnt_nxt = (ifc_ifbuf_tlast_i == 1'b1) ? 4'd0 :
                             (!window_active && ifc_ifbuf_vld_i && ifc_ifbuf_rdy_o) ? prefill_cnt + 1'b1 :
                             prefill_cnt;

    assign window_active_nxt = (prefill_cnt_nxt == (|(ifc_ins_hf_i - ifc_ins_stride_i) ? (ifc_ins_hf_i - ifc_ins_stride_i) : 1));

    assign fifo_wr_en = ((prefill_cnt < (ifc_ins_hf_i - ifc_ins_stride_i)) && ifc_ifbuf_vld_i) || 
                        (window_active && ifc_pu_rdy_i);

    assign window_cnt_nxt = (ifc_ifbuf_tlast_i == 1'b1) ? 4'd0 :
                            (window_active && fifo_wr_en) ? 
                                ((window_cnt == ifc_ins_hf_i - 1) ? 4'd0 : window_cnt + 1'b1) :
                            window_cnt;

    // ==========================================
    // 2. Cập nhật thanh ghi đồng bộ (Dùng tín hiệu _nxt)
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            prefill_cnt <= 0;
            window_cnt  <= 0;
            ifc_ifbuf_rdy_o <= 1'b0; // Hoặc 1'b1 tùy thuộc vào trạng thái init thiết kế của bạn
        end else begin
            // Cập nhật counter
            prefill_cnt <= prefill_cnt_nxt;
            window_cnt  <= window_cnt_nxt;
            
            // Tính trước và chốt ready cho chu kỳ tới
            ifc_ifbuf_rdy_o <= (prefill_cnt_nxt < (ifc_ins_hf_i - ifc_ins_stride_i)) || 
                               (window_active_nxt && (window_cnt_nxt < ifc_ins_stride_i) && ifc_pu_rdy_i);
        end
    end

    // ==========================================
    // 3. Logic của thanh ghi đếm 'is_begin'
    // ==========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_begin <= 0;
        end else begin
            if ((prefill_cnt == (|(ifc_ins_hf_i - ifc_ins_stride_i) ? (ifc_ins_hf_i - ifc_ins_stride_i - 1) : 0)) && ifc_ifbuf_vld_i && ifc_ifbuf_rdy_o) begin
                is_begin <= 1;
            end else if(fifo_dout[K*DATA_WIDTH + 3] && ifc_pu_rdy_i && ifc_pu_vld_o) begin
                is_begin <= window_active;
            end
        end
    end

    // ==========================================
    // 4. Các tín hiệu ngõ ra khác
    // ==========================================
    assign fifo_din = (window_active && (window_cnt >= ifc_ins_stride_i)) ? fifo_dout : combined_data_in;
    
    assign ifc_pu_data_o = fifo_dout[K*DATA_WIDTH - 1 : 0];
    assign ifc_pu_end_layer_o      = fifo_dout[K*DATA_WIDTH];
    assign ifc_pu_end_depth_o      = fifo_dout[K*DATA_WIDTH + 1];
    assign ifc_pu_end_row_circle_o = fifo_dout[K*DATA_WIDTH + 2];
    assign ifc_pu_end_row_o = fifo_dout[K*DATA_WIDTH + 3];
    
    assign ifc_pu_vld_o = is_begin;
    
    fifo_bram #(
        .WIDTH(K*DATA_WIDTH + 4),
        .DEPTH(FIFO_DEPTH)
    ) fifo_uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(fifo_wr_en),
        .rd_en(ifc_pu_rdy_i && ifc_pu_vld_o),
        .clr(1'b0),
        .din(fifo_din),
        .dout(fifo_dout),
        .full(),
        .vld_o(),
        .end_data()
    );

endmodule