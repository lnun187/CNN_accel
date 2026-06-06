`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/04/2026 03:14:49 PM
// Design Name: 
// Module Name: CNN_accel_tb
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


module CNN_accel_tb;
  localparam int WIDTH      = 8;
  localparam int DATA_WIDTH = WIDTH;
  localparam int ACC_WIDTH  = 32;
  localparam int K          = 4;
  localparam int M          = 2;

  localparam int MAX_MEM = 1151040;
  localparam int MAX_W   = 224;
  localparam int MAX_H   = 224;
  localparam int MAX_C   = 500;
  localparam int MAX_F   = 256;
  localparam int MAX_KSZ = 16;
  localparam int MAX_OUT = 65536;
  localparam int MAX_LAYERS_TB = 128;
  localparam int BASE_ALIGN = 64;


  // =========================================================
  // Clock / reset
  // =========================================================
  logic clk;
  logic rst_n;

  // =========================================================
  // DUT inputs / outputs
  // =========================================================
  // TABLE instruction interface to CNN_accel/layer_info
  logic                               cnn_table_vld_i;
  wire                                cnn_table_rdy_o;
  logic           [7:0]               cnn_table_ifheight_i;
  logic           [10:0]              cnn_table_ifchannel_i;
  logic           [10:0]              cnn_table_ofchannel_i;
  logic           [3:0]               cnn_table_hf_i;
  logic           [2:0]               cnn_table_stride_i;
  logic           [1:0]               cnn_table_padding_i;
  logic           [2:0]               cnn_table_ifparr_i;
  logic           [2:0]               cnn_table_oftile_i;
  logic           [4:0]               cnn_table_ofparr_i;
  logic           [23:0]              cnn_table_ifbaddr_i;
  logic           [23:0]              cnn_table_fltbaddr_i;
  logic           [23:0]              cnn_table_bias_baddr_i;
  logic           [23:0]              cnn_table_ofbaddr_i;
  logic signed    [DATA_WIDTH-1:0]    cnn_table_ifc_zp_i;
  logic signed    [DATA_WIDTH-1:0]    cnn_table_fltc_zp_i;
  logic signed    [31:0]              cnn_table_mult_i;
  logic           [5:0]               cnn_table_mult_shift_i;
  logic signed    [31:0]              cnn_table_alphamult_i;
  logic           [5:0]               cnn_table_alphamult_shift_i;
  logic signed    [7:0]               cnn_table_zpy_i;
  logic signed    [7:0]               cnn_table_qmin_i;
  logic signed    [7:0]               cnn_table_qmax_i;
  logic                               cnn_table_is_leaky_ReLU_i;
  logic                               cnn_table_is_use_pool_i;
  logic                               cnn_table_is_max_pool_i;
  logic           [4:0]               cnn_table_pool_size_i;
  logic                               cnn_table_is_stride_over_i;

  logic                  cnn_ifbuf_dma_rdycfg_i;
  logic                  cnn_ifbuf_dma_vld_i;
  logic [DATA_WIDTH-1:0] cnn_ifbuf_dma_data_i;
  logic                  cnn_ifbuf_dma_tlast_i;
  wire                   cnn_ifbuf_dma_vldcfg_o;
  wire [7:0]             cnn_ifbuf_dma_burst_o;
  wire [23:0]            cnn_ifbuf_dma_baddr_o;
  wire                   cnn_ifbuf_dma_rdy_o;

  logic                  cnn_fltbuf_dma_rdycfg_i;
  logic                  cnn_fltbuf_dma_vld_i;
  logic [DATA_WIDTH-1:0] cnn_fltbuf_dma_data_i;
  logic                  cnn_fltbuf_dma_tlast_i;
  wire                   cnn_fltbuf_dma_vldcfg_o;
  wire [9:0]             cnn_fltbuf_dma_burst_o;
  wire [23:0]            cnn_fltbuf_dma_baddr_o;
  wire                   cnn_fltbuf_dma_rdy_o;

  logic                  cnn_bias_dma_rdycfg_i;
  wire                   cnn_bias_dma_vldcfg_o;
  wire [6:0]             cnn_bias_dma_burst_o;
  wire [23:0]            cnn_bias_dma_baddr_o;
  logic                  cnn_bias_dma_vld_i;
  logic           [7:0]     cnn_bias_dma_data_i;
  logic                  cnn_bias_dma_tlast_i;
  wire                   cnn_bias_dma_rdy_o;

  logic                  cnn_ofbuf_dma_rdycfg_i;
  wire                   cnn_ofbuf_dma_vldcfg_o;
  wire [7:0]             cnn_ofbuf_dma_burst_o;
  wire [23:0]            cnn_ofbuf_dma_baddr_o;
  wire                   cnn_ofbuf_dma_vld_o;
  wire [DATA_WIDTH-1:0]  cnn_ofbuf_dma_data_o;
  wire                   cnn_ofbuf_dma_tlast_o;
  logic                  cnn_ofbuf_dma_rdy_i;

  // =========================================================
  // CNN CPU control interface
  // =========================================================
  wire                   cnn_cpu_accel_busy_o;
  logic                  cnn_cpu_accel_start_i;
  wire                   cnn_cpu_accel_done_o;
  logic                  cnn_cpu_receive_interupt_i;

  // =========================================================
  // External memories + scoreboard memories
  // =========================================================
  logic [DATA_WIDTH-1:0] if_ext_mem  [0:MAX_MEM-1];
  logic [DATA_WIDTH-1:0] flt_ext_mem [0:MAX_MEM-1];
  logic           [7:0]     bias_ext_mem[0:MAX_MEM-1];
  logic [DATA_WIDTH-1:0] of_ext_mem  [0:MAX_MEM-1];
  logic [ACC_WIDTH-1:0]  exp_out_mem [0:MAX_OUT-1];
  logic [ACC_WIDTH-1:0]  act_out_mem [0:MAX_OUT-1];
  logic [M*WIDTH-1:0] exp_pkt_mem [0:MAX_OUT-1];
  logic [M*WIDTH-1:0] act_pkt_mem [0:MAX_OUT-1];
  logic [M-1:0]           exp_vld_mem [0:MAX_OUT-1];
  logic [M-1:0]           act_vld_mem [0:MAX_OUT-1];

  int current_if_words;
  int current_flt_words;
  int current_bias_words;
  int exp_out_count;
  int act_out_count;
  int exp_pkt_count;
  int act_pkt_count;

  int current_if_base;
  int current_flt_base;
  int current_bias_base;
  int current_of_base;
  int current_w;
  int current_h;
  int current_ci;
  int current_co;
  int current_kw;
  int current_kh;
  int current_stride;
  int current_padding;
  int current_ifparr;
  int current_ofparr;
  int current_oftile;
  int current_ifc_zp;
  int current_fltc_zp;
  int current_mult;
  int current_mult_shift;
  int current_alphamult;
  int current_alphamult_shift;
  int current_zpy;
  int current_qmin;
  int current_qmax;
  int current_is_leaky_relu;
  int current_is_use_pool;
  int current_is_max_pool;
  int current_pool_size;
  int current_pool_stride;
  int current_is_stride_over;

  // =========================================================
  // Multi-layer testcase description storage
  // =========================================================
  string layer_name       [0:MAX_LAYERS_TB-1];
  int    layer_w          [0:MAX_LAYERS_TB-1];
  int    layer_h          [0:MAX_LAYERS_TB-1];
  int    layer_ci         [0:MAX_LAYERS_TB-1];
  int    layer_co         [0:MAX_LAYERS_TB-1];
  int    layer_kw         [0:MAX_LAYERS_TB-1];
  int    layer_kh         [0:MAX_LAYERS_TB-1];
  int    layer_stride     [0:MAX_LAYERS_TB-1];
  int    layer_padding    [0:MAX_LAYERS_TB-1];
  int    layer_ifparr     [0:MAX_LAYERS_TB-1];
  int    layer_ofparr     [0:MAX_LAYERS_TB-1];
  int    layer_oftile     [0:MAX_LAYERS_TB-1];
  int    layer_if_zp      [0:MAX_LAYERS_TB-1];
  int    layer_fl_zp      [0:MAX_LAYERS_TB-1];
  int    layer_is_use_pool[0:MAX_LAYERS_TB-1];
  int    layer_is_max_pool[0:MAX_LAYERS_TB-1];
  int    layer_pool_size  [0:MAX_LAYERS_TB-1];
  int    layer_pool_stride[0:MAX_LAYERS_TB-1];
  int    layer_is_stride_over[0:MAX_LAYERS_TB-1];
  int    layer_if_base    [0:MAX_LAYERS_TB-1];
  int    layer_flt_base   [0:MAX_LAYERS_TB-1];
  int    layer_bias_base  [0:MAX_LAYERS_TB-1];
  int    layer_of_base    [0:MAX_LAYERS_TB-1];
  int    layer_if_words   [0:MAX_LAYERS_TB-1];
  int    layer_flt_words  [0:MAX_LAYERS_TB-1];
  int    layer_bias_words [0:MAX_LAYERS_TB-1];
  int    layer_of_words   [0:MAX_LAYERS_TB-1];
  int    layer_exp_rows   [0:MAX_LAYERS_TB-1];
  int    layer_exp_values [0:MAX_LAYERS_TB-1];
  int    num_loaded_layers;

  // =========================================================
  // Helpers
  // =========================================================
  function automatic int min2(input int a, input int b);
    return (a < b) ? a : b;
  endfunction

  function automatic int ceil_div(input int a, input int b);
    return (a + b - 1) / b;
  endfunction

  function automatic int align_even(input int x);
    return (x % 2 == 0) ? x : (x + 1);
  endfunction

  function automatic int align_base(input int x);
    return ((x + BASE_ALIGN - 1) / BASE_ALIGN) * BASE_ALIGN;
  endfunction

  function automatic int calc_of_h(
    input int h,
    input int kh,
    input int stride,
    input int padding
  );
    return (h + 2 * padding - kh) / stride + 1;
  endfunction

  function automatic int calc_of_w(
    input int w,
    input int kw,
    input int stride,
    input int padding
  );
    return (w + 2 * padding - kw) / stride + 1;
  endfunction

  function automatic int calc_pool_out_dim(
    input int of_width,
    input int is_use_pool,
    input int pool_size,
    input int pool_stride,
    input int is_stride_over
  );
    int pool_num;
    int pool_den;
    begin
      if (!is_use_pool) begin
        return of_width;
      end

      if (pool_size <= 0) begin
        return of_width;
      end

      pool_den = pool_stride;
      if (pool_den <= 0) begin
        pool_den = 1;
      end

      pool_num = is_stride_over ? of_width : (of_width - 1);
      if (pool_num < 0) begin
        pool_num = 0;
      end

      return ceil_div(pool_num, pool_den);
    end
  endfunction

  function automatic int calc_if_words(
    input int w,
    input int h,
    input int ci
  );
    return align_even(w) * h * ci;
  endfunction

  function automatic int calc_of_words(
    input int w,
    input int h,
    input int co,
    input int kw,
    input int kh,
    input int stride,
    input int padding
  );
    int ho;
    int wo;
    begin
      ho = calc_of_h(h, kh, stride, padding);
      wo = calc_of_w(w, kw, stride, padding);
      ho = calc_pool_out_dim(ho, current_is_use_pool, current_pool_size,
                             current_pool_stride, current_is_stride_over);
      wo = calc_pool_out_dim(wo, current_is_use_pool, current_pool_size,
                             current_pool_stride, current_is_stride_over);
      return co * ho * align_even(wo);
    end
  endfunction

  function automatic int derive_is_stride_over(
    input string tc_name,
    input int pool_size,
    input int pool_stride
  );
    begin
      if (pool_size == pool_stride) begin
        return 1;
      end
      if (pool_size == (pool_stride + 1)) begin
        return 0;
      end
      $fatal(1, "%s: invalid pooling stride relation. Need pool_size == pool_stride or pool_size == pool_stride + 1, got pool_size=%0d pool_stride=%0d",
             tc_name, pool_size, pool_stride);
      return 0;
    end
  endfunction

  task automatic check_mem_range(
    input string tc_name,
    input string mem_name,
    input int    base_addr,
    input int    words
  );
    begin
      if (words < 0) begin
        $fatal(1, "%s: %s negative word count=%0d", tc_name, mem_name, words);
      end
      if ((base_addr < 0) || ((base_addr + words) > MAX_MEM)) begin
        $fatal(1, "%s: %s memory range overflow base=%0d words=%0d MAX_MEM=%0d",
               tc_name, mem_name, base_addr, words, MAX_MEM);
      end
    end
  endtask

  task automatic clear_table_interface();
    begin
      cnn_table_vld_i = 1'b0;
      cnn_table_ifheight_i = '0;
      cnn_table_ifchannel_i = '0;
      cnn_table_ofchannel_i = '0;
      cnn_table_hf_i = '0;
      cnn_table_stride_i = '0;
      cnn_table_padding_i = '0;
      cnn_table_ifparr_i = '0;
      cnn_table_oftile_i = '0;
      cnn_table_ofparr_i = '0;
      cnn_table_ifbaddr_i = '0;
      cnn_table_fltbaddr_i = '0;
      cnn_table_bias_baddr_i = '0;
      cnn_table_ofbaddr_i = '0;
      cnn_table_ifc_zp_i = '0;
      cnn_table_fltc_zp_i = '0;
      cnn_table_mult_i = '0;
      cnn_table_mult_shift_i = '0;
      cnn_table_alphamult_i = '1;
      cnn_table_alphamult_shift_i = '0;
      cnn_table_zpy_i = '0;
      cnn_table_qmin_i = -128;
      cnn_table_qmax_i = 127;
      cnn_table_is_leaky_ReLU_i = 1'b1;
      cnn_table_is_use_pool_i = 1'b0;
      cnn_table_is_max_pool_i = 1'b0;
      cnn_table_pool_size_i = 5'd1;
      cnn_table_is_stride_over_i = 1'b1;
    end
  endtask

  task automatic program_table_instruction(
    input string tc_name,
    input int    w,
    input int    h,
    input int    ci,
    input int    co,
    input int    kw,
    input int    kh,
    input int    stride,
    input int    padding,
    input int    ifparr,
    input int    ofparr,
    input int    oftile
  );
    begin
      if (w != h) begin
        $fatal(1, "%s: table interface has one ifheight/ifwidth value, but w=%0d h=%0d", tc_name, w, h);
      end
      if (kw != kh) begin
        $fatal(1, "%s: table interface has only one hf field, but kw=%0d kh=%0d", tc_name, kw, kh);
      end
      if (h > 255) begin
        $fatal(1, "%s: h=%0d exceeds cnn_table_ifheight_i[7:0]", tc_name, h);
      end
      if (ci > 2047) begin
        $fatal(1, "%s: ci=%0d exceeds cnn_table_ifchannel_i[10:0]", tc_name, ci);
      end
      if (co > 2047) begin
        $fatal(1, "%s: co=%0d exceeds cnn_table_ofchannel_i[10:0]", tc_name, co);
      end
      if (ifparr > 7) begin
        $fatal(1, "%s: ifparr=%0d exceeds cnn_table_ifparr_i[2:0]", tc_name, ifparr);
      end
      if (oftile > 7) begin
        $fatal(1, "%s: oftile=%0d exceeds cnn_table_oftile_i[2:0]", tc_name, oftile);
      end
      if (ofparr > 31) begin
        $fatal(1, "%s: ofparr=%0d exceeds cnn_table_ofparr_i[4:0]", tc_name, ofparr);
      end

      // Direct table interface: no LUT encoding is used here.
      cnn_table_ifheight_i         = h[7:0];
      cnn_table_ifchannel_i        = ci[10:0];
      cnn_table_ofchannel_i        = co[10:0];
      cnn_table_hf_i               = kh[3:0];
      cnn_table_stride_i           = stride[2:0];
      cnn_table_padding_i          = padding[1:0];
      cnn_table_ifparr_i           = ifparr[2:0];
      cnn_table_oftile_i           = oftile[2:0];
      cnn_table_ofparr_i           = ofparr[4:0];
      cnn_table_ifbaddr_i          = current_if_base[23:0];
      cnn_table_fltbaddr_i         = current_flt_base[23:0];
      cnn_table_bias_baddr_i       = current_bias_base[23:0];
      cnn_table_ofbaddr_i          = current_of_base[23:0];
      cnn_table_ifc_zp_i           = current_ifc_zp[DATA_WIDTH-1:0];
      cnn_table_fltc_zp_i          = current_fltc_zp[DATA_WIDTH-1:0];
      cnn_table_mult_i             = current_mult;
      cnn_table_mult_shift_i       = current_mult_shift[5:0];
      cnn_table_alphamult_i        = current_alphamult;
      cnn_table_alphamult_shift_i  = current_alphamult_shift[5:0];
      cnn_table_zpy_i              = current_zpy[7:0];
      cnn_table_qmin_i             = current_qmin[7:0];
      cnn_table_qmax_i             = current_qmax[7:0];
      cnn_table_is_leaky_ReLU_i    = current_is_leaky_relu[0];
      cnn_table_is_use_pool_i      = current_is_use_pool[0];
      cnn_table_is_max_pool_i      = current_is_max_pool[0];
      cnn_table_pool_size_i        = current_pool_size[4:0];
      cnn_table_is_stride_over_i   = current_is_stride_over[0];
    end
  endtask

  // Input ifmap/filter duoc quantize theo WIDTH bit.
  // Ifmap dùng đúng pattern init_memory: c*10000 + h*100 + w
  function automatic logic [WIDTH-1:0] mk_if_val(input int c, input int h, input int w);
    // return c * 10000 + h * 100 + w;
    return c+h+w;
  endfunction

  function automatic logic [WIDTH-1:0] mk_flt_val(input int f, input int c, input int h, input int w);
    // return {f * 1000000 + c * 10000 + h * 100 + w};
    return f+c+h+w;
  endfunction

  function automatic logic signed [31:0] mk_bias_val(input int f);
    int signed tmp;
    begin
      // Small signed bias pattern, deterministic per output channel.
      tmp = f % 2 ? f : -f;
      return tmp;
    end
  endfunction

  function automatic longint signed arshift(
    input longint signed value,
    input int shift
  );
    longint signed bias;

    begin
      if (shift <= 0) begin
        return value;
      end

      bias = 64'sd1 <<< (shift - 1);

      if (value < 0) begin
        return (value + bias - 64'sd1) >>> shift;
      end else begin
        return (value + bias) >>> shift;
      end
    end
  endfunction

  function automatic logic [ACC_WIDTH-1:0] apply_output_pipeline(
    input longint signed mac_acc,
    input int co_idx
  );
    longint signed with_bias;
    longint signed scaled;
    longint signed activated;
    longint signed shifted_zp;
    longint signed clamped;
    begin
      // Expected datapath:
      // MAC + bias -> scale -> ReLU/LeakyReLU -> +zpy -> clamp.

      with_bias = mac_acc + $signed(mk_bias_val(co_idx));

      // Main quantization scale always happens first.
      scaled = arshift(with_bias * current_mult,
                       current_mult_shift);

      // Activation is applied after main scale.
      if (scaled < 0) begin
        if (current_is_leaky_relu) begin
          activated = arshift(scaled * current_alphamult,
                              current_alphamult_shift);
        end else begin
          activated = 0;
        end
      end else begin
        activated = scaled;
      end

      shifted_zp = activated + current_zpy;

      if (shifted_zp < current_qmin) begin
        clamped = current_qmin;
      end else if (shifted_zp > current_qmax) begin
        clamped = current_qmax;
      end else begin
        clamped = shifted_zp;
      end

      return clamped[ACC_WIDTH-1:0];
    end
  endfunction

  task automatic clear_all_memories();
    int i;
    begin
      for (i = 0; i < MAX_MEM; i++) begin
        if_ext_mem[i]   = '0;
        flt_ext_mem[i]  = '0;
        bias_ext_mem[i] = '0;
        of_ext_mem[i]   = '0;
      end
      for (i = 0; i < MAX_OUT; i++) begin
        exp_out_mem[i] = '0;
        act_out_mem[i] = '0;
        exp_pkt_mem[i] = '0;
        act_pkt_mem[i] = '0;
        exp_vld_mem[i] = '0;
        act_vld_mem[i] = '0;
      end
      current_if_words = 0;
      current_flt_words = 0;
      current_bias_words = 0;
      exp_out_count = 0;
      act_out_count = 0;
      exp_pkt_count = 0;
      act_pkt_count = 0;
      current_ifc_zp = 0;
      current_fltc_zp = 0;
      current_mult = 1;
      current_mult_shift = 0;
      current_alphamult = 1;
      current_alphamult_shift = 0;
      current_zpy = 0;
      current_qmin = -128;
      current_qmax = 127;
      current_is_leaky_relu = 1;
      current_is_use_pool = 0;
      current_is_max_pool = 0;
      current_pool_size = 1;
      current_pool_stride = 1;
      current_is_stride_over = 1;
    end
  endtask

  task automatic apply_reset();
    begin
      rst_n = 1'b0;
      clear_table_interface();
      cnn_cpu_accel_start_i = 1'b0;
      cnn_cpu_receive_interupt_i = 1'b0;
      cnn_ifbuf_dma_vld_i = 1'b0;
      cnn_fltbuf_dma_vld_i = 1'b0;
      cnn_bias_dma_vld_i = 1'b0;
      cnn_ifbuf_dma_data_i = '0;
      cnn_fltbuf_dma_data_i = '0;
      cnn_bias_dma_data_i = '0;
      cnn_ifbuf_dma_tlast_i = 1'b0;
      cnn_fltbuf_dma_tlast_i = 1'b0;
      cnn_bias_dma_tlast_i = 1'b0;
      cnn_ofbuf_dma_rdycfg_i = 1'b0;
      cnn_ofbuf_dma_rdy_i    = 1'b0;
      repeat (8) @(posedge clk);
      rst_n = 1'b1;
      repeat (4) @(posedge clk);
    end
  endtask

  // ifmap memory layout:
  // addr = base + c*(h*align_w) + row*align_w + col
  // Giữ nguyên ý user: init memory trước, DMA chỉ đọc lại từ memory đã init.
  task automatic fill_ifmap_external_memory(
    input int base_addr,
    input int w,
    input int h,
    input int ci
  );
    int c_idx, h_idx, w_idx;
    int addr;
    int align_w;
    begin
      align_w = align_even(w);
      for (c_idx = 0; c_idx < ci; c_idx++) begin
        for (h_idx = 0; h_idx < h; h_idx++) begin
          for (w_idx = 0; w_idx < align_w; w_idx++) begin
            addr = base_addr + c_idx * (h * align_w) + h_idx * align_w + w_idx;
            if (w_idx < w) begin
              if_ext_mem[addr] = mk_if_val(c_idx, h_idx, w_idx);
            end else begin
              if_ext_mem[addr] = {WIDTH{1'b1}};
            end
          end
        end
      end
      current_if_words = align_w * h * ci;
    end
  endtask

  // filter memory layout:
  // group channel = oftile * ofparr
  // trong moi group: cg block -> f_tile
  // moi f_tile la 1 burst rieng, add one padding word if burst is odd
    task automatic fill_filter_external_memory(
    input int base_addr,
    input int kw,
    input int kh,
    input int ci,
    input int co,
    input int ifparr,
    input int ofparr
  );
    int addr;
    int cg;
    int cp;
    int c_local, h_idx, w_idx;

    int total_cols;
    int full_cols;
    int tail_slots;

    int lane_rows [0:M-1];
    int lane_count[0:M-1];
    int lane_base [0:M-1];

    int lane;
    int r;
    int group_start;
    int group_cols;
    int col_in_group;
    int idx_in_lane;
    int filter_idx;

    int block_id;
    int block_real;
    int red_need [0:4-1];
    int remain_in_block;

    int slot_ch [0:M-1][0:24-1][0:4-1];

    int lane_seq      [0:M-1][0:MAX_F-1];
    int lane_seq_used [0:M-1][0:MAX_F-1];
    int lane_seq_count[0:M-1];

    int seq_pos;
    int need;
    int placed;

    int burst_filters[0:MAX_F-1];
    int burst_filter_count;
    int burst_width;

    begin
      addr = base_addr;

      total_cols = ceil_div(co, ofparr);
      full_cols  = co / ofparr;
      tail_slots = co % ofparr;

      for (lane = 0; lane < M; lane++) begin
        lane_rows[lane] = 0;
        for (r = lane; r < ofparr; r += M) begin
          lane_rows[lane]++;
        end
      end

      for (lane = 0; lane < M; lane++) begin
        lane_count[lane] = full_cols * lane_rows[lane];

        if (tail_slots > lane) begin
          lane_count[lane] += ceil_div(tail_slots - lane, M);
        end
      end

      lane_base[0] = 0;
      for (lane = 1; lane < M; lane++) begin
        lane_base[lane] = lane_base[lane-1] + lane_count[lane-1];
      end

      // =====================================================
      // 1 block = oftile * ofparr.
      // Trong 1 block:
      //   red_arrow_0 fill toi da ofparr
      //   red_arrow_1 fill toi da ofparr
      //   ...
      //   red_arrow cuoi co the bi tail.
      // =====================================================
      for (group_start = 0;
           group_start < total_cols;
           group_start += current_oftile) begin

        group_cols = min2(current_oftile, total_cols - group_start);
        block_id   = group_start / current_oftile;

        block_real = co - block_id * current_oftile * ofparr;
        if (block_real > current_oftile * ofparr) begin
          block_real = current_oftile * ofparr;
        end
        if (block_real < 0) begin
          block_real = 0;
        end

        remain_in_block = block_real;
        for (col_in_group = 0; col_in_group < group_cols; col_in_group++) begin
          red_need[col_in_group] = min2(ofparr, remain_in_block);
          remain_in_block -= red_need[col_in_group];
        end

        // Clear slot map.
        for (lane = 0; lane < M; lane++) begin
          for (r = 0; r < 24; r++) begin
            for (col_in_group = 0; col_in_group < 4; col_in_group++) begin
              slot_ch[lane][r][col_in_group] = -1;
            end
          end
        end

        // Build lane-local sequence in GREEN order for this block.
        for (lane = 0; lane < M; lane++) begin
          lane_seq_count[lane] = 0;

          for (r = 0; r < lane_rows[lane]; r++) begin
            for (col_in_group = 0; col_in_group < group_cols; col_in_group++) begin
              idx_in_lane =
                lane_base[lane]
                + lane_rows[lane] * group_start
                + r * group_cols
                + col_in_group;

              if (idx_in_lane < lane_base[lane] + lane_count[lane]) begin
                if (idx_in_lane < co) begin
                  lane_seq[lane][lane_seq_count[lane]] = idx_in_lane;
                  lane_seq_used[lane][lane_seq_count[lane]] = 0;
                  lane_seq_count[lane]++;
                end
              end
            end
          end
        end

        // First pass:
        // place natural row/col positions, but each red_arrow only up to red_need.
        for (col_in_group = 0; col_in_group < group_cols; col_in_group++) begin
          need = red_need[col_in_group];

          for (lane = 0; lane < M; lane++) begin
            for (r = 0; r < lane_rows[lane]; r++) begin
              if (need > 0) begin
                seq_pos = r * group_cols + col_in_group;

                if (seq_pos < lane_seq_count[lane]) begin
                  if (lane_seq_used[lane][seq_pos] == 0) begin
                    slot_ch[lane][r][col_in_group] = lane_seq[lane][seq_pos];
                    lane_seq_used[lane][seq_pos] = 1;
                    need--;
                  end
                end
              end
            end
          end

          // Second pass:
          // if this red_arrow has not reached ofparr yet,
          // compact remaining filters into this red_arrow.
          while (need > 0) begin
            placed = 0;

            for (lane = 0; lane < M; lane++) begin
              for (seq_pos = 0; seq_pos < lane_seq_count[lane]; seq_pos++) begin
                if ((need > 0) && (placed == 0)) begin
                  if (lane_seq_used[lane][seq_pos] == 0) begin
                    for (r = 0; r < lane_rows[lane]; r++) begin
                      if ((placed == 0) &&
                          (slot_ch[lane][r][col_in_group] < 0)) begin
                        slot_ch[lane][r][col_in_group] = lane_seq[lane][seq_pos];
                        lane_seq_used[lane][seq_pos] = 1;
                        need--;
                        placed = 1;
                      end
                    end
                  end
                end
              end
            end

            if (placed == 0) begin
              need = 0;
            end
          end
        end

        // Write filter external memory:
        // for block
        //   for cg
        //     for red_arrow_col in block
        for (cg = 0; cg < ci; cg += ifparr) begin
          cp = min2(ifparr, ci - cg);

          for (col_in_group = 0; col_in_group < group_cols; col_in_group++) begin
            burst_filter_count = 0;

            for (lane = 0; lane < M; lane++) begin
              for (r = 0; r < lane_rows[lane]; r++) begin
                filter_idx = slot_ch[lane][r][col_in_group];

                if ((filter_idx >= 0) && (filter_idx < co)) begin
                  burst_filters[burst_filter_count] = filter_idx;
                  burst_filter_count++;
                end
              end
            end

            for (int bf = 0; bf < burst_filter_count; bf++) begin
              filter_idx = burst_filters[bf];

              for (c_local = 0; c_local < cp; c_local++) begin
                for (h_idx = 0; h_idx < kh; h_idx++) begin
                  for (w_idx = 0; w_idx < kw; w_idx++) begin
                    flt_ext_mem[addr] = mk_flt_val(
                      filter_idx,
                      cg + c_local,
                      h_idx,
                      w_idx
                    );
                    addr++;
                  end
                end
              end
            end

            burst_width = kw * kh * cp * burst_filter_count;

            if ((burst_width % 2) != 0) begin
              flt_ext_mem[addr] = {WIDTH{1'b1}};
              addr++;
            end
          end
        end
      end

      current_flt_words = addr - base_addr;
    end
  endtask

  // Bias memory layout follows the same one-config/one-burst DMA handshake style
  // as filter DMA.  Payload order is head0 lanes first, then head1 lanes.
  // Each 32-bit bias value is stored as four consecutive 8-bit locations in
  // big-endian order: [31:24] at the lowest address, then [23:16], [15:8], [7:0].
  // No dummy/padding beat is needed because each bias always expands to 4 bytes.
    task automatic fill_bias_external_memory(
    input int base_addr,
    input int co,
    input int ofparr,
    input int oftile
  );
    int addr;

    int total_cols;
    int full_cols;
    int tail_slots;

    int lane_rows [0:M-1];
    int lane_count[0:M-1];
    int lane_base [0:M-1];

    int lane;
    int r;
    int group_start;
    int group_cols;
    int col_in_group;
    int idx_in_lane;
    int channel_idx;
    logic signed [31:0] bias_word;

    int block_id;
    int block_real;
    int red_need [0:4-1];
    int remain_in_block;

    int slot_ch [0:M-1][0:24-1][0:4-1];

    int lane_seq      [0:M-1][0:MAX_F-1];
    int lane_seq_used [0:M-1][0:MAX_F-1];
    int lane_seq_count[0:M-1];

    int seq_pos;
    int need;
    int placed;

    begin
      addr = base_addr;

      total_cols = ceil_div(co, ofparr);
      full_cols  = co / ofparr;
      tail_slots = co % ofparr;

      for (lane = 0; lane < M; lane++) begin
        lane_rows[lane] = 0;
        for (r = lane; r < ofparr; r += M) begin
          lane_rows[lane]++;
        end
      end

      for (lane = 0; lane < M; lane++) begin
        lane_count[lane] = full_cols * lane_rows[lane];

        if (tail_slots > lane) begin
          lane_count[lane] += ceil_div(tail_slots - lane, M);
        end
      end

      lane_base[0] = 0;
      for (lane = 1; lane < M; lane++) begin
        lane_base[lane] = lane_base[lane-1] + lane_count[lane-1];
      end

      for (group_start = 0;
           group_start < total_cols;
           group_start += oftile) begin

        group_cols = min2(oftile, total_cols - group_start);
        block_id   = group_start / oftile;

        block_real = co - block_id * oftile * ofparr;
        if (block_real > oftile * ofparr) begin
          block_real = oftile * ofparr;
        end
        if (block_real < 0) begin
          block_real = 0;
        end

        remain_in_block = block_real;
        for (col_in_group = 0; col_in_group < group_cols; col_in_group++) begin
          red_need[col_in_group] = min2(ofparr, remain_in_block);
          remain_in_block -= red_need[col_in_group];
        end

        for (lane = 0; lane < M; lane++) begin
          for (r = 0; r < 24; r++) begin
            for (col_in_group = 0; col_in_group < 4; col_in_group++) begin
              slot_ch[lane][r][col_in_group] = -1;
            end
          end
        end

        for (lane = 0; lane < M; lane++) begin
          lane_seq_count[lane] = 0;

          for (r = 0; r < lane_rows[lane]; r++) begin
            for (col_in_group = 0; col_in_group < group_cols; col_in_group++) begin
              idx_in_lane =
                lane_base[lane]
                + lane_rows[lane] * group_start
                + r * group_cols
                + col_in_group;

              if (idx_in_lane < lane_base[lane] + lane_count[lane]) begin
                if (idx_in_lane < co) begin
                  lane_seq[lane][lane_seq_count[lane]] = idx_in_lane;
                  lane_seq_used[lane][lane_seq_count[lane]] = 0;
                  lane_seq_count[lane]++;
                end
              end
            end
          end
        end

        for (col_in_group = 0; col_in_group < group_cols; col_in_group++) begin
          need = red_need[col_in_group];

          for (lane = 0; lane < M; lane++) begin
            for (r = 0; r < lane_rows[lane]; r++) begin
              if (need > 0) begin
                seq_pos = r * group_cols + col_in_group;

                if (seq_pos < lane_seq_count[lane]) begin
                  if (lane_seq_used[lane][seq_pos] == 0) begin
                    slot_ch[lane][r][col_in_group] = lane_seq[lane][seq_pos];
                    lane_seq_used[lane][seq_pos] = 1;
                    need--;
                  end
                end
              end
            end
          end

          while (need > 0) begin
            placed = 0;

            for (lane = 0; lane < M; lane++) begin
              for (seq_pos = 0; seq_pos < lane_seq_count[lane]; seq_pos++) begin
                if ((need > 0) && (placed == 0)) begin
                  if (lane_seq_used[lane][seq_pos] == 0) begin
                    for (r = 0; r < lane_rows[lane]; r++) begin
                      if ((placed == 0) &&
                          (slot_ch[lane][r][col_in_group] < 0)) begin
                        slot_ch[lane][r][col_in_group] = lane_seq[lane][seq_pos];
                        lane_seq_used[lane][seq_pos] = 1;
                        need--;
                        placed = 1;
                      end
                    end
                  end
                end
              end
            end

            if (placed == 0) begin
              need = 0;
            end
          end
        end

        for (lane = 0; lane < M; lane++) begin
          for (r = 0; r < lane_rows[lane]; r++) begin
            for (col_in_group = 0; col_in_group < group_cols; col_in_group++) begin
              channel_idx = slot_ch[lane][r][col_in_group];

              if ((channel_idx >= 0) && (channel_idx < co)) begin
                bias_word = mk_bias_val(channel_idx);
                bias_ext_mem[addr + 0] = bias_word[31:24];
                bias_ext_mem[addr + 1] = bias_word[23:16];
                bias_ext_mem[addr + 2] = bias_word[15:8];
                bias_ext_mem[addr + 3] = bias_word[7:0];
                addr += 4;
              end
            end
          end
        end

      end

      current_bias_words = addr - base_addr;
    end
  endtask

  // Expected output order theo mo ta scale:
  // group channel = oftile * ofparr
  // trong moi group: h -> row_in_tile -> tile -> w
  // moi beat xuat {lane1, lane0}
    task automatic build_expected_output();
    logic [WIDTH-1:0] if_t [0:MAX_C-1][0:MAX_H-1][0:MAX_W-1];
    logic [WIDTH-1:0] flt_t[0:MAX_F-1][0:MAX_C-1][0:MAX_KSZ-1][0:MAX_KSZ-1];
    logic [WIDTH-1:0] of_t [0:MAX_F-1][0:MAX_H-1][0:MAX_W-1];
    logic [WIDTH-1:0] pool_t [0:MAX_F-1][0:MAX_H-1][0:MAX_W-1];

    logic [M*WIDTH-1:0] pkt_word;
    logic [M-1:0]       pkt_vld;

    longint signed acc;

    int co_idx, ci_idx, h_idx, w_idx;
    int oh, ow;
    int ho, wo;
    int pho, pwo;
    int ih, iw;
    int ph, pw;
    int py, px;
    int src_h, src_w;
    int pool_stride_eff;
    int signed pool_acc;
    int signed pool_max;
    int signed pool_val;
    int signed pooled;

    int total_cols;
    int full_cols;
    int tail_slots;

    int lane_rows [0:M-1];
    int lane_count[0:M-1];
    int lane_base [0:M-1];

    int lane;
    int r;
    int max_lane_rows;

    int group_start;
    int group_cols;
    int row_idx;
    int col_in_group;

    int idx_in_lane;
    int lane0_ch;
    int lane1_ch;

    logic signed [WIDTH:0]     if_val_adj;
    logic signed [WIDTH:0]     flt_val_adj;
    logic signed [2*WIDTH+1:0] mac_term;

    begin
      exp_out_count = 0;
      exp_pkt_count = 0;

      // =====================================================
      // Rebuild IF tensor
      // =====================================================
      for (ci_idx = 0; ci_idx < current_ci; ci_idx++) begin
        for (h_idx = 0; h_idx < current_h; h_idx++) begin
          for (w_idx = 0; w_idx < current_w; w_idx++) begin
            if_t[ci_idx][h_idx][w_idx] = mk_if_val(ci_idx, h_idx, w_idx);
          end
        end
      end

      // =====================================================
      // Rebuild FILTER tensor
      // =====================================================
      for (co_idx = 0; co_idx < current_co; co_idx++) begin
        for (ci_idx = 0; ci_idx < current_ci; ci_idx++) begin
          for (h_idx = 0; h_idx < current_kh; h_idx++) begin
            for (w_idx = 0; w_idx < current_kw; w_idx++) begin
              flt_t[co_idx][ci_idx][h_idx][w_idx] =
                mk_flt_val(co_idx, ci_idx, h_idx, w_idx);
            end
          end
        end
      end

      ho = (current_h + 2 * current_padding - current_kh) / current_stride + 1;
      wo = (current_w + 2 * current_padding - current_kw) / current_stride + 1;
      pool_stride_eff = current_is_stride_over ? current_pool_size : (current_pool_size - 1);
      if (pool_stride_eff <= 0) begin
        pool_stride_eff = 1;
      end
      pho = calc_pool_out_dim(ho, current_is_use_pool, current_pool_size,
                              current_pool_stride, current_is_stride_over);
      pwo = calc_pool_out_dim(wo, current_is_use_pool, current_pool_size,
                              current_pool_stride, current_is_stride_over);

      // =====================================================
      // Golden convolution value, unchanged
      // =====================================================
      for (co_idx = 0; co_idx < current_co; co_idx++) begin
        for (oh = 0; oh < ho; oh++) begin
          for (ow = 0; ow < wo; ow++) begin
            acc = 0;

            for (ci_idx = 0; ci_idx < current_ci; ci_idx++) begin
              for (h_idx = 0; h_idx < current_kh; h_idx++) begin
                for (w_idx = 0; w_idx < current_kw; w_idx++) begin
                  ih = oh * current_stride + h_idx - current_padding;
                  iw = ow * current_stride + w_idx - current_padding;

                  if ((ih >= 0) && (ih < current_h) &&
                      (iw >= 0) && (iw < current_w)) begin
                    if_val_adj =
                      $signed({if_t[ci_idx][ih][iw][WIDTH-1], if_t[ci_idx][ih][iw]})
                      - $signed((WIDTH+1)'(current_ifc_zp));

                    flt_val_adj =
                      $signed({flt_t[co_idx][ci_idx][h_idx][w_idx][WIDTH-1], flt_t[co_idx][ci_idx][h_idx][w_idx]})
                      - $signed((WIDTH+1)'(current_fltc_zp));

                    mac_term = if_val_adj * flt_val_adj;
                    acc += mac_term;
                  end
                end
              end
            end

            of_t[co_idx][oh][ow] = apply_output_pipeline(acc, co_idx);
          end
        end
      end

      // =====================================================
      // Golden pooling value. Pooling is applied after scale/ReLU.
      // For edge windows that run past the OFMAP width, only valid
      // source cells contribute; average mode still divides by pool_size^2,
      // matching max_avg_pooling.
      // =====================================================
      for (co_idx = 0; co_idx < current_co; co_idx++) begin
        for (ph = 0; ph < pho; ph++) begin
          for (pw = 0; pw < pwo; pw++) begin
            if (!current_is_use_pool) begin
              pool_t[co_idx][ph][pw] = of_t[co_idx][ph][pw];
            end else begin
              pool_acc = 0;
              pool_max = -128;

              for (py = 0; py < current_pool_size; py++) begin
                for (px = 0; px < current_pool_size; px++) begin
                  src_h = ph * pool_stride_eff + py;
                  src_w = pw * pool_stride_eff + px;
                  if ((src_h < ho) && (src_w < wo)) begin
                    pool_val = $signed(of_t[co_idx][src_h][src_w]);
                    pool_acc += pool_val;
                    if (pool_val > pool_max) begin
                      pool_max = pool_val;
                    end
                  end
                end
              end

              if (current_is_max_pool) begin
                pooled = pool_max;
              end else begin
                pooled = pool_acc / (current_pool_size * current_pool_size);
              end
              pool_t[co_idx][ph][pw] = pooled[WIDTH-1:0];
            end
          end
        end
      end

      // =====================================================
      // Expected memory layout for OFBUF DMA output
      // Memory order: column -> row -> channel
      // Address mapping checked later:
      //   addr = of_base + channel * (ho * align_even(wo))
      //                  + row     * align_even(wo)
      //                  + column
      // If wo is odd, the memory writer/module leaves 1 dummy cell
      // at the end of each row. The checker skips that cell.
      // =====================================================
      exp_out_count = 0;
      exp_pkt_count = current_co * pho;  // one completed DMA row per output channel row

      for (co_idx = 0; co_idx < current_co; co_idx++) begin
        for (oh = 0; oh < pho; oh++) begin
          for (ow = 0; ow < pwo; ow++) begin
            exp_out_mem[exp_out_count] = pool_t[co_idx][oh][ow];
            exp_out_count = exp_out_count + 1;
          end
        end
      end
    end
  endtask

  // Generic DMA responder cho IFBUF.
  // Chỉ nhận 1 config khi agent rảnh, sau đó trả đúng burst data
  // bằng cách đọc lại từ if_ext_mem đã được init sẵn.
  task automatic if_dma_agent();
    int req_base;
    int req_words;
    int idx;
    bit busy;
    begin
      req_base = 0;
      req_words = 0;
      idx = 0;
      busy = 1'b0;
      cnn_ifbuf_dma_rdycfg_i <= 1'b0;
      cnn_ifbuf_dma_vld_i    <= 1'b0;
      cnn_ifbuf_dma_data_i   <= '0;
      cnn_ifbuf_dma_tlast_i  <= 1'b0;

      forever begin
        @(posedge clk);

        if (!rst_n) begin
          busy               = 1'b0;
          req_base           = 0;
          req_words          = 0;
          idx                = 0;
          cnn_ifbuf_dma_rdycfg_i <= 1'b1;
          cnn_ifbuf_dma_vld_i    <= 1'b0;
          cnn_ifbuf_dma_data_i   <= '0;
          cnn_ifbuf_dma_tlast_i  <= 1'b0;
        end else begin
          cnn_ifbuf_dma_vld_i   <= 1'b0;
          cnn_ifbuf_dma_tlast_i <= 1'b0;

          if (!busy) begin
            cnn_ifbuf_dma_rdycfg_i <= 1'b1;
            if (cnn_ifbuf_dma_vldcfg_o) begin
              req_base           = cnn_ifbuf_dma_baddr_o;
              req_words          = cnn_ifbuf_dma_burst_o;
              idx                = 0;
              busy               = 1'b1;
              cnn_ifbuf_dma_rdycfg_i <= 1'b0;
            end
          end else begin
            cnn_ifbuf_dma_rdycfg_i <= 1'b0;
            if (cnn_ifbuf_dma_rdy_o && (idx < req_words)) begin
              cnn_ifbuf_dma_vld_i   <= 1'b1;
              cnn_ifbuf_dma_data_i  <= if_ext_mem[req_base + idx];
              cnn_ifbuf_dma_tlast_i <= (idx == req_words - 1);

              if (idx == req_words - 1) begin
                busy = 1'b0;
                cnn_ifbuf_dma_rdycfg_i <= 1'b1;
              end
              idx = idx + 1;
            end
          end
        end
      end
    end
  endtask

  // Generic DMA responder cho FLTBUF.
  // Chỉ accept config khi agent đang rảnh để không làm rơi request.
  task automatic flt_dma_agent();
    int req_base;
    int req_words;
    int idx;
    bit busy;
    begin
      req_base = 0;
      req_words = 0;
      idx = 0;
      busy = 1'b0;
      cnn_fltbuf_dma_rdycfg_i <= 1'b0;
      cnn_fltbuf_dma_vld_i    <= 1'b0;
      cnn_fltbuf_dma_data_i   <= '0;
      cnn_fltbuf_dma_tlast_i  <= 1'b0;

      forever begin
        @(posedge clk);

        if (!rst_n) begin
          busy               = 1'b0;
          req_base           = 0;
          req_words          = 0;
          idx                = 0;
          cnn_fltbuf_dma_rdycfg_i <= 1'b1;
          cnn_fltbuf_dma_vld_i    <= 1'b0;
          cnn_fltbuf_dma_data_i   <= '0;
          cnn_fltbuf_dma_tlast_i  <= 1'b0;
        end else begin
          cnn_fltbuf_dma_rdycfg_i <= !busy;
          cnn_fltbuf_dma_vld_i    <= 1'b0;
          cnn_fltbuf_dma_data_i   <= '0;
          cnn_fltbuf_dma_tlast_i  <= '0;

          if (!busy) begin
            if (cnn_fltbuf_dma_vldcfg_o && cnn_fltbuf_dma_rdycfg_i) begin
              req_base  = cnn_fltbuf_dma_baddr_o;
              req_words = cnn_fltbuf_dma_burst_o;
              idx       = 0;
              busy      = 1'b1;
              cnn_fltbuf_dma_rdycfg_i <= 0;
            end
          end else begin
            if (cnn_fltbuf_dma_rdy_o) begin
              cnn_fltbuf_dma_vld_i   <= 1'b1;
              cnn_fltbuf_dma_data_i  <= flt_ext_mem[req_base + idx];
              cnn_fltbuf_dma_tlast_i <= (idx == req_words - 1);

              if (idx == req_words - 1) begin
                busy = 1'b0;
                cnn_fltbuf_dma_rdycfg_i <= 1;
              end
              idx = idx + 1;
            end
          end
        end
      end
    end
  endtask

  // Generic DMA responder cho BIAS BUF.
  task automatic cnn_bias_dma_agent();
    int req_base;
    int req_words;
    int idx;
    bit busy;
    begin
      req_base = 0;
      req_words = 0;
      idx = 0;
      busy = 1'b0;
      cnn_bias_dma_rdycfg_i <= 1'b0;
      cnn_bias_dma_vld_i    <= 1'b0;
      cnn_bias_dma_data_i   <= '0;
      cnn_bias_dma_tlast_i  <= 1'b0;

      forever begin
        @(posedge clk);

        if (!rst_n) begin
          busy                = 1'b0;
          req_base            = 0;
          req_words           = 0;
          idx                 = 0;
          cnn_bias_dma_rdycfg_i   <= 1'b1;
          cnn_bias_dma_vld_i      <= 1'b0;
          cnn_bias_dma_data_i     <= '0;
          cnn_bias_dma_tlast_i    <= 1'b0;
        end else begin
          cnn_bias_dma_rdycfg_i <= !busy;
          cnn_bias_dma_vld_i    <= 1'b0;
          cnn_bias_dma_data_i   <= '0;
          cnn_bias_dma_tlast_i  <= 1'b0;

          if (!busy) begin
            if (cnn_bias_dma_vldcfg_o && cnn_bias_dma_rdycfg_i) begin
              req_base  = cnn_bias_dma_baddr_o;
              req_words = cnn_bias_dma_burst_o;
              idx       = 0;
              busy      = 1'b1;
              cnn_bias_dma_rdycfg_i <= 1'b0;
            end
          end else begin
            if (cnn_bias_dma_rdy_o && (idx < req_words)) begin
              cnn_bias_dma_vld_i   <= 1'b1;
              cnn_bias_dma_data_i  <= bias_ext_mem[req_base + idx];
              cnn_bias_dma_tlast_i <= (idx == req_words - 1);

              if (idx == req_words - 1) begin
                busy = 1'b0;
                cnn_bias_dma_rdycfg_i <= 1'b1;
              end
              idx = idx + 1;
            end
          end
        end
      end
    end
  endtask

  // DMA writer for OFBUF.
  // This is the memory-side model for the new CNN top-level OFBUF DMA interface.
  // It accepts write data whenever rdy_dma is asserted. If the write config is not
  // available/accepted yet, accepted data beats are held in a small FIFO instead of
  // being dropped. rdy_dma is deasserted only when that FIFO is full.
  // Dummy padding data, when generated by OFBUF/DMA, is not synthesized here; the
  // checker simply skips the padded memory cell at the end of an odd-width row.
  task automatic of_dma_agent();
    localparam int OF_DMA_FIFO_DEPTH = 16;

    int req_base;
    int req_words;
    int idx;
    bit busy;

    logic [DATA_WIDTH-1:0] data_fifo [0:OF_DMA_FIFO_DEPTH-1];
    logic                  last_fifo [0:OF_DMA_FIFO_DEPTH-1];
    int fifo_wr_ptr;
    int fifo_rd_ptr;
    int fifo_count;
    bit accepted_data;
    bit can_pop;
    logic [DATA_WIDTH-1:0] pop_data;
    logic                  pop_tlast;

    begin
      req_base    = 0;
      req_words   = 0;
      idx         = 0;
      busy        = 1'b0;
      fifo_wr_ptr = 0;
      fifo_rd_ptr = 0;
      fifo_count  = 0;
      cnn_ofbuf_dma_rdycfg_i <= 1'b0;
      cnn_ofbuf_dma_rdy_i    <= 1'b0;

      forever begin
        @(posedge clk);

        if (!rst_n) begin
          busy                = 1'b0;
          req_base            = 0;
          req_words           = 0;
          idx                 = 0;
          fifo_wr_ptr         = 0;
          fifo_rd_ptr         = 0;
          fifo_count          = 0;
          cnn_ofbuf_dma_rdycfg_i  <= 1'b1;
          cnn_ofbuf_dma_rdy_i     <= 1'b1;
          act_pkt_count       = 0;
          act_out_count       = 0;
        end else begin
          
          // DATA channel: rdy_dma means the beat will be stored.  When the DMA
          // model is waiting for/accepting a config, incoming beats are buffered.
          accepted_data = cnn_ofbuf_dma_vld_o && cnn_ofbuf_dma_rdy_i;
          if (accepted_data) begin
            if (fifo_count >= OF_DMA_FIFO_DEPTH) begin
              $fatal(1, "OFBUF DMA internal FIFO overflow");
            end
            data_fifo[fifo_wr_ptr] = cnn_ofbuf_dma_data_o;
            last_fifo[fifo_wr_ptr] = cnn_ofbuf_dma_tlast_o;
            fifo_wr_ptr = (fifo_wr_ptr + 1) % OF_DMA_FIFO_DEPTH;
            fifo_count  = fifo_count + 1;
          end

          // CONFIG channel: accept a new config only while no packet is active.
          cnn_ofbuf_dma_rdycfg_i <= !busy;
          if (!busy && cnn_ofbuf_dma_vldcfg_o && cnn_ofbuf_dma_rdycfg_i) begin
            req_base  = cnn_ofbuf_dma_baddr_o;
            req_words = cnn_ofbuf_dma_burst_o;
            idx       = 0;
            busy      = 1'b1;
            cnn_ofbuf_dma_rdycfg_i <= 1'b0;
          end

          // Once a config is active, drain exactly the beats that were accepted
          // from the data channel. This also handles beats that arrived before
          // rdycfg/config handshake completed.
          can_pop = busy && (fifo_count > 0);
          if (can_pop) begin
            pop_data  = data_fifo[fifo_rd_ptr];
            pop_tlast = last_fifo[fifo_rd_ptr];
            fifo_rd_ptr = (fifo_rd_ptr + 1) % OF_DMA_FIFO_DEPTH;
            fifo_count  = fifo_count - 1;

            if ((req_base + idx) >= MAX_MEM) begin
              $fatal(1, "OFBUF DMA write address overflow: base=%0d idx=%0d", req_base, idx);
            end

            of_ext_mem[req_base + idx] = pop_data;
            act_out_mem[act_out_count] = pop_data;
            act_out_count = act_out_count + 1;

            if (pop_tlast || (idx == req_words - 1)) begin
              busy = 1'b0;
              act_pkt_count = act_pkt_count + 1;
            end

            idx = idx + 1;
          end

          // Backpressure only when the FIFO cannot store the next beat.  Account
          // for a same-cycle pop so the source can continue when one slot opens.
          cnn_ofbuf_dma_rdy_i <= (fifo_count < OF_DMA_FIFO_DEPTH);
        end
      end
    end
  endtask

  task automatic wait_cnn_ofbuf_dma_done(input int wanted_row_count);
    int watchdog;
    begin
      watchdog = 0;
      while ((act_pkt_count < wanted_row_count) && (watchdog < 500000)) begin
        @(posedge clk);
        watchdog = watchdog + 1;
      end
      if (act_pkt_count != wanted_row_count) begin
        $fatal(1, "OFBUF DMA timeout. completed_rows=%0d wanted_rows=%0d data_writes=%0d",
               act_pkt_count, wanted_row_count, act_out_count);
      end
      $display("OFBUF DMA completed: rows=%0d data_writes=%0d", act_pkt_count, act_out_count);
    end
  endtask

  task automatic clear_cnn_done_if_pending();
    int watchdog;
    begin
      if (cnn_cpu_accel_done_o === 1'b1) begin
        @(negedge clk);
        cnn_cpu_receive_interupt_i = 1'b1;
        @(negedge clk);
        cnn_cpu_receive_interupt_i = 1'b0;

        watchdog = 0;
        while (cnn_cpu_accel_done_o !== 1'b0) begin
          @(posedge clk);
          #1;
          watchdog++;
          if (watchdog > 64) begin
            $fatal(1, "CNN done clear timeout before writing layer_description");
          end
        end
      end
    end
  endtask

  task automatic validate_layer_cfg(input string tc_name, input int layer_idx);
    begin
      if (layer_stride[layer_idx] > 7)
        $fatal(1, "%s[L%0d]: invalid stride=%0d exceeds 3-bit field", tc_name, layer_idx, layer_stride[layer_idx]);
      if (layer_padding[layer_idx] > 3)
        $fatal(1, "%s[L%0d]: invalid padding=%0d exceeds 2-bit field", tc_name, layer_idx, layer_padding[layer_idx]);
      if ((layer_stride[layer_idx] > layer_kw[layer_idx]) || (layer_stride[layer_idx] > layer_kh[layer_idx]))
        $fatal(1, "%s[L%0d]: invalid stride=%0d > filter=(%0d,%0d)", tc_name, layer_idx, layer_stride[layer_idx], layer_kw[layer_idx], layer_kh[layer_idx]);
      if ((layer_padding[layer_idx] >= layer_kw[layer_idx]) || (layer_padding[layer_idx] >= layer_kh[layer_idx]))
        $fatal(1, "%s[L%0d]: padding=%0d must be < filter=(%0d,%0d)", tc_name, layer_idx, layer_padding[layer_idx], layer_kw[layer_idx], layer_kh[layer_idx]);
      if ((layer_w[layer_idx] + 2 * layer_padding[layer_idx] < layer_kw[layer_idx]) ||
          (layer_h[layer_idx] + 2 * layer_padding[layer_idx] < layer_kh[layer_idx]))
        $fatal(1, "%s[L%0d]: padded ifmap smaller than filter", tc_name, layer_idx);
      if (layer_is_use_pool[layer_idx]) begin
        if ((layer_pool_size[layer_idx] <= 0) || (layer_pool_size[layer_idx] > 31))
          $fatal(1, "%s[L%0d]: invalid pool_size=%0d", tc_name, layer_idx, layer_pool_size[layer_idx]);
        if ((layer_pool_stride[layer_idx] <= 0) || (layer_pool_stride[layer_idx] > 31))
          $fatal(1, "%s[L%0d]: invalid pool_stride=%0d", tc_name, layer_idx, layer_pool_stride[layer_idx]);
        if (!((layer_pool_size[layer_idx] == layer_pool_stride[layer_idx]) ||
              (layer_pool_size[layer_idx] == (layer_pool_stride[layer_idx] + 1))))
          $fatal(1, "%s[L%0d]: invalid pooling stride relation pool_size=%0d pool_stride=%0d",
                 tc_name, layer_idx, layer_pool_size[layer_idx], layer_pool_stride[layer_idx]);
      end
    end
  endtask

  task automatic clear_layer_configs();
    int l;
    begin
      num_loaded_layers = 0;
      for (l = 0; l < MAX_LAYERS_TB; l++) begin
        layer_name[l]       = "";
        layer_w[l]          = 0;
        layer_h[l]          = 0;
        layer_ci[l]         = 0;
        layer_co[l]         = 0;
        layer_kw[l]         = 0;
        layer_kh[l]         = 0;
        layer_stride[l]     = 0;
        layer_padding[l]    = 0;
        layer_ifparr[l]     = 0;
        layer_ofparr[l]     = 0;
        layer_oftile[l]     = 0;
        layer_if_zp[l]      = 0;
        layer_fl_zp[l]      = 0;
        layer_is_use_pool[l] = 0;
        layer_is_max_pool[l] = 0;
        layer_pool_size[l]   = 1;
        layer_pool_stride[l] = 1;
        layer_is_stride_over[l] = 1;
        layer_if_base[l]    = 0;
        layer_flt_base[l]   = 0;
        layer_bias_base[l]  = 0;
        layer_of_base[l]    = 0;
        layer_if_words[l]   = 0;
        layer_flt_words[l]  = 0;
        layer_bias_words[l] = 0;
        layer_of_words[l]   = 0;
        layer_exp_rows[l]   = 0;
        layer_exp_values[l] = 0;
      end
    end
  endtask

  task automatic add_layer_cfg(
    input string layer_desc_name,
    input int    w,
    input int    h,
    input int    ci,
    input int    co,
    input int    kw,
    input int    kh,
    input int    stride,
    input int    padding,
    input int    ifparr,
    input int    ofparr,
    input int    oftile,
    input int    if_zp,
    input int    fl_zp
  );
    int l;
    begin
      if (num_loaded_layers >= MAX_LAYERS_TB) begin
        $fatal(1, "Too many layers for this TB. Increase MAX_LAYERS_TB=%0d", MAX_LAYERS_TB);
      end

      l = num_loaded_layers;
      layer_name[l]    = layer_desc_name;
      layer_w[l]       = w;
      layer_h[l]       = h;
      layer_ci[l]      = ci;
      layer_co[l]      = co;
      layer_kw[l]      = kw;
      layer_kh[l]      = kh;
      layer_stride[l]  = stride;
      layer_padding[l] = padding;
      layer_ifparr[l]  = ifparr;
      layer_ofparr[l]  = ofparr;
      layer_oftile[l]  = oftile;
      layer_if_zp[l]   = if_zp;
      layer_fl_zp[l]   = fl_zp;
      layer_is_use_pool[l] = 0;
      layer_is_max_pool[l] = 0;
      layer_pool_size[l]   = 1;
      layer_pool_stride[l] = 1;
      layer_is_stride_over[l] = 1;
      num_loaded_layers++;
    end
  endtask

  task automatic set_last_layer_pool_cfg(
    input string tc_name,
    input int    is_use_pool,
    input int    is_max_pool,
    input int    pool_size,
    input int    pool_stride
  );
    int l;
    begin
      if (num_loaded_layers <= 0) begin
        $fatal(1, "%s: cannot set pooling before add_layer_cfg", tc_name);
      end
      l = num_loaded_layers - 1;

      layer_is_use_pool[l] = is_use_pool;
      layer_is_max_pool[l] = is_max_pool;
      layer_pool_size[l]   = is_use_pool ? pool_size : 1;
      layer_pool_stride[l] = is_use_pool ? pool_stride : 1;
      layer_is_stride_over[l] = is_use_pool ?
        derive_is_stride_over(tc_name, pool_size, pool_stride) : 1;
    end
  endtask

  task automatic set_current_layer(input int layer_idx);
    begin
      current_if_base   = layer_if_base[layer_idx];
      current_flt_base  = layer_flt_base[layer_idx];
      current_bias_base = layer_bias_base[layer_idx];
      current_of_base   = layer_of_base[layer_idx];
      current_w         = layer_w[layer_idx];
      current_h         = layer_h[layer_idx];
      current_ci        = layer_ci[layer_idx];
      current_co        = layer_co[layer_idx];
      current_kw        = layer_kw[layer_idx];
      current_kh        = layer_kh[layer_idx];
      current_stride    = layer_stride[layer_idx];
      current_padding   = layer_padding[layer_idx];
      current_ifparr    = layer_ifparr[layer_idx];
      current_ofparr    = layer_ofparr[layer_idx];
      current_oftile    = layer_oftile[layer_idx];
      current_ifc_zp    = layer_if_zp[layer_idx];
      current_fltc_zp   = layer_fl_zp[layer_idx];
      current_is_use_pool = layer_is_use_pool[layer_idx];
      current_is_max_pool = layer_is_max_pool[layer_idx];
      current_pool_size   = layer_pool_size[layer_idx];
      current_pool_stride = layer_pool_stride[layer_idx];
      current_is_stride_over = layer_is_stride_over[layer_idx];
      current_mult      = 3;
      current_mult_shift = 2;
      current_alphamult = 1;
      current_alphamult_shift = 0;
      current_zpy       = 0;
      current_qmin      = -128;
      current_qmax      = 127;
      current_is_leaky_relu = 1;
    end
  endtask

  task automatic prepare_loaded_layers(input string tc_name, output int total_exp_rows);
    int l;
    int next_if_base;
    int next_flt_base;
    int next_bias_base;
    int next_of_base;
    begin
      if (num_loaded_layers <= 0) begin
        $fatal(1, "%s: no layer description was added", tc_name);
      end

      next_if_base   = 0;
      next_flt_base  = 0;
      next_bias_base = 0;
      next_of_base   = 0;
      total_exp_rows = 0;

      for (l = 0; l < num_loaded_layers; l++) begin
        validate_layer_cfg(tc_name, l);

        layer_if_base[l]    = align_base(next_if_base);
        layer_flt_base[l]   = align_base(next_flt_base);
        layer_bias_base[l]  = align_base(next_bias_base);
        layer_of_base[l]    = align_base(next_of_base);

        set_current_layer(l);

        fill_ifmap_external_memory(current_if_base, current_w, current_h, current_ci);
        layer_if_words[l] = current_if_words;
        check_mem_range(tc_name, "IFBUF", current_if_base, layer_if_words[l]);

        fill_filter_external_memory(current_flt_base, current_kw, current_kh, current_ci,
                                    current_co, current_ifparr, current_ofparr);
        layer_flt_words[l] = current_flt_words;
        check_mem_range(tc_name, "FLTBUF", current_flt_base, layer_flt_words[l]);

        fill_bias_external_memory(current_bias_base, current_co, current_ofparr, current_oftile);
        layer_bias_words[l] = current_bias_words;
        check_mem_range(tc_name, "BIAS", current_bias_base, layer_bias_words[l]);

        layer_of_words[l] = calc_of_words(current_w, current_h, current_co, current_kw,
                                          current_kh, current_stride, current_padding);
        check_mem_range(tc_name, "OFBUF", current_of_base, layer_of_words[l]);

        build_expected_output();
        layer_exp_rows[l]   = exp_pkt_count;
        layer_exp_values[l] = exp_out_count;
        total_exp_rows += layer_exp_rows[l];

        $display("%s[L%0d:%s]: IF base=%0d words=%0d, FLT base=%0d words=%0d, BIAS base=%0d words=%0d, OF base=%0d words=%0d, pool(use=%0d max=%0d size=%0d stride=%0d over=%0d), exp_rows=%0d exp_values=%0d",
                 tc_name, l, layer_name[l],
                 layer_if_base[l], layer_if_words[l],
                 layer_flt_base[l], layer_flt_words[l],
                 layer_bias_base[l], layer_bias_words[l],
                 layer_of_base[l], layer_of_words[l],
                 layer_is_use_pool[l], layer_is_max_pool[l],
                 layer_pool_size[l], layer_pool_stride[l], layer_is_stride_over[l],
                 layer_exp_rows[l], layer_exp_values[l]);

        next_if_base   = layer_if_base[l]   + layer_if_words[l]   + BASE_ALIGN;
        next_flt_base  = layer_flt_base[l]  + layer_flt_words[l]  + BASE_ALIGN;
        next_bias_base = layer_bias_base[l] + layer_bias_words[l] + BASE_ALIGN;
        next_of_base   = layer_of_base[l]   + layer_of_words[l]   + BASE_ALIGN;
      end
    end
  endtask

  task automatic issue_loaded_layer_descriptions();
    int l;
    begin
      for (l = 0; l < num_loaded_layers; l++) begin
        set_current_layer(l);
        program_table_instruction(layer_name[l], current_w, current_h, current_ci, current_co,
                                  current_kw, current_kh, current_stride, current_padding,
                                  current_ifparr, current_ofparr, current_oftile);
        issue_layer_description();
      end
    end
  endtask

  task automatic compare_layer_outputs(input string tc_name, input int layer_idx);
    int co_idx;
    int oh;
    int ow;
    int ho;
    int wo;
    int align_wo;
    int exp_idx;
    int mem_addr;
    logic [WIDTH-1:0] exp_data;
    logic [WIDTH-1:0] act_data;
    begin
      set_current_layer(layer_idx);
      build_expected_output();

      ho = calc_of_h(current_h, current_kh, current_stride, current_padding);
      wo = calc_of_w(current_w, current_kw, current_stride, current_padding);
      ho = calc_pool_out_dim(ho, current_is_use_pool, current_pool_size,
                             current_pool_stride, current_is_stride_over);
      wo = calc_pool_out_dim(wo, current_is_use_pool, current_pool_size,
                             current_pool_stride, current_is_stride_over);
      align_wo = align_even(wo);

      if (exp_out_count != layer_exp_values[layer_idx]) begin
        $fatal(1, "%s[L%0d]: expected scalar count changed. exp_now=%0d exp_saved=%0d",
               tc_name, layer_idx, exp_out_count, layer_exp_values[layer_idx]);
      end

      exp_idx = 0;
      for (co_idx = 0; co_idx < current_co; co_idx++) begin
        for (oh = 0; oh < ho; oh++) begin
          for (ow = 0; ow < wo; ow++) begin
            mem_addr = current_of_base + co_idx * (ho * align_wo) + oh * align_wo + ow;
            exp_data = exp_out_mem[exp_idx][WIDTH-1:0];
            act_data = of_ext_mem[mem_addr];

            if (act_data !== exp_data) begin
              $display("%s[L%0d:%s]: OFBUF mismatch ch=%0d row=%0d col=%0d addr=%0d act=0x%02x exp=0x%02x",
                       tc_name, layer_idx, layer_name[layer_idx], co_idx, oh, ow, mem_addr, act_data, exp_data);
              $fatal(1, "%s[L%0d] failed", tc_name, layer_idx);
            end
            exp_idx = exp_idx + 1;
          end
        end
      end

      $display("[PASS] %s[L%0d:%s] : %0d output values matched from OFBUF base=%0d row_stride=%0d",
               tc_name, layer_idx, layer_name[layer_idx], exp_out_count, current_of_base, align_wo);
    end
  endtask

  task automatic compare_loaded_layer_outputs(input string tc_name);
    int l;
    begin
      for (l = 0; l < num_loaded_layers; l++) begin
        compare_layer_outputs(tc_name, l);
      end
    end
  endtask

  task automatic run_loaded_layers(input string tc_name);
    int total_exp_rows;
    begin
      $display("\n========== RUN %s : %0d layer(s) ==========", tc_name, num_loaded_layers);

      clear_all_memories();
      prepare_loaded_layers(tc_name, total_exp_rows);
      $display("%s: total_exp_dma_rows=%0d", tc_name, total_exp_rows);

      fork
        if_dma_agent();
        flt_dma_agent();
        cnn_bias_dma_agent();
        of_dma_agent();
      join_none

      issue_loaded_layer_descriptions();
      pulse_cnn_start();
      wait_cnn_done_and_ack();
      wait_cnn_ofbuf_dma_done(total_exp_rows);
      repeat (20) @(posedge clk);
      compare_loaded_layer_outputs(tc_name);

      disable fork;
      repeat (10) @(posedge clk);
    end
  endtask

  task automatic issue_layer_description();
    int watchdog;
    begin
      // New control protocol:
      // 1) Only write layer_description when CNN is idle.
      clear_cnn_done_if_pending();
      watchdog = 0;
      while (cnn_cpu_accel_busy_o !== 1'b0) begin
        @(posedge clk);
        #1;
        watchdog++;
        if (watchdog > 500000) begin
          $fatal(1, "CNN busy timeout before writing layer_description");
        end
      end

      @(negedge clk);
      cnn_table_vld_i = 1'b1;

      watchdog = 0;
      while (cnn_table_rdy_o !== 1'b1) begin
        @(posedge clk);
        #1;
        watchdog++;
        if (watchdog > 500000) begin
          $fatal(1, "TABLE instruction timeout: cnn_table_rdy_o did not assert");
        end
      end

      @(negedge clk);
      cnn_table_vld_i = 1'b0;
    end
  endtask

  task automatic pulse_cnn_start();
    begin
      @(negedge clk);
      cnn_cpu_accel_start_i = 1'b1;
      @(negedge clk);
      cnn_cpu_accel_start_i = 1'b0;
    end
  endtask

  task automatic wait_cnn_done_and_ack();
    int watchdog;
    begin
      // Ignore any stale level; after start, first observe busy, then wait done.
      watchdog = 0;
      while (cnn_cpu_accel_busy_o !== 1'b1) begin
        @(posedge clk);
        #1;
        watchdog++;
        if (watchdog > 64) begin
          $fatal(1, "CNN busy timeout after cnn_cpu_accel_start_i pulse");
        end
      end

      watchdog = 0;
      while (cnn_cpu_accel_done_o !== 1'b1) begin
        #20000;
        watchdog++;
        if (watchdog > 500) begin
          $fatal(1, "CNN done timeout: cnn_cpu_accel_done_o did not assert");
        end
      end

      @(negedge clk);
      cnn_cpu_receive_interupt_i = 1'b1;
      @(negedge clk);
      cnn_cpu_receive_interupt_i = 1'b0;
    end
  endtask

  task automatic issue_inftructions();
    begin
      issue_layer_description();
      // 2) After all layer descriptions for this run have been written, pulse start.
      pulse_cnn_start();
      // 3) Wait for done, then pulse receive_interupt.
      wait_cnn_done_and_ack();
    end
  endtask

  task automatic issue_inftructions_no_wait_done();
    begin
      issue_layer_description();
      pulse_cnn_start();
    end
  endtask

  task automatic compare_outputs(input string tc_name);
    int co_idx;
    int oh;
    int ow;
    int ho;
    int wo;
    int align_wo;
    int exp_idx;
    int mem_addr;
    logic [WIDTH-1:0] exp_data;
    logic [WIDTH-1:0] act_data;
    begin
      ho = (current_h + 2 * current_padding - current_kh) / current_stride + 1;
      wo = (current_w + 2 * current_padding - current_kw) / current_stride + 1;
      ho = calc_pool_out_dim(ho, current_is_use_pool, current_pool_size,
                             current_pool_stride, current_is_stride_over);
      wo = calc_pool_out_dim(wo, current_is_use_pool, current_pool_size,
                             current_pool_stride, current_is_stride_over);
      align_wo = align_even(wo);

      if (exp_out_count != current_co * ho * wo) begin
        $fatal(1, "%s: expected scalar count internal mismatch. exp=%0d calc=%0d",
               tc_name, exp_out_count, current_co * ho * wo);
      end

      if (act_pkt_count != exp_pkt_count) begin
        $fatal(1, "%s: OFBUF DMA row count mismatch. act_rows=%0d exp_rows=%0d",
               tc_name, act_pkt_count, exp_pkt_count);
      end

      exp_idx = 0;
      for (co_idx = 0; co_idx < current_co; co_idx++) begin
        for (oh = 0; oh < ho; oh++) begin
          for (ow = 0; ow < wo; ow++) begin
            mem_addr = current_of_base + co_idx * (ho * align_wo) + oh * align_wo + ow;
            exp_data = exp_out_mem[exp_idx][WIDTH-1:0];
            act_data = of_ext_mem[mem_addr];

            if (act_data !== exp_data) begin
              $display("%s: OFBUF memory mismatch ch=%0d row=%0d col=%0d addr=%0d act=0x%02x exp=0x%02x",
                       tc_name, co_idx, oh, ow, mem_addr, act_data, exp_data);
              $fatal(1, "%s failed", tc_name);
            end
            exp_idx = exp_idx + 1;
          end
          // If wo is odd, addr current_of_base + ... + wo is dummy padding.
          // The checker intentionally does not compare it and moves to next row.
        end
      end

      if ((wo % 2) != 0) begin
        $display("[PASS] %s : %0d output values matched from OFBUF memory, row_stride=%0d (odd width: skipped dummy after each row)",
                 tc_name, exp_out_count, align_wo);
      end else begin
        $display("[PASS] %s : %0d output values matched from OFBUF memory, row_stride=%0d",
                 tc_name, exp_out_count, align_wo);
      end
    end
  endtask

  task automatic run_case(
    input string tc_name,
    input int    w,
    input int    h,
    input int    ci,
    input int    co,
    input int    kw,
    input int    kh,
    input int    stride,
    input int    padding,
    input int    ifparr,
    input int    ofparr,
    input int    oftile,
    input int    if_zp,
    input int    fl_zp
  );
    begin
      clear_layer_configs();
      add_layer_cfg(tc_name, w, h, ci, co, kw, kh, stride, padding,
                    ifparr, ofparr, oftile, if_zp, fl_zp);
      run_loaded_layers(tc_name);
    end
  endtask

  task automatic run_case_pool(
    input string tc_name,
    input int    w,
    input int    h,
    input int    ci,
    input int    co,
    input int    kw,
    input int    kh,
    input int    stride,
    input int    padding,
    input int    ifparr,
    input int    ofparr,
    input int    oftile,
    input int    if_zp,
    input int    fl_zp,
    input int    is_use_pool,
    input int    is_max_pool,
    input int    pool_size,
    input int    pool_stride
  );
    begin
      clear_layer_configs();
      add_layer_cfg(tc_name, w, h, ci, co, kw, kh, stride, padding,
                    ifparr, ofparr, oftile, if_zp, fl_zp);
      set_last_layer_pool_cfg(tc_name, is_use_pool, is_max_pool,
                              pool_size, pool_stride);
      run_loaded_layers(tc_name);
    end
  endtask

  task automatic run_case_multi_smoke();
    begin
      clear_layer_configs();
      add_layer_cfg("ML0_3x3_even",       10, 10, 1, 4, 3, 3, 1, 2, 1, 4, 1, 0, 0);
      add_layer_cfg("ML1_pointwise_tail", 11, 11, 3, 5, 1, 1, 1, 0, 2, 4, 2, 3, 1);
      // add_layer_cfg("ML2_stride2",        8,  8, 11, 3, 3, 3, 2, 2, 1, 3, 1, 2, 6);
      run_loaded_layers("TC_MULTI_3_LAYERS_ONE_START");
    end
  endtask




  // =========================================================
  // Reset-abort fault-injection run case
  // =========================================================
  // abort_packets > 0 : cho DUT chay den khi da thu du so packet nay roi reset.
  // abort_packets == 0: reset sau abort_cycles clock ke tu luc issue inftruction.
  // Sau khi task nay release reset, TB KHONG goi apply_reset() nua; run_case tiep theo
  // se duoc issue truc tiep de kiem tra DUT/agent co recover sach hay khong.
  task automatic run_case_abort_reset(
    input string tc_name,
    input int    w,
    input int    h,
    input int    ci,
    input int    co,
    input int    kw,
    input int    kh,
    input int    stride,
    input int    padding,
    input int    ifparr,
    input int    ofparr,
    input int    oftile,
    input int    if_zp,
    input int    fl_zp,
    input int    abort_cycles,
    input int    abort_packets
  );
    int align_w;
    int iftiles;
    int ifparr_tail;
    int ofparr_tail;
    int total_oftiles;
    int oftiles_tail;
    int wp;
    int normal_burst;
    int bias_block_real;
    int bias_tail_real;
    int bias_burst;
    int bias_tail_burst;
    int bias_h0_lanes;
    int bias_lane0;
    int bias_tail_full_tile;
    int bias_tail_mod;
    int bias_tail_lane0;
    int watchdog;
    begin
      $display("\n========== RUN %s : EXPECT RESET ABORT ==========" , tc_name);

      if (stride > 7)
        $fatal(1, "%s: invalid testcase, stride=%0d exceeds 3-bit field", tc_name, stride);
      if (padding > 3)
        $fatal(1, "%s: invalid testcase, padding=%0d exceeds 2-bit field", tc_name, padding);
      if ((stride > kw) || (stride > kh))
        $fatal(1, "%s: invalid testcase, stride=%0d > filter=(%0d,%0d)", tc_name, stride, kw, kh);
      if ((padding >= kw) || (padding >= kh))
        $fatal(1, "%s: invalid testcase, padding=%0d must be < filter=(%0d,%0d)", tc_name, padding, kw, kh);
      if ((w + 2 * padding < kw) || (h + 2 * padding < kh))
        $fatal(1, "%s: invalid testcase, padded ifmap smaller than filter", tc_name);
      if ((abort_cycles <= 0) && (abort_packets <= 0))
        $fatal(1, "%s: invalid reset-abort testcase, need abort_cycles>0 or abort_packets>0", tc_name);

      clear_all_memories();

      current_if_base   = 0;
      current_flt_base  = 8192;
      current_bias_base = 32768;
      current_of_base   = 0;
      current_w         = w;
      current_h         = h;
      current_ci        = ci;
      current_co        = co;
      current_kw        = kw;
      current_kh        = kh;
      current_stride    = stride;
      current_padding   = padding;
      current_ifparr    = ifparr;
      current_ofparr    = ofparr;
      current_oftile    = oftile;
      current_ifc_zp    = if_zp;
      current_fltc_zp   = fl_zp;
      current_mult      = 3;
      current_mult_shift = 2;
      current_alphamult = 1;
      current_alphamult_shift = 0;
      current_zpy       = 0;
      current_qmin      = -128;
      current_qmax      = 127;
      current_is_leaky_relu = 1;
      current_is_use_pool = 0;
      current_is_max_pool = 0;
      current_pool_size = 1;
      current_pool_stride = 1;
      current_is_stride_over = 1;

      fill_ifmap_external_memory(current_if_base, w, h, ci);
      fill_filter_external_memory(current_flt_base, kw, kh, ci, co, ifparr, ofparr);
      fill_bias_external_memory(current_bias_base, co, ofparr, oftile);
      build_expected_output();
      $display("%s: exp_dma_rows=%0d exp_out_count=%0d. This case will be reset before compare.",
         tc_name, exp_pkt_count, exp_out_count);

      align_w       = align_even(w);
      iftiles       = ceil_div(ci, ifparr);
      ifparr_tail   = ((ci % ifparr) == 0) ? ifparr : (ci % ifparr);
      ofparr_tail   = ((co % ofparr) == 0) ? ofparr : (co % ofparr);
      total_oftiles = ceil_div(co, ofparr);
      oftiles_tail  = ((total_oftiles % oftile) == 0) ? oftile : (total_oftiles % oftile);
      wp            = ((w + 2 * padding - kh) / stride) * stride + kh - 1;
      normal_burst  = kw * kh;
      bias_block_real      = ofparr * oftile;
      bias_tail_real       = ((co % bias_block_real) == 0) ? bias_block_real : (co % bias_block_real);
      bias_burst           = ((co / bias_block_real) == 0) ? bias_tail_real : bias_block_real;
      bias_tail_burst      = bias_tail_real;
      bias_h0_lanes        = ceil_div(ofparr, M);
      
      bias_tail_full_tile  = bias_tail_real / ofparr;
      bias_tail_mod        = bias_tail_real % ofparr;
      bias_tail_lane0      = bias_tail_full_tile * bias_h0_lanes + ceil_div(bias_tail_mod, M);
      bias_lane0           = ((co / bias_block_real) == 0) ? bias_tail_lane0 : bias_h0_lanes * oftile;

      program_table_instruction(tc_name, w, h, ci, co, kw, kh, stride, padding, ifparr, ofparr, oftile);

      fork
        if_dma_agent();
        flt_dma_agent();
        cnn_bias_dma_agent();
        of_dma_agent();
      join_none

      issue_inftructions_no_wait_done();

      if (abort_packets > 0) begin
        watchdog = 0;
        while ((act_pkt_count < abort_packets) && (watchdog < abort_cycles)) begin
          @(posedge clk);
          watchdog = watchdog + 1;
        end
        if (act_pkt_count < abort_packets) begin
          $display("[RST-ABORT][WARN] %s: only collected %0d/%0d packets before watchdog=%0d, reset anyway.",
                   tc_name, act_pkt_count, abort_packets, abort_cycles);
        end
      end else begin
        repeat (abort_cycles) @(posedge clk);
      end

      if (act_pkt_count >= exp_pkt_count) begin
        $fatal(1, "%s: abort point is too late; testcase completed before reset. act_pkt_count=%0d exp_pkt_count=%0d",
               tc_name, act_pkt_count, exp_pkt_count);
      end

      $display("[RST-ABORT] %s: assert reset mid-run at act_pkt_count=%0d/%0d",
               tc_name, act_pkt_count, exp_pkt_count);

      // Assert reset while DMA agents/collector are still alive, so DUT sees an abrupt in-flight reset.
      rst_n = 1'b0;
      repeat (2) @(posedge clk);

      // Stop the old run's DMA agents and collector. The next run_case() starts fresh agents.
      disable fork;

      // Hold all TB-driven interfaces idle during the rest of reset.
      clear_table_interface();
      cnn_cpu_accel_start_i = 1'b0;
      cnn_cpu_receive_interupt_i = 1'b0;
      cnn_ifbuf_dma_rdycfg_i = 1'b0;
      cnn_fltbuf_dma_rdycfg_i = 1'b0;
      cnn_bias_dma_rdycfg_i = 1'b0;
      cnn_ifbuf_dma_vld_i = 1'b0;
      cnn_fltbuf_dma_vld_i = 1'b0;
      cnn_bias_dma_vld_i = 1'b0;
      cnn_ifbuf_dma_data_i = '0;
      cnn_fltbuf_dma_data_i = '0;
      cnn_bias_dma_data_i = '0;
      cnn_ifbuf_dma_tlast_i = 1'b0;
      cnn_fltbuf_dma_tlast_i = 1'b0;
      cnn_bias_dma_tlast_i = 1'b0;
      cnn_ofbuf_dma_rdycfg_i = 1'b0;
      cnn_ofbuf_dma_rdy_i    = 1'b0;

      repeat (6) @(posedge clk);
      rst_n = 1'b1;
      repeat (4) @(posedge clk);

      $display("[RST-ABORT][PASS] %s: reset released. Next run_case is intentionally issued without another reset.", tc_name);
    end
  endtask

  // =========================================================
  // DUT
  // =========================================================
  wire [WIDTH-1:0]     fltbuf_comp_data_tb   [0:K*M-1];
  wire [WIDTH-1:0]     ifbuf_comp_data_tb    [0:K-1];
  wire [WIDTH-1:0]     scale_comp_data_tb    [0:M-1];
  wire [WIDTH-1:0]     flt_cache_pe_data_tb  [0:K*M*12-1];
  wire [WIDTH-1:0]     if_cache_pe_data_tb   [0:K-1];
  genvar i;
  generate
      for (i = 0; i < K*M; i = i + 1) begin : GEN_FLTBUF_TAP
          assign fltbuf_comp_data_tb[i] = dut.fltbuf_comp_data_w[(i+1)*WIDTH-1 -: WIDTH];
      end
      for (i = 0; i < K; i = i + 1) begin : GEN_IFBUF_TAP
          assign ifbuf_comp_data_tb[i]  = dut.ifbuf_comp_data_w[(i+1)*WIDTH-1 -: WIDTH];
          assign if_cache_pe_data_tb[i] = dut.u_computation.ifmap_cache_inft.ifc_pu_data_o[(i+1)*WIDTH-1 -: WIDTH];
      end
    for (i = 0; i < K*M*12; i = i + 1) begin : GEN_FTC_TAP
        assign flt_cache_pe_data_tb[i] =
            dut.u_computation.gen_comp_pu[0].comp_pu_inft.pe_fltc_data_i[(i+1)*WIDTH-1 -: WIDTH];
    end
    for (i = 0; i < M; i = i + 1) begin : GEN_scale_TAP
          assign scale_comp_data_tb[i] = dut.ofbuf_comp_data_w[(i+1)*WIDTH-1 -: WIDTH];
      end
  endgenerate
  CNN_accel #(
    .DATA_WIDTH(DATA_WIDTH),
    .ACC_WIDTH(ACC_WIDTH),
    .K(K),
    .M(M)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),

    .cnn_cpu_accel_busy_o(cnn_cpu_accel_busy_o),
    .cnn_cpu_accel_start_i(cnn_cpu_accel_start_i),
    .cnn_cpu_accel_done_o(cnn_cpu_accel_done_o),
    .cnn_cpu_receive_interupt_i(cnn_cpu_receive_interupt_i),

    .cnn_table_vld_i(cnn_table_vld_i),
    .cnn_table_rdy_o(cnn_table_rdy_o),
    .cnn_table_ifheight_i(cnn_table_ifheight_i),
    .cnn_table_ifchannel_i(cnn_table_ifchannel_i),
    .cnn_table_ofchannel_i(cnn_table_ofchannel_i),
    .cnn_table_hf_i(cnn_table_hf_i),
    .cnn_table_stride_i(cnn_table_stride_i),
    .cnn_table_padding_i(cnn_table_padding_i),
    .cnn_table_ifparr_i(cnn_table_ifparr_i),
    .cnn_table_oftile_i(cnn_table_oftile_i),
    .cnn_table_ofparr_i(cnn_table_ofparr_i),
    .cnn_table_ifbaddr_i(cnn_table_ifbaddr_i),
    .cnn_table_fltbaddr_i(cnn_table_fltbaddr_i),
    .cnn_table_bias_baddr_i(cnn_table_bias_baddr_i),
    .cnn_table_ofbaddr_i(cnn_table_ofbaddr_i),
    .cnn_table_ifc_zp_i(cnn_table_ifc_zp_i),
    .cnn_table_fltc_zp_i(cnn_table_fltc_zp_i),
    .cnn_table_mult_i(cnn_table_mult_i),
    .cnn_table_mult_shift_i(cnn_table_mult_shift_i),
    .cnn_table_alphamult_i(cnn_table_alphamult_i),
    .cnn_table_alphamult_shift_i(cnn_table_alphamult_shift_i),
    .cnn_table_zpy_i(cnn_table_zpy_i),
    .cnn_table_qmin_i(cnn_table_qmin_i),
    .cnn_table_qmax_i(cnn_table_qmax_i),
    .cnn_table_is_leaky_ReLU_i(cnn_table_is_leaky_ReLU_i),
    .cnn_table_is_use_pool_i(cnn_table_is_use_pool_i),
    .cnn_table_is_max_pool_i(cnn_table_is_max_pool_i),
    .cnn_table_pool_size_i(cnn_table_pool_size_i),
    .cnn_table_is_stride_over_i(cnn_table_is_stride_over_i),

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
    .cnn_ofbuf_dma_rdy_i(cnn_ofbuf_dma_rdy_i)
  );

  // =========================================================
  // Clock + init
  // =========================================================
  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;

    clear_table_interface();

    cnn_cpu_accel_start_i = 1'b0;
    cnn_cpu_receive_interupt_i = 1'b0;
    cnn_ifbuf_dma_rdycfg_i = 1'b0;
    cnn_fltbuf_dma_rdycfg_i = 1'b0;
    cnn_bias_dma_rdycfg_i = 1'b0;
    cnn_ofbuf_dma_rdycfg_i = 1'b0;
    cnn_ofbuf_dma_rdy_i = 1'b0;
    cnn_ifbuf_dma_vld_i = 1'b0;
    cnn_fltbuf_dma_vld_i = 1'b0;
    cnn_bias_dma_vld_i = 1'b0;
    cnn_ifbuf_dma_data_i = '0;
    cnn_fltbuf_dma_data_i = '0;
    cnn_bias_dma_data_i = '0;
    cnn_ifbuf_dma_tlast_i = 1'b0;
    cnn_fltbuf_dma_tlast_i = 1'b0;
    cnn_bias_dma_tlast_i = 1'b0;

    clear_all_memories();
    apply_reset();
    
    // Tham số: tc_name, w, h, ci, co, kw, kh, stride, padding, ifparr, ofparr, oftile, zp_if, zp_flt
    
    // Multi-layer smoke: ghi nhiều layer_description riêng biệt, sau đó mới pulse start.
    // run_case_multi_smoke();

    // 1) Ifmap kích thước chẵn, burst filter chẵn
    //ifmap 10x10, Ci=1, Co=4, kernel 3x3, ifparr=1, ofparr=2 (<= 6/3), oftile = 1, padding = 2, stride = 1
    // run_case("TC0_even_ifmap_even_burst", 28, 28, 1, 32, 3, 3, 1, 0, 1, 8, 2, 0, 0);
    // run_case("TC0_even_ifmap_even_burst", 5, 5, 32, 16, 5, 5, 1, 0, 4, 4, 4, 0, 0);
    // run_case("TC0_even_ifmap_even_burst", 2, 2, 256, 10, 2, 2, 1, 0, 4, 1, 5, 0, 0);
  // // $finish;
  //   // Pooling interface/scoreboard coverage.
  //   // run_case_pool parameters:
  //   // tc_name, w, h, ci, co, kw, kh, stride, padding, ifparr, ofparr, oftile,
  //   // if_zp, fl_zp, is_use_pool, is_max_pool, pool_size, pool_stride.
  //   // pool_stride rule: stride_over=1 when pool_size==pool_stride,
  //   // stride_over=0 when pool_size==pool_stride+1.
  //   // TC_POOL_NONE_EXPLICIT:
  //   // w=6, h=6, ci=1, co=4, kw=1, kh=1, stride=1, padding=0,
  //   // ifparr=1, ofparr=2, oftile=1, if_zp=0, fl_zp=0,
  //   // is_use_pool=0, is_max_pool=0, pool_size=1, pool_stride=1.
  //   // conv_ofwidth=6, pool_ofwidth=6.
    run_case_pool("TC_POOL_NONE_EXPLICIT", 224, 224, 3, 8, 7, 7, 2, 0, 3, 2, 1 , 0, 0,
                  1, 1, 3, 2);
    $finish;
    run_case_pool("TC_POOL_NONE_EXPLICIT", 12, 12, 32, 32, 3, 3, 1, 0, 4, 8, 2, 0, 0,
                  1, 1, 2, 2);
    // $finish;
    // run_case_pool("TC_POOL_MAX_3x3_STRIDE3", 224, 224, 1, 8, 1, 1, 1, 0, 1, 8, 1, 0, 0,
    //               1, 1, 2, 2);
    // TC_POOL_MAX_3x3_STRIDE3:
    // w=6, h=6, ci=1, co=4, kw=1, kh=1, stride=1, padding=0,
    // ifparr=1, ofparr=1, oftile=1, if_zp=0, fl_zp=0,
    // is_use_pool=1, is_max_pool=1, pool_size=3, pool_stride=3.
    // conv_ofwidth=6, pool_ofwidth=2.
    run_case_pool("TC_POOL_MAX_3x3_STRIDE3", 6, 6, 1, 4, 1, 1, 1, 0, 1, 1, 4, 0, 0,
                  1, 1, 3, 3);
    // TC_POOL_AVG_2x2_TAIL_STRIDE2:
    // w=5, h=5, ci=1, co=4, kw=1, kh=1, stride=1, padding=0,
    // ifparr=1, ofparr=2, oftile=1, if_zp=0, fl_zp=0,
    // is_use_pool=1, is_max_pool=0, pool_size=2, pool_stride=1.
    // conv_ofwidth=5, pool_ofwidth=3.
    run_case_pool("TC_POOL_AVG_2x2_STRIDE2", 5, 5, 1, 4, 1, 1, 1, 0, 1, 2, 1, 0, 0,
                  1, 1, 2, 1);
    // TC_POOL_AVG_2x2_TAIL_STRIDE2:
    // w=5, h=5, ci=1, co=4, kw=1, kh=1, stride=1, padding=0,
    // ifparr=1, ofparr=2, oftile=1, if_zp=0, fl_zp=0,
    // is_use_pool=1, is_max_pool=0, pool_size=2, pool_stride=2.
    // conv_ofwidth=5, pool_ofwidth=3.
    // run_case_pool("TC_POOL_AVG_2x2_TAIL_STRIDE2", 5, 5, 1, 4, 1, 1, 1, 0, 1, 2, 1, 0, 0,
    //               1, 0, 2, 2);
    // TC_POOL_GLOBAL_MAX:
    // w=5, h=5, ci=1, co=4, kw=1, kh=1, stride=1, padding=0,
    // ifparr=1, ofparr=2, oftile=1, if_zp=0, fl_zp=0,
    // is_use_pool=1, is_max_pool=1, pool_size=5, pool_stride=5.
    // conv_ofwidth=5, pool_ofwidth=1.
    run_case_pool("TC_POOL_GLOBAL_MAX", 5, 5, 1, 4, 1, 1, 1, 0, 1, 2, 1, 0, 0,
                  1, 1, 5, 5);
    // TC_POOL_GLOBAL_AVG:
    // w=7, h=7, ci=1, co=4, kw=1, kh=1, stride=1, padding=0,
    // ifparr=1, ofparr=2, oftile=1, if_zp=0, fl_zp=0,
    // is_use_pool=1, is_max_pool=0, pool_size=7, pool_stride=7.
    // conv_ofwidth=7, pool_ofwidth=1.
    // run_case_pool("TC_POOL_GLOBAL_AVG", 7, 7, 1, 4, 1, 1, 1, 0, 1, 2, 1, 0, 0,
    //               1, 0, 7, 7);
    // TC_POOL_MAX_3x3_OVERLAP_TAIL:
    // w=8, h=8, ci=1, co=4, kw=1, kh=1, stride=1, padding=0,
    // ifparr=1, ofparr=2, oftile=1, if_zp=0, fl_zp=0,
    // is_use_pool=1, is_max_pool=1, pool_size=3, pool_stride=2.
    // conv_ofwidth=8, pool_ofwidth=4.
    run_case_pool("TC_POOL_MAX_3x3_OVERLAP_TAIL", 8, 8, 1, 4, 1, 1, 1, 0, 1, 2, 1, 0, 0,
                  1, 1, 3, 2);

    // 2) Ifmap kich thuoc le -> test align width va padding hang ifmap
    // ifmap 5x5, Ci=8, Co=4, kernel 3x3, padding=1, ifparr=1, ofparr=2, oftile=2
    run_case("TC1_odd_ifmap_align_and_padding", 5, 5, 8, 4, 3, 3, 1, 1, 1, 2, 2, 3, 1);

    // 3) 1 burst filter le -> phai co them 1 word pad
    // ifmap 7x7, Ci=3, Co=10, kernel 3x3, ifparr=1, ofparr=1, oftile=2 (<= 2), padding = 1, stride = 1
    run_case("TC2_odd_filter_burst_need_pad", 7, 7, 3, 10, 3, 3, 1, 1, 1, 1, 2, 4, 5);

    // 4) So filter song song = 1 tile, stride = 2, padding = 2
    // ifmap 8x8, Ci=11, Co=3, kernel 3x3, ifparr=1, ofparr=2 (<= 6/3), oftile=1, padding=2, stride=2
    run_case("TC3_single_tile_stride2_pad2", 8, 8, 11, 3, 3, 3, 2, 2, 1, 2, 1, 2, 6);

    // 5) 1x1 pointwise, 2 block output-channel, test ofparr_tail
    // ifmap 11x11, Ci=3, Co=5, kernel 1x1, padding=0, stride=1, ifparr=1, ofparr=4 (<= 6/1), oftile=1
    run_case("TC4_pointwise_ofparr_tail_2block", 11, 11, 3, 5, 1, 1, 1, 0, 1, 4, 1, 3, 3);

    // 6) 1x1 pointwise, gop du output-channel vao 1 block, test oftiles_tail = 2
    // ifmap 11x11, Ci=3, Co=5, kernel 1x1, padding=0, stride=1, ifparr=1, ofparr=4, oftile=2
    run_case("TC5_pointwise_oftile_tail", 11, 11, 3, 5, 1, 1, 1, 0, 1, 4, 2, 3, 1);

    // 7) Dùng kernel 3x3 thay vì 5x5 (do hf max=3), stride=3, padding=1
    // ifmap 22x22, Ci=5, Co=7, kernel 3x3, ifparr=1, ofparr=2 (<= 6/3), oftile=1
    run_case("TC6_3x3_stride3_tail_mix", 22, 22, 5, 7, 3, 3, 3, 1, 1, 2, 1, 3, 2);

    // 8) stride = filter size, khong overlap receptive field
    // ifmap 9x9, Ci=4, Co=6, kernel 1x1, stride=1, padding=0, ifparr=1, ofparr=4, oftile=2
    run_case("TC7_stride_eq_filter", 9, 9, 4, 6, 1, 1, 1, 0, 1, 4, 2, 2, 3);

    // 9) padding lon nhung van nho hon filter, de cover case near-upper-bound
    // ifmap 11x11, Ci=2, Co=4, kernel 3x3, stride=1, padding=2, ifparr=1, ofparr=2, oftile=1
    run_case("TC8_padding_near_filter", 11, 11, 2, 4, 3, 3, 1, 2, 1, 2, 1, 4, 6);

    // 10) Dùng kernel 3x3 thay vì 7x7, pad=2 (do pad phải < kernel), stride=2
    // ifmap 13x13, Ci=3, Co=5, kernel 3x3, ifparr=1, ofparr=2 (<= 6/3), oftile=2
    run_case("TC9_3x3_kernel_tail", 13, 13, 3, 5, 3, 3, 2, 2, 1, 2, 2, 1, 3);

    // 11) ifmap nho, dùng kernel 3x3 thay vì 5x5, output 1 diem moi channel
    // ifmap 11x11, Ci=3, Co=3, kernel 3x3, stride=1, padding=0, ifparr=1, ofparr=2 (<= 6/3), oftile=1
    run_case("TC10_filter_3x3", 11, 11, 3, 3, 3, 3, 1, 0, 1, 2, 1, 1, 2);

    // 12) Ket hop stride = filter va padding < filter, sat hon voi CNN thuc te
    // ifmap 11x11, Ci=3, Co=4, kernel 3x3, stride=3, padding=2, ifparr=1, ofparr=2, oftile=2
    run_case("TC11_stride_eq_filter_pad_lt_filter", 11, 11, 3, 4, 3, 3, 3, 2, 1, 2, 2, 3, 5);


    // =====================================================
    // Reset-abort fault-tolerance checks
    // Muc tieu: reset dot ngot khi case chua xong, sau do chay ngay case tiep theo
    // KHONG goi apply_reset() them lan nua. Neu state noi bo/DMA/FSM chua duoc reset sach,
    // cac RECOVER case ben duoi se timeout hoac mismatch.
    // =====================================================

    // A) Reset rat som sau khi issue inftruction: cover loi FSM/DMA config dang bat dau.
    run_case_abort_reset("RST_ABORT_A_early_TC2", 7, 7, 3, 10, 3, 3, 1, 1, 1, 1, 2, 4, 5, 35, 0); 
    run_case("RST_RECOVER_A_next_no_extra_reset_TC3", 8, 8, 11, 3, 3, 3, 2, 2, 1, 2, 1, 2, 6);

    // B) Reset giua compute sau mot khoang clock: cover loi partial-sum/cache dang co du lieu cu. (Đổi TC6 xuống kernel 3x3)
    run_case_abort_reset("RST_ABORT_B_mid_compute_TC6", 22, 22, 5, 7, 3, 3, 3, 1, 1, 2, 1, 3, 2, 2200, 11);
    run_case("RST_RECOVER_B_next_no_extra_reset_TC7", 9, 9, 4, 6, 1, 1, 1, 0, 1, 4, 2, 2, 3);

    // C) Reset sau khi da co output packet dau tien nhung chua complete: cover loi output/scale pipeline. (Đổi TC9, TC10 xuống 3x3)
    // abort_cycles o day la watchdog toi da de doi packet dau tien.
    run_case_abort_reset("RST_ABORT_C_after_first_output_TC9", 13, 13, 3, 5, 3, 3, 2, 2, 1, 2, 2, 1, 3, 10000, 20);
    run_case("RST_RECOVER_C_next_no_extra_reset_TC10", 11, 11, 3, 3, 3, 3, 1, 0, 1, 2, 1, 1, 2);
    
    $display("\nAll requested environment-only and reset-abort testcases completed.");
    $finish;
  end
  initial begin
    // #10000 $finish;
  end
endmodule
