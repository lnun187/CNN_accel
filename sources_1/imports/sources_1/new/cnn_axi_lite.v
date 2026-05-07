`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// cnn_axi_lite
// -----------------------------------------------------------------------------
// AXI-Lite wrapper for CNN_accel.
//
// Important note about axi_lite_slave_interface:
//   - o_addr_w      : registered AW address captured from the AXI write-address
//                     channel. It is not a write-enable by itself.
//   - o_data_w      : registered W data captured from the AXI write-data channel.
//                     It is not guaranteed to arrive in the same cycle as AW.
//   - o_wen         : registered WSTRB byte-enable captured with W data.
//   - o_write_data_w: pulse/level from the W channel handshake. It only means
//                     write data has been accepted, not that AW and W are both
//                     available for a complete register write.
//   - o_addr_r      : registered AR address for read mux selection.
//   - o_read_data_r : pulse/level from the R channel side. For pure register
//                     readback this wrapper only needs o_addr_r and i_data_r.
//
// Because AW and W are independent AXI-Lite channels, this wrapper explicitly
// tracks both handshakes and commits a register write only after both the write
// address and write data have been captured.
// -----------------------------------------------------------------------------
module cnn_axi_lite #(
    parameter NUM_MASTERS      = 1,
    parameter ADDR_WIDTH       = 32,
    parameter DATA_WIDTH       = 32,
    parameter TRANS_W_STRB_W   = 4,
    parameter TRANS_WR_RESP_W  = 2,
    parameter TRANS_PROT       = 3,
    parameter CYCLE_CLOCK      = 2,

    // // CNN_accel parameters
    parameter CNN_DATA_WIDTH    = 8,
    parameter ACC_WIDTH     = 32,
    parameter IFBUF_DEPTH   = 224,
    parameter FLTBUF_DEPTH  = 3456,
    parameter COMP_DEPTH    = 12,
    parameter FIFO_DEPTH    = 12,
    parameter OFBUF_DEPTH   = 896,
    parameter K             = 4,
    parameter M             = 2,
    parameter PE_PER_PU     = 12,
    parameter PPDEPTH       = 224,
    parameter BURSTL_IFMAP = 8,
    parameter BURSTL_FILTER = 10,
    parameter BURSTL_BIAS = 7,
    parameter BURSTL_OFMAP = 8,

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

    // Interrupt ports: direct CNN signal, not an AXI-Lite decoded register bit.
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
    input                               cnn_ofbuf_dma_rdy_i

);
    // -------------------------------------------------------------------------
    // Signals exported by axi_lite_slave_interface
    // -------------------------------------------------------------------------
    wire [ADDR_WIDTH-1:0]       axi_addr_w_unused;
    wire [TRANS_PROT-1:0]       axi_awprot_unused;
    wire [DATA_WIDTH-1:0]       axi_data_w_unused;
    wire [TRANS_W_STRB_W-1:0]   axi_wstrb_unused;
    wire                        axi_write_data_seen_unused;

    wire [ADDR_WIDTH-1:0]       axi_addr_r;
    wire [TRANS_PROT-1:0]       axi_arprot_unused;
    reg  [DATA_WIDTH-1:0]       axi_data_r;
    wire                        axi_read_seen_unused;

    // Raw AXI channel fires. These are used only to build a complete write
    // transaction. The interface still owns READY/VALID response generation.
    wire                        axi_aw_fire;
    wire                        axi_w_fire;
    wire                        write_commit;

    assign axi_aw_fire = i_axi_awvalid & o_axi_awready;
    assign axi_w_fire  = i_axi_wvalid  & o_axi_wready;

    reg                         aw_pending_q;
    reg                         w_pending_q;
    reg  [ADDR_WIDTH-1:0]       wr_addr_q;
    reg  [DATA_WIDTH-1:0]       wr_data_q;
    reg  [TRANS_W_STRB_W-1:0]   wr_strb_q;

    assign write_commit = aw_pending_q & w_pending_q;

    // -------------------------------------------------------------------------
    // CNN configuration/status registers
    // -------------------------------------------------------------------------
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
    (* KEEP = "TRUE", DONT_TOUCH = "TRUE" *) wire cnn_irq_accel_done_w;

    assign irq_accel_done_o = cnn_irq_accel_done_w;

    // -------------------------------------------------------------------------
    // Helper functions
    // -------------------------------------------------------------------------
    function [31:0] reg_readback;
        input [ADDR_WIDTH-1:0] addr;
        begin
            case (addr)
                ADDR_START:           reg_readback = {31'd0, cnn_cpu_accel_start_reg};
                ADDR_WRITE_FIFO:      reg_readback = {31'd0, cnn_table_vld_reg};
                ADDR_STATUS:          reg_readback = {27'd0, cnn_cpu_accel_start_reg, cnn_irq_accel_done_w, cnn_cpu_accel_busy_o, cnn_table_rdy_w, cnn_table_vld_reg};
                ADDR_IFHEIGHT:        reg_readback = {24'd0, cnn_table_ifheight_reg};
                ADDR_IFCHANNEL:       reg_readback = {21'd0, cnn_table_ifchannel_reg};
                ADDR_OFCHANNEL:       reg_readback = {21'd0, cnn_table_ofchannel_reg};
                ADDR_HF:              reg_readback = {28'd0, cnn_table_hf_reg};
                ADDR_STRIDE:          reg_readback = {29'd0, cnn_table_stride_reg};
                ADDR_PADDING:         reg_readback = {30'd0, cnn_table_padding_reg};
                ADDR_IFPARR:          reg_readback = {29'd0, cnn_table_ifparr_reg};
                ADDR_OFTILE:          reg_readback = {30'd0, cnn_table_oftile_reg};
                ADDR_OFPARR:          reg_readback = {27'd0, cnn_table_ofparr_reg};
                ADDR_IFBADDR:         reg_readback = {8'd0, cnn_table_ifbaddr_reg};
                ADDR_FLTBADDR:        reg_readback = {8'd0, cnn_table_fltbaddr_reg};
                ADDR_BIAS_BADDR:      reg_readback = {8'd0, cnn_table_bias_baddr_reg};
                ADDR_OFBADDR:         reg_readback = {8'd0, cnn_table_ofbaddr_reg};
                ADDR_IFC_ZP:          reg_readback = {{(32-CNN_DATA_WIDTH){cnn_table_ifc_zp_reg[CNN_DATA_WIDTH-1]}}, cnn_table_ifc_zp_reg};
                ADDR_FLTC_ZP:         reg_readback = {{(32-CNN_DATA_WIDTH){cnn_table_fltc_zp_reg[CNN_DATA_WIDTH-1]}}, cnn_table_fltc_zp_reg};
                ADDR_MULT:            reg_readback = cnn_table_mult_reg;
                ADDR_MULT_SHIFT:      reg_readback = {26'd0, cnn_table_mult_shift_reg};
                ADDR_ALPHAMULT:       reg_readback = cnn_table_alphamult_reg;
                ADDR_ALPHAMULT_SHIFT: reg_readback = {26'd0, cnn_table_alphamult_shift_reg};
                ADDR_ZPY:             reg_readback = {{24{cnn_table_zpy_reg[7]}}, cnn_table_zpy_reg};
                ADDR_QMIN:            reg_readback = {{24{cnn_table_qmin_reg[7]}}, cnn_table_qmin_reg};
                ADDR_QMAX:            reg_readback = {{24{cnn_table_qmax_reg[7]}}, cnn_table_qmax_reg};
                ADDR_IS_LEAKY_RELU:   reg_readback = {31'd0, cnn_table_is_leaky_ReLU_reg};
                default:              reg_readback = 32'd0;
            endcase
        end
    endfunction

    function [31:0] apply_wstrb;
        input [31:0] old_value;
        input [31:0] new_value;
        input [3:0]  wstrb;
        begin
            apply_wstrb = old_value;
            if (wstrb[0]) apply_wstrb[7:0]   = new_value[7:0];
            if (wstrb[1]) apply_wstrb[15:8]  = new_value[15:8];
            if (wstrb[2]) apply_wstrb[23:16] = new_value[23:16];
            if (wstrb[3]) apply_wstrb[31:24] = new_value[31:24];
        end
    endfunction

    wire [31:0] wr_data_strobed;
    assign wr_data_strobed = apply_wstrb(reg_readback(wr_addr_q), wr_data_q[31:0], wr_strb_q[3:0]);

    // -------------------------------------------------------------------------
    // Join AXI AW/W channels into a complete register-write operation.
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            aw_pending_q <= 1'b0;
            w_pending_q  <= 1'b0;
            wr_addr_q    <= {ADDR_WIDTH{1'b0}};
            wr_data_q    <= {DATA_WIDTH{1'b0}};
            wr_strb_q    <= {TRANS_W_STRB_W{1'b0}};
        end else begin
            if (write_commit) begin
                aw_pending_q <= 1'b0;
                w_pending_q  <= 1'b0;
            end

            if (axi_aw_fire) begin
                wr_addr_q    <= i_axi_awaddr;
                aw_pending_q <= 1'b1;
            end

            if (axi_w_fire) begin
                wr_data_q    <= i_axi_wdata;
                wr_strb_q    <= i_axi_wstrb;
                w_pending_q  <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Register write side.
    //
    // ADDR_START:
    //   write bit[0] = 1 to generate a one-clock start pulse into CNN_accel.
    //
    // ADDR_WRITE_FIFO:
    //   write bit[0] = 1 to assert cnn_table_vld_reg. The bit remains asserted
    //   until CNN_accel raises cnn_table_rdy_w, forming a vld/rdy handshake.
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cnn_table_vld_reg             <= 1'b0;
            cnn_cpu_accel_start_reg       <= 1'b0;
            cnn_table_ifheight_reg        <= 8'd0;
            cnn_table_ifchannel_reg       <= 11'd0;
            cnn_table_ofchannel_reg       <= 11'd0;
            cnn_table_hf_reg              <= 4'd0;
            cnn_table_stride_reg          <= 3'd0;
            cnn_table_padding_reg         <= 2'd0;
            cnn_table_ifparr_reg          <= 3'd0;
            cnn_table_oftile_reg          <= 2'd0;
            cnn_table_ofparr_reg          <= 5'd0;
            cnn_table_ifbaddr_reg         <= 24'd0;
            cnn_table_fltbaddr_reg        <= 24'd0;
            cnn_table_bias_baddr_reg      <= 24'd0;
            cnn_table_ofbaddr_reg         <= 24'd0;
            cnn_table_ifc_zp_reg          <= {CNN_DATA_WIDTH{1'b0}};
            cnn_table_fltc_zp_reg         <= {CNN_DATA_WIDTH{1'b0}};
            cnn_table_mult_reg            <= 32'sd0;
            cnn_table_mult_shift_reg      <= 6'd0;
            cnn_table_alphamult_reg       <= 32'sd0;
            cnn_table_alphamult_shift_reg <= 6'd0;
            cnn_table_zpy_reg             <= 8'sd0;
            cnn_table_qmin_reg            <= 8'sd0;
            cnn_table_qmax_reg            <= 8'sd0;
            cnn_table_is_leaky_ReLU_reg   <= 1'b0;
        end else begin
            cnn_cpu_accel_start_reg <= 1'b0;

            if (cnn_table_rdy_w) begin
                cnn_table_vld_reg <= 1'b0;
            end

            if (write_commit) begin
                case (wr_addr_q)
                    ADDR_START: begin
                        if (wr_data_strobed[0]) begin
                            cnn_cpu_accel_start_reg <= 1'b1;
                        end
                    end

                    ADDR_WRITE_FIFO: begin
                        if (wr_data_strobed[0]) begin
                            cnn_table_vld_reg <= 1'b1;
                        end
                    end

                    ADDR_IFHEIGHT:        cnn_table_ifheight_reg        <= wr_data_strobed[7:0];
                    ADDR_IFCHANNEL:       cnn_table_ifchannel_reg       <= wr_data_strobed[10:0];
                    ADDR_OFCHANNEL:       cnn_table_ofchannel_reg       <= wr_data_strobed[10:0];
                    ADDR_HF:              cnn_table_hf_reg              <= wr_data_strobed[3:0];
                    ADDR_STRIDE:          cnn_table_stride_reg          <= wr_data_strobed[2:0];
                    ADDR_PADDING:         cnn_table_padding_reg         <= wr_data_strobed[1:0];
                    ADDR_IFPARR:          cnn_table_ifparr_reg          <= wr_data_strobed[2:0];
                    ADDR_OFTILE:          cnn_table_oftile_reg          <= wr_data_strobed[1:0];
                    ADDR_OFPARR:          cnn_table_ofparr_reg          <= wr_data_strobed[4:0];
                    ADDR_IFBADDR:         cnn_table_ifbaddr_reg         <= wr_data_strobed[23:0];
                    ADDR_FLTBADDR:        cnn_table_fltbaddr_reg        <= wr_data_strobed[23:0];
                    ADDR_BIAS_BADDR:      cnn_table_bias_baddr_reg      <= wr_data_strobed[23:0];
                    ADDR_OFBADDR:         cnn_table_ofbaddr_reg         <= wr_data_strobed[23:0];
                    ADDR_IFC_ZP:          cnn_table_ifc_zp_reg          <= wr_data_strobed[CNN_DATA_WIDTH-1:0];
                    ADDR_FLTC_ZP:         cnn_table_fltc_zp_reg         <= wr_data_strobed[CNN_DATA_WIDTH-1:0];
                    ADDR_MULT:            cnn_table_mult_reg            <= wr_data_strobed;
                    ADDR_MULT_SHIFT:      cnn_table_mult_shift_reg      <= wr_data_strobed[5:0];
                    ADDR_ALPHAMULT:       cnn_table_alphamult_reg       <= wr_data_strobed;
                    ADDR_ALPHAMULT_SHIFT: cnn_table_alphamult_shift_reg <= wr_data_strobed[5:0];
                    ADDR_ZPY:             cnn_table_zpy_reg             <= wr_data_strobed[7:0];
                    ADDR_QMIN:            cnn_table_qmin_reg            <= wr_data_strobed[7:0];
                    ADDR_QMAX:            cnn_table_qmax_reg            <= wr_data_strobed[7:0];
                    ADDR_IS_LEAKY_RELU:   cnn_table_is_leaky_ReLU_reg   <= wr_data_strobed[0];
                    default: ;
                endcase
            end
        end
    end

    // -------------------------------------------------------------------------
    // Read mux. axi_lite_slave_interface samples axi_data_r when its R channel
    // response is generated, so axi_data_r is purely combinational from o_addr_r.
    // -------------------------------------------------------------------------
    always @(*) begin
        axi_data_r = reg_readback(axi_addr_r);
    end

    // -------------------------------------------------------------------------
    // CNN accelerator instance
    // -------------------------------------------------------------------------
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
        .cnn_cpu_accel_done_o(cnn_irq_accel_done_w),
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

    );

    // -------------------------------------------------------------------------
    // AXI-Lite protocol adapter. This module produces AXI READY/VALID/BRESP/RRESP
    // and exposes captured address/data/status signals to this register wrapper.
    // -------------------------------------------------------------------------
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

        .o_addr_w(axi_addr_w_unused),
        .o_awprot_w(axi_awprot_unused),
        .o_wen(axi_wstrb_unused),
        .o_data_w(axi_data_w_unused),
        .o_write_data_w(axi_write_data_seen_unused),
        .i_bresp_w(2'b00),

        .o_addr_r(axi_addr_r),
        .o_arprot_r(axi_arprot_unused),
        .i_data_r(axi_data_r),
        .i_rresp_r(2'b00),
        .o_read_data_r(axi_read_seen_unused)
    );

endmodule
