`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Description: Updated Testbench for filter_cache (Independent Read/Write)
//////////////////////////////////////////////////////////////////////////////////

module filter_cache_tb;
    // =========================================================
    // 1. Parameters & Signals
    // =========================================================
    parameter WIDTH = 8;
    parameter DEPTH = 11;
    parameter PE_PER_PU = 4;

    // Inputs
    reg clk;
    reg rst_n;
    reg fltbuf_vld_i;
    reg [WIDTH-1:0] fltbuf_data_i;
    reg [3:0] hf;
    reg done_pass;
    reg comp_rdy_i;
    reg comp_clr_i;

    // Outputs
    wire fltbuf_rdy_o;
    wire [PE_PER_PU-1:0] comp_vld_o;       
    wire [PE_PER_PU*WIDTH-1:0] comp_data_o;

    // Internal Variables for Verification
    integer i;

    // =========================================================
    // 2. Instantiate the Unit Under Test (UUT)
    // =========================================================
    filter_cache #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH),
        .PE_PER_PU(PE_PER_PU)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .fltc_fltbuf_vld_i(fltbuf_vld_i),       
        .fltc_fltbuf_data_i(fltbuf_data_i),     
        .fltc_fltbuf_rdy_o(fltbuf_rdy_o),       
        .fltc_ins_hf_i(hf),                     
        .fltc_fltbuf_done_pass_i(done_pass),    
        .fltc_pe_rdy_i(comp_rdy_i),             
        .fltc_pu_clr_ch_flt_i(comp_clr_i),      
        .fltc_pe_vld_o(comp_vld_o),             
        .fltc_pe_data_o(comp_data_o)            
    );

    // =========================================================
    // 3. Clock Generation
    // =========================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // Chu kỳ 10ns
    end

    // =========================================================
    // 4. WRITE PROCESS (Producer & Main Control)
    // =========================================================
    initial begin
        $display("=== Bat dau mo phong ===");
        // Khởi tạo các tín hiệu đầu vào cho Write
        rst_n = 0;
        fltbuf_vld_i = 0;
        fltbuf_data_i = 0;
        hf = 1;         
        done_pass = 0;
        comp_clr_i = 0;
        
        // Reset
        #20;
        rst_n = 1;
        #10;
        $display("Time %t: [WRITE] Reset released", $time);

        // --- Nạp lần 1 ---
        $display("Time %t: [WRITE] Nap du lieu lan 1", $time);
        for (i = 0; i < 1; i = i + 1) begin
            wait(fltbuf_rdy_o == 1);
            @(negedge clk);
            fltbuf_vld_i = 1;
            fltbuf_data_i = i + 1;
        end
        done_pass = 1; 
        @(negedge clk); 
        fltbuf_vld_i = 0;
        done_pass = 0;
        
        // --- Nạp lần 2 ---
        $display("Time %t: [WRITE] Nap du lieu lan 2", $time);
        for (i = 0; i < 1; i = i + 1) begin
            wait(fltbuf_rdy_o == 1);
            @(negedge clk);
            fltbuf_vld_i = 1;
            fltbuf_data_i = i + 10; // Đổi data một chút để dễ phân biệt trên Waveform
        end
        done_pass = 1; 
        @(negedge clk); 
        fltbuf_vld_i = 0;
        done_pass = 0;
        
        // Chờ module xử lý một thời gian trước khi Clear
        #150; 
        
        // --- Test Clear ---
        $display("Time %t: [WRITE] Asserting Clear signal", $time);
        comp_clr_i = 1;
        #10;
        comp_clr_i = 0;
        
        // --- Nạp lần 3 (Sau Clear) ---
        $display("Time %t: [WRITE] Nap du lieu sau Clear", $time);
        for (i = 0; i < 1; i = i + 1) begin
            wait(fltbuf_rdy_o == 1);
            @(negedge clk);
            fltbuf_vld_i = 1;
            fltbuf_data_i = i + 100; // Đổi data để phân biệt
        end
        done_pass = 1; 
        @(negedge clk);
        fltbuf_vld_i = 0;
        done_pass = 0;
        
        // Chờ thêm một khoảng thời gian cho tiến trình Read chạy nốt
        #200;
        $display("=== Ket thuc mo phong ===");
        $finish; // Lệnh này sẽ kết thúc toàn bộ simulation, bao gồm cả tiến trình Read
    end

    // =========================================================
    // 5. READ PROCESS (Consumer)
    // =========================================================
    initial begin
        comp_rdy_i = 0;
        
        // Chờ đến khi hệ thống thoát khỏi reset
        wait(rst_n == 1);
        
        // Vòng lặp vĩnh viễn chạy song song với Write Process
        forever begin
            // Đợi đến khi có tín hiệu Valid từ UUT
            wait(comp_vld_o[0] == 1'b1);
            
            // Đồng bộ với xung clock
            @(negedge clk);
            
            $display("Time %t: [READ] Consumer nhan thay Valid = 1, keo Ready = 1", $time);
            comp_rdy_i = 1;
            
            // Giả lập đọc liên tục trong 4 chu kỳ
            repeat (4) @(negedge clk);
            
            // Giả lập Consumer bị bận (stall), kéo Ready xuống 0
            $display("Time %t: [READ] Consumer ban, keo Ready = 0", $time);
            comp_rdy_i = 0;
            
            // Nghỉ 3 chu kỳ rồi mới quay lại chờ Valid tiếp
            repeat (3) @(negedge clk);
        end
    end

endmodule