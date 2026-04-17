`timescale 1ns / 1ps

module comp_pe#(
    parameter ID            = 0,
    parameter WIDTH         = 8,     // Độ rộng dữ liệu đầu vào (8-bit)
    parameter ACC_WIDTH     = 32,    // Độ rộng bộ cộng dồn (thường dùng 32-bit cho INT8 MAC)
    parameter K             = 8
)(
    input                           clk,
    input                           rst_n,

    input       [3:0]               pe_ins_hf_i, 

    input                           pe_ifc_end_row_circle_i,
    input                           pe_ifc_end_depth_i,
    input                           pe_ifc_end_layer_i,
    input                           pe_ifc_vld_i,
    input       [K*WIDTH-1:0]       pe_ifc_data_i,
    // Các input mới cho lượng tử hóa
    input       [WIDTH-1:0]         pe_ifc_zp_i,  // Zero Point của Input Feature Map
    input       [WIDTH-1:0]         pe_fltc_zp_i, // Zero Point của Filter/width

    input                           pe_fltc_vld_i,
    input       [K*WIDTH-1:0]       pe_fltc_data_i,
    output                          pe_ifc_fltc_rdy_o,

    input       [ACC_WIDTH-1:0]     pe_pp_pre_data_i,
    output  reg                     pe_pp_pre_rd_o,
    input       [ACC_WIDTH-1:0]     pe_pp_cur_data_i,
    output  reg                     pe_pp_cur_rd_o,
    input                           pe_pp_vld_i,
    output  reg                     pe_pp_wr_o,
    output      [ACC_WIDTH-1:0]     pe_pp_data_o,
    output  reg                     pe_cwc_end_layer_o,
    output                          pe_cwc_swap_en_o
);
    localparam STAGES = $clog2(2*K) + 1; //current design has 6 STAGES (+ 1 STAGE at data_out)
    reg         [ACC_WIDTH-1:0]         sum_pipe [0:STAGES-2][0:K-1];
    reg         [ACC_WIDTH-1:0]         data;
    reg signed  [WIDTH:0]               ifc_sub [K-1:0];
    reg signed  [WIDTH:0]               fltc_sub [K-1:0];
    reg                                 end_row;
    reg         [STAGES - 1 : 0]        end_depth;
    reg         [STAGES - 1 : 0]        end_layer;
    reg         [STAGES - 1 : 0]        data_vld;
    reg         [ACC_WIDTH-1:0]         pp_data [0:STAGES - 3];
    reg                                 is_row_0;
    reg                                 is_channel_0;
    reg         [3:0]                   count_rd;
    reg         [3:0]                   count_wr;
    reg                                 en_compute;
    reg                                 en_compute1;
    reg                                 swap_en;
    reg         [ACC_WIDTH-1:0]         add_data;
    reg         [WIDTH-1:0]             pe_fltc_zp_reg;
    reg         [WIDTH-1:0]             pe_ifc_zp_reg;
    //--------------------------------------------ASSIGN-----------------------------------------------
    assign pe_cwc_swap_en_o     = swap_en;
    assign pe_ifc_fltc_rdy_o    = pe_fltc_vld_i && pe_ifc_vld_i && en_compute;
    // assign 
    assign pe_pp_data_o         = data;
    //--------------------------------------------CONTROL COMPUTE-----------------------------------------------
    always @(posedge clk) begin
        pe_fltc_zp_reg <= pe_fltc_zp_i;
        pe_ifc_zp_reg <= pe_ifc_zp_i;
    end
    always @(posedge clk) begin
        if(!rst_n) begin
            en_compute          <= 1;
            en_compute1         <= 1;
            swap_en             <= 0;
            count_rd            <= 0;
            count_wr            <= 0;
            is_row_0            <= 1'b1;
            is_channel_0        <= 1'b1;
            pe_pp_pre_rd_o      <= 0;
            pe_pp_cur_rd_o      <= 0;
            pe_pp_wr_o          <= 0;
            pe_cwc_end_layer_o  <= 0;
        end else begin
            if(end_depth[STAGES-1] && pe_pp_vld_i)  en_compute <= 0; //nếu hàng cuối cùng và chưa trống thì không hút nữa
            else if(!pe_pp_vld_i)                   en_compute <= 1;
            
            en_compute1 <= en_compute;
            
            swap_en <= !pe_pp_vld_i && (end_depth[STAGES-1] || !en_compute);
            
            if(data_vld[0] && en_compute) count_rd <= (count_rd == pe_ins_hf_i - 1) ? 0 : count_rd + 1;
            
            if(data_vld[STAGES-1] && en_compute) count_wr <= (count_wr == pe_ins_hf_i - 1) ? 0 : count_wr + 1;
            
            if(end_layer[0]) is_row_0 <= 1'b1;
            else if(end_row) is_row_0 <= 0;
            
            if(end_depth[0]) is_channel_0 <= 1'b1;
            else if(end_row) is_channel_0 <= 0;
            
            pe_pp_pre_rd_o  <= !is_row_0 && is_channel_0 && !(|count_rd) && data_vld[0] && |(ID % pe_ins_hf_i) && en_compute;
            pe_pp_cur_rd_o  <= !is_channel_0 && !(|count_rd) && data_vld[0] && en_compute;
            pe_pp_wr_o      <= (count_wr == pe_ins_hf_i - 1) && data_vld[STAGES-1] && en_compute;
            
            if(swap_en)                     pe_cwc_end_layer_o <= 0;
            else if(end_layer[STAGES-1])    pe_cwc_end_layer_o <= 1;
        end
    end

    //--------------------------------------------STAGE-----------------------------------------------
    integer stage;
    integer pp_idx;
    always @(posedge clk) begin
        if(!rst_n) begin
            end_row                 <= 0;
            end_depth[STAGES-1:0]   <= 0;
            end_layer[STAGES-1:0]   <= 0;
            data_vld[STAGES-1:0]    <= 0;
        end else if(en_compute) begin
            end_row         <= pe_ifc_end_row_circle_i;
            end_depth[0]    <= pe_ifc_end_depth_i;
            end_layer[0]    <= pe_ifc_end_layer_i;
            data_vld[0]     <= pe_ifc_fltc_rdy_o;
            for (stage = 1; stage < STAGES; stage = stage + 1) begin
                end_depth[stage]    <= end_depth[stage-1];
                end_layer[stage]    <= end_layer[stage-1];
                data_vld[stage]     <= data_vld[stage-1];
            end
        end
    end
    always @(posedge clk) begin
        if(en_compute1) begin
            pp_data[0] <= {ACC_WIDTH{pe_pp_pre_rd_o}} & pe_pp_pre_data_i | {ACC_WIDTH{pe_pp_cur_rd_o}} & pe_pp_cur_data_i; //Start at STAGE 2
            for (pp_idx = 1; pp_idx < STAGES-2; pp_idx = pp_idx + 1) begin
                pp_data[pp_idx] <= pp_data[pp_idx-1];
            end
        end
    end
    //--------------------------------------------STAGE 0 & STAGE 1-----------------------------------------------
    wire signed [WIDTH:0] ifc_zp_signed;
    wire signed [WIDTH:0] fltc_zp_signed;

    assign ifc_zp_signed    = $signed({1'b0, pe_ifc_zp_reg});
    assign fltc_zp_signed   = $signed({1'b0, pe_fltc_zp_reg});
    integer idx;
    always @(posedge clk) begin
        if (en_compute) begin
            for (idx = 0; idx < K; idx = idx + 1) begin
                ifc_sub[idx]   <= $signed({1'b0, pe_ifc_data_i[idx*WIDTH +: WIDTH]})  - ifc_zp_signed;
                fltc_sub[idx]  <= $signed({1'b0, pe_fltc_data_i[idx*WIDTH +: WIDTH]}) - fltc_zp_signed;
            end
        end
    end
    integer sum;
    always @(posedge clk) begin
        if (en_compute) begin
            for (sum = 0; sum < K; sum = sum + 1) begin
                sum_pipe[0][sum] <= $signed(ifc_sub[sum]) * $signed(fltc_sub[sum]);
            end
        end
    end
    //--------------------------------------------STAGE 2 -> 4-----------------------------------------------
    genvar s, i;
    generate
        
        for (s = 1; s < STAGES - 1; s = s + 1) begin : adder_tree_stage
            // Hằng số bước nhảy tính ngay lúc compile
            localparam STEP = 1 << (s - 1);
            // Cây cộng cho từng Node
            for (i = 0; i < K; i = i + 1) begin : adder_tree_node
                always @(posedge clk) begin
                    if(en_compute) begin 
                        if ((i % (STEP * 2)) == 0) begin
                            if (i + STEP < K) begin
                                sum_pipe[s][i] <= $signed(sum_pipe[s-1][i]) + $signed(sum_pipe[s-1][i + STEP]);
                            end else begin
                                sum_pipe[s][i] <= $signed(sum_pipe[s-1][i]);
                            end
                        end else begin
                            sum_pipe[s][i] <= $signed(sum_pipe[s-1][i]); // Bypass các node rác
                        end
                    end
                end
            end
        end
    endgenerate
    //--------------------------------------------STAGE 5-----------------------------------------------
    always @(posedge clk) begin
        if(en_compute) begin
            data <= $signed(add_data) + $signed(sum_pipe[STAGES-2][0]);
        end
    end
    always @(posedge clk) begin
        if(en_compute) begin
            add_data <= (count_wr == pe_ins_hf_i - 1) || ((count_wr == 0) && data_vld[STAGES-2] && !data_vld[STAGES-1]) ? $signed(pp_data[STAGES-4]) : $signed(add_data) + $signed(sum_pipe[STAGES-2][0]);
        end
    end
endmodule