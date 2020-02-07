module Segway(clk,RST_n,LED,INERT_SS_n,INERT_MOSI,
              INERT_SCLK,INERT_MISO,A2D_SS_n,A2D_MOSI,A2D_SCLK,
			  A2D_MISO,PWM_rev_rght,PWM_frwrd_rght,PWM_rev_lft,
			  PWM_frwrd_lft,piezo_n,piezo,INT,RX);
			  
  input clk,RST_n;
  input INERT_MISO;						// Serial in from inertial sensor
  input A2D_MISO;						// Serial in from A2D
  input INT;							// Interrupt from inertial indicating data ready
  input RX;								// UART input from BLE module

  
  output [7:0] LED;						// These are the 8 LEDs on the DE0, your choice what to do
  output A2D_SS_n, INERT_SS_n;			// Slave selects to A2D and inertial sensor
  output A2D_MOSI, INERT_MOSI;			// MOSI signals to A2D and inertial sensor
  output A2D_SCLK, INERT_SCLK;			// SCLK signals to A2D and inertial sensor
  output PWM_rev_rght, PWM_frwrd_rght;  // right motor speed controls
  output PWM_rev_lft, PWM_frwrd_lft;	// left motor speed controls
  output piezo_n,piezo;					// diff drive to piezo for sound
  
  ////////////////////////////////////////////////////////////////////////
  // fast_sim is asserted to speed up fullchip simulations.  Should be //
  // passed to both balance_cntrl and to steer_en.  Should be set to  //
  // 0 when we map to the DE0-Nano.                                  //
  ////////////////////////////////////////////////////////////////////
  localparam fast_sim = 1;	// asserted to speed up simulations. 
//  localparam MIN_RIDER_WEIGHT = 12'h200;
  ///////////////////////////////////////////////////////////
  ////// Internal interconnecting sigals defined here //////
  /////////////////////////////////////////////////////////
  wire rst_n;                           // internal global reset that goes to all units
  
  // You will need to declare a bunch more interanl signals to hook up everything
  wire vld;
  wire [15:0] ptch;
  wire [11:0] ld_cell_diff;
  wire [11:0] ld_cell_diffx, ld_cell_sum;
  wire nxt;	//WHERE DOES THIS COME FROM
 // wire diff_gt_eigth, diff_gt_15_16, sum_lt_min, sum_gt_min, tmr_full, clr_tmr, too_fast;		// !!!???WHHERE ARE THES COMING FROM/GOING TO!!!??? ---- clr_tmr, too_fast, tmr_full
  wire too_fast;
  wire en_steer, rider_off, pwr_up;
  wire [11:0] lft_ld, rght_ld, batt;
  wire [10:0] lft_spd, rght_spd;
  wire lft_rev, rght_rev;
  
  wire batt_low;		//battery low signal
  reg batt_low_ff;
  
  assign LED = 8'h55;
  
  assign batt_low = (batt < 12'h800) ? 1'b1 : 1'b0;
  assign nxt = vld; 	//
  
  /////////////////////////////////////////
  assign ld_cell_diffx = lft_ld - rght_ld;
  assign ld_cell_diff = (ld_cell_diffx < 0) ? -ld_cell_diffx : ld_cell_diffx;
  assign ld_cell_sum = lft_ld + rght_ld;
//  

  //flip flops to reduce critical path
  always@(posedge clk)
	batt_low_ff <= batt_low;

//////////////////////////MAKE THESE INTERNAL TO STEER_EN
//  assign diff_gt_eigth = (ld_cell_diff > (ld_cell_sum/8)) ? 1'b1 : 1'b0;	// asserted if load cell difference exceeds 1/8 sum (rider not situated)
//  assign diff_gt_15_16 = (ld_cell_diff > (ld_cell_sum*15/16)) ? 1'b1: 1'b0;		// asserted if load cell difference is great (rider stepping off)
//  assign sum_gt_min = (ld_cell_sum > MIN_RIDER_WEIGHT) ? 1'b1 : 1'b0;			// asserted when left and right load cells together exceed min rider weight
//  assign sum_lt_min = (ld_cell_sum < MIN_RIDER_WEIGHT) ? 1'b1 : 1'b0;			// asserted when left_and right load cells are less than min_rider_weight
  ////////////////////////////////////
   
  
  ///////////////////////////////////////////////////////
  // How you arrange the hierarchy of the top level is up to you.
  //
  // You could make a level of hierarchy called digital core
  // as shown in the block diagram in the spec.
  //
  // Or you could just instantiate all the components of the Segway
  // flat.
  //
  // Just for reference all the needed blocks (in no particular order) would be:
  //   Auth_blk
  Auth_blk abDUT(.clk(clk), .rst_n(rst_n), .RX(RX), .rider_off(rider_off), .pwr_up(pwr_up));

  //   A2D_intf
  A2D_Intf A2DiDUT(.clk(clk), .rst_n(rst_n), .nxt(nxt), .lft_ld(lft_ld), .rght_ld(rght_ld), .batt(batt),
					.MISO(A2D_MISO), .MOSI(A2D_MOSI), .SCLK(A2D_SCLK), .SS_n(A2D_SS_n));
  /////////////////////////////DIGITAL CORE///////////////////////////////
  //   inert_intf
  inert_intf iiDUT(.clk(clk), .rst_n(rst_n), .vld(vld), .ptch(ptch), .SS_n(INERT_SS_n), .SCLK(INERT_SCLK), .MOSI(INERT_MOSI), .MISO(INERT_MISO), .INT(INT));
  
  //	steer_en
  steer_en #(fast_sim) sesDUT(.clk(clk), .rst_n(rst_n), .ld_cell_diff(ld_cell_diff), .ld_cell_sum(ld_cell_sum), .en_steer(en_steer), .rider_off(rider_off));
  
  //   balance_cntrl
  balance_cntrl #(fast_sim) bcDUT(.clk(clk), .rst_n(rst_n), .vld(vld), .ptch(ptch), .ld_cell_diff(ld_cell_diff),
						.lft_spd(lft_spd), .lft_rev(lft_rev), .rght_spd(rght_spd), .rght_rev(rght_rev),
							.rider_off(rider_off), .en_steer(en_steer), .pwr_up(pwr_up), .too_fast(too_fast));
												
//////////////////////////////////////////////////////////////////////						
							
  //   mtr_drv
  mtr_drv mdDUT(.clk(clk), .rst_n(rst_n), .lft_spd(lft_spd), .lft_rev(lft_rev),.PWM_rev_lft(PWM_rev_lft),
				.PWM_frwrd_lft(PWM_frwrd_lft), .rght_spd(rght_spd), .rght_rev(rght_rev), .PWM_rev_rght(PWM_rev_rght), .PWM_frwrd_rght(PWM_frwrd_rght));

  
 
  //   piezo
  piezo pDUT(.clk(clk), .rst_n(rst_n), .batt_low(batt_low_ff), .ovr_spd(too_fast), .en_steer(en_steer), .piezo(piezo), .piezo_n(piezo_n));
  
  
  //////////////////////////////////////////////////////
  

  /////////////////////////////////////
  // Instantiate reset synchronizer //
  ///////////////////////////////////  
  rst_synch iRST(.clk(clk),.RST_n(RST_n),.rst_n(rst_n));
  
endmodule
