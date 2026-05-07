`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/10/2026 11:19:59 PM
// Design Name: 
// Module Name: ping_pong_fifo_tb
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


module ping_pong_fifo_tb;

    // Parameters
    parameter WIDTH = 8;
    parameter DEPTH = 11;
    parameter CLK_PERIOD = 10;

    // Inputs
    reg clk;
    reg rst_n;
    reg id_i;
    reg wr_en;
    reg rd_ena;
    reg rd_enb;
    reg clr_i;
    reg [WIDTH-1:0] data_i;

    // Outputs
    wire [WIDTH-1:0] data_oa;
    wire [WIDTH-1:0] data_ob;
    wire empty_o;
    wire end_data_o;

    // inftantiate the Device Under Test (DUT)
    pu_ping_pong_fifo #(
        .WIDTH(WIDTH),
        .DEPTH(DEPTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .id_i(id_i),
        .wr_en(wr_en),
        .rd_ena(rd_ena),
        .rd_enb(rd_enb),
        .clr_i(clr_i),
        .data_i(data_i),
        .data_oa(data_oa),
        .data_ob(data_ob),
        .empty_o(empty_o),
        .end_data_o(end_data_o)
    );

    // Clock Generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Stimulus Process
    initial begin
        // 1. Initialize Inputs
        rst_n = 0;
        id_i = 1;      // Start with FIFO 1 as Active
        wr_en = 0;
        rd_ena = 0;
        rd_enb = 0;
        clr_i = 0;
        data_i = 0;

        // 2. Apply Reset
        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        $display("--- PHASE 1: Write to Active FIFO (FIFO 1) ---");
        // id_i = 1 -> Active is FIFO 1, Background is FIFO 2
        write_data(8'hA1);
        write_data(8'hA2);
        write_data(8'hA3);
        
        // Read one byte back immediately from Active interface (A)
        read_a();

        #(CLK_PERIOD * 2);

        $display("--- PHASE 2: Toggle id_i and Write/Read ---");
        // Swap roles: FIFO 2 becomes Active, FIFO 1 becomes Background
        id_i = 0; 
        #(CLK_PERIOD);

        // Write to newly active FIFO 2
        write_data(8'hB1);
        write_data(8'hB2);

        // Read remaining data from FIFO 1 using the Background interface (B)
        // Since we wrote 3 bytes and read 1 earlier, 2 bytes should remain (A2, A3)
        read_b();
        read_a();
        read_a();

        #(CLK_PERIOD * 2);

        $display("--- PHASE 3: Test Clear Functionality ---");
        // Clear the inactive FIFO (Currently FIFO 1 since id_i = 0)
        clr_i = 1;
        #(CLK_PERIOD);
        clr_i = 0;
        #(CLK_PERIOD);

        // Finish simulation
        $display("--- SIMULATION COMPLETE ---");
        $stop;
    end

    // --- Helper Tasks for clean stimulus --- //

    // Task to write data to the active FIFO
    task write_data(input [WIDTH-1:0] d_in);
        begin
            @(negedge clk); // Align to negative edge to avoid setup/hold issues
            wr_en = 1;
            data_i = d_in;
            @(negedge clk);
            wr_en = 0;
            data_i = 8'h00;
        end
    endtask

    // Task to read data from Interface A (Active)
    task read_a();
        begin
            @(negedge clk);
            rd_ena = 1;
            @(negedge clk);
            rd_ena = 0;
        end
    endtask

    // Task to read data from Interface B (Background)
    task read_b();
        begin
            @(negedge clk);
            rd_enb = 1;
            @(negedge clk);
            rd_enb = 0;
        end
    endtask

endmodule
