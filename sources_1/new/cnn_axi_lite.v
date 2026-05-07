`timescale 1ns / 1ps

module cnn_axi_lite #(
    parameter NUM_MASTERS      = 1,
    parameter ADDR_WIDTH       = 32,
    parameter DATA_WIDTH       = 32,
    parameter TRANS_W_STRB_W   = 4,
    parameter TRANS_WR_RESP_W  = 2,
    parameter TRANS_PROT       = 3,
    parameter CYCLE_CLOCK      = 2,

    // CNN_accel parameters
    parameter CNN_DATA_WIDTH   = 8,
    parameter ACC_WIDTH        = 32,
    parameter IFBUF_DEPTH      = 300,
    parameter FLTBUF_DEPTH     = 2304,
    parameter COMP_DEPTH       = 12,
    parameter FIFO_DEPTH       = 12,
    parameter OFBUF_DEPTH      = 896,
    parameter K                = 8,
    parameter M                = 2,
    parameter PE_PER_PU        = 12,
    parameter PPDEPTH          = 640,
    parameter BURSTL_IFMAP     = 8,
    parameter BURSTL_FILTER    = 10,
    parameter BURSTL_BIAS      = 5,
    parameter BURSTL_OFMAP     = 8,

    // Register map
    parameter [ADDR_WIDTH-1:0] ADDR_START             = 32'h0200_3000,
    parameter [ADDR_WIDTH-1:0] ADDR_WRITE_FIFO        = 32'h0200_3064,
    parameter [ADDR_WIDTH-1:0] ADDR_STATUS            = 32'h0200_3004,
    parameter [ADDR_WIDTH-1:0] ADDR_IFHEIGHT          = 32'h0200_3008,
    parameter [ADDR_WIDTH-1:0] ADDR_IFCHANNEL         = 32'h0200_300C,
    parameter [ADDR_WIDTH-1:0] ADDR_OFCHANNEL         = 32'h0200_3010,
    parameter [ADDR_WIDTH-1:0] ADDR_HF                = 32'h0200_3014,
    parameter [ADDR_WIDTH-1:0] ADDR_STRIDE            = 32'h0200_3018,
    parameter [ADDR_WIDTH-1:0] ADDR_PADDING           = 32'h0200_301C,
    parameter [ADDR_WIDTH-1:0] ADDR_IFPARR            = 32'h0200_3020,
    parameter [ADDR_WIDTH-1:0] ADDR_OFTILE            = 32'h0200_3024,
    parameter [ADDR_WIDTH-1:0] ADDR_OFPARR            = 32'h0200_3028,
    parameter [ADDR_WIDTH-1:0] ADDR_IFBADDR           = 32'h0200_302C,
    parameter [ADDR_WIDTH-1:0] ADDR_FLTBADDR          = 32'h0200_3030,
    parameter [ADDR_WIDTH-1:0] ADDR_BIAS_BADDR        = 32'h0200_3034,
    parameter [ADDR_WIDTH-1:0] ADDR_OFBADDR           = 32'h0200_3038,
    parameter [ADDR_WIDTH-1:0] ADDR_IFC_ZP            = 32'h0200_303C,
    parameter [ADDR_WIDTH-1:0] ADDR_FLTC_ZP           = 32'h0200_3040,
    parameter [ADDR_WIDTH-1:0] ADDR_MULT              = 32'h0200_3044,
    parameter [ADDR_WIDTH-1:0] ADDR_MULT_SHIFT        = 32'h0200_3048,
    parameter [ADDR_WIDTH-1:0] ADDR_ALPHAMULT         = 32'h0200_304C,
    parameter [ADDR_WIDTH-1:0] ADDR_ALPHAMULT_SHIFT   = 32'h0200_3050,
    parameter [ADDR_WIDTH-1:0] ADDR_ZPY               = 32'h0200_3054,
    parameter [ADDR_WIDTH-1:0] ADDR_QMIN              = 32'h0200_3058,
    parameter [ADDR_WIDTH-1:0] ADDR_QMAX              = 32'h0200_305C,
    parameter [ADDR_WIDTH-1:0] ADDR_IS_LEAKY_RELU     = 32'h0200_3060
)(
    input                               clk,
    input                               resetn,

    // AXI-Lite Write Address Channel
    input       [ADDR_WIDTH-1:0]        i_axi_awaddr,
    input                               i_axi_awvalid,
    output                              o_axi_awready,
    input       [TRANS_PROT-1:0]        i_axi_awprot,

    // AXI-Lite Write Data Channel
    input       [DATA_WIDTH-1:0]        i_axi_wdata,
    input       [TRANS_W_STRB_W-1:0]    i_axi_wstrb,
    input                               i_axi_wvalid,
    output                              o_axi_wready,

    // AXI-Lite Write Response Channel
    output      [TRANS_WR_RESP_W-1:0]   o_axi_bresp,
    output                              o_axi_bvalid,
    input                               i_axi_bready,

    // AXI-Lite Read Address Channel
    input       [ADDR_WIDTH-1:0]        i_axi_araddr,
    input                               i_axi_arvalid,
    output                              o_axi_arready,
    input       [TRANS_PROT-1:0]        i_axi_arprot,

    // AXI-Lite Read Data Channel
    output      [DATA_WIDTH-1:0]        o_axi_rdata,
    output                              o_axi_rvalid,
    output      [TRANS_WR_RESP_W-1:0]   o_axi_rresp,
    input                               i_axi_rready,

    // Interrupt ports: direct, not controlled through AXI-Lite
    output                              irq_accel_done_o,
    input                               eoi_accel_done_i,

    // Optional direct status port
    output                              cnn_cpu_accel_busy_o,

    // IFBUF DMA side
    input                               cnn_ifbuf_dma_rdycfg_i,
    input                               cnn_ifbuf_dma_vld_i,
    input       [CNN_DATA_WIDTH-1:0]    cnn_ifbuf_dma_data_i,
    input                               cnn_ifbuf_dma_tlast_i,
    output                              cnn_ifbuf_dma_vldcfg_o,
    output      [BURSTL_IFMAP-1:0]      cnn_ifbuf_dma_burst_o,
    output      [23:0]                  cnn_ifbuf_dma_baddr_o,
    output                              cnn_ifbuf_dma_rdy_o,

    // FLTBUF DMA side
    input                               cnn_fltbuf_dma_rdycfg_i,
    input                               cnn_fltbuf_dma_vld_i,
    input       [CNN_DATA_WIDTH-1:0]    cnn_fltbuf_dma_data_i,
    input                               cnn_fltbuf_dma_tlast_i,
    output                              cnn_fltbuf_dma_vldcfg_o,
    output      [BURSTL_FILTER-1:0]     cnn_fltbuf_dma_burst_o,
    output      [23:0]                  cnn_fltbuf_dma_baddr_o,
    output                              cnn_fltbuf_dma_rdy_o,

    // BIAS BUF DMA side
    input                               cnn_bias_dma_rdycfg_i,
    output                              cnn_bias_dma_vldcfg_o,
    output      [BURSTL_BIAS-1:0]       cnn_bias_dma_burst_o,
    output      [23:0]                  cnn_bias_dma_baddr_o,
    input                               cnn_bias_dma_vld_i,
    input       [7:0]                   cnn_bias_dma_data_i,
    input                               cnn_bias_dma_tlast_i,
    output                              cnn_bias_dma_rdy_o,

    // OFBUF DMA side
    input                               cnn_ofbuf_dma_rdycfg_i,
    output                              cnn_ofbuf_dma_vldcfg_o,
    output      [BURSTL_OFMAP-1:0]      cnn_ofbuf_dma_burst_o,
    output      [23:0]                  cnn_ofbuf_dma_baddr_o,
    output                              cnn_ofbuf_dma_vld_o,
    output      [CNN_DATA_WIDTH-1:0]    cnn_ofbuf_dma_data_o,
    output                              cnn_ofbuf_dma_tlast_o,
    input                               cnn_ofbuf_dma_rdy_i,

    // Optional debug / status
    output                              cnn_comp_pa_done_compute_o,
    output                              cnn_ifbuf_comp_end_layer_o,
    output                              cnn_ifbuf_comp_end_layer_real_o,
    output                              cnn_fltbuf_comp_donepass_o
);

    // =========================================================
    // Internal AXI-Lite slave signals
    // =========================================================
    wire [ADDR_WIDTH-1:0]       o_addr_w;
    wire [ADDR_WIDTH-1:0]       o_addr_r;
    wire [DATA_WIDTH-1:0]       o_data_w;
    reg  [DATA_WIDTH-1:0]       i_data_r;
    wire [3:0]                  o_wen;
    wire                        o_wr_w;
    wire                        o_rd_r;

    // =========================================================
    // CNN configuration registers
    // =========================================================
    reg                         cnn_table_vld_reg;
    reg                         cnn_cpu_accel_start_reg;

    reg [7:0]                   cnn_table_ifheight_reg;
    reg [10:0]                  cnn_table_ifchannel_reg;
    reg [10:0]                  cnn_table_ofchannel_reg;
    reg [3:0]                   cnn_table_hf_reg;
    reg [2:0]                   cnn_table_stride_reg;
    reg [1:0]                   cnn_table_padding_reg;
    reg [2:0]                   cnn_table_ifparr_reg;
    reg [1:0]                   cnn_table_oftile_reg;
    reg [4:0]                   cnn_table_ofparr_reg;
    reg [23:0]                  cnn_table_ifbaddr_reg;
    reg [23:0]                  cnn_table_fltbaddr_reg;
    reg [23:0]                  cnn_table_bias_baddr_reg;
    reg [23:0]                  cnn_table_ofbaddr_reg;
    reg signed [CNN_DATA_WIDTH-1:0] cnn_table_ifc_zp_reg;
    reg signed [CNN_DATA_WIDTH-1:0] cnn_table_fltc_zp_reg;
    reg signed [31:0]           cnn_table_mult_reg;
    reg [5:0]                   cnn_table_mult_shift_reg;
    reg signed [31:0]           cnn_table_alphamult_reg;
    reg [5:0]                   cnn_table_alphamult_shift_reg;
    reg signed [7:0]            cnn_table_zpy_reg;
    reg signed [7:0]            cnn_table_qmin_reg;
    reg signed [7:0]            cnn_table_qmax_reg;
    reg                         cnn_table_is_leaky_ReLU_reg;

    wire                        cnn_table_rdy_w;

    // =========================================================
    // ADDR_START:
    //   write bit[0] = 1 -> generate 1-cycle cnn_cpu_accel_start_reg pulse
    //
    // ADDR_WRITE_FIFO:
    //   write bit[0] = 1 -> assert cnn_table_vld_reg
    //   cnn_table_vld_reg is cleared when cnn_table_rdy_w = 1
    // =========================================================
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cnn_table_vld_reg           <= 1'b0;
            cnn_cpu_accel_start_reg     <= 1'b0;
            cnn_table_ifheight_reg      <= 8'd0;
            cnn_table_ifchannel_reg     <= 11'd0;
            cnn_table_ofchannel_reg     <= 11'd0;
            cnn_table_hf_reg            <= 4'd0;
            cnn_table_stride_reg        <= 3'd0;
            cnn_table_padding_reg       <= 2'd0;
            cnn_table_ifparr_reg        <= 3'd0;
            cnn_table_oftile_reg        <= 2'd0;
            cnn_table_ofparr_reg        <= 5'd0;
            cnn_table_ifbaddr_reg       <= 24'd0;
            cnn_table_fltbaddr_reg      <= 24'd0;
            cnn_table_bias_baddr_reg    <= 24'd0;
            cnn_table_ofbaddr_reg       <= 24'd0;
            cnn_table_ifc_zp_reg        <= {CNN_DATA_WIDTH{1'b0}};
            cnn_table_fltc_zp_reg       <= {CNN_DATA_WIDTH{1'b0}};
            cnn_table_mult_reg          <= 32'sd0;
            cnn_table_mult_shift_reg    <= 6'd0;
            cnn_table_alphamult_reg     <= 32'sd0;
            cnn_table_alphamult_shift_reg <= 6'd0;
            cnn_table_zpy_reg           <= 8'sd0;
            cnn_table_qmin_reg          <= 8'sd0;
            cnn_table_qmax_reg          <= 8'sd0;
            cnn_table_is_leaky_ReLU_reg <= 1'b0;
        end else begin

            if (o_wr_w && (o_addr_w == ADDR_START) && o_data_w[0]) begin
                cnn_cpu_accel_start_reg <= 1'b1;
            end else cnn_cpu_accel_start_reg <= 1'b0;
            
            if (o_wr_w && (o_addr_w == ADDR_WRITE_FIFO) && o_data_w[0]) begin
                cnn_table_vld_reg <= 1'b1;
            end else if(cnn_table_rdy_w) begin
                cnn_table_vld_reg <= 0;
            end
            if (o_wr_w) begin
                case (o_addr_w)
                    ADDR_IFHEIGHT:        cnn_table_ifheight_reg        <= o_data_w[7:0];
                    ADDR_IFCHANNEL:       cnn_table_ifchannel_reg       <= o_data_w[10:0];
                    ADDR_OFCHANNEL:       cnn_table_ofchannel_reg       <= o_data_w[10:0];
                    ADDR_HF:              cnn_table_hf_reg              <= o_data_w[3:0];
                    ADDR_STRIDE:          cnn_table_stride_reg          <= o_data_w[2:0];
                    ADDR_PADDING:         cnn_table_padding_reg         <= o_data_w[1:0];
                    ADDR_IFPARR:          cnn_table_ifparr_reg          <= o_data_w[2:0];
                    ADDR_OFTILE:          cnn_table_oftile_reg          <= o_data_w[1:0];
                    ADDR_OFPARR:          cnn_table_ofparr_reg          <= o_data_w[4:0];
                    ADDR_IFBADDR:         cnn_table_ifbaddr_reg         <= o_data_w[23:0];
                    ADDR_FLTBADDR:        cnn_table_fltbaddr_reg        <= o_data_w[23:0];
                    ADDR_BIAS_BADDR:      cnn_table_bias_baddr_reg      <= o_data_w[23:0];
                    ADDR_OFBADDR:         cnn_table_ofbaddr_reg         <= o_data_w[23:0];
                    ADDR_IFC_ZP:          cnn_table_ifc_zp_reg          <= o_data_w[CNN_DATA_WIDTH-1:0];
                    ADDR_FLTC_ZP:         cnn_table_fltc_zp_reg         <= o_data_w[CNN_DATA_WIDTH-1:0];
                    ADDR_MULT:            cnn_table_mult_reg            <= o_data_w[31:0];
                    ADDR_MULT_SHIFT:      cnn_table_mult_shift_reg      <= o_data_w[5:0];
                    ADDR_ALPHAMULT:       cnn_table_alphamult_reg       <= o_data_w[31:0];
                    ADDR_ALPHAMULT_SHIFT: cnn_table_alphamult_shift_reg <= o_data_w[5:0];
                    ADDR_ZPY:             cnn_table_zpy_reg             <= o_data_w[7:0];
                    ADDR_QMIN:            cnn_table_qmin_reg            <= o_data_w[7:0];
                    ADDR_QMAX:            cnn_table_qmax_reg            <= o_data_w[7:0];
                    ADDR_IS_LEAKY_RELU:   cnn_table_is_leaky_ReLU_reg   <= o_data_w[0];
                    default: ;
                endcase
            end 
        end
    end

    // =========================================================
    // Read mux
    // STATUS read data:
    //   bit[0] = table_vld pending
    //   bit[1] = table_rdy from CNN
    //   bit[2] = accel_busy from CNN
    //   bit[3] = accel_done interrupt from CNN
    //   bit[4] = accel_start pulse register, mostly for debug
    // =========================================================
    always @(*) begin
        case (o_addr_r)
            ADDR_START:           i_data_r = {31'd0, cnn_cpu_accel_start_reg};
            ADDR_WRITE_FIFO:      i_data_r = {31'd0, cnn_table_vld_reg};
            ADDR_STATUS:          i_data_r = {27'd0, cnn_cpu_accel_start_reg, irq_accel_done_o, cnn_cpu_accel_busy_o, cnn_table_rdy_w, cnn_table_vld_reg};
            ADDR_IFHEIGHT:        i_data_r = {24'd0, cnn_table_ifheight_reg};
            ADDR_IFCHANNEL:       i_data_r = {21'd0, cnn_table_ifchannel_reg};
            ADDR_OFCHANNEL:       i_data_r = {21'd0, cnn_table_ofchannel_reg};
            ADDR_HF:              i_data_r = {28'd0, cnn_table_hf_reg};
            ADDR_STRIDE:          i_data_r = {29'd0, cnn_table_stride_reg};
            ADDR_PADDING:         i_data_r = {30'd0, cnn_table_padding_reg};
            ADDR_IFPARR:          i_data_r = {29'd0, cnn_table_ifparr_reg};
            ADDR_OFTILE:          i_data_r = {30'd0, cnn_table_oftile_reg};
            ADDR_OFPARR:          i_data_r = {27'd0, cnn_table_ofparr_reg};
            ADDR_IFBADDR:         i_data_r = {8'd0, cnn_table_ifbaddr_reg};
            ADDR_FLTBADDR:        i_data_r = {8'd0, cnn_table_fltbaddr_reg};
            ADDR_BIAS_BADDR:      i_data_r = {8'd0, cnn_table_bias_baddr_reg};
            ADDR_OFBADDR:         i_data_r = {8'd0, cnn_table_ofbaddr_reg};
            ADDR_IFC_ZP:          i_data_r = {{(32-CNN_DATA_WIDTH){cnn_table_ifc_zp_reg[CNN_DATA_WIDTH-1]}}, cnn_table_ifc_zp_reg};
            ADDR_FLTC_ZP:         i_data_r = {{(32-CNN_DATA_WIDTH){cnn_table_fltc_zp_reg[CNN_DATA_WIDTH-1]}}, cnn_table_fltc_zp_reg};
            ADDR_MULT:            i_data_r = cnn_table_mult_reg;
            ADDR_MULT_SHIFT:      i_data_r = {26'd0, cnn_table_mult_shift_reg};
            ADDR_ALPHAMULT:       i_data_r = cnn_table_alphamult_reg;
            ADDR_ALPHAMULT_SHIFT: i_data_r = {26'd0, cnn_table_alphamult_shift_reg};
            ADDR_ZPY:             i_data_r = {{24{cnn_table_zpy_reg[7]}}, cnn_table_zpy_reg};
            ADDR_QMIN:            i_data_r = {{24{cnn_table_qmin_reg[7]}}, cnn_table_qmin_reg};
            ADDR_QMAX:            i_data_r = {{24{cnn_table_qmax_reg[7]}}, cnn_table_qmax_reg};
            ADDR_IS_LEAKY_RELU:   i_data_r = {31'd0, cnn_table_is_leaky_ReLU_reg};
            default:              i_data_r = 32'd0;
        endcase
    end

    // =========================================================
    // CNN accelerator instance
    // =========================================================
    CNN_accel #(
        .DATA_WIDTH(CNN_DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .IFBUF_DEPTH(IFBUF_DEPTH),
        .FLTBUF_DEPTH(FLTBUF_DEPTH),
        .COMP_DEPTH(COMP_DEPTH),
        .FIFO_DEPTH(FIFO_DEPTH),
        .OFBUF_DEPTH(OFBUF_DEPTH),
        .K(K),
        .M(M),
        .PE_PER_PU(PE_PER_PU),
        .PPDEPTH(PPDEPTH),
        .BURSTL_IFMAP(BURSTL_IFMAP),
        .BURSTL_FILTER(BURSTL_FILTER),
        .BURSTL_BIAS(BURSTL_BIAS),
        .BURSTL_OFMAP(BURSTL_OFMAP)
    ) u_cnn_accel (
        .clk(clk),
        .rst_n(resetn),

        .cnn_table_vld_i(cnn_table_vld_reg),
        .cnn_table_rdy_o(cnn_table_rdy_w),
        .cnn_table_ifheight_i(cnn_table_ifheight_reg),
        .cnn_table_ifchannel_i(cnn_table_ifchannel_reg),
        .cnn_table_ofchannel_i(cnn_table_ofchannel_reg),
        .cnn_table_hf_i(cnn_table_hf_reg),
        .cnn_table_stride_i(cnn_table_stride_reg),
        .cnn_table_padding_i(cnn_table_padding_reg),
        .cnn_table_ifparr_i(cnn_table_ifparr_reg),
        .cnn_table_oftile_i(cnn_table_oftile_reg),
        .cnn_table_ofparr_i(cnn_table_ofparr_reg),
        .cnn_table_ifbaddr_i(cnn_table_ifbaddr_reg),
        .cnn_table_fltbaddr_i(cnn_table_fltbaddr_reg),
        .cnn_table_bias_baddr_i(cnn_table_bias_baddr_reg),
        .cnn_table_ofbaddr_i(cnn_table_ofbaddr_reg),
        .cnn_table_ifc_zp_i(cnn_table_ifc_zp_reg),
        .cnn_table_fltc_zp_i(cnn_table_fltc_zp_reg),
        .cnn_table_mult_i(cnn_table_mult_reg),
        .cnn_table_mult_shift_i(cnn_table_mult_shift_reg),
        .cnn_table_alphamult_i(cnn_table_alphamult_reg),
        .cnn_table_alphamult_shift_i(cnn_table_alphamult_shift_reg),
        .cnn_table_zpy_i(cnn_table_zpy_reg),
        .cnn_table_qmin_i(cnn_table_qmin_reg),
        .cnn_table_qmax_i(cnn_table_qmax_reg),
        .cnn_table_is_leaky_ReLU_i(cnn_table_is_leaky_ReLU_reg),

        .cnn_cpu_accel_busy_o(cnn_cpu_accel_busy_o),
        .cnn_cpu_accel_start_i(cnn_cpu_accel_start_reg),
        .cnn_cpu_accel_done_o(irq_accel_done_o),
        .cnn_cpu_receive_interupt_i(eoi_accel_done_i),

        .cnn_ifbuf_dma_rdycfg_i(cnn_ifbuf_dma_rdycfg_i),
        .cnn_ifbuf_dma_vld_i(cnn_ifbuf_dma_vld_i),
        .cnn_ifbuf_dma_data_i(cnn_ifbuf_dma_data_i),
        .cnn_ifbuf_dma_tlast_i(cnn_ifbuf_dma_tlast_i),
        .cnn_ifbuf_dma_vldcfg_o(cnn_ifbuf_dma_vldcfg_o),
        .cnn_ifbuf_dma_burst_o(cnn_ifbuf_dma_burst_o),
        .cnn_ifbuf_dma_baddr_o(cnn_ifbuf_dma_baddr_o),
        .cnn_ifbuf_dma_rdy_o(cnn_ifbuf_dma_rdy_o),

        .cnn_fltbuf_dma_rdycfg_i(cnn_fltbuf_dma_rdycfg_i),
        .cnn_fltbuf_dma_vld_i(cnn_fltbuf_dma_vld_i),
        .cnn_fltbuf_dma_data_i(cnn_fltbuf_dma_data_i),
        .cnn_fltbuf_dma_tlast_i(cnn_fltbuf_dma_tlast_i),
        .cnn_fltbuf_dma_vldcfg_o(cnn_fltbuf_dma_vldcfg_o),
        .cnn_fltbuf_dma_burst_o(cnn_fltbuf_dma_burst_o),
        .cnn_fltbuf_dma_baddr_o(cnn_fltbuf_dma_baddr_o),
        .cnn_fltbuf_dma_rdy_o(cnn_fltbuf_dma_rdy_o),

        .cnn_bias_dma_rdycfg_i(cnn_bias_dma_rdycfg_i),
        .cnn_bias_dma_vldcfg_o(cnn_bias_dma_vldcfg_o),
        .cnn_bias_dma_burst_o(cnn_bias_dma_burst_o),
        .cnn_bias_dma_baddr_o(cnn_bias_dma_baddr_o),
        .cnn_bias_dma_vld_i(cnn_bias_dma_vld_i),
        .cnn_bias_dma_data_i(cnn_bias_dma_data_i),
        .cnn_bias_dma_tlast_i(cnn_bias_dma_tlast_i),
        .cnn_bias_dma_rdy_o(cnn_bias_dma_rdy_o),

        .cnn_ofbuf_dma_rdycfg_i(cnn_ofbuf_dma_rdycfg_i),
        .cnn_ofbuf_dma_vldcfg_o(cnn_ofbuf_dma_vldcfg_o),
        .cnn_ofbuf_dma_burst_o(cnn_ofbuf_dma_burst_o),
        .cnn_ofbuf_dma_baddr_o(cnn_ofbuf_dma_baddr_o),
        .cnn_ofbuf_dma_vld_o(cnn_ofbuf_dma_vld_o),
        .cnn_ofbuf_dma_data_o(cnn_ofbuf_dma_data_o),
        .cnn_ofbuf_dma_tlast_o(cnn_ofbuf_dma_tlast_o),
        .cnn_ofbuf_dma_rdy_i(cnn_ofbuf_dma_rdy_i),

        .cnn_comp_pa_done_compute_o(cnn_comp_pa_done_compute_o),
        .cnn_ifbuf_comp_end_layer_o(cnn_ifbuf_comp_end_layer_o),
        .cnn_ifbuf_comp_end_layer_real_o(cnn_ifbuf_comp_end_layer_real_o),
        .cnn_fltbuf_comp_donepass_o(cnn_fltbuf_comp_donepass_o)
    );

    // =========================================================
    // AXI-Lite slave interface instance
    // =========================================================
    axi_lite_slave_interface #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .TRANS_W_STRB_W(TRANS_W_STRB_W),
        .TRANS_WR_RESP_W(TRANS_WR_RESP_W),
        .TRANS_PROT(TRANS_PROT),
        .CYCLE_CLOCK(CYCLE_CLOCK),
        .NUM_MASTERS(NUM_MASTERS)
    ) u_axi_lite_slave_interface (
        .clk_i(clk),
        .resetn_i(resetn),

        .i_axi_awaddr(i_axi_awaddr),
        .i_axi_awvalid(i_axi_awvalid),
        .o_axi_awready(o_axi_awready),
        .i_axi_awprot(i_axi_awprot),

        .i_axi_wdata(i_axi_wdata),
        .i_axi_wstrb(i_axi_wstrb),
        .i_axi_wvalid(i_axi_wvalid),
        .o_axi_wready(o_axi_wready),

        .o_axi_bresp(o_axi_bresp),
        .o_axi_bvalid(o_axi_bvalid),
        .i_axi_bready(i_axi_bready),

        .i_axi_araddr(i_axi_araddr),
        .i_axi_arvalid(i_axi_arvalid),
        .o_axi_arready(o_axi_arready),
        .i_axi_arprot(i_axi_arprot),

        .o_axi_rdata(o_axi_rdata),
        .o_axi_rvalid(o_axi_rvalid),
        .o_axi_rresp(o_axi_rresp),
        .i_axi_rready(i_axi_rready),

        .o_addr_w(o_addr_w),
        .o_awprot_w(),
        .o_wen(o_wen),
        .o_data_w(o_data_w),
        .o_write_data_w(o_wr_w),
        .i_bresp_w(2'b00),

        .o_addr_r(o_addr_r),
        .o_arprot_r(),
        .i_data_r(i_data_r),
        .i_rresp_r(2'b00),
        .o_read_data_r(o_rd_r)
    );

endmodule
