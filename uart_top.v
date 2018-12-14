`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/14/2018 04:29:02 PM
// Design Name: 
// Module Name: uart_top
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


module uart_top(
    input clk,
    output wire uart_txd
    );
    
    parameter CLK_HZ = 100000000;
    parameter BITRATE = 9600;
    parameter PAYLOADS = 8;
    parameter STACK_DEPTH = 64;
    
    reg [7:0] uart_tx_data;
    reg [7:0] message [0:15];
    reg [3:0] messageindex;
    	
    wire uart_tx_busy;
    wire uart_tx_en;
    
    reg [7:0] stack_data    [63:0];
    reg [7:0] stack_counter;
    
    reg sending_stack;
    initial messageindex = 1'b0;
    
    always @(posedge clk) begin
        if(!uart_tx_busy) messageindex = messageindex + 1;
    end
    
    always @(posedge clk) begin
        uart_tx_data <= message[messageindex];
    end
    
    initial begin
		message[ 0] = "H";
		message[ 1] = "e";
		message[ 2] = "l";
		message[ 3] = "l";
		message[ 4] = "o";
		message[ 5] = ",";
		message[ 6] = " ";
		message[ 7] = "W";
		message[ 8] = "o";
		message[ 9] = "r";
		message[10] = "l";
		message[11] = "d";
		message[12] = "!";
		message[13] = " ";
		message[14] = "\r";
		message[15] = "\n";
	end

    
    assign uart_tx_en = !uart_tx_busy;
    
    uart_tx(.clk(clk), .resetn(1), .uart_txd(uart_txd), .uart_tx_en(uart_tx_en), .uart_tx_busy(uart_tx_busy), .uart_tx_data(uart_tx_data));
endmodule
