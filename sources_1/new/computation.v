`timescale 1ns / 1ps

module computation #(
    // Parameters cho comp_pu
    parameter WIDTH         = 8,
    parameter ACC_WIDTH     = 32,
    parameter PE_PER_PU     = 12,
    parameter DEPTH         = 12,
    parameter K             = 8,
    parameter M             = 2,
    parameter PPDEPTH       = 640,
    
    // Parameters bổ sung cho ifmap_cache
    parameter FIFO_DEPTH    = 12
)(
    input  clk,
    input  rst_n,

    // Tín hiệu Instruction (Dùng chung và riêng cho PU/Cache)
    input  [3:0]        comp_ins_hf_i,
    input  [2:0]        comp_ins_stride_i,
    input  [1:0]        comp_ins_padding_i,
    input  [WIDTH-1:0]  comp_ins_ifc_zp_i,
    input  [WIDTH-1:0]  comp_ins_fltc_zp_i,

    // Giao tiếp với Input Feature Map (ifbuf) - đi vào ifmap_cache
    input                   comp_ifbuf_vld_i,
    input  [K*WIDTH-1:0]    comp_ifbuf_data_i,
    input                   comp_ifbuf_end_row_i,
    input                   comp_ifbuf_end_row_circle_i,
    input                   comp_ifbuf_end_depth_i,
    input                   comp_ifbuf_end_layer_i,
    output                  comp_ifbuf_rdy_o,

    // Giao tiếp với Filter Buffer (fltbuf) - đi vào comp_pu (Đã mở rộng cho M PU)
    input  [K*M-1:0]        comp_fltbuf_vld_i,
    input  [K*M*WIDTH-1:0]  comp_fltbuf_data_i,
    input                   comp_fltbuf_done_pass_i, // Dùng chung
    output [M-1:0]          comp_fltbuf_rdy_o,

    // Giao tiếp với Output Buffer (ofbuf) - đi ra từ comp_pu (Đã mở rộng cho M PU)
    input  [M-1:0]          comp_ofbuf_rdy_i,
    output [M-1:0]          comp_ofbuf_vld_o,
    output [M*ACC_WIDTH-1:0] comp_ofbuf_data_o,
    
    // Tín hiệu báo xong - Lấy từ PU[0]
    output                  comp_pa_done_compute_o
);

    // ==========================================
    // Khai báo wire kết nối nội bộ giữa ifmap_cache và comp_pu
    // Có chèn skid_buffer giữa 2 khối
    // ==========================================
    localparam IFC_SBUF_WIDTH = K*WIDTH + 4;

    // Phía output của ifmap_cache -> input của skid_buffer
    wire [K*WIDTH-1:0]        ifc_cache_data_w;
    wire                      ifc_cache_vld_w;
    wire                      ifc_cache_rdy_w;
    wire                      ifc_cache_end_row_w;
    wire                      ifc_cache_end_row_circle_w;
    wire                      ifc_cache_end_depth_w;
    wire                      ifc_cache_end_layer_w;

    // Phía output của skid_buffer -> input của comp_pu
    wire [K*WIDTH-1:0]        ifc_pu_data_w;
    wire                      ifc_pu_vld_w;
    wire                      pu_ifc_rdy_w;
    wire                      ifc_pu_end_row_w;
    wire                      ifc_pu_end_row_circle_w;
    wire                      ifc_pu_end_depth_w;
    wire                      ifc_pu_end_layer_w;

    wire [IFC_SBUF_WIDTH-1:0] ifc_sbuf_bwd_data_w;
    wire [IFC_SBUF_WIDTH-1:0] ifc_sbuf_fwd_data_w;
    // Tín hiệu rdy và done compute gom từ các PU
    wire [M-1:0]        pu_ifc_rdy_m;
    wire [M-1:0]        pu_pa_done_compute_m;

    reg [3:0]           comp_ins_hf_reg;
    reg [2:0]           comp_ins_stride_reg;
    reg [1:0]           comp_ins_padding_reg;
    reg [WIDTH-1:0]     comp_ins_ifc_zp_reg;
    reg [WIDTH-1:0]     comp_ins_fltc_zp_reg;

    always @(posedge clk) begin
        comp_ins_hf_reg         <= comp_ins_hf_i;
        comp_ins_stride_reg     <= comp_ins_stride_i;
        comp_ins_padding_reg    <= comp_ins_padding_i;
        comp_ins_ifc_zp_reg     <= comp_ins_ifc_zp_i;
        comp_ins_fltc_zp_reg    <= comp_ins_fltc_zp_i;
    end
    // Chỉ báo rdy cho cache khi tất cả M PUs đều sẵn sàng
    assign pu_ifc_rdy_w = pu_ifc_rdy_m[0]; 
    
    // Gán tín hiệu done compute từ PU 0 ra ngoài theo yêu cầu
    assign comp_pa_done_compute_o = pu_pa_done_compute_m[0];

    // ==========================================
    // Instantiation: ifmap_cache
    // ==========================================
    ifmap_cache #(
        .DATA_WIDTH(WIDTH),      // Map WIDTH của hệ thống vào DATA_WIDTH
        .FIFO_DEPTH(FIFO_DEPTH),
        .K(K)
    ) ifmap_cache_inst (
        .clk(clk),
        .rst_n(rst_n),
        
        // Từ Instruction
        .ifc_ins_hf_i(comp_ins_hf_reg),
        .ifc_ins_stride_i(comp_ins_stride_reg),
        
        // Giao tiếp với IFBUF bên ngoài
        .ifc_ifbuf_data_i(comp_ifbuf_data_i),
        .ifc_ifbuf_end_row_i(comp_ifbuf_end_row_i),
        .ifc_ifbuf_end_row_circle_i(comp_ifbuf_end_row_circle_i),
        .ifc_ifbuf_end_depth_i(comp_ifbuf_end_depth_i),
        .ifc_ifbuf_end_layer_i(comp_ifbuf_end_layer_i),
        .ifc_ifbuf_vld_i(comp_ifbuf_vld_i),
        .ifc_ifbuf_rdy_o(comp_ifbuf_rdy_o),
        
        // Giao tiếp nội bộ với comp_pu qua skid_buffer
        .ifc_pu_rdy_i(ifc_cache_rdy_w),
        .ifc_pu_vld_o(ifc_cache_vld_w),
        .ifc_pu_data_o(ifc_cache_data_w),
        .ifc_pu_end_row_o(ifc_cache_end_row_w),
        .ifc_pu_end_row_circle_o(ifc_cache_end_row_circle_w),
        .ifc_pu_end_depth_o(ifc_cache_end_depth_w),
        .ifc_pu_end_layer_o(ifc_cache_end_layer_w)
    );

    assign ifc_sbuf_bwd_data_w = {
        ifc_cache_end_layer_w,
        ifc_cache_end_depth_w,
        ifc_cache_end_row_circle_w,
        ifc_cache_end_row_w,
        ifc_cache_data_w
    };

    skid_buffer #(
        .SBUF_TYPE(4),
        .DATA_WIDTH(IFC_SBUF_WIDTH)
    ) ifc_to_pu_skid_buffer_inst (
        .clk(clk),
        .rst_n(rst_n),
        .bwd_data_i(ifc_sbuf_bwd_data_w),
        .bwd_valid_i(ifc_cache_vld_w),
        .fwd_ready_i(pu_ifc_rdy_w),
        .fwd_data_o(ifc_sbuf_fwd_data_w),
        .bwd_ready_o(ifc_cache_rdy_w),
        .fwd_valid_o(ifc_pu_vld_w)
    );

    assign {
        ifc_pu_end_layer_w,
        ifc_pu_end_depth_w,
        ifc_pu_end_row_circle_w,
        ifc_pu_end_row_w,
        ifc_pu_data_w
    } = ifc_sbuf_fwd_data_w;

    // ==========================================
    // Instantiation: M comp_pu modules
    // ==========================================
    wire [M-1:0]    pu_comp_vld_o;
    wire [M-1:0]    pu_swap_fltc_o;
    wire            pu_comp_vld_i;
    assign pu_comp_vld_i = |pu_comp_vld_o;
    genvar i;
    generate
        for (i = 0; i < M; i = i + 1) begin : gen_comp_pu
            comp_pu #(
                .WIDTH(WIDTH),
                .ACC_WIDTH(ACC_WIDTH),
                .PE_PER_PU(PE_PER_PU),
                .DEPTH(DEPTH),
                .K(K),
                .PPDEPTH(PPDEPTH)
            ) comp_pu_inst (
                .clk(clk),
                .rst_n(rst_n),

                .pu_ins_hf_i(comp_ins_hf_reg),
                .pu_ins_stride_i(comp_ins_stride_reg),
                .pu_ins_padding_i(comp_ins_padding_reg),
                .pu_ins_ifc_zp_i(comp_ins_ifc_zp_reg),
                .pu_ins_fltc_zp_i(comp_ins_fltc_zp_reg),
                
                // Giao tiếp nội bộ với ifmap_cache (Chung cho tất cả PU)
                .pu_ifc_end_row_circle_i(ifc_pu_end_row_circle_w),
                .pu_ifc_end_row_i(ifc_pu_end_row_w), 
                .pu_ifc_end_depth_i(ifc_pu_end_depth_w),
                .pu_ifc_end_layer_i(ifc_pu_end_layer_w),
                .pu_ifc_vld_i(ifc_pu_vld_w),
                .pu_ifc_data_i(ifc_pu_data_w),
                
                
                // Tín hiệu RDY trả về cho cache (Tách riêng để đưa vào mảng AND)
                .pu_ifc_rdy_o(pu_ifc_rdy_m[i]),
                
                // Giao tiếp với FLTBUF bên ngoài (Phần riêng)
                .pu_fltbuf_vld_i(comp_fltbuf_vld_i[i*K +: K]),
                .pu_fltbuf_data_i(comp_fltbuf_data_i[i*K*WIDTH +: K*WIDTH]),
                .pu_fltbuf_done_pass_i(comp_fltbuf_done_pass_i), // Dùng chung
                .pu_fltbuf_rdy_o(comp_fltbuf_rdy_o[i]),
                
                .pu_swap_fltc_i(pu_swap_fltc_o[0]),
                .pu_swap_fltc_o(pu_swap_fltc_o[i]),
                .pu_comp_vld_o(pu_comp_vld_o[i]),
                .pu_comp_vld_i(pu_comp_vld_i),
                // Giao tiếp với OFBUF bên ngoài (Phần riêng)
                .pu_ofbuf_rdy_i(comp_ofbuf_rdy_i[i]),
                .pu_ofbuf_vld_o(comp_ofbuf_vld_o[i]),
                .pu_ofbuf_data_o(comp_ofbuf_data_o[(i+1)*ACC_WIDTH-1 : i*ACC_WIDTH]),
                
                // Tín hiệu done (Xuất ra mảng rồi lấy phần tử 0)
                .pu_pa_done_compute_o(pu_pa_done_compute_m[i])
            );
        end
    endgenerate
    (* keep = "false" *) wire _unused_sink; 
    
    assign _unused_sink = &{
        1'b0,                                                               // Pad to ensure reduction AND works cleanly
        pu_pa_done_compute_m[1],                                             // Unused bit 0
        pu_ifc_rdy_m[M-1:1],
        pu_swap_fltc_o[M-1:1]
    };
endmodule