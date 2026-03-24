`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/21/2026 07:38:17 PM
// Design Name: 
// Module Name: ifbuf
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


module ifbuf #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH = 300,
    parameter K = 8
)(
    input  wire clk,
    input  wire rst_n,
    
    // Giao tiếp Instruction
    input  wire ifbuf_ins_vld_i,
    input  wire [31:0] ifbuf_ins_ifbaddr_i,
    input  wire [8:0]  ifbuf_ins_width_i,
    input  wire [10:0] ifbuf_ins_channel_i,
    input  wire [8:0]  ifbuf_ins_ifsize_i,
    input  wire [10:0] ifbuf_ins_ifblock_i,
    input  wire [10:0] ifbuf_ins_oftiles_i,
    input  wire [10:0] ifbuf_ins_iftiles_i,
    input  wire [8:0]  ifbuf_ins_wp_i,
    input  wire [1:0]  ifbuf_ins_padding_i,
    output wire ifbuf_ins_rdy_o,

    // Tín hiệu DMA
    input  wire ifbuf_dma_rdycfg_i,
    input  wire ifbuf_dma_vld_i,
    input  wire [DATA_WIDTH-1:0] ifbuf_dma_data_i,
    input  wire ifbuf_dma_tlast_i,
    output wire ifbuf_dma_vldcfg_o,
    output reg [8:0]  ifbuf_dma_burst_o, 
    output wire [31:0] ifbuf_dma_baddr_o,
    output  wire ifbuf_dma_rdy_o,

    // Tín hiệu giao tiếp với khối khác
    input  wire ifbuf_ifc_rdy_i,
    output wire ifbuf_ifc_vld_o,
    output wire [K*DATA_WIDTH-1:0] ifbuf_ifc_data_o,
    output wire ifbuf_ifc_end_row_o,
    output wire ifbuf_ifc_end_row_circle_o,
    output wire ifbuf_ifc_end_depth_o,
    output wire ifbuf_ifc_end_layer_o
);

    // ==========================================
    // 1. Latch các thông số Instruction nội bộ của ifbuf 
    // (Các thông số không thuộc về ifbuf_mem)
    // ==========================================
    reg [10:0] ifbuf_ins_oftiles_reg;
    reg [10:0] ifbuf_ins_iftiles_reg;
    reg [8:0]  ifbuf_ins_wp_reg;
    reg [1:0]  ifbuf_ins_padding_reg;
    wire swap_en;

    // ==========================================
    // 2. Instantiate module con ifbuf_mem
    // ==========================================
    reg [31:0] ifbuf_ins_ifbaddr_reg;
    reg [8:0]  ifbuf_ins_width_reg;
    reg [10:0] ifbuf_ins_channel_reg;
    reg [8:0]  ifbuf_ins_ifsize_reg;
    reg [10:0] ifbuf_ins_ifblock_reg;

    // Khai báo các tín hiệu logic nội bộ
    reg         vld_i_reg;
    wire        vld_i_rst;
    reg         vld;
    reg         en_config;
    wire        en_config_rst;
    reg [10:0]  ifblock_count;
    wire        ifblock_count_en;
    reg [8:0]   height_config;
    reg [16:0]  height_width_config;
    wire        height_config_en;
    reg [10:0]  channel_config;
    wire        channel_config_en;  // Bổ sung wire bị thiếu
    reg [31:0]  base_addr_config;
    wire [31:0] base_addr_config_nxt;
    wire [8:0]  width_align;
    wire [K-1:0] wr_en;
    wire [K-1:0] vld_o;
    wire clr;
    wire [K*DATA_WIDTH-1:0] data_o;
    reg [K-1:0] key_ring;
    reg done_prepare;
    reg id;
    wire is_padding_data;
    reg [8:0] count_w_read;
    wire count_w_read_en;
    reg [10:0] count_oftiles_read;
    wire count_oftiles_read_en;
    reg [10:0] count_depth_read;
    wire count_depth_read_en;
    reg [8:0] count_height_read;
    wire count_height_read_en;
    // Phân luồng các Assign logic
    assign channel_config_en    = ifbuf_dma_rdycfg_i && ifbuf_dma_vldcfg_o;
    assign height_config_en     = channel_config_en && (channel_config == ifbuf_ins_channel_reg - 1);
    assign ifblock_count_en     = height_config_en && (height_config == ifbuf_ins_width_reg - 1);
    assign vld_i_rst            = ifblock_count_en && (ifblock_count == ifbuf_ins_ifblock_reg - 1);
    
    assign ifbuf_ins_rdy_o      = !vld_i_reg;
    // assign ifbuf_dma_burst_o    = ifbuf_ins_width_reg;
    
    assign base_addr_config_nxt = (!vld || ifblock_count_en) ? ifbuf_ins_ifbaddr_reg :
                                  ((channel_config == ifbuf_ins_channel_reg - 1) ? 
                                   (ifbuf_ins_ifbaddr_reg + height_width_config + ifbuf_dma_burst_o) : 
                                   (base_addr_config + ifbuf_ins_ifsize_reg));
                                  
    assign en_config_rst        = channel_config_en && ((&channel_config[2:0]) || (channel_config == ifbuf_ins_channel_reg - 1));

    // Đẩy giá trị nội bộ ra Output
    assign ifbuf_dma_baddr_o   = base_addr_config;
    assign ifbuf_dma_vldcfg_o     = vld && en_config;
    assign width_align        = ifbuf_ins_width_reg + ifbuf_ins_width_reg[0];

    always @(posedge clk) begin
        if (ifbuf_ins_vld_i && ifbuf_ins_rdy_o) begin
            ifbuf_ins_oftiles_reg <= ifbuf_ins_oftiles_i;
            ifbuf_ins_iftiles_reg <= ifbuf_ins_iftiles_i;
            ifbuf_ins_wp_reg      <= ifbuf_ins_wp_i;
            ifbuf_ins_padding_reg <= ifbuf_ins_padding_i;
        end
    end

    always @(posedge clk) begin
        ifbuf_dma_burst_o <= width_align;
        if(ifbuf_ins_vld_i && ifbuf_ins_rdy_o) begin
            ifbuf_ins_ifbaddr_reg <= ifbuf_ins_ifbaddr_i;
            ifbuf_ins_width_reg  <= ifbuf_ins_width_i;
            ifbuf_ins_channel_reg <= ifbuf_ins_channel_i;
            ifbuf_ins_ifsize_reg  <= ifbuf_ins_ifsize_i;
            ifbuf_ins_ifblock_reg <= ifbuf_ins_ifblock_i;
        end
    end

    // Khối Valid Input Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vld_i_reg <= 0;
        end else begin
            if (vld_i_rst) begin
                vld_i_reg <= 0;
            end else if (ifbuf_ins_vld_i) begin
                vld_i_reg <= 1;
            end
        end 
    end

    // Khối Valid Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vld <= 0;
        end else begin
            if (vld_i_rst) begin
                vld <= 0;
            end else begin
                vld <= vld_i_reg;
            end
        end 
    end

    // Khối cấu hình Base Address
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            base_addr_config <= 32'd0;
        end else begin
            if (!vld || channel_config_en) begin
                base_addr_config <= base_addr_config_nxt;
            end
        end 
    end

    // Khối đếm Channel
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            channel_config <= 0;
        end else if (channel_config_en) begin
            channel_config <= (channel_config == ifbuf_ins_channel_reg - 1) ? 0 : channel_config + 1;
        end 
    end

    // Khối đếm Height
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            height_config <= 0;
            height_width_config <= 0;
        end else if (height_config_en) begin
            height_config <= (height_config == ifbuf_ins_width_reg - 1) ? 0 : height_config + 1;
            height_width_config <= (height_config == ifbuf_ins_width_reg - 1) ? 0 : height_width_config + ifbuf_dma_burst_o;
        end 
    end

    // Khối đếm Block
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ifblock_count <= 0;
        end else if (ifblock_count_en) begin
            ifblock_count <= (ifblock_count == ifbuf_ins_ifblock_reg - 1) ? 0 : ifblock_count + 1;
        end 
    end

    // Khối Enable Config
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_config <= 1;
        end else begin
            if (en_config_rst) begin
                en_config <= 0;
            end else if(swap_en) en_config <= 1;
        end
    end

    // ==========================================
    // 3. Khối FIFO và logic sinh tự động (Giữ nguyên của bạn)
    // ==========================================
    
    assign clr = count_depth_read_en;
    assign ifbuf_ifc_vld_o = vld_o[0];
    assign swap_en = done_prepare && (!vld_o[0] || clr);
    assign ifbuf_dma_rdy_o = !done_prepare;
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
          done_prepare <= 0;
      end else begin
        if(swap_en) done_prepare <= 0;
        else if (ifbuf_dma_tlast_i && !en_config) begin
          done_prepare <= 1;
        end
      end 
    end
    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
          id <= 0;
      end else begin
        if(swap_en) id <= !id;
      end 
    end

    genvar i;
    generate
        for (i = 0; i < K; i = i + 1) begin : fifo_array
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                key_ring[i] <= (i == 0) ? 1'b1 : 1'b0;
            end else begin
                if (swap_en) begin
                    key_ring[i] <= (i == 0) ? 1'b1 : 1'b0;
                end else if(ifbuf_dma_tlast_i) begin
                    key_ring[i] <= (i == 0) ? key_ring[K - 1] : key_ring[i - 1];
                end
            end
        end
            ping_pong_circle_fifo #(
                .WIDTH(DATA_WIDTH),
                .DEPTH(DEPTH)
            ) fifo_inst (
                .clk    (clk),
                .rst_n  (rst_n),
                .id_i   (id), // Cần khai báo 'id'
                .wr_en  (wr_en[i]),
                .rd_en  (count_w_read_en && !is_padding_data),
                .clr_i  (clr), // Cần khai báo
                .data_i (ifbuf_dma_data_i),
                .data_o (data_o[i*DATA_WIDTH +: DATA_WIDTH]),
                .vld_o  (vld_o[i])
            );
        end
    endgenerate
    assign ifbuf_ifc_data_o = is_padding_data ? {(K*DATA_WIDTH){1'b0}} : data_o;
    genvar j;
    generate
        for (j = 0; j < K; j = j + 1) begin : wr_en_array
            assign wr_en[j] = ifbuf_dma_vld_i && (!ifbuf_dma_tlast_i || !ifbuf_ins_width_reg[0]) && key_ring[j]; 
        end
    endgenerate
    
    assign is_padding_data = count_w_read < ifbuf_ins_padding_reg || count_w_read >= ifbuf_ins_width_reg + ifbuf_ins_padding_reg;
    assign count_w_read_en = ifbuf_ifc_rdy_i && ifbuf_ifc_vld_o;
    assign count_oftiles_read_en = count_w_read_en && (count_w_read == ifbuf_ins_wp_reg);
    assign count_depth_read_en   = count_oftiles_read_en && (count_oftiles_read == ifbuf_ins_oftiles_reg - 1);
    assign count_height_read_en  = count_depth_read_en && (count_depth_read == ifbuf_ins_iftiles_reg - 1);

    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
          count_w_read <= 9'b0;
      end else if(count_w_read_en) begin
          count_w_read <= (count_w_read == ifbuf_ins_wp_reg) ? 9'b0 : count_w_read + 1;
      end 
    end

    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
          count_oftiles_read <= 11'b0;
      end else if(count_oftiles_read_en) begin
          count_oftiles_read <= (count_oftiles_read == ifbuf_ins_oftiles_reg - 1) ? 11'b0 : count_oftiles_read + 1;
      end
    end

    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
          count_depth_read <= 11'b0;
      end else if(count_depth_read_en) begin
          count_depth_read <= (count_depth_read == ifbuf_ins_iftiles_reg - 1) ? 11'b0 : count_depth_read + 1;
      end
    end

    always @(posedge clk or negedge rst_n) begin
      if(!rst_n) begin
          count_height_read <= 9'b0;
      end else if(count_height_read_en) begin
          count_height_read <= (count_height_read == ifbuf_ins_width_reg - 1) ? 9'b0 : count_height_read + 1;
      end
    end
    assign ifbuf_ifc_end_row_o = (count_w_read == ifbuf_ins_wp_reg);
    assign ifbuf_ifc_end_row_circle_o = ifbuf_ifc_end_row_o && (count_oftiles_read == ifbuf_ins_oftiles_reg - 1);
    assign ifbuf_ifc_end_depth_o = ifbuf_ifc_end_row_circle_o && (count_depth_read == ifbuf_ins_iftiles_reg - 1);
    assign ifbuf_ifc_end_layer_o = ifbuf_ifc_end_depth_o && (count_height_read == ifbuf_ins_width_reg - 1);
endmodule
