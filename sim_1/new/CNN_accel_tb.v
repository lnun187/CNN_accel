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
  localparam int WIDTH      = 32;
  localparam int DATA_WIDTH = WIDTH;
  localparam int ACC_WIDTH  = 32;
  localparam int K          = 4;
  localparam int M          = 2;

  localparam int MAX_MEM = 65536;
  localparam int MAX_W   = 32;
  localparam int MAX_H   = 32;
  localparam int MAX_C   = 64;
  localparam int MAX_F   = 64;
  localparam int MAX_KSZ = 16;
  localparam int MAX_OUT = 65536;

  // =========================================================
  // Clock / reset
  // =========================================================
  logic clk;
  logic rst_n;

  // =========================================================
  // DUT inputs / outputs
  // =========================================================
  logic        ifbuf_ins_vld_i;
  logic [31:0] ifbuf_ins_ifbaddr_i;
  logic [8:0]  ifbuf_ins_width_i;
  logic [10:0] ifbuf_ins_channel_i;
  logic [3:0]  ifbuf_ins_ifparr_i;
  logic [15:0]  ifbuf_ins_ifsize_i;
  logic [6:0]  ifbuf_ins_ifblock_i;
  logic [3:0]  ifbuf_ins_oftiles_i;
  logic [3:0]  ifbuf_ins_oftiles_tail_i;
  logic [6:0]  ifbuf_ins_iftiles_i;
  logic [8:0]  ifbuf_ins_wp_i;
  logic [1:0]  ifbuf_ins_padding_i;
  logic [DATA_WIDTH-1:0]  ifbuf_ins_ifc_zp_i;
  wire         ifbuf_ins_rdy_o;

  logic        fltbuf_ins_vld_i;
  logic [31:0] fltbuf_ins_fltbaddr_i;
  logic [3:0]  fltbuf_ins_ifparr_i;
  logic [3:0]  fltbuf_ins_ifparr_tail_i;
  logic [6:0]  fltbuf_ins_fltsize_i;
  logic [6:0]  fltbuf_ins_ifblock_i;
  logic [4:0]  fltbuf_ins_ofparr_i;
  logic [4:0]  fltbuf_ins_ofparr_tail_i;
  logic [3:0]  fltbuf_ins_oftiles_i;
  logic [3:0]  fltbuf_ins_oftiles_tail_i;
  logic [6:0]  fltbuf_ins_iftiles_i;
  wire         fltbuf_ins_rdy_o;

  logic [3:0]  comp_ins_hf_i;
  logic [2:0]  comp_ins_stride_i;
  logic [1:0]  comp_ins_padding_i;
  logic [DATA_WIDTH-1:0]  comp_ins_ifc_zp_i;
  logic [DATA_WIDTH-1:0]  comp_ins_fltc_zp_i;

  logic                  ifbuf_dma_rdycfg_i;
  logic                  ifbuf_dma_vld_i;
  logic [DATA_WIDTH-1:0] ifbuf_dma_data_i;
  logic                  ifbuf_dma_tlast_i;
  wire                   ifbuf_dma_vldcfg_o;
  wire [8:0]             ifbuf_dma_burst_o;
  wire [31:0]            ifbuf_dma_baddr_o;
  wire                   ifbuf_dma_rdy_o;

  logic                  fltbuf_dma_rdycfg_i;
  logic                  fltbuf_dma_vld_i;
  logic [DATA_WIDTH-1:0] fltbuf_dma_data_i;
  logic                  fltbuf_dma_tlast_i;
  wire                   fltbuf_dma_vldcfg_o;
  wire [9:0]             fltbuf_dma_burst_o;
  wire [31:0]            fltbuf_dma_baddr_o;
  wire                   fltbuf_dma_rdy_o;

  logic [M-1:0]            comp_ofbuf_rdy_i;
  wire  [M-1:0]            comp_ofbuf_vld_o;
  wire  [M*ACC_WIDTH-1:0]  comp_ofbuf_data_o;

  wire                     comp_pa_done_compute_o;
  wire                     ifbuf_comp_end_layer_o;
  wire                     fltbuf_comp_donepass_o;

  // =========================================================
  // External memories + scoreboard memories
  // =========================================================
  logic [DATA_WIDTH-1:0] if_ext_mem  [0:MAX_MEM-1];
  logic [DATA_WIDTH-1:0] flt_ext_mem [0:MAX_MEM-1];
  logic [ACC_WIDTH-1:0]  exp_out_mem [0:MAX_OUT-1];
  logic [ACC_WIDTH-1:0]  act_out_mem [0:MAX_OUT-1];
  logic [M*ACC_WIDTH-1:0] exp_pkt_mem [0:MAX_OUT-1];
  logic [M*ACC_WIDTH-1:0] act_pkt_mem [0:MAX_OUT-1];
  logic [M-1:0]           exp_vld_mem [0:MAX_OUT-1];
  logic [M-1:0]           act_vld_mem [0:MAX_OUT-1];

  int current_if_words;
  int current_flt_words;
  int exp_out_count;
  int act_out_count;
  int exp_pkt_count;
  int act_pkt_count;

  int current_if_base;
  int current_flt_base;
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

  task automatic clear_all_memories();
    int i;
    begin
      for (i = 0; i < MAX_MEM; i++) begin
        if_ext_mem[i]  = '0;
        flt_ext_mem[i] = '0;
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
      exp_out_count = 0;
      act_out_count = 0;
      exp_pkt_count = 0;
      act_pkt_count = 0;
      current_ifc_zp = 0;
      current_fltc_zp = 0;
    end
  endtask

  task automatic apply_reset();
    begin
      rst_n = 1'b0;
      ifbuf_ins_vld_i = 1'b0;
      fltbuf_ins_vld_i = 1'b0;
      ifbuf_dma_vld_i = 1'b0;
      fltbuf_dma_vld_i = 1'b0;
      ifbuf_dma_data_i = '0;
      fltbuf_dma_data_i = '0;
      ifbuf_dma_tlast_i = 1'b0;
      fltbuf_dma_tlast_i = 1'b0;
      comp_ofbuf_rdy_i = '1;
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
    input int kw,//width of kernel
    input int kh,//height of kernel
    input int ci,//channel of ifmap
    input int co,//channel of ofmap
    input int ifparr, //channel parrallel
    input int ofparr //filter parrallel
    // input current_oftile //filter tile
  );
    int addr;
    int fg, cg;
    int cp;
    int group_ch;
    int fo;
    int f_tile;
    int fp;
    int f_local, c_local, h_idx, w_idx;
    int burst_width;
    begin
      addr = base_addr;
      for (fg = 0; fg < co; fg += (ofparr * current_oftile)) begin
        group_ch = min2(ofparr * current_oftile, co - fg);
        fo       = ceil_div(group_ch, ofparr);
        for (cg = 0; cg < ci; cg += ifparr) begin
          cp = min2(ifparr, ci - cg);
          for (f_tile = 0; f_tile < fo; f_tile++) begin
            fp = min2(ofparr, group_ch - f_tile * ofparr);
            for (f_local = 0; f_local < fp; f_local++) begin
              for (c_local = 0; c_local < cp; c_local++) begin
                for (h_idx = 0; h_idx < kh; h_idx++) begin
                  for (w_idx = 0; w_idx < kw; w_idx++) begin
                    flt_ext_mem[addr] = mk_flt_val(
                      fg + f_tile * ofparr + f_local, //filter idx
                      cg + c_local,//channel idx
                      h_idx,//height idx
                      w_idx//width
                    );
                    addr++;
                  end
                end
              end
            end
            burst_width = kw * kh * cp * fp;
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

  // Expected output order theo mo ta ofbuf:
  // group channel = oftile * ofparr
  // trong moi group: h -> row_in_tile -> tile -> w
  // moi beat xuat {lane1, lane0}
  task automatic build_expected_output();
    logic [WIDTH-1:0] if_t [0:MAX_C-1][0:MAX_H-1][0:MAX_W-1];
    logic [WIDTH-1:0] flt_t[0:MAX_F-1][0:MAX_C-1][0:MAX_KSZ-1][0:MAX_KSZ-1];
    logic [ACC_WIDTH-1:0] of_t [0:MAX_F-1][0:MAX_H-1][0:MAX_W-1];
    logic [M*ACC_WIDTH-1:0] pkt_word;
    logic [M-1:0] pkt_vld;
    longint signed acc;
    int co_idx, ci_idx, h_idx, w_idx;
    int fg;
    int oh, ow;
    int ho, wo;
    int ih, iw;
    int group_ch;
    int tile_idx;
    int row_idx;
    int row_per_tile;
    int lane0_rel;
    int lane1_rel;
    int tile_base;
    int active_tiles;
    int fp_active;
    int row_per_tile_local;
    int lane0_seq [0:MAX_F-1];
    int lane1_seq [0:MAX_F-1];
    int lane0_count;
    int lane1_count;
    int fp_active_tile;
    int lane0_in_tile;
    int lane1_in_tile;
    int block_rows;
    int max_lane0_rows_tile;
    int max_lane1_rows_tile;
    int lane0_cnt_tile [0:31];
    int lane1_cnt_tile [0:31];
    logic signed [WIDTH:0] if_val_adj;
    logic signed [WIDTH:0] flt_val_adj;
    logic signed [2*WIDTH+1:0] mac_term;
    begin
      exp_out_count = 0;
      exp_pkt_count = 0;

      for (ci_idx = 0; ci_idx < current_ci; ci_idx++)
        for (h_idx = 0; h_idx < current_h; h_idx++)
          for (w_idx = 0; w_idx < current_w; w_idx++)
            if_t[ci_idx][h_idx][w_idx] = mk_if_val(ci_idx, h_idx, w_idx);

      for (co_idx = 0; co_idx < current_co; co_idx++)
        for (ci_idx = 0; ci_idx < current_ci; ci_idx++)
          for (h_idx = 0; h_idx < current_kh; h_idx++)
            for (w_idx = 0; w_idx < current_kw; w_idx++)
              flt_t[co_idx][ci_idx][h_idx][w_idx] = mk_flt_val(co_idx, ci_idx, h_idx, w_idx);

      ho = (current_h + 2 * current_padding - current_kh) / current_stride + 1;
      wo = (current_w + 2 * current_padding - current_kw) / current_stride + 1;
      row_per_tile = ceil_div(current_ofparr, M);

      for (co_idx = 0; co_idx < current_co; co_idx++) begin
        for (oh = 0; oh < ho; oh++) begin
          for (ow = 0; ow < wo; ow++) begin
            acc = 0;
            for (ci_idx = 0; ci_idx < current_ci; ci_idx++) begin
              for (h_idx = 0; h_idx < current_kh; h_idx++) begin
                for (w_idx = 0; w_idx < current_kw; w_idx++) begin
                  ih = oh * current_stride + h_idx - current_padding;
                  iw = ow * current_stride + w_idx - current_padding;
                  if ((ih >= 0) && (ih < current_h) && (iw >= 0) && (iw < current_w)) begin
                    if_val_adj  = $signed({1'b0, if_t[ci_idx][ih][iw]}) - $signed((WIDTH+1)'(current_ifc_zp));
                    flt_val_adj = $signed({1'b0, flt_t[co_idx][ci_idx][h_idx][w_idx]}) - $signed((WIDTH+1)'(current_fltc_zp));
                    mac_term    = if_val_adj * flt_val_adj;
                    acc += mac_term;
                  end
                end
              end
            end
            of_t[co_idx][oh][ow] = acc[ACC_WIDTH-1:0];
          end
        end
      end

      exp_out_count = current_co * ho * wo;

      for (fg = 0; fg < current_co; fg += (current_oftile * current_ofparr)) begin
        group_ch            = min2(current_oftile * current_ofparr, current_co - fg);
        active_tiles        = ceil_div(group_ch, current_ofparr);
        lane0_count         = 0;
        lane1_count         = 0;
        max_lane0_rows_tile = 0;
        max_lane1_rows_tile = 0;

        for (tile_idx = 0; tile_idx < active_tiles; tile_idx++) begin
          tile_base      = tile_idx * current_ofparr;
          fp_active_tile = min2(current_ofparr, group_ch - tile_base);
          lane0_in_tile  = ceil_div(fp_active_tile, M);
          lane1_in_tile  = fp_active_tile - lane0_in_tile;

          lane0_cnt_tile[tile_idx] = lane0_in_tile;
          lane1_cnt_tile[tile_idx] = lane1_in_tile;

          if (lane0_in_tile > max_lane0_rows_tile) max_lane0_rows_tile = lane0_in_tile;
          if (lane1_in_tile > max_lane1_rows_tile) max_lane1_rows_tile = lane1_in_tile;
        end

        // Thu tu accel: trong moi lane, xuat theo row cua lane tren toan block.
        // Vi du oftile=2, ofparr=3 => lane0: 0,3,1 ; lane1: 2,4
        for (row_idx = 0; row_idx < max_lane0_rows_tile; row_idx++) begin
          for (tile_idx = 0; tile_idx < active_tiles; tile_idx++) begin
            tile_base = tile_idx * current_ofparr;
            if (row_idx < lane0_cnt_tile[tile_idx]) begin
              lane0_seq[lane0_count] = tile_base + row_idx;
              lane0_count = lane0_count + 1;
            end
          end
        end

        for (row_idx = 0; row_idx < max_lane1_rows_tile; row_idx++) begin
          for (tile_idx = 0; tile_idx < active_tiles; tile_idx++) begin
            tile_base = tile_idx * current_ofparr;
            if (row_idx < lane1_cnt_tile[tile_idx]) begin
              lane1_seq[lane1_count] = tile_base + lane0_cnt_tile[tile_idx] + row_idx;
              lane1_count = lane1_count + 1;
            end
          end
        end

        block_rows = (lane0_count > lane1_count) ? lane0_count : lane1_count;
        for (oh = 0; oh < ho; oh++) begin
          for (row_idx = 0; row_idx < block_rows; row_idx++) begin
            for (ow = 0; ow < wo; ow++) begin
              pkt_vld  = '0;
              pkt_word = '0;

              if (row_idx < lane0_count) begin
                pkt_vld[0] = 1'b1;
                pkt_word[ACC_WIDTH-1:0] = of_t[fg + lane0_seq[row_idx]][oh][ow];
              end
              if (row_idx < lane1_count) begin
                pkt_vld[1] = 1'b1;
                pkt_word[2*ACC_WIDTH-1:ACC_WIDTH] = of_t[fg + lane1_seq[row_idx]][oh][ow];
              end

              exp_vld_mem[exp_pkt_count] = pkt_vld;
              exp_pkt_mem[exp_pkt_count] = pkt_word;
              exp_pkt_count = exp_pkt_count + 1;
            end
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
      ifbuf_dma_rdycfg_i <= 1'b0;
      ifbuf_dma_vld_i    <= 1'b0;
      ifbuf_dma_data_i   <= '0;
      ifbuf_dma_tlast_i  <= 1'b0;

      forever begin
        @(posedge clk);

        if (!rst_n) begin
          busy               = 1'b0;
          req_base           = 0;
          req_words          = 0;
          idx                = 0;
          ifbuf_dma_rdycfg_i <= 1'b1;
          ifbuf_dma_vld_i    <= 1'b0;
          ifbuf_dma_data_i   <= '0;
          ifbuf_dma_tlast_i  <= 1'b0;
        end else begin
          ifbuf_dma_vld_i   <= 1'b0;
          ifbuf_dma_tlast_i <= 1'b0;

          if (!busy) begin
            ifbuf_dma_rdycfg_i <= 1'b1;
            if (ifbuf_dma_vldcfg_o) begin
              req_base           = ifbuf_dma_baddr_o;
              req_words          = ifbuf_dma_burst_o;
              idx                = 0;
              busy               = 1'b1;
              ifbuf_dma_rdycfg_i <= 1'b0;
            end
          end else begin
            ifbuf_dma_rdycfg_i <= 1'b0;
            if (ifbuf_dma_rdy_o && (idx < req_words)) begin
              ifbuf_dma_vld_i   <= 1'b1;
              ifbuf_dma_data_i  <= if_ext_mem[req_base + idx];
              ifbuf_dma_tlast_i <= (idx == req_words - 1);

              if (idx == req_words - 1) begin
                busy = 1'b0;
                ifbuf_dma_rdycfg_i <= 1'b1;
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
      fltbuf_dma_rdycfg_i <= 1'b0;
      fltbuf_dma_vld_i    <= 1'b0;
      fltbuf_dma_data_i   <= '0;
      fltbuf_dma_tlast_i  <= 1'b0;

      forever begin
        @(posedge clk);

        if (!rst_n) begin
          busy               = 1'b0;
          req_base           = 0;
          req_words          = 0;
          idx                = 0;
          fltbuf_dma_rdycfg_i <= 1'b1;
          fltbuf_dma_vld_i    <= 1'b0;
          fltbuf_dma_data_i   <= '0;
          fltbuf_dma_tlast_i  <= 1'b0;
        end else begin
          fltbuf_dma_rdycfg_i <= !busy;
          fltbuf_dma_vld_i    <= 1'b0;
          fltbuf_dma_data_i   <= '0;
          fltbuf_dma_tlast_i  <= '0;

          if (!busy) begin
            if (fltbuf_dma_vldcfg_o && fltbuf_dma_rdycfg_i) begin
              req_base  = fltbuf_dma_baddr_o;
              req_words = fltbuf_dma_burst_o;
              idx       = 0;
              busy      = 1'b1;
              fltbuf_dma_rdycfg_i <= 0;
            end
          end else begin
            if (fltbuf_dma_rdy_o) begin
              fltbuf_dma_vld_i   <= 1'b1;
              fltbuf_dma_data_i  <= flt_ext_mem[req_base + idx];
              fltbuf_dma_tlast_i <= (idx == req_words - 1);

              if (idx == req_words - 1) begin
                busy = 1'b0;
                fltbuf_dma_rdycfg_i <= 1;
              end
              idx = idx + 1;
            end
          end
        end
      end
    end
  endtask

  // Collector theo tung beat {lane1, lane0}.
  // Chi so sanh cac lane co valid = 1.
  task automatic collect_outputs(input int wanted_pkt_count, input int wanted_scalar_count);
    int watchdog;
    int lane;
    begin
      watchdog = 0;
      act_pkt_count = 0;
      act_out_count = 0;
      while ((act_pkt_count < wanted_pkt_count) && (watchdog < 500000)) begin
        @(posedge clk);
        if (rst_n) begin
          if (|(comp_ofbuf_vld_o & comp_ofbuf_rdy_i)) begin
            act_vld_mem[act_pkt_count] = comp_ofbuf_vld_o & comp_ofbuf_rdy_i;
            act_pkt_mem[act_pkt_count] = comp_ofbuf_data_o;
            for (lane = 0; lane < M; lane++) begin
              if ((comp_ofbuf_vld_o[lane] == 1'b1) && (comp_ofbuf_rdy_i[lane] == 1'b1)) begin
                act_out_mem[act_out_count] = comp_ofbuf_data_o[lane*ACC_WIDTH +: ACC_WIDTH];
                act_out_count = act_out_count + 1;
              end
            end
            act_pkt_count = act_pkt_count + 1;
          end
        end
        watchdog = watchdog + 1;
      end
      if (act_pkt_count != wanted_pkt_count)
        $fatal(1, "Output collection timeout. collected_pkt=%0d wanted_pkt=%0d", act_pkt_count, wanted_pkt_count);
      if (act_out_count != wanted_scalar_count)
        $fatal(1, "Output scalar count mismatch after collection. collected=%0d wanted=%0d", act_out_count, wanted_scalar_count);
    end
    $display("act_pkt_count=%0d act_out_count=%0d vld=%b",
         act_pkt_count, act_out_count, comp_ofbuf_vld_o & comp_ofbuf_rdy_i);
  endtask

  task automatic issue_instructions();
    begin
      wait (ifbuf_ins_rdy_o === 1'b1 && fltbuf_ins_rdy_o === 1'b1);
      @(posedge clk);
      ifbuf_ins_vld_i  <= 1'b1;
      fltbuf_ins_vld_i <= 1'b1;
      @(posedge clk);
      ifbuf_ins_vld_i  <= 1'b0;
      fltbuf_ins_vld_i <= 1'b0;
    end
  endtask

  task automatic compare_outputs(input string tc_name);
    int i;
    int lane;
    begin
      if (act_pkt_count != exp_pkt_count)
        $fatal(1, "%s: packet count mismatch. act=%0d exp=%0d", tc_name, act_pkt_count, exp_pkt_count);
      if (act_out_count != exp_out_count)
        $fatal(1, "%s: scalar count mismatch. act=%0d exp=%0d", tc_name, act_out_count, exp_out_count);

      for (i = 0; i < exp_pkt_count; i++) begin
        if (act_vld_mem[i] !== exp_vld_mem[i]) begin
          $display("%s: valid mismatch at pkt=%0d act_vld=%b exp_vld=%b", tc_name, i, act_vld_mem[i], exp_vld_mem[i]);
          $fatal(1, "%s failed", tc_name);
        end
        for (lane = 0; lane < M; lane++) begin
          if (exp_vld_mem[i][lane]) begin
            if (act_pkt_mem[i][lane*ACC_WIDTH +: ACC_WIDTH] !== exp_pkt_mem[i][lane*ACC_WIDTH +: ACC_WIDTH]) begin
              $display("%s: data mismatch at pkt=%0d lane=%0d act=0x%08x exp=0x%08x",
                       tc_name, i, lane,
                       act_pkt_mem[i][lane*ACC_WIDTH +: ACC_WIDTH],
                       exp_pkt_mem[i][lane*ACC_WIDTH +: ACC_WIDTH]);
              $fatal(1, "%s failed", tc_name);
            end
          end
        end
      end
      $display("[PASS] %s : %0d packets / %0d outputs matched", tc_name, exp_pkt_count, exp_out_count);
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
    int align_w;
    int iftiles;
    int ifparr_tail;
    int ofparr_tail;
    int total_oftiles;
    int oftiles_tail;
    int wp;
    int normal_burst;
    begin
      $display("\n========== RUN %s ==========", tc_name);

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

      clear_all_memories();

      current_if_base   = 0;
      current_flt_base  = 8192;
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

      fill_ifmap_external_memory(current_if_base, w, h, ci);
      fill_filter_external_memory(current_flt_base, kw, kh, ci, co, ifparr, ofparr);
      build_expected_output();
      $display("%s: exp_pkt_count=%0d exp_out_count=%0d",
         tc_name, exp_pkt_count, exp_out_count);
      align_w      = align_even(w);
      iftiles      = ceil_div(ci, ifparr);
      ifparr_tail  = ((ci % ifparr) == 0) ? ifparr : (ci % ifparr);
      ofparr_tail  = ((co % ofparr) == 0) ? ofparr : (co % ofparr);
      total_oftiles = ceil_div(co, ofparr);
      oftiles_tail = ((total_oftiles % oftile) == 0) ? oftile : (total_oftiles % oftile);
      wp           = ((w + 2 * padding - kh) / stride) * stride + kh - 1;
      normal_burst = kw * kh;

      // Program IFBUF instruction fields
      ifbuf_ins_ifbaddr_i      = current_if_base;
      ifbuf_ins_width_i        = w[8:0];
      ifbuf_ins_channel_i      = ci[10:0];
      ifbuf_ins_ifparr_i       = ifparr[3:0];
      ifbuf_ins_ifsize_i       = align_w * h;
      ifbuf_ins_ifblock_i      = ceil_div(co, (ofparr*oftile));
      ifbuf_ins_oftiles_i      = oftile[3:0];
      ifbuf_ins_oftiles_tail_i = oftiles_tail[3:0];
      ifbuf_ins_iftiles_i      = iftiles[6:0];
      ifbuf_ins_wp_i           = wp[8:0];
      ifbuf_ins_padding_i      = padding[1:0];
      ifbuf_ins_ifc_zp_i       = current_ifc_zp[DATA_WIDTH-1:0];

      // Program FLTBUF instruction fields
      fltbuf_ins_fltbaddr_i      = current_flt_base;
      fltbuf_ins_ifparr_i        = ifparr[3:0];
      fltbuf_ins_ifparr_tail_i   = ifparr_tail[3:0];
      fltbuf_ins_fltsize_i       = normal_burst;
      fltbuf_ins_ifblock_i       = ceil_div(co, (ofparr*oftile));
      fltbuf_ins_ofparr_i        = ofparr[4:0];
      fltbuf_ins_ofparr_tail_i   = ofparr_tail[4:0];
      fltbuf_ins_oftiles_i       = oftile;
      fltbuf_ins_oftiles_tail_i  = oftiles_tail[3:0];
      fltbuf_ins_iftiles_i       = iftiles[6:0];

      // Program COMPUTATION instruction fields
      comp_ins_hf_i         = kh[3:0];
      comp_ins_stride_i     = stride[2:0];
      comp_ins_padding_i    = padding[1:0];
      comp_ins_ifc_zp_i     = current_ifc_zp[DATA_WIDTH-1:0];
      comp_ins_fltc_zp_i    = current_fltc_zp[DATA_WIDTH-1:0];

      fork
        if_dma_agent();
        flt_dma_agent();
        collect_outputs(exp_pkt_count, exp_out_count);
      join_none

      issue_instructions();
      wait (act_pkt_count == exp_pkt_count);
      repeat (20) @(posedge clk);
      compare_outputs(tc_name);

      disable fork;
      repeat (10) @(posedge clk);
    end
  endtask

  // =========================================================
  // DUT
  // =========================================================
  wire [WIDTH-1:0]     fltbuf_comp_data_tb   [0:K*M-1];
  wire [WIDTH-1:0]     ifbuf_comp_data_tb    [0:K-1];
  wire [ACC_WIDTH-1:0] ofbuf_comp_data_tb    [0:M-1];
  wire [WIDTH-1:0]     flt_cache_pe_data_tb  [0:K*M*12-1];
  wire [WIDTH-1:0]     if_cache_pe_data_tb   [0:K-1];
  genvar i;
  generate
      for (i = 0; i < K*M; i = i + 1) begin : GEN_FLTBUF_TAP
          assign fltbuf_comp_data_tb[i] = dut.fltbuf_comp_data_w[(i+1)*WIDTH-1 -: WIDTH];
      end
      for (i = 0; i < K; i = i + 1) begin : GEN_IFBUF_TAP
          assign ifbuf_comp_data_tb[i]  = dut.ifbuf_comp_data_w[(i+1)*WIDTH-1 -: WIDTH];
          assign if_cache_pe_data_tb[i] = dut.u_computation.ifmap_cache_inst.ifc_pu_data_o[(i+1)*WIDTH-1 -: WIDTH];
      end
    for (i = 0; i < K*M*12; i = i + 1) begin : GEN_FTC_TAP
        assign flt_cache_pe_data_tb[i] =
            dut.u_computation.gen_comp_pu[0].comp_pu_inst.pe_fltc_data_i[(i+1)*WIDTH-1 -: WIDTH];
    end
    for (i = 0; i < M; i = i + 1) begin : GEN_OFBUF_TAP
          assign ofbuf_comp_data_tb[i] = comp_ofbuf_data_o[(i+1)*ACC_WIDTH-1 -: ACC_WIDTH];
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

    .ifbuf_ins_vld_i(ifbuf_ins_vld_i),
    .ifbuf_ins_ifbaddr_i(ifbuf_ins_ifbaddr_i),
    .ifbuf_ins_width_i(ifbuf_ins_width_i),
    .ifbuf_ins_channel_i(ifbuf_ins_channel_i),
    .ifbuf_ins_ifparr_i(ifbuf_ins_ifparr_i),
    .ifbuf_ins_ifsize_i(ifbuf_ins_ifsize_i),
    .ifbuf_ins_ifblock_i(ifbuf_ins_ifblock_i),
    .ifbuf_ins_oftiles_i(ifbuf_ins_oftiles_i),
    .ifbuf_ins_oftiles_tail_i(ifbuf_ins_oftiles_tail_i),
    .ifbuf_ins_iftiles_i(ifbuf_ins_iftiles_i),
    .ifbuf_ins_wp_i(ifbuf_ins_wp_i),
    .ifbuf_ins_padding_i(ifbuf_ins_padding_i),
    .ifbuf_ins_ifc_zp_i(ifbuf_ins_ifc_zp_i),
    .ifbuf_ins_rdy_o(ifbuf_ins_rdy_o),

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

    .comp_ins_hf_i(comp_ins_hf_i),
    .comp_ins_stride_i(comp_ins_stride_i),
    .comp_ins_padding_i(comp_ins_padding_i),
    .comp_ins_ifc_zp_i(comp_ins_ifc_zp_i),
    .comp_ins_fltc_zp_i(comp_ins_fltc_zp_i),

    .ifbuf_dma_rdycfg_i(ifbuf_dma_rdycfg_i),
    .ifbuf_dma_vld_i(ifbuf_dma_vld_i),
    .ifbuf_dma_data_i(ifbuf_dma_data_i),
    .ifbuf_dma_tlast_i(ifbuf_dma_tlast_i),
    .ifbuf_dma_vldcfg_o(ifbuf_dma_vldcfg_o),
    .ifbuf_dma_burst_o(ifbuf_dma_burst_o),
    .ifbuf_dma_baddr_o(ifbuf_dma_baddr_o),
    .ifbuf_dma_rdy_o(ifbuf_dma_rdy_o),

    .fltbuf_dma_rdycfg_i(fltbuf_dma_rdycfg_i),
    .fltbuf_dma_vld_i(fltbuf_dma_vld_i),
    .fltbuf_dma_data_i(fltbuf_dma_data_i),
    .fltbuf_dma_tlast_i(fltbuf_dma_tlast_i),
    .fltbuf_dma_vldcfg_o(fltbuf_dma_vldcfg_o),
    .fltbuf_dma_burst_o(fltbuf_dma_burst_o),
    .fltbuf_dma_baddr_o(fltbuf_dma_baddr_o),
    .fltbuf_dma_rdy_o(fltbuf_dma_rdy_o),

    .comp_ofbuf_rdy_i(comp_ofbuf_rdy_i),
    .comp_ofbuf_vld_o(comp_ofbuf_vld_o),
    .comp_ofbuf_data_o(comp_ofbuf_data_o),

    .comp_pa_done_compute_o(comp_pa_done_compute_o),
    .ifbuf_comp_end_layer_o(ifbuf_comp_end_layer_o),
    .fltbuf_comp_donepass_o(fltbuf_comp_donepass_o)
  );

  // =========================================================
  // Clock + init
  // =========================================================
  always #5 clk = ~clk;

  initial begin
    clk = 1'b0;
    rst_n = 1'b0;

    ifbuf_ins_vld_i = 1'b0;
    fltbuf_ins_vld_i = 1'b0;
    ifbuf_ins_ifbaddr_i = '0;
    ifbuf_ins_width_i = '0;
    ifbuf_ins_channel_i = '0;
    ifbuf_ins_ifparr_i = '0;
    ifbuf_ins_ifsize_i = '0;
    ifbuf_ins_ifblock_i = '0;
    ifbuf_ins_oftiles_i = '0;
    ifbuf_ins_oftiles_tail_i = '0;
    ifbuf_ins_iftiles_i = '0;
    ifbuf_ins_wp_i = '0;
    ifbuf_ins_padding_i = '0;
    ifbuf_ins_ifc_zp_i = '0;

    fltbuf_ins_fltbaddr_i = '0;
    fltbuf_ins_ifparr_i = '0;
    fltbuf_ins_ifparr_tail_i = '0;
    fltbuf_ins_fltsize_i = '0;
    fltbuf_ins_ifblock_i = '0;
    fltbuf_ins_ofparr_i = '0;
    fltbuf_ins_ofparr_tail_i = '0;
    fltbuf_ins_oftiles_i = '0;
    fltbuf_ins_oftiles_tail_i = '0;
    fltbuf_ins_iftiles_i = '0;

    comp_ins_hf_i = '0;
    comp_ins_stride_i = '0;
    comp_ins_padding_i = '0;
    comp_ins_ifc_zp_i = '0;
    comp_ins_fltc_zp_i = '0;

    ifbuf_dma_rdycfg_i = 1'b0;
    fltbuf_dma_rdycfg_i = 1'b0;
    ifbuf_dma_vld_i = 1'b0;
    fltbuf_dma_vld_i = 1'b0;
    ifbuf_dma_data_i = '0;
    fltbuf_dma_data_i = '0;
    ifbuf_dma_tlast_i = 1'b0;
    fltbuf_dma_tlast_i = 1'b0;
    comp_ofbuf_rdy_i = '1;

    clear_all_memories();
    apply_reset();
    //tc_name, w, h, ci, co, kw, kh, stride, padding, ifparr, ofparr, oftile,zp,zp
    
    // 1) Ifmap kích thước chẵn, burst filter chẵn
    //ifmap 10x10, Ci=1, Co=4, kernel 3x3, ifparr=1, ofparr=4, oftile = 1, padding = 2
    run_case("TC0_even_ifmap_even_burst", 10, 10, 1, 4, 3, 3, 1, 2, 1, 4, 1, 0, 0);  

    // 2) Ifmap kich thuoc le -> test align width va padding hang ifmap
    // ifmap 5x5, Ci=8, Co=4, kernel 3x3, padding=1, ifparr=1, ofparr=2, oftile=2
    run_case("TC1_odd_ifmap_align_and_padding", 5, 5, 8, 4, 3, 3, 1, 1, 1, 2, 2, 3, 1);

    // 3) 1 burst filter le -> phai co them 1 word pad
    // ifmap 7x7, Ci=3, Co=10, kernel 3x3, ifparr=3, ofparr=1, oftile=3, padding = 1, stride = 1
    run_case("TC2_odd_filter_burst_need_pad", 7, 7, 3, 10, 3, 3, 1, 1, 3, 1, 3, 4, 5);

    // 4) So filter song song = 1 tile, stride = 2, padding = 2
    // ifmap 8x8, Ci=11, Co=3, kernel 3x3, ifparr=1, ofparr=3, oftile=1, padding=2, stride=2
    run_case("TC3_single_tile_stride2_pad2", 8, 8, 11, 3, 3, 3, 2, 2, 1, 3, 1, 2, 6);

    // 5) 1x1 pointwise, 2 block output-channel, test ofparr_tail
    // ifmap 11x11, Ci=3, Co=5, kernel 1x1, padding=0, stride=1, ifparr=2, ofparr=3, oftile=1
    run_case("TC4_pointwise_ofparr_tail_2block", 11, 11, 3, 5, 1, 1, 1, 0, 2, 4, 1, 3, 3);

    // 6) 1x1 pointwise, gop du output-channel vao 1 block, test oftiles_tail = 2
    // ifmap 11x11, Ci=3, Co=5, kernel 1x1, padding=0, stride=1, ifparr=2, ofparr=3, oftile=2
    run_case("TC5_pointwise_oftile_tail", 11, 11, 3, 5, 1, 1, 1, 0, 2, 4, 2, 3, 1);

    // 7) Kernel lon 5x5, stride=3 (< filter), padding=1, test ifparr/ofparr tail dong thoi
    // ifmap 22x22, Ci=5, Co=7, kernel 5x5, ifparr=2, ofparr=3, oftile=1
    run_case("TC6_5x5_stride3_tail_mix", 22, 22, 5, 7, 5, 5, 3, 1, 2, 3, 1, 3, 2);

    // 8) stride = filter size, khong overlap receptive field
    // ifmap 9x9, Ci=4, Co=6, kernel 1x1, stride=1, padding=0, ifparr=2, ofparr=2, oftile=2
    run_case("TC7_stride_eq_filter", 9, 9, 4, 6, 1, 1, 1, 0, 2, 4, 2, 2, 3);

    // 9) padding lon nhung van nho hon filter, de cover case near-upper-bound
    // ifmap 11x11, Ci=2, Co=4, kernel 3x3, stride=1, padding=2, ifparr=1, ofparr=2, oftile=1
    run_case("TC8_padding_near_filter", 11, 11, 2, 4, 3, 3, 1, 2, 1, 2, 1, 4, 6);

    // 10) Kernel 7x7, stride=2, padding=3 (same-like), test burst lon hon va output tile tail
    // ifmap 13x13, Ci=3, Co=5, kernel 7x7, ifparr=3, ofparr=2, oftile=2
    run_case("TC9_7x7_large_kernel_tail", 13, 13, 3, 5, 7, 7, 2, 3, 3, 2, 2, 1, 3);

    // 11) ifmap nho, filter bang ifmap, output 1 diem moi channel
    // ifmap 11x11, Ci=3, Co=3, kernel 5x5, stride=1, padding=0, ifparr=2, ofparr=2, oftile=1
    run_case("TC10_filter_equal_ifmap", 11, 11, 3, 3, 5, 5, 1, 0, 2, 2, 1, 1, 2);

    // 12) Ket hop stride = filter va padding < filter, sat hon voi CNN thuc te
    // ifmap 11x11, Ci=3, Co=4, kernel 3x3, stride=3, padding=2, ifparr=1, ofparr=2, oftile=2
    run_case("TC11_stride_eq_filter_pad_lt_filter", 11, 11, 3, 4, 3, 3, 3, 2, 1, 2, 2, 3, 5);
    $display("\nAll requested environment-only testcases completed.");
    $finish;
  end
  initial begin
    // #200000 $finish;
  end
endmodule

