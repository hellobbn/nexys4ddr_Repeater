`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/12/2018 09:36:59 PM
// Design Name: 
// Module Name: microphone
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

/* Microphone Interface
 * From Nexys4DDR's reference Manual
 * The microphone has a input clk, output data, and a input L/R SEL
 */

module microphone(
    output micro_clk,
    output anout,
    input micro_data,
    input clk,                  // It is a 100Mhz Clock
    output lrsel,
    input reset
    );

    // save audio file to an reg
    reg pwm_data;

    // Set lrsel to 1 so we can sample on micro_clk's posedge
    assign lrsel = 1'b0;
    
    // Let's use ip to make it 5MHz
    wire clk_5mhz;
    clk_wiz_0 clk_conv(.clk_out1(clk_5mhz), .clk_in1(clk));

    // Let's convert it to 2.5Mhz
    wire clk_2_5_mhz;
    clock_divider clv1(.clk_in(clk_5mhz), .clk_out(clk_2_5_mhz));
    assign micro_clk = clk_2_5_mhz;

    // collect the data
    always @(posedge clk) begin
        pwm_data <= micro_data;
    end

    assign anout = pwm_data;

endmodule

