module mtr_drv(
	input clk,
	input rst_n,
	input [10:0] lft_spd,
	input lft_rev,
	output PWM_rev_lft,
	output PWM_frwrd_lft,
	input [10:0] rght_spd,
	input rght_rev,
	output PWM_rev_rght,
	output PWM_frwrd_rght);

	wire w_rhb, w_lhb;
	
	PWM11 rightHB(.clk(clk), .rst_n(rst_n), .duty(rght_spd), .PWM_sig(w_rhb));		//This module instantiation is the right side of the Hbridge
	PWM11 leftHB(.clk(clk), .rst_n(rst_n), .duty(lft_spd), .PWM_sig(w_lhb));		//This is the left side of the Hbridge

	assign PWM_frwrd_rght = w_rhb & ~rght_rev;		//Right side is driven forward when the PWM_sig from the right side of the Hbridge is high and 
	assign PWM_rev_rght =  w_rhb & rght_rev;		//we are not in reverse (determined from the input from this module). Same for when in reverse, but rght_rev is asserted.
	
	assign PWM_frwrd_lft = w_lhb & ~lft_rev;		//Left side is driven forward when the PWM_sig from the left side of the Hbridge is high and 
	assign PWM_rev_lft =  w_lhb & lft_rev;			//we are not in reverse (determined from the input from this module). Same for when in reverse, but lft_rev is asserted.


endmodule
