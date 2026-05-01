`timescale 1ns / 1ps

module fltbuf_tb;

  parameter DATA_WIDTH = 32;
  parameter K          = 8;
  parameter M          = 2;
  parameter MAX_CFG    = 128;
  parameter MAX_GROUP  = 32;
  parameter MAX_Q      = 256;

  reg clk;
  reg rst_n;

  reg         fltbuf_inf_vld_i;
  reg [31:0]  fltbuf_inf_fltbaddr_i;
  reg [8:0]   fltbuf_inf_width_i;
  reg [10:0]  fltbuf_inf_channel_i;
  reg [3:0]   fltbuf_inf_ifparr_i;
  reg [3:0]   fltbuf_inf_ifparr_tail_i;
  reg [6:0]   fltbuf_inf_fltsize_i;
  reg [6:0]   fltbuf_inf_ifblock_i;
  reg [4:0]   fltbuf_inf_ofparr_i;
  reg [4:0]   fltbuf_inf_ofparr_tail_i;
  reg [3:0]   fltbuf_inf_oftiles_i;
  reg [3:0]   fltbuf_inf_oftiles_tail_i;
  reg [6:0]   fltbuf_inf_iftiles_i;
  reg [8:0]   fltbuf_inf_wp_i;
  reg [1:0]   fltbuf_inf_padding_i;
  reg [7:0]   fltbuf_inf_ifc_zp_i;
  reg         fltbuf_ifbuf_end_layer_i;

  reg         fltbuf_dma_rdycfg_i;
  reg         fltbuf_dma_vld_i;
  reg [DATA_WIDTH-1:0] fltbuf_dma_data_i;
  reg         fltbuf_dma_tlast_i;
  reg         fltbuf_comp_rdy_i;

  wire           fltbuf_inf_rdy_o;
  wire           fltbuf_dma_vldcfg_o;
  wire [9:0]     fltbuf_dma_burst_o;
  wire [31:0]    fltbuf_dma_baddr_o;
  wire           fltbuf_dma_rdy_o;
  wire [K*M-1:0] fltbuf_comp_vld_o;
  wire [K*M*DATA_WIDTH-1:0] fltbuf_comp_data_o;
  wire           fltbuf_comp_donepass_o;
  reg [DATA_WIDTH-1:0] fltbuf_comp_data [K*M-1:0];
  integer test;
  always @ (*) begin
    for(test = 0; test < K*M; test = test + 1) fltbuf_comp_data[test] = fltbuf_comp_data_o[test*DATA_WIDTH +: DATA_WIDTH];
  end
  integer cycle_ctr;
  integer err_count;
  integer warn_count;
  integer accept_cycle;
  integer first_hs_cycle;
  integer exp_cfg_total;
  integer got_cfg_total;
  integer num_groups;
  integer group_start [0:MAX_GROUP-1];
  integer group_count [0:MAX_GROUP-1];
  integer group_words [0:MAX_GROUP-1];
  reg [31:0] exp_addr [0:MAX_CFG-1];
  reg [9:0]  exp_burst[0:MAX_CFG-1];

  reg        checking_en;
  reg        check_addr_chain;

  reg        cfg_bp_en;
  integer    cfg_bp_target0;
  integer    cfg_bp_target1;
  integer    cfg_bp_hold0;
  integer    cfg_bp_hold1;
  reg        dma_rdycfg_default;

  reg        data_stream_en;
  reg        comp_rdy_auto_en;
  integer    comp_rdy_recv_cfg_idx;
  integer    comp_rdy_recv_word_idx;
  integer    comp_rdy_block_idx;
  integer    comp_rdy_delay_ctr;
  integer    comp_rdy_recv_block_idx;
  reg        comp_rdy_hold_high;
  reg        comp_rdy_wait_change;
  integer    comp_rdy_loaded_passes [0:MAX_GROUP-1];
  integer    comp_rdy_done_passes   [0:MAX_GROUP-1];
  integer    stream_q [0:MAX_Q-1];
  integer    q_head;
  integer    q_tail;
  integer    q_count;
  integer    q_cfg_idx [0:MAX_Q-1];
  integer    stream_remaining;
  integer    stream_words_sent;
  integer    stream_words_expected;
  integer    stream_words_this_cfg;
  integer    stream_word_idx;
  integer    stream_cfg_idx;
  reg        stream_active;
  integer    exp_cfg_ifparr [0:MAX_CFG-1];
  integer    exp_cfg_ofparr [0:MAX_CFG-1];
  integer    exp_cfg_fltsize[0:MAX_CFG-1];

  integer i;
  integer lane;

  // ==========================================================================
  // Directed checker for fltbuf_comp_data_o
  //   - donepass duoc xem la 1 pass da doc xong
  //   - comp_rdy len 1 va giu 1 cho toi khi nhan donepass
  //   - sau moi donepass trong cung 1 block: comp_rdy xuong 0 trong 3 chu ky,
  //     sau do len 1 lai neu pass tiep theo cua block da load xong
  //   - donepass du het so pass cua 1 block thi comp_rdy giu 0 cho den khi
  //     nhan fltbuf_ifbuf_end_layer_i de mo block tiep theo
  //   - inf_rdy chi len 1 sau khi da gui xong toan bo pass cua 1 layer
  //     va da nhan fltbuf_ifbuf_end_layer_i o cuoi layer
  //   - comp checker sample o negedge clk de tranh bat som 1 beat
  // ==========================================================================
  localparam [31:0] COMPCHK_BASE_ADDR     = 32'h0000_1000;
  localparam [3:0]  COMPCHK_IFPARR        = 4'd4;
  localparam [3:0]  COMPCHK_IFPARR_T      = 4'd4;
  localparam [6:0]  COMPCHK_FLTSIZE       = 7'd9;
  localparam [6:0]  COMPCHK_IFBLOCK       = 7'd2;
  localparam [4:0]  COMPCHK_OFPARR        = 5'd6;
  localparam [4:0]  COMPCHK_OFPARR_T      = 5'd6;
  localparam [3:0]  COMPCHK_OFTILES       = 4'd1;
  localparam [3:0]  COMPCHK_OFTILES_T     = 4'd1;
  localparam [6:0]  COMPCHK_IFTILES       = 7'd1;
  localparam integer COMPCHK_TOTAL_CFGS         = COMPCHK_IFBLOCK * COMPCHK_IFTILES * COMPCHK_OFTILES;
  localparam integer COMPCHK_CFGS_PER_BLOCK     = COMPCHK_IFTILES * COMPCHK_OFTILES;
  localparam integer COMPCHK_OUT_BEATS_PER_PASS = COMPCHK_FLTSIZE * ((COMPCHK_OFPARR + 1) / 2);
  localparam integer COMPCHK_OUT_BEATS_PER_BLK  = COMPCHK_CFGS_PER_BLOCK * COMPCHK_OUT_BEATS_PER_PASS;

  reg        comp_check_en;
  integer    comp_cfg_block [0:MAX_CFG-1];
  integer    comp_cfg_iftile[0:MAX_CFG-1];
  integer    comp_cfg_oftile[0:MAX_CFG-1];
  integer    comp_pass_idx;
  integer    comp_pass_beat;
  integer    comp_block_beats;
  integer    comp_donepass_count;
  integer    donepass_total;
  reg [K*M*DATA_WIDTH-1:0] comp_exp_data;
  reg [K*M-1:0]            comp_exp_vld;

  // ==========================================================================
  // DUT
  // ==========================================================================
  filter_buf #(
    .DATA_WIDTH(DATA_WIDTH),
    .K(K),
    .M(M)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .fltbuf_inf_vld_i(fltbuf_inf_vld_i),
    .fltbuf_inf_fltbaddr_i(fltbuf_inf_fltbaddr_i),
    .fltbuf_inf_width_i(fltbuf_inf_width_i),
    .fltbuf_inf_channel_i(fltbuf_inf_channel_i),
    .fltbuf_inf_ifparr_i(fltbuf_inf_ifparr_i),
    .fltbuf_inf_ifparr_tail_i(fltbuf_inf_ifparr_tail_i),
    .fltbuf_inf_fltsize_i(fltbuf_inf_fltsize_i),
    .fltbuf_inf_ifblock_i(fltbuf_inf_ifblock_i),
    .fltbuf_inf_ofparr_i(fltbuf_inf_ofparr_i),
    .fltbuf_inf_ofparr_tail_i(fltbuf_inf_ofparr_tail_i),
    .fltbuf_inf_oftiles_i(fltbuf_inf_oftiles_i),
    .fltbuf_inf_oftiles_tail_i(fltbuf_inf_oftiles_tail_i),
    .fltbuf_inf_iftiles_i(fltbuf_inf_iftiles_i),
    .fltbuf_inf_wp_i(fltbuf_inf_wp_i),
    .fltbuf_inf_padding_i(fltbuf_inf_padding_i),
    .fltbuf_inf_ifc_zp_i(fltbuf_inf_ifc_zp_i),
    .fltbuf_inf_rdy_o(fltbuf_inf_rdy_o),
    .fltbuf_ifbuf_end_layer_i(fltbuf_ifbuf_end_layer_i),
    .fltbuf_dma_rdycfg_i(fltbuf_dma_rdycfg_i),
    .fltbuf_dma_vld_i(fltbuf_dma_vld_i),
    .fltbuf_dma_data_i(fltbuf_dma_data_i),
    .fltbuf_dma_tlast_i(fltbuf_dma_tlast_i),
    .fltbuf_dma_vldcfg_o(fltbuf_dma_vldcfg_o),
    .fltbuf_dma_burst_o(fltbuf_dma_burst_o),
    .fltbuf_dma_baddr_o(fltbuf_dma_baddr_o),
    .fltbuf_dma_rdy_o(fltbuf_dma_rdy_o),
    .fltbuf_comp_rdy_i(fltbuf_comp_rdy_i),
    .fltbuf_comp_vld_o(fltbuf_comp_vld_o),
    .fltbuf_comp_data_o(fltbuf_comp_data_o),
    .fltbuf_comp_donepass_o(fltbuf_comp_donepass_o)
  );

  always #5 clk = ~clk;

  // ==========================================================================
  // Utility helpers
  // ==========================================================================
  function integer ceil_div;
    input integer num;
    input integer den;
    begin
      if (den <= 0)
        ceil_div = 0;
      else
        ceil_div = (num + den - 1) / den;
    end
  endfunction

  // Mỗi word DMA trong 1 pass được mã hóa trực tiếp theo thứ tự:
  //   cot -> hang -> channel -> filter
  // Trong TB này, phan (cot, hang) duoc flatten thanh elem_idx 0..fltsize-1,
  // nen thu tu tuong duong voi: filter-major -> channel-major -> elem-minor.
  // Gia tri ma hoa: filter*10000 + channel*100 + elem_idx
  //
  // Ví dụ: filter=3, channel=12, elem_idx=5
  //   value = 3*10000 + 12*100 + 5 = 31205
  // tương ứng dạng đọc được: [03][12][05].
  function [DATA_WIDTH-1:0] dma_encoded_word_fn;
    input integer filter_idx;
    input integer channel_idx;
    input integer elem_idx;
    integer value;
    begin
      value = filter_idx * 10000 + channel_idx * 100 + elem_idx;
      dma_encoded_word_fn = value[DATA_WIDTH-1:0];
    end
  endfunction

  function [DATA_WIDTH-1:0] dma_stream_word_fn;
    input integer cfg_idx;
    input integer word_idx;
    integer filter_idx;
    integer channel_idx;
    integer elem_idx;
    integer logical_words;
    integer act_ifparr;
    integer act_ofparr;
    integer act_fltsize;
    begin
      if ((cfg_idx < 0) || (cfg_idx >= MAX_CFG)) begin
        dma_stream_word_fn = {DATA_WIDTH{1'b0}};
      end else begin
        act_ifparr   = exp_cfg_ifparr[cfg_idx];
        act_ofparr   = exp_cfg_ofparr[cfg_idx];
        act_fltsize  = exp_cfg_fltsize[cfg_idx];
        logical_words = act_ofparr * act_ifparr * act_fltsize;

        if ((word_idx >= logical_words) || (act_ifparr <= 0) || (act_ofparr <= 0) || (act_fltsize <= 0)) begin
          dma_stream_word_fn = {DATA_WIDTH{1'b0}};
        end else begin
          filter_idx  = word_idx / (act_ifparr * act_fltsize);
          channel_idx = (word_idx / act_fltsize) % act_ifparr;
          elem_idx    = word_idx % act_fltsize;
          dma_stream_word_fn = dma_encoded_word_fn(filter_idx, channel_idx, elem_idx);
        end
      end
    end
  endfunction

  function integer comp_pass_words_fn;
    input integer cfg_idx;
    begin
      if ((cfg_idx < 0) || (cfg_idx >= MAX_CFG))
        comp_pass_words_fn = 0;
      else
        comp_pass_words_fn = exp_burst[cfg_idx];
    end
  endfunction

  function integer cfg_block_fn;
    input integer cfg_idx;
    integer blk;
    begin
      cfg_block_fn = -1;
      for (blk = 0; blk < MAX_GROUP; blk = blk + 1) begin
        if ((blk < num_groups) &&
            (cfg_idx >= group_start[blk]) &&
            (cfg_idx < (group_start[blk] + group_count[blk])))
          cfg_block_fn = blk;
      end
    end
  endfunction

  function integer comp_out_beats_per_cfg_fn;
    input integer cfg_idx;
    integer act_ofparr;
    integer act_fltsize;
    begin
      if ((cfg_idx < 0) || (cfg_idx >= MAX_CFG)) begin
        comp_out_beats_per_cfg_fn = 0;
      end else begin
        act_ofparr  = exp_cfg_ofparr[cfg_idx];
        act_fltsize = exp_cfg_fltsize[cfg_idx];
        comp_out_beats_per_cfg_fn = act_fltsize * ((act_ofparr + 1) / 2);
      end
    end
  endfunction

  function [K*M-1:0] comp_exp_vld_mask_fn;
    input integer cfg_idx;
    input integer beat_idx;
    integer ch;
    integer act_ifparr;
    integer act_ofparr;
    integer act_fltsize;
    integer pair_idx;
    integer pair_offset;
    integer pa0_filter_idx;
    integer pa1_filter_idx;
    reg [K*M-1:0] tmp;
    begin
      tmp = {K*M{1'b0}};
      act_ifparr   = exp_cfg_ifparr[cfg_idx];
      act_ofparr   = exp_cfg_ofparr[cfg_idx];
      act_fltsize  = exp_cfg_fltsize[cfg_idx];
      pair_idx     = beat_idx / act_fltsize;
      pair_offset  = (act_ofparr + 1) / 2;
      pa0_filter_idx = pair_idx;
      pa1_filter_idx = pair_offset + pair_idx;

      if (pa0_filter_idx < act_ofparr) begin
        for (ch = 0; ch < act_ifparr; ch = ch + 1)
          tmp[ch] = 1'b1;
      end

      if (pa1_filter_idx < act_ofparr) begin
        for (ch = 0; ch < act_ifparr; ch = ch + 1)
          tmp[K + ch] = 1'b1;
      end

      comp_exp_vld_mask_fn = tmp;
    end
  endfunction

  function [K*M*DATA_WIDTH-1:0] comp_exp_bus_fn;
    input integer cfg_idx;
    input integer beat_idx;
    integer pair_idx;
    integer pair_offset;
    integer elem_idx;
    integer ch;
    integer act_ifparr;
    integer act_ofparr;
    integer act_fltsize;
    integer pa0_filter_idx;
    integer pa1_filter_idx;
    reg [K*M*DATA_WIDTH-1:0] tmp;
    reg [DATA_WIDTH-1:0] pa0_val;
    reg [DATA_WIDTH-1:0] pa1_val;
    begin
      tmp          = {K*M*DATA_WIDTH{1'b0}};
      act_ifparr   = exp_cfg_ifparr[cfg_idx];
      act_ofparr   = exp_cfg_ofparr[cfg_idx];
      act_fltsize  = exp_cfg_fltsize[cfg_idx];
      pair_idx     = beat_idx / act_fltsize;
      pair_offset  = (act_ofparr + 1) / 2;
      elem_idx     = beat_idx % act_fltsize;
      pa0_filter_idx = pair_idx;
      pa1_filter_idx = pair_offset + pair_idx;

      if (pa0_filter_idx < act_ofparr) begin
        for (ch = 0; ch < act_ifparr; ch = ch + 1) begin
          pa0_val = dma_encoded_word_fn(pa0_filter_idx, ch, elem_idx);
          tmp = tmp | ({ {((K*M*DATA_WIDTH)-DATA_WIDTH){1'b0}}, pa0_val } << (ch*DATA_WIDTH));
        end
      end

      if (pa1_filter_idx < act_ofparr) begin
        for (ch = 0; ch < act_ifparr; ch = ch + 1) begin
          pa1_val = dma_encoded_word_fn(pa1_filter_idx, ch, elem_idx);
          tmp = tmp | ({ {((K*M*DATA_WIDTH)-DATA_WIDTH){1'b0}}, pa1_val } << ((K + ch)*DATA_WIDTH));
        end
      end

      comp_exp_bus_fn = tmp;
    end
  endfunction

  // Quy đổi tham số layer-level theo kiến trúc trong báo cáo:
  //   iftile      = ceil(Ci / Nip)
  //   oftile      = Npass
  //   ofparallel  = Nfp
  //   ifparallel  = Nip
  //   Ifblock     = số lần 1 ifmap phải tải lại = ceil(Co / (Npass*Nfp))
  task derive_cfg_from_layer;
    input integer ci;
    input integer co;
    input integer nip;
    input integer nfp;
    input integer npass;
    output [3:0] ifparr;
    output [3:0] ifparr_tail;
    output [6:0] iftiles;
    output [6:0] ifblock;
    output [4:0] ofparr;
    output [4:0] ofparr_tail;
    output [3:0] oftiles;
    output [3:0] oftiles_tail;
    integer tifmap;
    integer g;
    integer tof;
    integer last_cluster_filters;
    integer last_ci_tile;
    integer last_pass_filters;
    begin
      tifmap = ceil_div(ci, nip);
      g      = nfp * npass;
      tof    = ceil_div(co, g);

      last_ci_tile = ci - (tifmap - 1) * nip;
      if (last_ci_tile <= 0)
        last_ci_tile = nip;

      last_cluster_filters = co - (tof - 1) * g;
      if (last_cluster_filters <= 0)
        last_cluster_filters = g;

      oftiles_tail = ceil_div(last_cluster_filters, nfp);
      last_pass_filters = last_cluster_filters - (oftiles_tail - 1) * nfp;
      if (last_pass_filters <= 0)
        last_pass_filters = nfp;

      ifparr      = nip[3:0];
      ifparr_tail = last_ci_tile[3:0];
      iftiles     = tifmap[6:0];
      ifblock     = tof[6:0];
      ofparr      = nfp[4:0];
      ofparr_tail = last_pass_filters[4:0];
      oftiles     = npass[3:0];
    end
  endtask

  task dump_layer_cfg;
    input integer ci;
    input integer co;
    input integer nip;
    input integer nfp;
    input integer npass;
    input [3:0] ifparr;
    input [3:0] ifparr_tail;
    input [6:0] iftiles;
    input [6:0] ifblock;
    input [4:0] ofparr;
    input [4:0] ofparr_tail;
    input [3:0] oftiles;
    input [3:0] oftiles_tail;
    begin
      $display("  layer cfg: Ci=%0d Co=%0d Nip=%0d Nfp=%0d Npass=%0d", ci, co, nip, nfp, npass);
      $display("  derived  : ifparallel=%0d iftile=%0d iftail=%0d", ifparr, iftiles, ifparr_tail);
      $display("             ofparallel=%0d oftile=%0d oftail_pass=%0d oftail_filter=%0d", ofparr, oftiles, oftiles_tail, ofparr_tail);
      $display("             ifblock=%0d", ifblock);
    end
  endtask

  // ==========================================================================
  // Monitors
  // ==========================================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) cycle_ctr <= 0;
    else        cycle_ctr <= cycle_ctr + 1;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) donepass_total <= 0;
    else if (fltbuf_comp_donepass_o) donepass_total <= donepass_total + 1;
  end

  always @(*) begin
    fltbuf_dma_rdycfg_i = dma_rdycfg_default;
    if (cfg_bp_en && fltbuf_dma_vldcfg_o) begin
      if ((got_cfg_total == cfg_bp_target0) && (cfg_bp_hold0 > 0))
        fltbuf_dma_rdycfg_i = 1'b0;
      else if ((got_cfg_total == cfg_bp_target1) && (cfg_bp_hold1 > 0))
        fltbuf_dma_rdycfg_i = 1'b0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cfg_bp_hold0 <= 0;
      cfg_bp_hold1 <= 0;
    end else if (cfg_bp_en && fltbuf_dma_vldcfg_o && !fltbuf_dma_rdycfg_i) begin
      if ((got_cfg_total == cfg_bp_target0) && (cfg_bp_hold0 > 0))
        cfg_bp_hold0 <= cfg_bp_hold0 - 1;
      else if ((got_cfg_total == cfg_bp_target1) && (cfg_bp_hold1 > 0))
        cfg_bp_hold1 <= cfg_bp_hold1 - 1;
    end
  end

  always @(posedge clk) begin
    if (rst_n && checking_en && fltbuf_dma_vldcfg_o && fltbuf_dma_rdycfg_i) begin
      if (got_cfg_total == 0)
        first_hs_cycle = cycle_ctr;

      if (got_cfg_total >= exp_cfg_total) begin
        err_count = err_count + 1;
        $error("Unexpected extra DMA cfg: addr=%0d burst=%0d", fltbuf_dma_baddr_o, fltbuf_dma_burst_o);
      end else begin
        if (fltbuf_dma_burst_o !== exp_burst[got_cfg_total]) begin
          err_count = err_count + 1;
          $error("BURST mismatch @cfg[%0d]: got=%0d exp=%0d", got_cfg_total, fltbuf_dma_burst_o, exp_burst[got_cfg_total]);
        end

        if (got_cfg_total == 0) begin
          if ((^fltbuf_dma_baddr_o === 1'bx) || (fltbuf_dma_baddr_o !== exp_addr[0])) begin
            check_addr_chain = 1'b0;
            warn_count = warn_count + 1;
            $display("WARN: first baddr = %h, expected = %h. Disable strict address-chain check.",
                     fltbuf_dma_baddr_o, exp_addr[0]);
          end else begin
            check_addr_chain = 1'b1;
          end
        end else if (check_addr_chain) begin
          if (fltbuf_dma_baddr_o !== exp_addr[got_cfg_total]) begin
            err_count = err_count + 1;
            $error("BADDR mismatch @cfg[%0d]: got=%0d exp=%0d", got_cfg_total, fltbuf_dma_baddr_o, exp_addr[got_cfg_total]);
          end
        end

        if (data_stream_en) begin
          if (q_count >= MAX_Q) begin
            err_count = err_count + 1;
            $error("Internal stream queue overflow");
          end else begin
            stream_q[q_tail]        = exp_burst[got_cfg_total];
            q_cfg_idx[q_tail]       = got_cfg_total;
            q_tail                  = (q_tail + 1) % MAX_Q;
            q_count                 = q_count + 1;
            stream_words_expected   = stream_words_expected + exp_burst[got_cfg_total];
          end
        end
      end

      got_cfg_total = got_cfg_total + 1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fltbuf_dma_vld_i      <= 1'b0;
      fltbuf_dma_data_i     <= {DATA_WIDTH{1'b0}};
      fltbuf_dma_tlast_i    <= 1'b0;
      stream_active         <= 1'b0;
      stream_remaining      <= 0;
      stream_words_sent     <= 0;
      stream_words_this_cfg <= 0;
      stream_word_idx       <= 0;
      stream_cfg_idx        <= 0;
      q_head                <= 0;
      q_tail                <= 0;
      q_count               <= 0;
      stream_words_expected <= 0;
    end else begin
      fltbuf_dma_vld_i   <= 1'b0;
      fltbuf_dma_tlast_i <= 1'b0;

      if (data_stream_en) begin
        if (!stream_active && (q_count > 0)) begin
          stream_remaining      <= stream_q[q_head];
          stream_words_this_cfg <= stream_q[q_head];
          stream_word_idx       <= 0;
          stream_cfg_idx        <= q_cfg_idx[q_head];
          q_head                <= (q_head + 1) % MAX_Q;
          q_count               <= q_count - 1;
          stream_active         <= 1'b1;
        end else if (stream_active) begin
          if (fltbuf_dma_rdy_o !== 1'b0) begin
            fltbuf_dma_vld_i   <= 1'b1;
            fltbuf_dma_data_i <= dma_stream_word_fn(stream_cfg_idx, stream_word_idx);
            fltbuf_dma_tlast_i <= (stream_remaining == 1);

            stream_word_idx    <= stream_word_idx + 1;
            stream_remaining   <= stream_remaining - 1;
            stream_words_sent  <= stream_words_sent + 1;

            if (stream_remaining == 1)
              stream_active <= 1'b0;
          end
        end
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fltbuf_comp_rdy_i       <= 1'b0;
      comp_rdy_recv_cfg_idx   <= 0;
      comp_rdy_recv_word_idx  <= 0;
      comp_rdy_block_idx      <= 0;
      comp_rdy_delay_ctr      <= 0;
      comp_rdy_recv_block_idx <= 0;
      comp_rdy_hold_high      <= 1'b0;
      comp_rdy_wait_change    <= 1'b0;
      for (i = 0; i < MAX_GROUP; i = i + 1) begin
        comp_rdy_loaded_passes[i] <= 0;
        comp_rdy_done_passes[i]   <= 0;
      end
    end else begin
      fltbuf_comp_rdy_i <= 1'b0;

      if (comp_rdy_auto_en) begin
        if (fltbuf_dma_vld_i && fltbuf_dma_rdy_o) begin
          if ((comp_rdy_recv_cfg_idx < exp_cfg_total) &&
              (comp_rdy_recv_word_idx == comp_pass_words_fn(comp_rdy_recv_cfg_idx) - 1)) begin
            comp_rdy_recv_block_idx = cfg_block_fn(comp_rdy_recv_cfg_idx);
            if ((comp_rdy_recv_block_idx >= 0) && (comp_rdy_recv_block_idx < MAX_GROUP))
              comp_rdy_loaded_passes[comp_rdy_recv_block_idx] <= comp_rdy_loaded_passes[comp_rdy_recv_block_idx] + 1;
            comp_rdy_recv_cfg_idx  <= comp_rdy_recv_cfg_idx + 1;
            comp_rdy_recv_word_idx <= 0;
          end else begin
            comp_rdy_recv_word_idx <= comp_rdy_recv_word_idx + 1;
          end
        end

        if (comp_rdy_hold_high) begin
          fltbuf_comp_rdy_i <= 1'b1;
          if (fltbuf_comp_donepass_o) begin
            comp_rdy_hold_high <= 1'b0;
            comp_rdy_done_passes[comp_rdy_block_idx] <= comp_rdy_done_passes[comp_rdy_block_idx] + 1;
            if ((comp_rdy_done_passes[comp_rdy_block_idx] + 1) >= group_count[comp_rdy_block_idx]) begin
              comp_rdy_wait_change <= 1'b1;
              comp_rdy_delay_ctr   <= 0;
            end else begin
              comp_rdy_wait_change <= 1'b0;
              comp_rdy_delay_ctr   <= 3;
            end
          end
        end else if (comp_rdy_wait_change) begin
          if (fltbuf_ifbuf_end_layer_i) begin
            comp_rdy_wait_change <= 1'b0;
            comp_rdy_delay_ctr   <= 0;
            if (comp_rdy_block_idx < (num_groups - 1))
              comp_rdy_block_idx <= comp_rdy_block_idx + 1;
          end
        end else if (comp_rdy_delay_ctr > 0) begin
          comp_rdy_delay_ctr <= comp_rdy_delay_ctr - 1;
        end else if ((comp_rdy_block_idx < num_groups) &&
                     (comp_rdy_loaded_passes[comp_rdy_block_idx] > comp_rdy_done_passes[comp_rdy_block_idx])) begin
          comp_rdy_hold_high <= 1'b1;
          fltbuf_comp_rdy_i  <= 1'b1;
        end
      end
    end
  end

  always @(posedge clk) begin
    if (rst_n && !comp_check_en && (|fltbuf_comp_vld_o)) begin
      for (lane = 0; lane < K*M; lane = lane + 1) begin
        if (fltbuf_comp_vld_o[lane]) begin
          if (^fltbuf_comp_data_o[(lane+1)*DATA_WIDTH-1 -: DATA_WIDTH] === 1'bx) begin
            warn_count = warn_count + 1;
            $display("WARN: comp_data has X on valid lane %0d at time %0t", lane, $time);
          end
        end
      end
    end
  end

  always @(negedge clk) begin
    if (rst_n && comp_check_en) begin
      if (fltbuf_comp_donepass_o)
        comp_donepass_count = comp_donepass_count + 1;

      if ((|fltbuf_comp_vld_o) && (comp_pass_idx < COMPCHK_TOTAL_CFGS)) begin
        comp_exp_data = comp_exp_bus_fn(comp_pass_idx, comp_pass_beat);
        comp_exp_vld  = comp_exp_vld_mask_fn(comp_pass_idx, comp_pass_beat);

        if (fltbuf_comp_vld_o !== comp_exp_vld) begin
          err_count = err_count + 1;
          $error("COMP VLD mismatch @pass=%0d beat=%0d cfg(block=%0d iftile=%0d oftile=%0d): got=%h exp=%h",
                 comp_pass_idx, comp_pass_beat,
                 comp_cfg_block[comp_pass_idx], comp_cfg_iftile[comp_pass_idx], comp_cfg_oftile[comp_pass_idx],
                 fltbuf_comp_vld_o, comp_exp_vld);
        end

        if (fltbuf_comp_data_o !== comp_exp_data) begin
          err_count = err_count + 1;
          $error("COMP DATA mismatch @pass=%0d beat=%0d cfg(block=%0d iftile=%0d oftile=%0d): got=%h exp=%h",
                 comp_pass_idx, comp_pass_beat,
                 comp_cfg_block[comp_pass_idx], comp_cfg_iftile[comp_pass_idx], comp_cfg_oftile[comp_pass_idx],
                 fltbuf_comp_data_o, comp_exp_data);
        end else begin
          $display("COMP OUT pass=%0d beat=%0d block=%0d iftile=%0d oftile=%0d data=%h donepass=%0b",
                   comp_pass_idx, comp_pass_beat,
                   comp_cfg_block[comp_pass_idx], comp_cfg_iftile[comp_pass_idx], comp_cfg_oftile[comp_pass_idx],
                   fltbuf_comp_data_o, fltbuf_comp_donepass_o);
        end

        comp_block_beats = comp_block_beats + 1;
        if (comp_pass_beat == comp_out_beats_per_cfg_fn(comp_pass_idx) - 1) begin
          comp_pass_beat = 0;
          comp_pass_idx  = comp_pass_idx + 1;
        end else begin
          comp_pass_beat = comp_pass_beat + 1;
        end
      end
    end
  end

  // ==========================================================================
  // Common tasks
  // ==========================================================================
  task clear_inputs;
    begin
      fltbuf_inf_vld_i          = 1'b0;
      fltbuf_inf_fltbaddr_i     = 32'd0;
      fltbuf_inf_width_i        = 9'd0;
      fltbuf_inf_channel_i      = 11'd0;
      fltbuf_inf_ifparr_i       = 4'd0;
      fltbuf_inf_ifparr_tail_i  = 4'd0;
      fltbuf_inf_fltsize_i      = 7'd0;
      fltbuf_inf_ifblock_i      = 7'd0;
      fltbuf_inf_ofparr_i       = 5'd0;
      fltbuf_inf_ofparr_tail_i  = 5'd0;
      fltbuf_inf_oftiles_i      = 4'd0;
      fltbuf_inf_oftiles_tail_i = 4'd0;
      fltbuf_inf_iftiles_i      = 7'd0;
      fltbuf_inf_wp_i           = 9'd0;
      fltbuf_inf_padding_i      = 2'd0;
      fltbuf_inf_ifc_zp_i       = 8'd0;
      fltbuf_ifbuf_end_layer_i       = 1'b0;
      dma_rdycfg_default        = 1'b1;
      fltbuf_dma_vld_i          = 1'b0;
      fltbuf_dma_data_i         = {DATA_WIDTH{1'b0}};
      fltbuf_dma_tlast_i        = 1'b0;
      fltbuf_comp_rdy_i         = 1'b0;
      comp_rdy_auto_en          = 1'b1;
      cfg_bp_en                 = 1'b0;
      cfg_bp_target0            = -1;
      cfg_bp_target1            = -1;
      cfg_bp_hold0              = 0;
      cfg_bp_hold1              = 0;
      data_stream_en            = 1'b1;
      comp_check_en             = 1'b0;
    end
  endtask

  task do_reset;
    begin
      rst_n            = 1'b0;
      checking_en      = 1'b0;
      check_addr_chain = 1'b0;
      accept_cycle     = 0;
      first_hs_cycle   = 0;
      exp_cfg_total    = 0;
      got_cfg_total    = 0;
      num_groups       = 0;
      clear_inputs();
      for (i = 0; i < MAX_GROUP; i = i + 1) begin
        group_start[i] = 0;
        group_count[i] = 0;
        group_words[i] = 0;
        comp_rdy_loaded_passes[i] = 0;
        comp_rdy_done_passes[i]   = 0;
      end
      comp_rdy_recv_cfg_idx   = 0;
      comp_rdy_recv_word_idx  = 0;
      comp_rdy_block_idx      = 0;
      comp_rdy_delay_ctr      = 0;
      comp_rdy_recv_block_idx = 0;
      comp_rdy_hold_high      = 1'b0;
      comp_rdy_wait_change    = 1'b0;
      stream_cfg_idx   = 0;
      comp_pass_idx       = 0;
      comp_pass_beat      = 0;
      comp_block_beats    = 0;
      comp_donepass_count = 0;
      donepass_total      = 0;
      for (i = 0; i < MAX_Q; i = i + 1) begin
        q_cfg_idx[i]  = 0;
      end
      for (i = 0; i < MAX_CFG; i = i + 1) begin
        exp_addr[i]        = 32'd0;
        exp_burst[i]       = 10'd0;
        exp_cfg_ifparr[i]  = 0;
        exp_cfg_ofparr[i]  = 0;
        exp_cfg_fltsize[i] = 0;
        comp_cfg_block[i]  = 0;
        comp_cfg_iftile[i] = 0;
        comp_cfg_oftile[i] = 0;
      end
      repeat (5) @(posedge clk);
      rst_n = 1'b1;
      repeat (2) @(posedge clk);
    end
  endtask

  task build_expected;
    input [31:0] base_addr;
    input [3:0]  ifparr;
    input [3:0]  ifparr_tail;
    input [6:0]  fltsize;
    input [6:0]  ifblock;
    input [4:0]  ofparr;
    input [4:0]  ofparr_tail;
    input [3:0]  oftiles;
    input [3:0]  oftiles_tail;
    input [6:0]  iftiles;
    integer idx;
    integer ib;
    integer it;
    integer ot;
    integer ot_lim;
    integer addr_cur;
    integer act_ch;
    integer act_f;
    integer burst_tmp;
    begin
      idx       = 0;
      addr_cur  = base_addr;
      num_groups = ifblock;

      for (ib = 0; ib < ifblock; ib = ib + 1) begin
        group_start[ib] = idx;
        ot_lim          = (ib == ifblock - 1) ? oftiles_tail : oftiles;
        group_count[ib] = iftiles * ot_lim;
        group_words[ib] = 0;

        for (it = 0; it < iftiles; it = it + 1) begin
          if (it == iftiles - 1)
            act_ch = ifparr_tail;
          else
            act_ch = ifparr;

          for (ot = 0; ot < ot_lim; ot = ot + 1) begin
            if ((ib == ifblock - 1) && (ot == ot_lim - 1))
              act_f = ofparr_tail;
            else
              act_f = ofparr;

            burst_tmp = act_ch * act_f * fltsize;
            if ((burst_tmp % 2) != 0)
              burst_tmp = burst_tmp + 1;

            exp_addr[idx]     = addr_cur;
            exp_burst[idx]    = burst_tmp[9:0];
            exp_cfg_ifparr[idx] = act_ch;
            exp_cfg_ofparr[idx]  = act_f;
            exp_cfg_fltsize[idx] = fltsize;
            addr_cur          = addr_cur + burst_tmp;
            group_words[ib]   = group_words[ib] + burst_tmp;
            idx               = idx + 1;
          end
        end
      end

      exp_cfg_total = idx;
    end
  endtask


  task build_comp_expected;
    integer idx;
    integer ib;
    integer it;
    integer ot;
    integer burst_tmp;
    integer addr_cur;
    begin
      idx        = 0;
      addr_cur   = COMPCHK_BASE_ADDR;
      num_groups = COMPCHK_IFBLOCK;

      burst_tmp = COMPCHK_OFPARR * COMPCHK_IFPARR * COMPCHK_FLTSIZE;
      if ((burst_tmp % 2) != 0)
        burst_tmp = burst_tmp + 1;

      for (ib = 0; ib < COMPCHK_IFBLOCK; ib = ib + 1) begin
        group_start[ib] = idx;
        group_count[ib] = COMPCHK_CFGS_PER_BLOCK;
        group_words[ib] = COMPCHK_CFGS_PER_BLOCK * burst_tmp;

        for (it = 0; it < COMPCHK_IFTILES; it = it + 1) begin
          for (ot = 0; ot < COMPCHK_OFTILES; ot = ot + 1) begin
            exp_addr[idx]         = addr_cur;
            exp_burst[idx]        = burst_tmp[9:0];
            exp_cfg_ifparr[idx]   = COMPCHK_IFPARR;
            exp_cfg_ofparr[idx]    = COMPCHK_OFPARR;
            exp_cfg_fltsize[idx]   = COMPCHK_FLTSIZE;
            comp_cfg_block[idx]    = ib;
            comp_cfg_iftile[idx]  = it;
            comp_cfg_oftile[idx]  = ot;
            addr_cur              = addr_cur + burst_tmp;
            idx                   = idx + 1;
          end
        end
      end

      exp_cfg_total = idx;
    end
  endtask

  task dump_expected;
    integer g;
    integer j;
    begin
      $display("  total_cfg=%0d num_groups=%0d", exp_cfg_total, num_groups);
      for (g = 0; g < num_groups; g = g + 1)
        $display("  group[%0d]: start=%0d count=%0d words=%0d", g, group_start[g], group_count[g], group_words[g]);
      $display("  data rule : dma_data_i = filter*10000 + channel*100 + elem_idx");
      $display("             burst order = cot -> hang -> channel -> filter");
      for (j = 0; j < exp_cfg_total; j = j + 1)
        $display("  exp[%0d]: addr=%0d burst=%0d ifparr=%0d ofparr=%0d fltsize=%0d",
                 j, exp_addr[j], exp_burst[j], exp_cfg_ifparr[j], exp_cfg_ofparr[j], exp_cfg_fltsize[j]);
    end
  endtask

  task send_inftruction;
    input [31:0] base_addr;
    input [3:0]  ifparr;
    input [3:0]  ifparr_tail;
    input [6:0]  fltsize;
    input [6:0]  ifblock;
    input [4:0]  ofparr;
    input [4:0]  ofparr_tail;
    input [3:0]  oftiles;
    input [3:0]  oftiles_tail;
    input [6:0]  iftiles;
    begin
      @(posedge clk);
      while (!fltbuf_inf_rdy_o) @(posedge clk);

      fltbuf_inf_vld_i          <= 1'b1;
      fltbuf_inf_fltbaddr_i     <= base_addr;
      fltbuf_inf_width_i        <= 9'd0;
      fltbuf_inf_channel_i      <= 11'd0;
      fltbuf_inf_ifparr_i       <= ifparr;
      fltbuf_inf_ifparr_tail_i  <= ifparr_tail;
      fltbuf_inf_fltsize_i      <= fltsize;
      fltbuf_inf_ifblock_i      <= ifblock;
      fltbuf_inf_ofparr_i       <= ofparr;
      fltbuf_inf_ofparr_tail_i  <= ofparr_tail;
      fltbuf_inf_oftiles_i      <= oftiles;
      fltbuf_inf_oftiles_tail_i <= oftiles_tail;
      fltbuf_inf_iftiles_i      <= iftiles;
      fltbuf_inf_wp_i           <= 9'd0;
      fltbuf_inf_padding_i      <= 2'd0;
      fltbuf_inf_ifc_zp_i       <= 8'd0;

      @(posedge clk);
      if (!(fltbuf_inf_rdy_o && fltbuf_inf_vld_i)) begin
        err_count = err_count + 1;
        $error("inftruction was not accepted when expected");
      end
      accept_cycle     = cycle_ctr;
      fltbuf_inf_vld_i <= 1'b0;
    end
  endtask

  task wait_until_cfg_total;
    input integer target_count;
    input integer timeout_limit;
    integer timeout;
    begin
      timeout = 0;
      while ((got_cfg_total < target_count) && (timeout < timeout_limit)) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
      if (got_cfg_total != target_count) begin
        err_count = err_count + 1;
        $error("Timeout or cfg_count mismatch: got=%0d exp_target=%0d", got_cfg_total, target_count);
      end
    end
  endtask

  task wait_until_donepass_total;
    input integer target_count;
    input integer timeout_limit;
    integer timeout;
    begin
      timeout = 0;
      while ((donepass_total < target_count) && (timeout < timeout_limit)) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
      if (donepass_total != target_count) begin
        err_count = err_count + 1;
        $error("Timeout or donepass_count mismatch: got=%0d exp_target=%0d", donepass_total, target_count);
      end
    end
  endtask

  task wait_stream_progress;
    input integer expected_words_min;
    input integer timeout_limit;
    integer timeout;
    begin
      timeout = 0;
      while ((stream_words_sent < expected_words_min) && (timeout < timeout_limit)) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
      if (stream_words_sent < expected_words_min) begin
        warn_count = warn_count + 1;
        $display("WARN: stream_words_sent=%0d did not reach expected minimum %0d", stream_words_sent, expected_words_min);
      end
    end
  endtask

  task wait_stream_idle;
    input integer timeout_limit;
    integer timeout;
    begin
      timeout = 0;
      while (((q_count != 0) || stream_active) && (timeout < timeout_limit)) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
      if ((q_count != 0) || stream_active) begin
        warn_count = warn_count + 1;
        $display("WARN: DMA data stream did not go idle before timeout");
      end
    end
  endtask

  task verify_waiting_for_ifbuf_change;
    input integer idle_cycles;
    input integer expected_cfg_total;
    integer k;
    begin
      for (k = 0; k < idle_cycles; k = k + 1) begin
        @(posedge clk);
        if (got_cfg_total != expected_cfg_total) begin
          err_count = err_count + 1;
          $error("Module kept issuing cfg without fltbuf_ifbuf_end_layer_i: got=%0d expected=%0d", got_cfg_total, expected_cfg_total);
        end
        if (fltbuf_dma_vldcfg_o !== 1'b0) begin
          err_count = err_count + 1;
          $error("fltbuf_dma_vldcfg_o should stay low while waiting for fltbuf_ifbuf_end_layer_i");
        end
      end
    end
  endtask

  task pulse_ifbuf_change;
    begin
      @(negedge clk);
      fltbuf_ifbuf_end_layer_i = 1'b1;
      @(negedge clk);
      fltbuf_ifbuf_end_layer_i = 1'b0;
    end
  endtask

  task finish_and_check_ready;
    integer timeout;
    begin
      if (data_stream_en) begin
        wait_stream_idle(4000);
        if (stream_words_sent != stream_words_expected) begin
          warn_count = warn_count + 1;
          $display("WARN: stream_words_sent=%0d stream_words_expected=%0d", stream_words_sent, stream_words_expected);
        end
      end

      if (fltbuf_inf_rdy_o !== 1'b1)
        pulse_ifbuf_change();

      timeout = 0;
      while (!fltbuf_inf_rdy_o && (timeout < 80)) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
      if (!fltbuf_inf_rdy_o) begin
        err_count = err_count + 1;
        $error("fltbuf_inf_rdy_o did not return to 1 after finishing full layer + fltbuf_ifbuf_end_layer_i");
      end
    end
  endtask

  task run_grouped_case;
    input [31:0] base_addr;
    input [3:0]  ifparr;
    input [3:0]  ifparr_tail;
    input [6:0]  fltsize;
    input [6:0]  ifblock;
    input [4:0]  ofparr;
    input [4:0]  ofparr_tail;
    input [3:0]  oftiles;
    input [3:0]  oftiles_tail;
    input [6:0]  iftiles;
    input        do_latency_check;
    integer grp;
    integer target_total;
    integer target_words;
    begin
      build_expected(base_addr, ifparr, ifparr_tail, fltsize, ifblock, ofparr, ofparr_tail, oftiles, oftiles_tail, iftiles);
      dump_expected();

      got_cfg_total         = 0;
      donepass_total        = 0;
      stream_words_sent     = 0;
      stream_words_expected = 0;
      q_head                = 0;
      q_tail                = 0;
      q_count               = 0;
      stream_active         = 1'b0;
      stream_remaining      = 0;
      stream_words_this_cfg = 0;
      stream_word_idx       = 0;
      first_hs_cycle        = 0;
      check_addr_chain      = 1'b0;
      checking_en           = 1'b1;

      send_inftruction(base_addr, ifparr, ifparr_tail, fltsize, ifblock, ofparr, ofparr_tail, oftiles, oftiles_tail, iftiles);

      target_words = 0;
      for (grp = 0; grp < num_groups; grp = grp + 1) begin
        target_total = group_start[grp] + group_count[grp];
        target_words = target_words + group_words[grp];

        wait_until_cfg_total(target_total, 4000);
        if (data_stream_en)
          wait_stream_progress(target_words, 20000);

        wait_until_donepass_total(target_total, 20000);

        $display("  PASS group %0d: cfg=%0d words=%0d total_cfg=%0d total_words=%0d donepass_total=%0d",
                 grp, group_count[grp], group_words[grp], got_cfg_total, stream_words_sent, donepass_total);

        if (grp != num_groups - 1) begin
          wait_stream_idle(4000);
          verify_waiting_for_ifbuf_change(0, target_total);
          pulse_ifbuf_change();
        end
      end

      checking_en = 1'b0;
      finish_and_check_ready();

      if (do_latency_check) begin
        if ((first_hs_cycle - accept_cycle) != 7) begin
          err_count = err_count + 1;
          $error("First DMA cfg latency mismatch: got=%0d cycles exp=7 cycles",
                 first_hs_cycle - accept_cycle);
        end else begin
          $display("  PASS latency check: first cfg after %0d cycles", first_hs_cycle - accept_cycle);
        end
      end
    end
  endtask

  task run_layer_case;
    input [31:0] base_addr;
    input integer ci;
    input integer co;
    input integer nip;
    input integer nfp;
    input integer npass;
    input [6:0]  fltsize;
    input        do_latency_check;
    reg   [3:0]  ifparr;
    reg   [3:0]  ifparr_tail;
    reg   [6:0]  iftiles;
    reg   [6:0]  ifblock;
    reg   [4:0]  ofparr;
    reg   [4:0]  ofparr_tail;
    reg   [3:0]  oftiles;
    reg   [3:0]  oftiles_tail;
    begin
      derive_cfg_from_layer(ci, co, nip, nfp, npass,
                            ifparr, ifparr_tail, iftiles, ifblock,
                            ofparr, ofparr_tail, oftiles, oftiles_tail);
      dump_layer_cfg(ci, co, nip, nfp, npass,
                     ifparr, ifparr_tail, iftiles, ifblock,
                     ofparr, ofparr_tail, oftiles, oftiles_tail);
      run_grouped_case(base_addr,
                       ifparr, ifparr_tail,
                       fltsize,
                       ifblock,
                       ofparr, ofparr_tail,
                       oftiles, oftiles_tail,
                       iftiles,
                       do_latency_check);
    end
  endtask


  task wait_comp_block_output_done;
    input integer target_block;
    integer timeout;
    begin
      timeout = 0;
      while ((comp_block_beats < COMPCHK_OUT_BEATS_PER_BLK) && (timeout < 5000)) begin
        @(posedge clk);
        timeout = timeout + 1;
      end
      if (comp_block_beats != COMPCHK_OUT_BEATS_PER_BLK) begin
        err_count = err_count + 1;
        $error("Timeout waiting comp output for ifblock %0d. got_beats=%0d exp=%0d",
               target_block, comp_block_beats, COMPCHK_OUT_BEATS_PER_BLK);
      end
    end
  endtask

  task test_comp_output_architecture;
    begin
      $display("\n[TEST 3] Check comp_vld_o/comp_data_o voi dma_data_i = filter*10000 + channel*100 + elem_idx");
      $display("         Thu tu mong doi: (f0,f3) elem0..8 -> (f1,f4) elem0..8 -> (f2,f5) elem0..8");
      $display("         fltbuf_ifbuf_end_layer_i chi duoc pulse giua cac block, con inf_rdy chi len sau full layer + change");
      comp_check_en     = 1'b1;
      cfg_bp_en         = 1'b0;
      dma_rdycfg_default = 1'b1;
      data_stream_en    = 1'b1;

      build_comp_expected();
      dump_expected();

      got_cfg_total         = 0;
      donepass_total        = 0;
      stream_words_sent     = 0;
      stream_words_expected = 0;
      q_head                = 0;
      q_tail                = 0;
      q_count               = 0;
      stream_active         = 1'b0;
      stream_remaining      = 0;
      stream_words_this_cfg = 0;
      stream_word_idx       = 0;
      stream_cfg_idx        = 0;
      first_hs_cycle        = 0;
      check_addr_chain      = 1'b0;
      checking_en           = 1'b1;
      comp_pass_idx         = 0;
      comp_pass_beat        = 0;
      comp_block_beats      = 0;
      comp_donepass_count   = 0;

      send_inftruction(
        COMPCHK_BASE_ADDR,
        COMPCHK_IFPARR,
        COMPCHK_IFPARR_T,
        COMPCHK_FLTSIZE,
        COMPCHK_IFBLOCK,
        COMPCHK_OFPARR,
        COMPCHK_OFPARR_T,
        COMPCHK_OFTILES,
        COMPCHK_OFTILES_T,
        COMPCHK_IFTILES
      );

      wait_until_cfg_total(COMPCHK_CFGS_PER_BLOCK, 4000);
      wait_comp_block_output_done(0);
      wait_until_donepass_total(COMPCHK_CFGS_PER_BLOCK, 20000);
      wait_stream_idle(4000);
      verify_waiting_for_ifbuf_change(0, COMPCHK_CFGS_PER_BLOCK);
      pulse_ifbuf_change();

      comp_block_beats = 0;

      wait_until_cfg_total(COMPCHK_TOTAL_CFGS, 4000);
      wait_comp_block_output_done(1);
      wait_until_donepass_total(COMPCHK_TOTAL_CFGS, 20000);

      checking_en = 1'b0;
      finish_and_check_ready();

      if (comp_pass_idx != COMPCHK_TOTAL_CFGS) begin
        err_count = err_count + 1;
        $error("Not all expected comp passes were observed. got=%0d exp=%0d", comp_pass_idx, COMPCHK_TOTAL_CFGS);
      end

      if (comp_donepass_count != COMPCHK_TOTAL_CFGS) begin
        warn_count = warn_count + 1;
        $display("WARN: donepass pulse count = %0d, expected %0d", comp_donepass_count, COMPCHK_TOTAL_CFGS);
      end

      comp_check_en = 1'b0;
    end
  endtask

  // ==========================================================================
  // Tests
  // ==========================================================================
  task test_basic_streamed_grouped;
    begin
      $display("\n[TEST 1] Layer-derived cfg + DMA data stream");
      cfg_bp_en          = 1'b0;
      dma_rdycfg_default = 1'b1;
      data_stream_en     = 1'b1;

      // Quy luat data cho moi cfg/pass:
      //   do dai 1 pass = so filter thuc te * so channel thuc te * fltsize
      //   data[n] = filter*10000 + channel*100 + elem_idx
      //   thu tu burst = cot -> hang -> channel -> filter
      // Tương đương case cũ:
      //   Ci=11  -> iftile=ceil(11/4)=3, iftail=3
      //   Co=17  -> ifblock=ceil(17/(2*6))=2,
      //             last block có 1 pass và pass cuối có 5 filter
      run_layer_case(
        32'd1024,
        11,
        17,
        4,
        6,
        2,
        7'd9,
        1'b1
      );
    end
  endtask

  task test_backpressure_streamed_grouped;
    begin
      $display("\n[TEST 2] Layer-derived cfg + cfg backpressure + DMA data stream");
      dma_rdycfg_default = 1'b1;
      cfg_bp_en          = 1'b1;
      cfg_bp_target0     = 1;
      cfg_bp_hold0       = 3;
      cfg_bp_target1     = 7;
      cfg_bp_hold1       = 2;
      data_stream_en     = 1'b1;
      // Quy luat data cho moi cfg/pass:
      //   do dai 1 pass = so filter thuc te * so channel thuc te * fltsize
      //   data[n] = filter*10000 + channel*100 + elem_idx
      //   thu tu burst = cot -> hang -> channel -> filter
      // Tương đương case cũ:
      //   Ci=3   -> iftile=ceil(3/2)=2, iftail=1
      //   Co=31  -> ifblock=ceil(31/(3*7))=2,
      //             last block có 2 pass và pass cuối có 3 filter
      run_layer_case(
        32'd4096,
        3,
        31,
        2,
        7,
        3,
        7'd3,
        1'b0
      );

      cfg_bp_en = 1'b0;
    end
  endtask

  initial begin
    clk        = 1'b0;
    err_count  = 0;
    warn_count = 0;

    do_reset();
    test_basic_streamed_grouped();

    repeat (5) @(posedge clk);
    do_reset();
    test_backpressure_streamed_grouped();

    repeat (5) @(posedge clk);
    do_reset();
    test_comp_output_architecture();

    repeat (20) @(posedge clk);
    if (err_count == 0)
      $display("\nALL TESTS PASSED (warnings=%0d)", warn_count);
    else
      $display("\nTESTBENCH FINISHED WITH %0d ERROR(S), warnings=%0d", err_count, warn_count);

    $finish;
  end

endmodule
