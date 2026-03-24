`timescale 1ns / 1ps

module comp_pe#(
    parameter ID = 0,
    parameter WIDTH = 8,         // Độ rộng dữ liệu đầu vào (8-bit)
    parameter ACC_WIDTH = 32,    // Độ rộng bộ cộng dồn (thường dùng 32-bit cho INT8 MAC)
    parameter K = 6
)(
    input clk,
    input rst_n,

    input pe_ins_dw_i,
    input [3:0] pe_ins_hf_i, 

    input pe_ifc_end_row_circle_i,
    input pe_ifc_end_depth_i,
    input pe_ifc_end_layer_i,
    input pe_ifc_vld_i,
    input [K*WIDTH-1:0] pe_ifc_data_i,
    // Các input mới cho lượng tử hóa
    input [7:0] pe_ifc_zp_i,  // Zero Point của Input Feature Map
    input [7:0] pe_fltc_zp_i, // Zero Point của Filter/width

    input pe_fltc_vld_i,
    input [K*WIDTH-1:0] pe_fltc_data_i,
    output pe_ifc_fltc_rdy_o,

    input [ACC_WIDTH-1:0] pe_pp_pre_data_i,
    output reg pe_pp_pre_rd_o,
    input [ACC_WIDTH-1:0] pe_pp_cur_data_i,
    output reg pe_pp_cur_rd_o,
    input pe_pp_vld_i,
    output reg pe_pp_wr_o,
    output [ACC_WIDTH-1:0] pe_pp_data_o,
    output pe_cwc_end_layer_o,
    output pe_cwc_swap_en_o
);
    localparam STAGES = $clog2(K);
    reg [ACC_WIDTH-1:0] sum_pipe [0:STAGES][0:K-1];
    reg [STAGES + 1 : 0] data_vld;
    reg [STAGES + 2 : 0] is_row_0;
    reg [STAGES + 2 : 0] is_channel_0;
    reg [STAGES + 1 : 0] pu_ifc_end_layer_i_reg;
    reg [STAGES + 1 : 0] pu_ifc_end_depth_i_reg;
    reg [STAGES + 1 : 0] pe_ifc_end_row_circle_i_reg;
    reg swap_en;
    reg [3:0] count;
    reg [ACC_WIDTH-1:0] data;
    // reg [ACC_WIDTH-1:0] data_nxt;
    // reg [ACC_WIDTH-1:0] pe_pp_pre_data_i_reg;
    // reg [ACC_WIDTH-1:0] pe_pp_cur_data_i_reg;
    wire [3:0] id;
    reg [ACC_WIDTH-1:0] add_data;
    wire signed [8:0] ifc_zp_signed;
    assign ifc_zp_signed = $signed({1'b0, pe_ifc_zp_i});
    wire signed [8:0] fltc_zp_signed;
    assign fltc_zp_signed = $signed({1'b0, pe_fltc_zp_i});
    // reg pe_pp_cur_rd_o_nxt;
    // reg pe_pp_pre_rd_o_nxt;

    assign id = ID;
    assign pe_pp_data_o = data;
    assign pe_ifc_fltc_rdy_o = pe_fltc_vld_i && pe_ifc_vld_i && (!pe_pp_vld_i || !pe_ifc_end_depth_i);
    assign pe_cwc_end_layer_o = pu_ifc_end_layer_i_reg[STAGES + 1];
    assign pe_cwc_swap_en_o = swap_en;
    

    // ---------------------------------------------------------
    // Pipeline Registers
    // ---------------------------------------------------------
    

    // assign pe_pp_wr_o = (count == (pe_ins_hf_i - 1)) && data_vld[STAGES + 1];

    integer vld_s;
    // ---------------------------------------------------------
    // Khối 1: Tín hiệu điều khiển (Control Pipeline) - FIXED
    // ---------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Explicitly reset all pipeline registers
            data_vld <= 0;
            pu_ifc_end_layer_i_reg <= 0;
            pu_ifc_end_depth_i_reg <= 0;
            pe_ifc_end_row_circle_i_reg <= 0;
            pe_pp_wr_o <= 1'b0;
            is_row_0[STAGES + 2 : 1] <= 0;      // Highly recommended to reset these too
            is_channel_0[STAGES + 2 : 1] <= 0;
        end else begin
            pe_pp_wr_o <= (count == (pe_ins_hf_i - 1)) && data_vld[STAGES + 1];
            data_vld[0] <= pe_ifc_fltc_rdy_o;
            pu_ifc_end_layer_i_reg[0] <= pe_ifc_end_layer_i;
            pu_ifc_end_depth_i_reg[0] <= pe_ifc_end_depth_i;
            pe_ifc_end_row_circle_i_reg[0] <= pe_ifc_end_row_circle_i;
            
            for (vld_s = 1; vld_s <= STAGES + 1; vld_s = vld_s + 1) begin
                data_vld[vld_s] <= data_vld[vld_s - 1];
                is_row_0[vld_s] <= is_row_0[vld_s - 1];
                is_channel_0[vld_s] <= is_channel_0[vld_s - 1];
                pu_ifc_end_layer_i_reg[vld_s] <= pu_ifc_end_layer_i_reg[vld_s - 1];
                pu_ifc_end_depth_i_reg[vld_s] <= pu_ifc_end_depth_i_reg[vld_s - 1];
                pe_ifc_end_row_circle_i_reg[vld_s] <= pe_ifc_end_row_circle_i_reg[vld_s - 1];
            end
            is_row_0[STAGES + 2] <= is_row_0[STAGES + 1];
            is_channel_0[STAGES + 2] <= is_channel_0[STAGES + 1];
        end
    end

    integer idx;
    // ---------------------------------------------------------
    // Khối 2: STAGE 0 - Tính các phép nhân song song (Lượng tử hóa)
    // ---------------------------------------------------------
    

    // Thêm tên block 'stage0_process' để cho phép khai báo biến cục bộ
    reg signed [K*(WIDTH + 1) - 1:0] ifc_sub;
    reg signed [K*(WIDTH + 1) - 1:0] fltc_sub;
    // reg signed [K*(WIDTH*2 + 1) - 1:0] mult_res;
    always @(posedge clk or negedge rst_n) begin
        // Khai báo các biến tạm kiểu 'reg' thay vì 'wire'
        // reg [7:0] ifc_val;
        // reg [7:0] fltc_val;
        

        if (!rst_n) begin
            for (idx = 0; idx < K; idx = idx + 1) begin
                sum_pipe[0][idx] <= 0;
            end
        end else begin
            for (idx = 0; idx < K; idx = idx + 1) begin
                // 1. Trích xuất dữ liệu 8-bit (Dùng phép gán blocking '=' cho logic tổ hợp)
                // ifc_val[idx*WIDTH +: WIDTH] <= pe_ifc_data_i[idx*WIDTH +: WIDTH];
                // fltc_val[idx*WIDTH +: WIDTH] <= pe_fltc_data_i[idx*WIDTH +: WIDTH];
                
                // 2. Trừ đi Zero Point
                ifc_sub[idx*(WIDTH + 1) +: WIDTH + 1] <= $signed({1'b0, pe_ifc_data_i[idx*WIDTH +: WIDTH]})  - ifc_zp_signed;
                fltc_sub[idx*(WIDTH + 1) +: WIDTH + 1] <= $signed({1'b0, pe_fltc_data_i[idx*WIDTH +: WIDTH]}) - fltc_zp_signed;
                
                // 3. Nhân 2 giá trị đã trừ ZP (Kết quả 18-bit signed)
                // mult_res[idx*(WIDTH*2 + 1) +: WIDTH*2 + 1] <= ifc_sub[idx*(WIDTH + 1) +: WIDTH + 1] * fltc_sub[idx*(WIDTH + 1) +: WIDTH + 1];
                
                // 4. Mở rộng dấu và đưa vào pipeline 32-bit (Dùng gán non-blocking '<=' cho Flip-Flop)
                sum_pipe[0][idx] <= ifc_sub[idx*(WIDTH + 1) +: WIDTH + 1] * fltc_sub[idx*(WIDTH + 1) +: WIDTH + 1];
            end
        end
    end

    // ---------------------------------------------------------
    // Khối 3: STAGE 1 đến STAGES - Cây cộng bằng GENERATE
    // ---------------------------------------------------------
    genvar s, i;
    generate
        
        for (s = 1; s <= STAGES; s = s + 1) begin : adder_tree_stage
            // Hằng số bước nhảy tính ngay lúc compile
            localparam STEP = 1 << (s - 1);
            

            // Cây cộng cho từng Node
            for (i = 0; i < K; i = i + 1) begin : adder_tree_node
                always @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        sum_pipe[s][i] <= 0;
                    end else begin
                        if ((i % (STEP * 2)) == 0) begin
                            if (i + STEP < K) begin
                                sum_pipe[s][i] <= sum_pipe[s-1][i] + sum_pipe[s-1][i + STEP];
                            end else begin
                                sum_pipe[s][i] <= sum_pipe[s-1][i];
                            end
                        end else begin
                            sum_pipe[s][i] <= sum_pipe[s-1][i]; // Bypass các node rác
                        end
                    end
                end
            end
        end
    endgenerate

    // ---------------------------------------------------------
    // Khối 4: STAGE CUỐI CÙNG - Cộng dồn kết quả cuối
    // ---------------------------------------------------------
    always @(posedge clk) begin
        data <= add_data + sum_pipe[STAGES][0];
        swap_en <= !pe_pp_vld_i && (pu_ifc_end_depth_i_reg[STAGES]) && (data_vld[STAGES]);    
        // pe_pp_cur_data_i_reg <= pe_pp_cur_data_i;
        // pe_pp_pre_data_i_reg <= pe_pp_pre_data_i;
    end

    // ---------------------------------------------------------
    // Các logic điều khiển phía sau (Giữ nguyên)
    // ---------------------------------------------------------
    always @(*) begin
        pe_pp_pre_rd_o = 0;
        pe_pp_cur_rd_o = 0;
        casez({count == 0, is_row_0[STAGES], is_channel_0[STAGES], id % pe_ins_hf_i == 0})
            4'b100?: begin 
                add_data = pe_pp_cur_data_i;
                pe_pp_cur_rd_o = 1 & data_vld[STAGES + 1];
            end
            4'b0???: begin
                add_data = data;
            end
            4'b11??: begin
                add_data = 0;
            end
            4'b1011: begin
                add_data = 0;
            end
            4'b1010: begin
                add_data = pe_pp_pre_data_i;
                pe_pp_pre_rd_o = 1 & data_vld[STAGES + 1];
            end
            default: add_data = 0;
        endcase
        // data_nxt = add_data + sum_pipe[STAGES][0];
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            is_channel_0[0] <= 1'b1;
        end else begin
            if(pu_ifc_end_depth_i_reg[STAGES + 1] && data_vld[STAGES + 1]) begin
                is_channel_0[0] <= 1'b1;
            end else if(pe_ifc_end_row_circle_i_reg[STAGES + 1] && !pe_ins_dw_i && data_vld[STAGES + 1]) begin
                is_channel_0[0] <= 0;
            end
        end 
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            is_row_0[0] <= 1'b1;
        end else begin
            if(pu_ifc_end_layer_i_reg[STAGES + 1] && data_vld[STAGES + 1]) is_row_0[0] <= 1'b1;
            else if((pe_ifc_end_row_circle_i_reg[STAGES + 1] && !pe_ins_dw_i || pu_ifc_end_depth_i_reg[STAGES + 1] && pe_ins_dw_i) && data_vld[STAGES + 1])begin
                is_row_0[0] <= 0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            count <= 0;
        end else begin
            if(count == (pe_ins_hf_i - 1) && data_vld[STAGES + 1]) begin
                count <= 0;
            end else if(data_vld[STAGES + 1])begin
                count <= count + 1;
            end
        end 
    end

endmodule