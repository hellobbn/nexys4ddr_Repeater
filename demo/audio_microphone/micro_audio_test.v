/* This is the main module of the project */

module micro_audio_test(
    // Clock
    input clk_100mhz,

    // microphone
    input m_data,
    output lrsel,

    // pwm
    output wire clk_2_5_mhz,
    output ampsd,
    output ampPWM
);

    wire clk_5_mhz;
    reg pwm_val_reg;

    // Let's use ip to make it 5MHz
    clk_wiz_0 clk_conv(.clk_out1(clk_5_mhz), .clk_in1(clk_100mhz));

    // Let's convert it to 2.5Mhz
    clock_divider clv1(.clk_in(clk_5_mhz), .clk_out(clk_2_5_mhz));

    assign ampsd = 1;

    always @(posedge clk_2_5_mhz) begin
        pwm_val_reg <= m_data;
    end
    assign lrsel = 1;
    assign ampPWM = pwm_val_reg;

endmodule

module clock_divider(input clk_in, output reg clk_out = 0);
	always @(posedge clk_in) begin
		clk_out <= ~clk_out;
	end
endmodule