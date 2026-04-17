`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/03/2026 06:12:01 PM
// Design Name: 
// Module Name: CNN_accel
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


module CNN_accel#(
    parameter DATA_WIDTH    = 8,
    parameter ACC_WIDTH     = 32,
    parameter IFBUF_DEPTH   = 300,
    parameter FLTBUF_DEPTH  = 2304,
    parameter COMP_DEPTH    = 12,
    parameter FIFO_DEPTH    = 12,
    parameter K             = 8,
    parameter M             = 2,
    parameter PE_PER_PU     = 12,
    parameter PPDEPTH       = 640
)(
    input               clk,
    input               rst_n,

    // =========================================================
    // IFBUF instruction interface
    // =========================================================
    input               ifbuf_ins_vld_i,
    input  [31:0]       ifbuf_ins_ifbaddr_i, //base address for ifmap
    input  [7:0]        ifbuf_ins_width_i, //width and height of ifmap channel
    input  [10:0]       ifbuf_ins_channel_i, //total ifmap channel
    input  [3:0]        ifbuf_ins_ifparr_i, //count of parrallel ifmap channel
    input  [15:0]       ifbuf_ins_ifsize_i, //width da duoc align (so chan) * height
    input  [6:0]        ifbuf_ins_ifblock_i, //so lan 1 ifmap duoc tai lai = Co / (ofparrallel * oftile)
    input  [3:0]        ifbuf_ins_oftiles_i, //so cum ofmap duoc tinh song song tren 1 lan tai ifmap
    input  [3:0]        ifbuf_ins_oftiles_tail_i, //so cum ofmap song song o block cuoi cung
    input  [6:0]        ifbuf_ins_iftiles_i, //Ci / ifmap parrallel
    input  [8:0]        ifbuf_ins_wp_i, // the end point of row ifmap (include padding) 
    //this is how too calculate ifbuf_ins_wp_i
    //ALIGNED_WIDTH = (TEST_WIDTH % 2 != 0) ? (TEST_WIDTH + 1) : TEST_WIDTH;
    //TEST_IFSIZE   = TEST_WIDTH * ALIGNED_WIDTH; // Giả sử height = width
    //TEST_WP       = ((TEST_WIDTH + 2*TEST_PADDING - TEST_HF) / TEST_STRIDE) * TEST_STRIDE + TEST_HF - 1;
    input  [1:0]                ifbuf_ins_padding_i, //padding
    input  [DATA_WIDTH-1:0]     ifbuf_ins_ifc_zp_i, //zero point of quantize 8 bit
    output                      ifbuf_ins_rdy_o,

    // =========================================================
    // FLTBUF instruction interface
    // =========================================================
    input               fltbuf_ins_vld_i, 
    input  [31:0]       fltbuf_ins_fltbaddr_i, //base address for filter
    input  [3:0]        fltbuf_ins_ifparr_i,
    input  [3:0]        fltbuf_ins_ifparr_tail_i,
    input  [6:0]        fltbuf_ins_fltsize_i,
    input  [6:0]        fltbuf_ins_ifblock_i,
    input  [4:0]        fltbuf_ins_ofparr_i, //so ofmap channel duoc tinh song song
    input  [4:0]        fltbuf_ins_ofparr_tail_i,//so ofmap channel duoc tinh song song o block cuoi va oftile cuoi
    input  [3:0]        fltbuf_ins_oftiles_i,
    input  [3:0]        fltbuf_ins_oftiles_tail_i,
    input  [6:0]        fltbuf_ins_iftiles_i,
    output              fltbuf_ins_rdy_o,

    // =========================================================
    // COMPUTATION instruction interface
    // =========================================================
    input  [3:0]                comp_ins_hf_i, //height of channel of filter
    input  [2:0]                comp_ins_stride_i,
    input  [1:0]                comp_ins_padding_i,
    input  [DATA_WIDTH-1:0]     comp_ins_ifc_zp_i, //zero point of ifmap
    input  [DATA_WIDTH-1:0]     comp_ins_fltc_zp_i, //zero point of filter

    // =========================================================
    // IFBUF DMA side
    // =========================================================
    input                   ifbuf_dma_rdycfg_i, //dma rdy to receive config from ifbuf
    input                   ifbuf_dma_vld_i, //dma has data to send ifbuf
    input  [DATA_WIDTH-1:0] ifbuf_dma_data_i,
    input                   ifbuf_dma_tlast_i,
    output                  ifbuf_dma_vldcfg_o, //ifbuf has valid config
    output [8:0]            ifbuf_dma_burst_o, //length of data, it will be align to even
    output [31:0]           ifbuf_dma_baddr_o, //base address of data need to read
    output                  ifbuf_dma_rdy_o,

    // =========================================================
    // FLTBUF DMA side
    // =========================================================
    input                   fltbuf_dma_rdycfg_i,
    input                   fltbuf_dma_vld_i,
    input  [DATA_WIDTH-1:0] fltbuf_dma_data_i,
    input                   fltbuf_dma_tlast_i,
    output                  fltbuf_dma_vldcfg_o,
    output [9:0]            fltbuf_dma_burst_o,
    output [31:0]           fltbuf_dma_baddr_o,
    output                  fltbuf_dma_rdy_o,

    // =========================================================
    // Toward OFBUF (not implemented in the uploaded RTL set)
    // =========================================================
    input  [M-1:0]            comp_ofbuf_rdy_i,
    output [M-1:0]            comp_ofbuf_vld_o,
    output [M*ACC_WIDTH-1:0]  comp_ofbuf_data_o,

    // =========================================================
    // Optional debug / status
    // =========================================================
    output                    comp_pa_done_compute_o,
    output                    ifbuf_comp_end_layer_o,
    output                    fltbuf_comp_donepass_o
);

    // =========================================================
    // Internal datapath wires
    // =========================================================
    wire                    ifbuf_comp_vld_w;
    wire [K*DATA_WIDTH-1:0] ifbuf_comp_data_w;
    wire                    ifbuf_comp_end_row_w;
    wire                    ifbuf_comp_end_row_circle_w;
    wire                    ifbuf_comp_end_depth_w;
    wire                    ifbuf_comp_end_layer_w;
    wire                    comp_ifbuf_rdy_w;

    wire [K*DATA_WIDTH+3:0] ifbuf_comp_payload_w;
    wire [K*DATA_WIDTH+3:0] ifbuf_comp_payload_buf_w;
    wire                    ifbuf_comp_vld_buf_w;
    wire                    ifbuf_comp_rdy_buf_w;
    wire                    ifbuf_comp_end_row_buf_w;
    wire                    ifbuf_comp_end_row_circle_buf_w;
    wire                    ifbuf_comp_end_depth_buf_w;
    wire                    ifbuf_comp_end_layer_buf_w;
    wire [K*DATA_WIDTH-1:0] ifbuf_comp_data_buf_w;

    wire [K*M-1:0]            fltbuf_comp_vld_w;
    wire [K*M*DATA_WIDTH-1:0] fltbuf_comp_data_w;
    wire                      fltbuf_comp_donepass_w;
    wire [M-1:0]              comp_fltbuf_rdy_w;
    wire                      fltbuf_comp_rdy_w;

    wire [M-1:0]            comp_ofbuf_vld_w;
    wire [M-1:0]            comp_ofbuf_rdy_w;
    wire [M*ACC_WIDTH-1:0]  comp_ofbuf_data_w;

    reg [3:0]               comp_ins_hf_reg; //height of channel of filter
    reg [2:0]               comp_ins_stride_reg;
    reg [1:0]               comp_ins_padding_reg;
    reg [DATA_WIDTH-1:0]    comp_ins_ifc_zp_reg; //zero point of ifmap
    reg [DATA_WIDTH-1:0]    comp_ins_fltc_zp_reg;

    always @(posedge clk) begin
        comp_ins_hf_reg         <= comp_ins_hf_i;
        comp_ins_stride_reg     <= comp_ins_stride_i;
        comp_ins_padding_reg    <= comp_ins_padding_i;
        comp_ins_ifc_zp_reg     <= comp_ins_ifc_zp_i;
        comp_ins_fltc_zp_reg    <= comp_ins_fltc_zp_i;
    end

    // Current filter_buf RTL only exposes one scalar ready input.
    // Best-effort integration: only pop weights when both PA branches are ready.
    assign fltbuf_comp_rdy_w = &comp_fltbuf_rdy_w;

    assign ifbuf_comp_end_layer_o = ifbuf_comp_end_layer_w;
    assign fltbuf_comp_donepass_o = fltbuf_comp_donepass_w;

    // =========================================================
    // IFBUF
    // =========================================================
    ifbuf #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(IFBUF_DEPTH),
        .K(K)
    ) u_ifbuf (
        .clk(clk),
        .rst_n(rst_n),

        .ifbuf_ins_vld_i(ifbuf_ins_vld_i),
        .ifbuf_ins_ifbaddr_i(ifbuf_ins_ifbaddr_i),
        .ifbuf_ins_ifparr_i(ifbuf_ins_ifparr_i),
        .ifbuf_ins_ifsize_i(ifbuf_ins_ifsize_i),
        .ifbuf_ins_channel_i(ifbuf_ins_channel_i),
        .ifbuf_ins_width_i(ifbuf_ins_width_i),
        .ifbuf_ins_ifblock_i(ifbuf_ins_ifblock_i),
        .ifbuf_ins_oftiles_i(ifbuf_ins_oftiles_i),
        .ifbuf_ins_oftiles_tail_i(ifbuf_ins_oftiles_tail_i),
        .ifbuf_ins_iftiles_i(ifbuf_ins_iftiles_i),
        .ifbuf_ins_wp_i(ifbuf_ins_wp_i),
        .ifbuf_ins_padding_i(ifbuf_ins_padding_i),
        .ifbuf_ins_ifc_zp_i(ifbuf_ins_ifc_zp_i),
        .ifbuf_ins_rdy_o(ifbuf_ins_rdy_o),

        .ifbuf_dma_rdycfg_i(ifbuf_dma_rdycfg_i),
        .ifbuf_dma_vld_i(ifbuf_dma_vld_i),
        .ifbuf_dma_data_i(ifbuf_dma_data_i),
        .ifbuf_dma_tlast_i(ifbuf_dma_tlast_i),
        .ifbuf_dma_vldcfg_o(ifbuf_dma_vldcfg_o),
        .ifbuf_dma_burst_o(ifbuf_dma_burst_o),
        .ifbuf_dma_baddr_o(ifbuf_dma_baddr_o),
        .ifbuf_dma_rdy_o(ifbuf_dma_rdy_o),

        .ifbuf_comp_rdy_i(comp_ifbuf_rdy_w),
        .ifbuf_comp_vld_o(ifbuf_comp_vld_w),
        .ifbuf_comp_data_o(ifbuf_comp_data_w),
        .ifbuf_comp_end_row_o(ifbuf_comp_end_row_w),
        .ifbuf_comp_end_row_circle_o(ifbuf_comp_end_row_circle_w),
        .ifbuf_comp_end_depth_o(ifbuf_comp_end_depth_w),
        .ifbuf_comp_end_layer_o(ifbuf_comp_end_layer_w)
    );

    assign ifbuf_comp_payload_w = {
        ifbuf_comp_end_layer_w,
        ifbuf_comp_end_depth_w,
        ifbuf_comp_end_row_circle_w,
        ifbuf_comp_end_row_w,
        ifbuf_comp_data_w
    };

    
    skid_buffer #(
        .SBUF_TYPE(0),
        .DATA_WIDTH(K*DATA_WIDTH + 4)
    ) skide_ifbuf_computation (
        .clk(clk),
        .rst_n(rst_n),

        .bwd_data_i(ifbuf_comp_payload_w),
        .bwd_valid_i(ifbuf_comp_vld_w),
        .fwd_ready_i(ifbuf_comp_rdy_buf_w),

        .fwd_data_o(ifbuf_comp_payload_buf_w),
        .bwd_ready_o(comp_ifbuf_rdy_w),
        .fwd_valid_o(ifbuf_comp_vld_buf_w)
    );
    assign {
        ifbuf_comp_end_layer_buf_w,
        ifbuf_comp_end_depth_buf_w,
        ifbuf_comp_end_row_circle_buf_w,
        ifbuf_comp_end_row_buf_w,
        ifbuf_comp_data_buf_w
    } = ifbuf_comp_payload_buf_w;

    // =========================================================
    // FLTBUF
    // =========================================================
   
    filter_buf #(
        .DATA_WIDTH(DATA_WIDTH),
        .DEPTH(FLTBUF_DEPTH),
        .K(K),
        .M(M),
        .PE_PER_PU(PE_PER_PU)
    ) u_filter_buf (
        .clk(clk),
        .rst_n(rst_n),

        .fltbuf_ins_vld_i(fltbuf_ins_vld_i),
        .fltbuf_ins_fltbaddr_i(fltbuf_ins_fltbaddr_i),
        .fltbuf_ins_ifparr_i(fltbuf_ins_ifparr_i),
        .fltbuf_ins_ifparr_tail_i(fltbuf_ins_ifparr_tail_i),
        .fltbuf_ins_fltsize_i(fltbuf_ins_fltsize_i),
        .fltbuf_ins_ifblock_i(fltbuf_ins_ifblock_i),
        .fltbuf_ins_ofparr_i(fltbuf_ins_ofparr_i),
        .fltbuf_ins_ofparr_tail_i(fltbuf_ins_ofparr_tail_i),
        .fltbuf_ins_oftiles_i(fltbuf_ins_oftiles_i),
        .fltbuf_ins_oftiles_tail_i(fltbuf_ins_oftiles_tail_i),
        .fltbuf_ins_iftiles_i(fltbuf_ins_iftiles_i),
        .fltbuf_ins_rdy_o(fltbuf_ins_rdy_o),
        .fltbuf_ins_height_i(ifbuf_ins_width_i),
        .zp(comp_ins_fltc_zp_i),

        .fltbuf_dma_rdycfg_i(fltbuf_dma_rdycfg_i),
        .fltbuf_dma_vld_i(fltbuf_dma_vld_i),
        .fltbuf_dma_data_i(fltbuf_dma_data_i),
        .fltbuf_dma_tlast_i(fltbuf_dma_tlast_i),
        .fltbuf_dma_vldcfg_o(fltbuf_dma_vldcfg_o),
        .fltbuf_dma_burst_o(fltbuf_dma_burst_o),
        .fltbuf_dma_baddr_o(fltbuf_dma_baddr_o),
        .fltbuf_dma_rdy_o(fltbuf_dma_rdy_o),

        .fltbuf_comp_rdy_i(fltbuf_comp_rdy_w),
        .fltbuf_comp_vld_o(fltbuf_comp_vld_w),
        .fltbuf_comp_data_o(fltbuf_comp_data_w),
        .fltbuf_comp_donepass_o(fltbuf_comp_donepass_w)
    );

    // =========================================================
    // COMPUTATION
    // =========================================================
    computation #(
        .WIDTH(DATA_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .PE_PER_PU(PE_PER_PU),
        .DEPTH(COMP_DEPTH),
        .K(K),
        .M(M),
        .PPDEPTH(PPDEPTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_computation (
        .clk(clk),
        .rst_n(rst_n),

        .comp_ins_hf_i(comp_ins_hf_reg),
        .comp_ins_stride_i(comp_ins_stride_reg),
        .comp_ins_padding_i(comp_ins_padding_reg),
        .comp_ins_ifc_zp_i(comp_ins_ifc_zp_reg),
        .comp_ins_fltc_zp_i(comp_ins_fltc_zp_reg),

        .comp_ifbuf_vld_i(ifbuf_comp_vld_buf_w),
        .comp_ifbuf_data_i(ifbuf_comp_data_buf_w),

        .comp_ifbuf_end_row_i(ifbuf_comp_end_row_buf_w),

        .comp_ifbuf_end_row_circle_i(ifbuf_comp_end_row_circle_buf_w),
        .comp_ifbuf_end_depth_i(ifbuf_comp_end_depth_buf_w),
        .comp_ifbuf_end_layer_i(ifbuf_comp_end_layer_buf_w),
        .comp_ifbuf_rdy_o(ifbuf_comp_rdy_buf_w),

        .comp_fltbuf_vld_i(fltbuf_comp_vld_w),
        .comp_fltbuf_data_i(fltbuf_comp_data_w),
        .comp_fltbuf_done_pass_i(fltbuf_comp_donepass_w),
        .comp_fltbuf_rdy_o(comp_fltbuf_rdy_w),

        .comp_ofbuf_rdy_i(comp_ofbuf_rdy_w),
        .comp_ofbuf_vld_o(comp_ofbuf_vld_w),
        .comp_ofbuf_data_o(comp_ofbuf_data_w),
        .comp_pa_done_compute_o(comp_pa_done_compute_o)
    );

    genvar gi;
    generate
        for (gi = 0; gi < M; gi = gi + 1) begin : gen_ofbuf_skid
            skid_buffer #(
                .SBUF_TYPE(0),
                .DATA_WIDTH(ACC_WIDTH)
            ) u_skid_ofbuf (
                .clk(clk),
                .rst_n(rst_n),

                .bwd_data_i (comp_ofbuf_data_w[gi*ACC_WIDTH +: ACC_WIDTH]),
                .bwd_valid_i(comp_ofbuf_vld_w[gi]),
                .fwd_ready_i(comp_ofbuf_rdy_i[gi]),

                .fwd_data_o (comp_ofbuf_data_o[gi*ACC_WIDTH +: ACC_WIDTH]),
                .bwd_ready_o(comp_ofbuf_rdy_w[gi]),
                .fwd_valid_o(comp_ofbuf_vld_o[gi])
            );
        end
    endgenerate

endmodule

