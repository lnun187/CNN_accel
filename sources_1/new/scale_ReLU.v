`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/21/2026 02:18:47 PM
// Design Name: 
// Module Name: scale_ReLU
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


module scale_ReLU #(
    parameter DATA_OUT_WIDTH = 8,
    parameter DATA_IN_WIDTH = 32
)(
    input                       clk,
    input                       rst_n,

    input           [7:0]       scale_ins_width_i,
    input   signed  [31:0]      scale_ins_mult_i,
    input           [5:0]       scale_ins_mult_shift_i,
    input   signed  [15:0]      scale_ins_alphamult_i,
    input           [5:0]       scale_ins_alphamult_shift_i,
    input   signed  [7:0]       scale_ins_zpy_i,
    input   signed  [7:0]       scale_ins_qmin_i,
    input   signed  [7:0]       scale_ins_qmax_i,
    input                       scale_ins_is_leaky_ReLU_i,

    input   signed  [DATA_IN_WIDTH-1:0]      scale_bias_data_i,
    input                       scale_bias_vld_i,
    output                      scale_bias_rdy_o,

    input   signed  [DATA_IN_WIDTH-1:0]      scale_comp_data_i,
    input                       scale_comp_vld_i,
    output                      scale_comp_rdy_o,
    
    input                       scale_ofbuf_rdy_i,
    output  signed  [DATA_OUT_WIDTH-1:0]       scale_ofbuf_data_o,
    output                      scale_ofbuf_vld_o
    );

    reg             [7:0]        scale_ins_width_reg;
    reg  signed     [DATA_IN_WIDTH-1:0]       scale_ins_mult_reg;
    reg             [5:0]        scale_ins_mult_shift_reg;
    reg  signed     [15:0]       scale_ins_alphamult_reg;
    reg             [5:0]        scale_ins_alphamult_shift_reg;
    reg  signed     [7:0]        scale_ins_zpy_reg;
    reg  signed     [7:0]        scale_ins_qmin_reg;
    reg  signed     [7:0]        scale_ins_qmax_reg;
    reg                          scale_ins_is_leaky_ReLU_reg;
    reg  signed     [DATA_IN_WIDTH-1:0]       bias_data_q;
    reg                          bias_vld_q;
    reg             [7:0]        count_w_q;
    reg  signed           [63:0]       round_value;
    reg  signed           [63:0]       round_value_alpha;

    

    assign scale_bias_rdy_o     = !bias_vld_q || (count_w_q == scale_ins_width_reg - 1);
    assign scale_comp_rdy_o     = bias_vld_q && (!data_vld_q[0] || scale_ofbuf_rdy_i);
    assign scale_ofbuf_data_o   = data_stage_10_q;
    assign scale_ofbuf_vld_o    = data_vld_q[10];

    always @(posedge clk) begin
        if (scale_bias_vld_i && scale_bias_rdy_o) begin
            scale_ins_width_reg <= scale_ins_width_i;
            scale_ins_mult_reg <= scale_ins_mult_i;
            scale_ins_mult_shift_reg <= scale_ins_mult_shift_i;
            scale_ins_alphamult_reg <= scale_ins_alphamult_i;
            scale_ins_alphamult_shift_reg <= scale_ins_alphamult_shift_i;
            scale_ins_zpy_reg <= scale_ins_zpy_i;
            scale_ins_qmin_reg <= scale_ins_qmin_i;
            scale_ins_qmax_reg <= scale_ins_qmax_i;
            scale_ins_is_leaky_ReLU_reg <= scale_ins_is_leaky_ReLU_i;
        end
        round_value <= |scale_ins_mult_shift_reg ? 64'sd1 << (scale_ins_mult_shift_reg - 1) : 64'sd0;
        round_value_alpha <= |scale_ins_alphamult_shift_reg ? 64'sd1 << (scale_ins_alphamult_shift_reg - 1) : 64'sd0;
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            bias_vld_q <= 0;
        end else if(!bias_vld_q || (count_w_q == scale_ins_width_reg - 1)) begin
            bias_vld_q <= scale_bias_rdy_o && scale_bias_vld_i;
        end
    end
    always @(posedge clk) begin
        if(scale_bias_rdy_o && scale_bias_vld_i) begin
            bias_data_q <= scale_bias_data_i;
        end
    end

    always @(posedge clk) begin
        if(!rst_n) begin
            count_w_q <= 0;
        end else if(scale_comp_rdy_o && scale_comp_vld_i) begin
            count_w_q <= (count_w_q == scale_ins_width_reg - 1) ? 0 : count_w_q + 1;
        end
    end

    genvar stage;
    generate
        for(stage = 0; stage  < 11; stage = stage + 1) begin
            always @(posedge clk) begin
                if(!rst_n) begin
                    data_vld_q[stage] <= 0;
                end else if(!data_vld_q[stage] || scale_ofbuf_rdy_i) begin
                    data_vld_q[stage] <= (stage == 0) ? (bias_vld_q && scale_comp_vld_i) : data_vld_q[stage-1];
                end
            end
        end
    endgenerate
    reg             [10:0]        data_vld_q; //Pipeline 11 STAGES
    reg  signed     [31:0]       data_stage_0_q;
    reg  signed     [63:0]       data_stage_1_q;
    reg  signed     [63:0]       data_stage_2_q;
    reg  signed     [63:0]       data_stage_3_q;
    reg  signed     [31:0]        data_stage_4_q;
    reg  signed     [63:0]       data_stage_5_q;
    reg  signed     [31:0]        data_stage_5_cross_q;
    reg  signed     [63:0]       data_stage_6_q;
    reg  signed     [31:0]        data_stage_6_cross_q;
    reg  signed     [31:0]       data_stage_7_q;
    reg  signed     [31:0]        data_stage_7_cross_q;
    reg  signed     [31:0]       data_stage_8_q;
    reg  signed     [31:0]       data_stage_9_q;
    reg  signed     [7:0]       data_stage_10_q;

    wire signed     [31:0]       data_stage_0_d;
    wire signed     [63:0]       data_stage_1_d;
    wire signed     [63:0]       data_stage_2_d;
    wire signed     [63:0]       data_stage_3_d;
    wire signed     [31:0]       data_stage_4_d;
    wire signed     [63:0]       data_stage_5_d;
    wire signed     [63:0]       data_stage_6_d;
    wire signed     [31:0]       data_stage_7_d;
    wire signed     [31:0]        data_stage_8_d;
    wire signed     [31:0]        data_stage_9_d;
    wire signed     [7:0]        data_stage_10_d;
    //======================================================================================
    //          STAGE 0: ADD BIAS
    //======================================================================================
    assign data_stage_0_d = bias_data_q + scale_comp_data_i;
    always @(posedge clk) begin
        if(!data_vld_q[0] || scale_ofbuf_rdy_i) begin
            data_stage_0_q <= data_stage_0_d;
        end
    end
    //======================================================================================
    //          STAGE 1: MULTIPLY MULTIPLIER
    //======================================================================================
    assign data_stage_1_d = data_stage_0_q * scale_ins_mult_reg;
    always @(posedge clk) begin
        if(!data_vld_q[1] || scale_ofbuf_rdy_i) begin
            data_stage_1_q <= data_stage_1_d;
        end
    end
    //======================================================================================
    //          STAGE 2: ADD ROUND VALUE
    //======================================================================================
    assign data_stage_2_d = data_stage_1_q + round_value - ({64{data_stage_1_q[63]}} & 64'sd1);
    always @(posedge clk) begin
        if(!data_vld_q[2] || scale_ofbuf_rdy_i) begin
            data_stage_2_q <= data_stage_2_d;
        end
    end
    //======================================================================================
    //          STAGE 3: SHIFT
    //======================================================================================
    assign data_stage_3_d = |scale_ins_mult_shift_reg ? data_stage_2_q >>> scale_ins_mult_shift_reg : data_stage_2_q;
    always @(posedge clk) begin
        if(!data_vld_q[3] || scale_ofbuf_rdy_i) begin
            data_stage_3_q <= data_stage_3_d;
        end
    end
    //======================================================================================
    //          STAGE 4: CLAMP TO 32 BIT
    //======================================================================================
    assign data_stage_4_d = (|data_stage_3_q[63:31] && !(&data_stage_3_q[63:31])) ? 
                            (data_stage_3_q[63] ? 32'h8000_0000 : 32'h7FFF_FFFF)
                            : data_stage_3_q[31:0];
    always @(posedge clk) begin
        if(!data_vld_q[4] || scale_ofbuf_rdy_i) begin
            data_stage_4_q <= data_stage_4_d;
        end
    end
    //======================================================================================
    //          STAGE 5: MULTIPLY WITH ALPHA MULTIPLIER
    //======================================================================================
    assign data_stage_5_d = data_stage_4_q * scale_ins_alphamult_reg;
    always @(posedge clk) begin
        if(!data_vld_q[5] || scale_ofbuf_rdy_i) begin
            data_stage_5_q <= data_stage_5_d;
            data_stage_5_cross_q <= data_stage_4_q;
        end
    end
    //======================================================================================
    //          STAGE 6: ADD ROUND ALPHA VALUE
    //======================================================================================
    assign data_stage_6_d = data_stage_5_q + round_value_alpha - ({64{data_stage_5_q[63]}} & 64'sd1);
    always @(posedge clk) begin
        if(!data_vld_q[6] || scale_ofbuf_rdy_i) begin
            data_stage_6_q <= data_stage_6_d;
            data_stage_6_cross_q <= data_stage_5_cross_q;
        end
    end
    //======================================================================================
    //          STAGE 7: ALPHA SHIFT
    //======================================================================================
    assign data_stage_7_d = |scale_ins_alphamult_shift_reg ? data_stage_6_q >>> scale_ins_alphamult_shift_reg : data_stage_6_q;
    always @(posedge clk) begin
        if(!data_vld_q[7] || scale_ofbuf_rdy_i) begin
            data_stage_7_q <= data_stage_7_d;
            data_stage_7_cross_q <= data_stage_6_cross_q;
        end
    end
    //======================================================================================
    //          STAGE 8: CHOOSE data_stage_7_q IF IS LEAKY RELU & data_stage_7_cross_q < 0
    //======================================================================================
    assign data_stage_8_d = data_stage_7_cross_q[31] ? 
                            (scale_ins_is_leaky_ReLU_reg ? data_stage_7_q : 32'sd0) : 
                            data_stage_7_cross_q;
    always @(posedge clk) begin
        if(!data_vld_q[8] || scale_ofbuf_rdy_i) begin
            data_stage_8_q <= data_stage_8_d;
        end
    end
    //======================================================================================
    //          STAGE 9: ADD ZPY
    //======================================================================================
    assign data_stage_9_d = data_stage_8_q + scale_ins_zpy_reg;
    always @(posedge clk) begin
        if(!data_vld_q[9] || scale_ofbuf_rdy_i) begin
            data_stage_9_q <= data_stage_9_d;
        end
    end
    //======================================================================================
    //          STAGE 10: CLAMP min(qmax, max(qmin, data_stage_9_q))
    //======================================================================================
    assign data_stage_10_d = data_stage_9_q > scale_ins_qmax_reg ? scale_ins_qmax_reg :
                            data_stage_9_q < scale_ins_qmin_reg ? scale_ins_qmin_reg :
                            data_stage_9_q;
    always @(posedge clk) begin
        if(!data_vld_q[10] || scale_ofbuf_rdy_i) begin
            data_stage_10_q <= data_stage_10_d;
        end
    end
    
endmodule
