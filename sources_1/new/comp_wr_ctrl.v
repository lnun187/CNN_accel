`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/28/2026 03:38:20 PM
// Design Name: 
// Module Name: comp_wr_ctrl
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


module comp_wr_ctrl#(
    parameter WIDTH = 8,
    parameter PE_PER_PU = 12
)(
    input clk,
    input rst_n,
    input [3:0] cwc_ins_hf_i,
    input [2:0] cwc_ins_stride_i,
    input [1:0] cwc_ins_padding_i,
    input cwc_pe_end_layer_nxt_i,
    
    input [PE_PER_PU*WIDTH-1:0] cwc_pp_data_i,
    input [PE_PER_PU-1:0] cwc_pp_vld_i,
    input [PE_PER_PU-1:0] cwc_pp_end_data_i,
    output [PE_PER_PU-1:0] cwc_pp_rdy_o,
    output [PE_PER_PU-1:0] cwc_pp_clear_o,
    output [PE_PER_PU-1:0] cwc_pp_pe_is_read_o,

    input cwc_pu_swap_en_i,
    
    input cwc_ofbuf_rdy_i,
    output cwc_ofbuf_vld_o,
    output [WIDTH-1:0] cwc_ofbuf_data_o,
    output cwc_pu_done_compute_o
    );
    
    reg [3:0] count_p;
    wire [3:0] count_p_nxt;
    reg [2:0] cwc_ins_stride_i_count;
    wire [2:0] cwc_ins_stride_i_count_nxt;
    reg [$clog2(PE_PER_PU)-1:0] id;
    reg end_layer;
    wire [$clog2(PE_PER_PU)-1:0] id_nxt;
    reg [PE_PER_PU-1:0] pp_clear_reg;
    wire [PE_PER_PU-1:0] pp_clear_nxt;
    // reg [3:0] id_mod_cwc_ins_hf_i;
    // wire [3:0] id_mod_cwc_ins_hf_i_nxt;

    wire is_id_nxt_vld;
    wire is_add_cwc_ins_padding_i_data;
    wire vld_id;
    wire vld_id_nxt;
    wire end_data_id;
    posedge_detection a(
    .clk(clk),
    .rst_n(rst_n),
    .signal_i(end_layer && !(|cwc_pp_vld_i)),
    .signal_o(cwc_pu_done_compute_o)
    );
    assign cwc_pp_rdy_o = {PE_PER_PU{cwc_ofbuf_rdy_i && cwc_ofbuf_vld_o}} & (1'b1 << id);
    // assign end_data_id = (id < PE_PER_PU) ? cwc_pp_end_data_i[id] : 1'b0;
    assign end_data_id = |cwc_pp_end_data_i;
    assign vld_id = (id < PE_PER_PU) ? cwc_pp_vld_i[id] && !pp_clear_reg[id]: 1'b0;
    assign cwc_ofbuf_vld_o = vld_id;
    assign cwc_pp_pe_is_read_o = {PE_PER_PU{~end_layer}};
    wire [4:0] next_id_sum = {1'b0, id} + {1'b0, cwc_ins_hf_i};
    assign vld_id_nxt = (next_id_sum < PE_PER_PU) ? cwc_pp_vld_i[next_id_sum] && !pp_clear_reg[next_id_sum]: 1'b0;
    assign cwc_ofbuf_data_o = (id < PE_PER_PU) ? cwc_pp_data_i[id*WIDTH +: WIDTH] : {WIDTH{1'b0}};
    assign is_id_nxt_vld = vld_id_nxt;
    // assign is_add_cwc_ins_padding_i_data = (cwc_pu_end_height_i & cwc_ins_dw_i) || end_layer;
    assign is_add_cwc_ins_padding_i_data = end_layer && !cwc_pu_swap_en_i;
    // assign id_mod_cwc_ins_hf_i_nxt = id % cwc_ins_hf_i;
    // assign id_mod_cwc_ins_hf_i_nxt = is_id_nxt_vld ? id_mod_cwc_ins_hf_i : (is_add_cwc_ins_padding_i_data ? (id_mod_cwc_ins_hf_i - (cwc_ins_stride_i - cwc_ins_stride_i_count)) : (cwc_ins_hf_i - 1));
    assign id_nxt = is_id_nxt_vld ? (id + cwc_ins_hf_i) : (is_add_cwc_ins_padding_i_data ? (id % cwc_ins_hf_i - (cwc_ins_stride_i - cwc_ins_stride_i_count)) : (cwc_ins_hf_i - 1));
    // assign count_p_nxt = cwc_ins_dw_i & cwc_pu_end_height_i ? 1 : count_p + 1;
    assign count_p_nxt = count_p + 1;
    assign cwc_ins_stride_i_count_nxt = (cwc_ins_stride_i_count == cwc_ins_stride_i - 1) ? 0 : cwc_ins_stride_i_count + 1;
    reg id_en;
    always @(posedge clk) begin
        if(!rst_n) begin
          id_en <= 0;
        //   id_mod_cwc_ins_hf_i <= cwc_ins_hf_i - 1;
        end else begin
           id_en <= vld_id || cwc_pu_swap_en_i;
        end 
    end
    always @(posedge clk) begin
        if(!rst_n) begin
          id <= cwc_ins_hf_i - 1;
          end_layer <= 0;
        //   id_mod_cwc_ins_hf_i <= cwc_ins_hf_i - 1;
        end else begin
            if(cwc_pu_swap_en_i) begin
                id <= cwc_ins_hf_i - 1;
                end_layer <= cwc_pe_end_layer_nxt_i;
            //   id_mod_cwc_ins_hf_i <= cwc_ins_hf_i - 1;
            end 
            else if(!vld_id || end_data_id && vld_id && cwc_ofbuf_rdy_i) begin
                id <= id_nxt;
            //   id_mod_cwc_ins_hf_i <= id_mod_cwc_ins_hf_i_nxt;
            end
        end 
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            count_p <= 0;
        end else begin
            if(is_add_cwc_ins_padding_i_data) begin
                count_p <= 0;
            end else if((cwc_pu_swap_en_i && ((count_p + cwc_ins_padding_i) != cwc_ins_hf_i))) begin
                count_p <= count_p_nxt;
            end
        end
       
    end
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
          cwc_ins_stride_i_count <= 0;
        end
        else begin
            if(is_add_cwc_ins_padding_i_data) begin
                cwc_ins_stride_i_count <= 0;
            end else if(cwc_pu_swap_en_i && (count_p + cwc_ins_padding_i) == cwc_ins_hf_i) begin
                cwc_ins_stride_i_count <= cwc_ins_stride_i_count_nxt;
            end
        end 
    end

    genvar i;
    generate
        for(i = 0; i < PE_PER_PU; i = i + 1) begin : pp_clear_gen
        wire [3:0] i_mod_cwc_ins_hf_i;
        assign i_mod_cwc_ins_hf_i = i % cwc_ins_hf_i;
            // wire [3:0] i_mod_cwc_ins_hf_i = (i < cwc_ins_hf_i)     ? i[3:0] :
            //                       (i < 2 * cwc_ins_hf_i) ? (i - cwc_ins_hf_i) :
            //                       (i < 3 * cwc_ins_hf_i) ? (i - 2 * cwc_ins_hf_i) :
            //                       (i < 4 * cwc_ins_hf_i) ? (i - 3 * cwc_ins_hf_i) :
            //                       (i < 5 * cwc_ins_hf_i) ? (i - 4 * cwc_ins_hf_i) :
            //                       (i < 6 * cwc_ins_hf_i) ? (i - 5 * cwc_ins_hf_i) :
            //                       (i < 7 * cwc_ins_hf_i) ? (i - 6 * cwc_ins_hf_i) :
            //                       (i < 8 * cwc_ins_hf_i) ? (i - 7 * cwc_ins_hf_i) :
            //                       (i < 9 * cwc_ins_hf_i) ? (i - 8 * cwc_ins_hf_i) :
            //                       (i < 10 * cwc_ins_hf_i)? (i - 9 * cwc_ins_hf_i) :
            //                       (i < 11 * cwc_ins_hf_i)? (i - 10 * cwc_ins_hf_i) :
            //                       (i < 12 * cwc_ins_hf_i)? (i - 11 * cwc_ins_hf_i) : 4'd0;
            wire cwc_ins_stride_i_term_cond;
            assign cwc_ins_stride_i_term_cond = ((cwc_ins_stride_i_count_nxt == 0) && ((count_p + cwc_ins_padding_i) == cwc_ins_hf_i)) | ((cwc_ins_stride_i_count == 0) && ((count_p_nxt + cwc_ins_padding_i) == cwc_ins_hf_i));
            wire [2:0] cwc_ins_stride_i_term;
            assign cwc_ins_stride_i_term = ((count_p + cwc_ins_padding_i) != cwc_ins_hf_i ) ? 2'b00 : (cwc_ins_stride_i - cwc_ins_stride_i_count_nxt);
            wire signed [6:0] val_term;
            assign val_term = $signed({1'b0, cwc_ins_hf_i}) - 1 - $signed({1'b0, i_mod_cwc_ins_hf_i}) - $signed({1'b0, cwc_ins_stride_i_term});
            wire [6:0] distance;
            assign distance = $signed({1'b0, cwc_ins_hf_i}) - 1 - $signed({1'b0, i_mod_cwc_ins_hf_i});
            wire is_val_valid;
            assign is_val_valid = (val_term >= 0);

            wire val_mod_cwc_ins_stride_i_zero;
            assign val_mod_cwc_ins_stride_i_zero = (cwc_ins_stride_i == 1) ? 1'b1 :
                                       (cwc_ins_stride_i == 2) ? (val_term[0] == 1'b0) : // Chia hết cho 2 chỉ cần ktra LSB
                                       (cwc_ins_stride_i == 3) ? (val_term == 0 || val_term == 3 || val_term == 6 || val_term == 9 || val_term == 12 || val_term == 15) : 
                                       (cwc_ins_stride_i == 4) ? (val_term[1:0] == 2'b0) : 1'b0;

            wire cwc_ins_padding_i_cond;
            assign cwc_ins_padding_i_cond = cwc_ins_padding_i >= distance;

            wire complex_cond_met;
            assign complex_cond_met = is_val_valid & cwc_ins_padding_i_cond & val_mod_cwc_ins_stride_i_zero;

            wire is_cwc_ins_hf_i_edge;
            assign is_cwc_ins_hf_i_edge = (i_mod_cwc_ins_hf_i == cwc_ins_hf_i - 1);

            assign pp_clear_nxt[i] = is_cwc_ins_hf_i_edge ? (cwc_ins_stride_i_term_cond ? 0 : 1) 
                                    //  : ((cwc_pu_end_height_nxt_i & cwc_ins_dw_i | cwc_pe_end_layer_nxt_i) & !complex_cond_met) ? 1 : 0;
                                    : (cwc_pe_end_layer_nxt_i & !complex_cond_met) ? 1 : 0;
            
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    pp_clear_reg[i] <= 0;
                end
                else if(cwc_pu_swap_en_i) begin
                    pp_clear_reg[i] <= pp_clear_nxt[i];
                end
            end
            assign cwc_pp_clear_o[i] = pp_clear_reg[i];
        end
    endgenerate
endmodule
