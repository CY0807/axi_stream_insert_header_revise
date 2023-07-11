`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/07/11 09:39:19
// Design Name: 
// Module Name: axi_stream_insert_header_revise
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


module axi_stream_insert_header_revise
#(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) 
(
    input clk,
    input rst_n,
    // AXI Stream input original data
    input valid_in,
    input [DATA_WD-1:0] data_in,
    input [DATA_BYTE_WD-1:0] keep_in,
    input last_in,
    output ready_in,
    // AXI Stream output with header inserted
    output valid_out,
    output [DATA_WD-1:0] data_out,
    output [DATA_BYTE_WD-1:0] keep_out,
    output last_out,
    input ready_out,
    // The header to be inserted to AXI Stream input
    input valid_insert,
    input [DATA_WD-1:0] data_insert,
    input [DATA_BYTE_WD-1:0] keep_insert,
    input [BYTE_CNT_WD-1:0] byte_insert_cnt,
    output ready_insert
);

// 握手信号
wire shake_in = ready_in & valid_in;
wire shake_insert = ready_insert & valid_insert;
wire shake_out = ready_out & valid_out;

// 1.数据头和数据体输入部分
reg header_captured_reg;
reg [DATA_WD-1:0] data_cache_reg;
reg [DATA_BYTE_WD-1:0] keep_cache_reg;
reg [BYTE_CNT_WD-1:0] byte_insert_cnt_reg;

assign ready_insert = ~header_captured_reg | (last_out & ~last_in);
assign ready_in = header_captured_reg & shake_out;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        keep_cache_reg <= 0;
        keep_cache_reg <= 0;
    end
    else if(shake_insert) begin
        data_cache_reg <= data_insert;
        keep_cache_reg <= keep_insert;
    end
    else if(shake_in) begin
        data_cache_reg <= data_in;
        keep_cache_reg <= keep_in;
    end
end

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        header_captured_reg <= 0;
        byte_insert_cnt_reg <= 0;
    end
    else if(shake_insert) begin
        header_captured_reg <= 1;
        byte_insert_cnt_reg <= byte_insert_cnt;
    end
    else if(last_out) begin
        header_captured_reg <= 0;
    end
end

// 2.数据输出部分

wire [DATA_WD-1:0] bit_insert_cnt = byte_insert_cnt_reg << 3; // head的有效bit
wire [BYTE_CNT_WD-1:0] disbyte_insert_cnt = DATA_BYTE_WD-byte_insert_cnt_reg; //head的无效byte
//wire [DATA_WD-1:0] disbit_insert_cnt = disbyte_insert_cnt << 3; // head的无效bit
wire [DATA_WD-1:0] data_zero = 0;
wire [DATA_BYTE_WD-1:0] keep_zero = 0;
wire [3:0] last_out_temp;
wire last_out_pulse, last_out_en;

reg last_out_hold_reg;

assign valid_out = valid_in & header_captured_reg | last_out_hold_reg;
assign last_out_temp = {keep_cache_reg, keep_in}<<disbyte_insert_cnt;
assign last_out_pulse = last_out_temp==4'b0;
assign last_out_en = last_out_pulse | last_out_hold_reg;
assign last_out = last_out_en & shake_out;
assign data_out = ~last_out_hold_reg ? {data_cache_reg, data_in} >> bit_insert_cnt : 
                                   {data_cache_reg, data_zero} >> bit_insert_cnt;
assign keep_out = ~last_out_hold_reg ? {keep_cache_reg, keep_in} >> byte_insert_cnt_reg : 
                                   {keep_cache_reg, keep_zero} >> byte_insert_cnt_reg;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        last_out_hold_reg <= 0;
    end
    else if(last_in && !last_out_en) begin // 多一拍的处理
        last_out_hold_reg <= 1;
    end
    else if(last_out_en && !shake_out) begin // 保持last_out
        last_out_hold_reg <= 1;
    end
    else if(last_out_en && shake_out) begin
        last_out_hold_reg <= 0;
    end
end

endmodule