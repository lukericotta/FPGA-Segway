module balance_cntrl #(parameter fast_sim=0)(clk,rst_n,vld,ptch,ld_cell_diff,lft_spd,lft_rev,
                     rght_spd,rght_rev,rider_off, en_steer, pwr_up, too_fast);
								
  input clk,rst_n;
  input vld;						// tells when a new valid inertial reading ready
  input signed [15:0] ptch;			// actual pitch measured
  input signed [11:0] ld_cell_diff;	// lft_ld - rght_ld from steer_en block
  input rider_off;					// High when weight on load cells indicates no rider
  input en_steer;
  output [10:0] lft_spd;			// 11-bit unsigned speed at which to run left motor
  output lft_rev;					// direction to run left motor (1==>reverse)
  output [10:0] rght_spd;			// 11-bit unsigned speed at which to run right motor
  output rght_rev;					// direction to run right motor (1==>reverse)
  input pwr_up;
  output too_fast;
  
    /////////////////////////////////////////////
  // local params for increased flexibility //
  ///////////////////////////////////////////
  localparam P_COEFF = 5'h0E;
  localparam D_COEFF = 6'h14;				// D coefficient in PID control = +20 
    
  localparam LOW_TORQUE_BAND = 8'h46;	// LOW_TORQUE_BAND = 5*P_COEFF
  localparam GAIN_MULTIPLIER = 6'h0F;	// GAIN_MULTIPLIER = 1 + (MIN_DUTY/LOW_TORQUE_BAND)
  localparam MIN_DUTY = 15'h03D4;		// minimum duty cycle (stiffen motor and get it ready)
  
  
  ////////////////////////////////////
  // Define needed registers below //
  //////////////////////////////////

  
  ///////////////////////////////////////////
  // Define needed internal signals below //
  /////////////////////////////////////////
  
  
//  logic signed [12:0] ptch_PID; // should be 1-bit wider than widest term added
//  logic [11:0] ptch_PID_abs; // when take ABS you need one less bit.
	logic signed [9:0] ptch_err_sat, ptch_err_sat_ff;
  
  //Pterm signals

	logic signed [14:0] ptch_P_term, ptch_P_term_ff; // ¾ takes same number of bits]


	//Iterm signals
	logic signed [17:0] integrator, I_prev;
	logic OV;
	logic signed [15:0] ptch_I_term; // since we >>> it requires one less bit
  
  //Dterm signals
	logic signed [12:0] ptch_D_term, ptch_D_term_ff; // 7 + 5 = 12-bits needed	
	logic signed [9:0] FF1, prev_ptch_err, ptch_D_diff;
	logic signed [6:0] ptch_D_diff_sat;
	
	
	//PID signals
	logic signed [15:0] ld_cell_diff_extended;
	logic signed [15:0] PID_cntrl;			// WILL THIS BE BIG ENOUGH TO AVOID OVERFLOW
	logic signed [15:0] lft_torque, rght_torque, lft_torque_ff, rght_torque_ff;
	
	
	
	
	//Toque to Duty signals
	logic signed [15:0] lft_shaped, rght_shaped, lft_shaped_ff, rght_shaped_ff;
	logic [15:0] lft_shaped_abs, rght_shaped_abs;
	logic [15:0] lft_torque_abs, rght_torque_abs;
	
	
	//flip flops to reduce critical path
	always@(posedge clk)
		ptch_P_term_ff <= ptch_P_term;
	
	always@(posedge clk)
		ptch_D_term_ff <= ptch_D_term;
  
	always@(posedge clk)
		lft_shaped_ff <= lft_shaped;
		
	always@(posedge clk)
		rght_shaped_ff <= rght_shaped;
  
	always@(posedge clk)
		rght_torque_ff <= rght_torque;
		
	always@(posedge clk)
		lft_torque_ff <= lft_torque;
  
	always@(posedge clk)
		ptch_err_sat_ff <= ptch_err_sat;
  
  //Pterm math
  assign ptch_err_sat = (ptch[15] && ~&ptch[14:9]) ? 10'h200 : // most –
	(~ptch[15] && | ptch[14:9]) ? 10'h1FF : // most +
	ptch[9:0];
  
  assign ptch_P_term = ptch_err_sat_ff * $signed(P_COEFF);
  
  assign OV = (ptch_err_sat_ff[9] & integrator[17] & ~I_prev[17]) ? (1'b1) :
				(~ptch_err_sat_ff[9] & ~integrator[17] & I_prev[17]) ? (1'b1): (1'b0);
  
  assign I_prev = integrator + {{8{ptch_err_sat_ff[9]}},ptch_err_sat_ff};
  
	//Iterm math
  always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		integrator	<= 18'h00000;
	else if(~pwr_up)
		integrator	<= 18'h00000;
	else if(rider_off)
		integrator <= 18'h00000;
	else if(vld && !OV)
		integrator <=  I_prev;
	else
		integrator <= integrator;
  
  end
  
  assign ptch_I_term = (fast_sim) ? integrator[17:2] : {{4{integrator[17]}},integrator[17:6]};
  
  //Dterm math
  
  //FF1
  always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		FF1 <= 10'h000;
	else if(vld)
		FF1 <= ptch_err_sat_ff;
	else
		FF1 <= FF1;
  
  end
  
  //FF2
  always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		prev_ptch_err <= 10'h000;
	else if(vld)
		prev_ptch_err <= FF1;
	else
		prev_ptch_err <= prev_ptch_err;
  
  
  end
  
  assign ptch_D_diff = ptch_err_sat_ff - prev_ptch_err;
  assign ptch_D_diff_sat =  (ptch_D_diff[9] && ~&ptch_D_diff[8:6]) ? 7'h40 : // most –
	(~ptch_D_diff[9] && | ptch_D_diff[8:6]) ? 7'h3F : // most +
	ptch_D_diff[6:0];
  assign ptch_D_term = $signed(D_COEFF) * ptch_D_diff_sat;
  
  
  
  
  
  //PID MATH
  assign ld_cell_diff_extended = {{8{ld_cell_diff[11]}}, ld_cell_diff[11:3]};
  assign PID_cntrl = {{3{ptch_D_term_ff[12]}},ptch_D_term_ff} + ptch_I_term + {ptch_P_term_ff[14],ptch_P_term_ff};
  
  assign lft_torque = en_steer ? (PID_cntrl - ld_cell_diff_extended) : (PID_cntrl);
  assign rght_torque = en_steer ? (PID_cntrl + ld_cell_diff_extended) : (PID_cntrl);
  
  
  
  assign lft_torque_abs = lft_torque_ff[15] ? (~lft_torque_ff + 1) : (lft_torque_ff);
  assign rght_torque_abs = rght_torque_ff[15] ? (~rght_torque_ff + 1) : (rght_torque_ff);
  
  
  
  //Torque to Duty MATH
  assign lft_shaped = (lft_torque_abs >= LOW_TORQUE_BAND) ? ( lft_torque_ff[15] ? (lft_torque_ff - $signed(MIN_DUTY)) : (lft_torque_ff + $signed(MIN_DUTY))) : ($signed(GAIN_MULTIPLIER) * lft_torque_ff);
  assign lft_shaped_abs = lft_shaped_ff[15] ? (~lft_shaped_ff + 1) : (lft_shaped_ff);
  assign lft_spd = pwr_up ? ((|lft_shaped_abs[15:11]) ? 11'h7FF : lft_shaped_abs[10:0]) : 11'h000; // most +
  assign lft_rev = lft_shaped_ff[15];
  
  
  
  assign rght_shaped = (rght_torque_abs >= LOW_TORQUE_BAND) ? ( rght_torque_ff[15] ? (rght_torque_ff - $signed(MIN_DUTY)) : (rght_torque_ff + $signed(MIN_DUTY))) : ($signed(GAIN_MULTIPLIER) * rght_torque_ff);
  assign rght_shaped_abs = rght_shaped_ff[15] ? (~rght_shaped_ff + 1) : (rght_shaped_ff);
  assign rght_spd = pwr_up ? ((|rght_shaped_abs[15:11]) ? (11'h7FF) : (rght_shaped_abs[10:0])) : 11'h000;	// most +
  assign rght_rev = rght_shaped_ff[15];
  
  
  //asserted if lft_spd or rght_spd is greater than 1536 (too fast)
  assign too_fast = (rght_spd > 11'h600 || lft_spd > 11'h600) ? (1'b1) : (1'b0);
  
  
  

  //// You fill in the rest ////
  
endmodule
