`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 06/03/2026 11:22:43 PM
// Design Name: 
// Module Name: pipeline_buffer
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

`timescale 1ns / 1ps

module pipeline_buffer #(
    parameter DATA_WIDTH  = 32,
    parameter PIPE_STAGES = 1
)(
    input                       clk,
    input                       rst_n,

    input      [DATA_WIDTH-1:0] data_i,
    input                       vld_i,
    output                      rdy_o,

    output     [DATA_WIDTH-1:0] data_o,
    output                      vld_o,
    input                       rdy_i
);

    reg  [PIPE_STAGES-1:0]      data_vld_q;
    reg  [DATA_WIDTH-1:0]       data_q [0:PIPE_STAGES-1];
    wire [PIPE_STAGES-1:0]      pipe_rdy;

    integer i;
    genvar  stage;

    assign rdy_o  = pipe_rdy[0];
    assign vld_o  = data_vld_q[PIPE_STAGES-1];
    assign data_o = data_q[PIPE_STAGES-1];

    // Stage cuối nhận data mới nếu nó đang empty hoặc downstream ready.
    assign pipe_rdy[PIPE_STAGES-1] = !data_vld_q[PIPE_STAGES-1] || rdy_i;

    // Ready chain giống file scale_ReLU:
    // pipe_rdy[i] = !data_vld_q[i] || pipe_rdy[i+1]
    generate
        for(stage = 0; stage < PIPE_STAGES-1; stage = stage + 1) begin : gen_pipe_rdy
            assign pipe_rdy[stage] = !data_vld_q[stage] || pipe_rdy[stage+1];
        end
    endgenerate

    // Valid pipeline.
    always @(posedge clk) begin
        if(!rst_n) begin
            data_vld_q <= {PIPE_STAGES{1'b0}};
        end else begin
            if(pipe_rdy[0]) begin
                data_vld_q[0] <= vld_i;
            end

            for(i = 1; i < PIPE_STAGES; i = i + 1) begin
                if(pipe_rdy[i]) begin
                    data_vld_q[i] <= data_vld_q[i-1];
                end
            end
        end
    end

    // Data pipeline.
    // Data chỉ có ý nghĩa khi valid bit tương ứng = 1.
    always @(posedge clk) begin
        if(pipe_rdy[0] && vld_i) begin
            data_q[0] <= data_i;
        end

        for(i = 1; i < PIPE_STAGES; i = i + 1) begin
            if(pipe_rdy[i] && data_vld_q[i-1]) begin
                data_q[i] <= data_q[i-1];
            end
        end
    end

endmodule
