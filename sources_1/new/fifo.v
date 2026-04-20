module fifo
#(
    parameter  DATA_WIDTH    = 8,
    parameter  FIFO_DEPTH    = 32,
    parameter  FF_TYPE       = 0,
    parameter  FF_NUM        = 2,
    parameter  ADDR_WIDTH    = $clog2(FIFO_DEPTH)
)
(
    input                       clk,
    input   [DATA_WIDTH - 1:0]  data_i,
    output  [DATA_WIDTH - 1:0]  data_o,
    input                       wr_valid_i,
    input                       rd_valid_i,
    input                       clr_rd_i,
    input                       clr_ff_i,
    output                      empty_o,
    output                      full_o,
    output                      almost_empty_o,
    output                      almost_full_o,
    output  [ADDR_WIDTH:0]      counter,
    input                       rst_n
);

function [ADDR_WIDTH-1:0] ptr_map;
    input [ADDR_WIDTH:0] ptr_abs;
    begin
        ptr_map = ptr_abs % FIFO_DEPTH;
    end
endfunction

function [ADDR_WIDTH:0] count_valid_ff;
    input [FF_NUM-1:0] vld_vec;
    integer i;
    begin
        count_valid_ff = { (ADDR_WIDTH+1){1'b0} };
        for (i = 0; i < FF_NUM; i = i + 1) begin
            count_valid_ff = count_valid_ff + vld_vec[i];
        end
    end
endfunction

generate
// ============================================================
// MODE 0 : FIFO thường, data_o đọc thẳng từ memory.
// Ghi ở chu kỳ N thì data hợp lệ ở data_o từ chu kỳ N+1.
// clr_rd_i : đọc lại từ address 0.
// clr_ff_i : reset cả read/write pointer.
// ============================================================
if (FF_TYPE == 0) begin : gen_mode_0
    reg  [DATA_WIDTH - 1:0]  buffer [0:FIFO_DEPTH - 1];
    reg  [ADDR_WIDTH:0]      wr_addr;
    reg  [ADDR_WIDTH:0]      rd_addr;
    wire [ADDR_WIDTH:0]      wr_addr_d;
    wire [ADDR_WIDTH:0]      rd_addr_d;
    wire [ADDR_WIDTH:0]      occ_count;
    wire                     wr_fire;
    wire                     rd_fire;

    assign wr_addr_d = wr_addr + 1'b1;
    assign rd_addr_d = rd_addr + 1'b1;
    assign occ_count = wr_addr - rd_addr;

    assign counter         = occ_count;
    assign empty_o         = (occ_count == 0);
    assign almost_empty_o  = (occ_count == 1);
    assign full_o          = (occ_count >= FIFO_DEPTH);
    assign almost_full_o   = (occ_count >= (FIFO_DEPTH - 1));
    assign wr_fire         = wr_valid_i && !full_o;
    assign rd_fire         = rd_valid_i && !empty_o;
    assign data_o          = empty_o ? {DATA_WIDTH{1'b0}} : buffer[ptr_map(rd_addr)];

    always @(posedge clk) begin
        if (wr_fire) begin
            buffer[ptr_map(wr_addr)] <= data_i;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_addr <= 0;
        end else if (clr_ff_i) begin
            wr_addr <= 0;
        end else if (wr_fire) begin
            wr_addr <= wr_addr_d;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_addr <= 0;
        end else if (clr_ff_i || clr_rd_i) begin
            rd_addr <= 0;
        end else if (rd_fire) begin
            rd_addr <= rd_addr_d;
        end
    end
end
// ============================================================
// MODE 1 : FIFO kiểu BRAM + 1 FF output + bypass.
// Hành vi nhìn từ ngoài giống MODE 0: ghi chu kỳ này, chu kỳ sau đọc được.
// clr_rd_i : clear output FF và fetch lại từ address 0.
// ============================================================
else if (FF_TYPE == 1) begin : gen_mode_1
    reg  [DATA_WIDTH - 1:0]  memory [0:FIFO_DEPTH - 1];
    reg  [ADDR_WIDTH:0]      wr_addr;
    reg  [ADDR_WIDTH:0]      rd_addr;
    reg  [DATA_WIDTH - 1:0]  data_q;
    reg                      data_vld;

    wire [ADDR_WIDTH:0]      wr_addr_d;
    wire [ADDR_WIDTH:0]      rd_addr_d;
    wire [ADDR_WIDTH:0]      mem_count;
    wire [ADDR_WIDTH:0]      total_count;
    wire                     mem_vld;
    wire                     wr_fire;
    wire                     out_take;
    wire                     fetch_from_mem;
    wire                     fetch_from_bypass;

    assign wr_addr_d        = wr_addr + 1'b1;
    assign rd_addr_d        = rd_addr + 1'b1;
    assign mem_count        = wr_addr - rd_addr;
    assign mem_vld          = (mem_count != 0);
    assign total_count      = mem_count + data_vld;
    assign counter          = total_count;
    assign empty_o          = !data_vld;
    assign almost_empty_o   = (total_count == 1);
    assign full_o           = (total_count >= FIFO_DEPTH);
    assign almost_full_o    = (total_count >= (FIFO_DEPTH - 1));
    assign wr_fire          = wr_valid_i && !full_o;
    assign out_take         = rd_valid_i || !data_vld;
    assign fetch_from_mem   = out_take && mem_vld;
    assign fetch_from_bypass= out_take && !mem_vld && wr_fire;
    assign data_o           = data_vld ? data_q : {DATA_WIDTH{1'b0}};

    always @(posedge clk) begin
        if (wr_fire) begin
            memory[ptr_map(wr_addr)] <= data_i;
        end
    end

    always @(posedge clk) begin
        if (fetch_from_mem) begin
            data_q <= memory[ptr_map(rd_addr)];
        end else if (fetch_from_bypass) begin
            data_q <= data_i;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_addr <= 0;
        end else if (clr_ff_i) begin
            wr_addr <= 0;
        end else if (wr_fire) begin
            wr_addr <= wr_addr_d;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_addr <= 0;
        end else if (clr_ff_i || clr_rd_i) begin
            rd_addr <= 0;
        end else if (fetch_from_mem || fetch_from_bypass) begin
            rd_addr <= rd_addr_d;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            data_vld <= 1'b0;
        end else if (clr_ff_i || clr_rd_i) begin
            data_vld <= 1'b0;
        end else if (out_take) begin
            if (mem_vld) begin
                data_vld <= 1'b1;
            end else if (wr_fire) begin
                data_vld <= 1'b1;
            end else begin
                data_vld <= 1'b0;
            end
        end
    end
end
// ============================================================
// MODE 2 : FIFO kiểu BRAM + FF_NUM FF output.
// Với FF_NUM = 2: write->mem, chu kỳ sau lên ff0, chu kỳ sau nữa lên ff1/data_o.
// clr_rd_i : clear toàn bộ FF valid và fetch lại từ address 0.
// ============================================================
else begin : gen_mode_2
    reg  [DATA_WIDTH - 1:0]  memory [0:FIFO_DEPTH - 1];
    reg  [ADDR_WIDTH:0]      wr_addr;
    reg  [ADDR_WIDTH:0]      rd_addr;
    reg  [DATA_WIDTH - 1:0]  data_q [0:FF_NUM-1];
    reg  [FF_NUM-1:0]        data_vld;

    wire [ADDR_WIDTH:0]      wr_addr_d;
    wire [ADDR_WIDTH:0]      rd_addr_d;
    wire [ADDR_WIDTH:0]      mem_count;
    wire [ADDR_WIDTH:0]      ff_count;
    wire [ADDR_WIDTH:0]      total_count;
    wire                     mem_vld;
    wire                     wr_fire;
    wire [FF_NUM-1:0]        ff_hsk;

    genvar ff;

    assign wr_addr_d        = wr_addr + 1'b1;
    assign rd_addr_d        = rd_addr + 1'b1;
    assign mem_count        = wr_addr - rd_addr;
    assign mem_vld          = (mem_count != 0);
    assign ff_count         = count_valid_ff(data_vld);
    assign total_count      = mem_count + ff_count;
    assign counter          = total_count;
    assign empty_o          = !data_vld[FF_NUM-1];
    assign almost_empty_o   = (total_count == 1);
    assign full_o           = (total_count >= FIFO_DEPTH);
    assign almost_full_o    = (total_count >= (FIFO_DEPTH - 1));
    assign wr_fire          = wr_valid_i && !full_o;
    assign data_o           = data_vld[FF_NUM-1] ? data_q[FF_NUM-1] : {DATA_WIDTH{1'b0}};

    assign ff_hsk[FF_NUM-1] = rd_valid_i || !data_vld[FF_NUM-1];
    for (ff = 0; ff < FF_NUM - 1; ff = ff + 1) begin : gen_ff_hsk
        assign ff_hsk[ff] = ff_hsk[ff+1] || !data_vld[ff];
    end

    always @(posedge clk) begin
        if (wr_fire) begin
            memory[ptr_map(wr_addr)] <= data_i;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            data_vld[0] <= 1'b0;
        end else if (clr_ff_i || clr_rd_i) begin
            data_vld[0] <= 1'b0;
        end else if (ff_hsk[0]) begin
            data_vld[0] <= mem_vld;
        end
    end

    always @(posedge clk) begin
        if (ff_hsk[0] && mem_vld) begin
            data_q[0] <= memory[ptr_map(rd_addr)];
        end
    end

    for (ff = 1; ff < FF_NUM; ff = ff + 1) begin : gen_ff_pipe
        always @(posedge clk) begin
            if (!rst_n) begin
                data_vld[ff] <= 1'b0;
            end else if (clr_ff_i || clr_rd_i) begin
                data_vld[ff] <= 1'b0;
            end else if (ff_hsk[ff]) begin
                data_vld[ff] <= data_vld[ff-1];
            end
        end

        always @(posedge clk) begin
            if (ff_hsk[ff] && data_vld[ff-1]) begin
                data_q[ff] <= data_q[ff-1];
            end
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_addr <= 0;
        end else if (clr_ff_i) begin
            wr_addr <= 0;
        end else if (wr_fire) begin
            wr_addr <= wr_addr_d;
        end
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_addr <= 0;
        end else if (clr_ff_i || clr_rd_i) begin
            rd_addr <= 0;
        end else if (ff_hsk[0] && mem_vld) begin
            rd_addr <= rd_addr_d;
        end
    end
end
endgenerate

endmodule
