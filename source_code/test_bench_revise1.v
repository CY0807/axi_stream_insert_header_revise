`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2023/05/04 12:17:49
// Design Name: 
// Module Name: test_bench_revise1
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


module test_bench_revise1(
);
	
parameter DATA_WD = 32;
parameter DATA_BYTE_WD = DATA_WD / 8;
parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD);
parameter CLK_TIME = 10;
parameter cnt_test_num_max = 5000;

// module ports	
reg clk, rst_n;
reg valid_in, valid_insert, last_in, ready_out;
reg [DATA_WD-1:0] data_in, data_insert;
reg [DATA_BYTE_WD-1:0] keep_in, keep_insert;
reg [BYTE_CNT_WD-1:0] byte_insert_cnt;
wire ready_in, ready_insert, valid_out, last_out;	
wire [DATA_BYTE_WD-1:0] keep_out;
wire [DATA_WD-1:0] data_out;

// other test bench variables
reg [8:0] data_len; // length of data_in: 1~256
reg [8:0] cnt_data_len; // count of length of data_in
reg [BYTE_CNT_WD-1:0] byte_in_cnt; // last word of data_in
integer seed = 0;

// clk
always #(CLK_TIME/2) clk = ~clk;

// initialization
initial begin
  // basic
  $display("***** Start	Simulation *****");
  $display("Random Seed = ", seed);
  clk = 1;
  rst_n = 0;
  
  // data_in
  data_len = {$random(seed)} % 256 + 1;
  data_in = $random(seed);
  last_in = 0;
  keep_in = 4'b1111;
  byte_in_cnt = 0;
  cnt_data_len = 0;  
  valid_in = 0;
  
  // data_insert
  data_insert = $random(seed);
  valid_insert = 0;
  byte_insert_cnt = {$random(seed)} % (DATA_BYTE_WD-1) + 1;
  keep_insert = ~(4'b1111<<(byte_insert_cnt)); 
  
  // start
  # 105
  rst_n = 1;
  # 10
  valid_insert = 1;
end

// random data_in: content, length
always@(posedge clk) begin 
  if(valid_in && ready_in) begin
    data_in <= $random(seed);
    cnt_data_len <= cnt_data_len + 1;	
    if(cnt_data_len == data_len-1) begin
  	  cnt_data_len <= 0;
  	  data_len <= {$random(seed)} % 256 + 1;
    end  
  end
end

// random valid_in
always@(posedge clk) begin
  if(!valid_in || ready_in) //
    valid_in <= $random(seed);
end

// random last keep_in
always@(*) begin
  if(valid_in && ready_in && last_in) begin
    byte_in_cnt = {$random(seed)} % (DATA_BYTE_WD);
    keep_in = 4'b1111 << (byte_in_cnt);
  end
  else begin
    keep_in = 4'b1111;
  end
end

// last_in
always@(*) begin
  if(valid_in && ready_in && cnt_data_len==data_len-1)
  	last_in = 1;
  else
    last_in = 0;
end

// random ready_out
always@(posedge clk) begin
  ready_out <= $random(seed);
end

// random data header
always@(*) begin
    if(ready_insert && valid_insert) begin
        data_insert = $random(seed);
        byte_insert_cnt = {$random(seed)} % (DATA_BYTE_WD-1) + 1;
        keep_insert = ~(4'b1111<<(byte_insert_cnt)); 
    end
end

// 自动化验证部分

reg [7:0] data_input[0:10000];
reg [7:0] data_input_cache[0:10000];
reg [7:0] data_output[0:10000];
reg [31:0] cnt_out, cnt_out_cache, cnt_in, cnt_in_cache, cnt_test_num;

// reserve output data
wire [2:0] byte_data_out_cnt = keep_out[0] + keep_out[1] + keep_out[2] + keep_out[3];
reg output_finish_reg = 0;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt_out <= 0;
        output_finish_reg <= 0;
    end
    else if(valid_out && ready_out) begin    
        for(integer i=0; i<=byte_data_out_cnt-1; i=i+1) begin
            data_output[cnt_out+i] <= data_out >> ((3-i)*8);
        end
        cnt_out <= cnt_out + byte_data_out_cnt;	
        if(last_out) begin
            output_finish_reg <= 1;
            cnt_out_cache <= cnt_out + byte_data_out_cnt;	
            cnt_out <= 0;
        end
    end
    if(output_finish_reg) begin
        output_finish_reg <= 0;
    end
end

// reserve input data
wire [2:0] byte_data_in_cnt = keep_in[0] + keep_in[1] + keep_in[2] + keep_in[3];
reg input_finish_reg = 0;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cnt_in <= 0;
        input_finish_reg <= 0;
    end
    else if(ready_insert && valid_insert) begin
        for(integer i=0; i<=byte_insert_cnt-1; i=i+1) begin
            data_input[cnt_in+i] <= data_insert >> ((byte_insert_cnt-i-1)*8);
        end
        cnt_in <= cnt_in + byte_insert_cnt;	
    end
    else if(ready_in && valid_in) begin  
        for(integer i=0; i<=byte_data_in_cnt-1; i=i+1) begin
            data_input[cnt_in+i] <= data_in >> ((3-i)*8);
        end
        cnt_in <= cnt_in + byte_data_in_cnt;
        if(last_in) begin
            input_finish_reg <= 1;
            cnt_in <= 0;
            cnt_in_cache <= cnt_in + byte_data_in_cnt;
        end
    end
    if(input_finish_reg) begin
        input_finish_reg <= 0;
    end
end

// display and check data
initial begin
    cnt_test_num = 0;
    repeat(cnt_test_num_max) begin
        cnt_test_num = cnt_test_num + 1;
        
        // display input data
        wait(input_finish_reg);
        for(integer i=0; i<cnt_in_cache; i=i+1) begin
            data_input_cache[i] = data_input[i];	
        end
        $display("\n\ntest repeat times: %d", cnt_test_num);
        $display("input data:");
        for(integer i=0; i<cnt_in_cache; i=i+1) begin	 	
            $write("%H", data_input_cache[i]);
        end
        
        // display output data
        wait(output_finish_reg);
        $display("\noutput data:");
        for(integer i=0; i<cnt_out_cache; i=i+1) begin	  
            $write("%H", data_output[i]);
        end
        
        // check result
        if(cnt_in_cache != cnt_out_cache) begin
            $display("\nError: num of data not equal");
            $finish;
        end
        for(integer i=0; i<cnt_out_cache; i=i+1) begin	  
            if(data_input_cache[i] != data_output[i]) begin
                $display("\nError: data not equal");
                $finish;
            end
        end       
    end
    $display("\ntest success! repeat time: %d", cnt_test_num_max);
    $finish;
end

axi_stream_insert_header_revise
#(
  .DATA_WD(DATA_WD)
) 
axi_stream_insert_header_inst
(
  .clk(clk),
  .rst_n(rst_n),
  .valid_in(valid_in),
  .data_in(data_in),
  .keep_in(keep_in),
  .last_in(last_in),
  .ready_in(ready_in),
  .valid_out(valid_out),
  .data_out(data_out),
  .keep_out(keep_out),
  .last_out(last_out),
  .ready_out(ready_out),
  .valid_insert(valid_insert),
  .data_insert(data_insert),
  .keep_insert(keep_insert),
  .byte_insert_cnt(byte_insert_cnt),
  .ready_insert(ready_insert)
);


endmodule
