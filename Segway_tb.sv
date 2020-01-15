module Segway_tb();
			
//// Interconnects to DUT/support defined as type wire /////
wire SS_n,SCLK,MOSI,MISO,INT;				// to inertial sensor
wire A2D_SS_n,A2D_SCLK,A2D_MOSI,A2D_MISO;	// to A2D converter
wire RX_TX;
wire PWM_rev_rght, PWM_frwrd_rght, PWM_rev_lft, PWM_frwrd_lft;
wire piezo,piezo_n;

////// Stimulus is declared as type reg ///////
reg clk, RST_n;
reg [7:0] cmd;					// command host is sending to DUT
reg send_cmd;					// asserted to initiate sending of command
reg signed [15:0] rider_lean;	// forward/backward lean (goes to SegwayModel)
// Perhaps more needed?
reg [11:0] rght_ld_stim, lft_ld_stim, batt_stim;

/////// declare any internal signals needed at this level //////
wire cmd_sent;
// Perhaps more needed?


////////////////////////////////////////////////////////////////
// Instantiate Physical Model of Segway with Inertial sensor //
//////////////////////////////////////////////////////////////	
SegwayModel iPHYS(.clk(clk),.RST_n(RST_n),.SS_n(SS_n),.SCLK(SCLK),
                  .MISO(MISO),.MOSI(MOSI),.INT(INT),.PWM_rev_rght(PWM_rev_rght),
				  .PWM_frwrd_rght(PWM_frwrd_rght),.PWM_rev_lft(PWM_rev_lft),
				  .PWM_frwrd_lft(PWM_frwrd_lft),.rider_lean(rider_lean));
				  
  //**************************************************************************
/////////////////////////////////////////////////////////
// Instantiate Model of A2D for load cell and battery //
///////////////////////////////////////////////////////
//  What is this?  You need to build some kind of wrapper around ADC128S.sv or perhaps
//  around SPI_ADC128S.sv that mimics the behavior of the A2D converter on the DE0 used
//  to read ld_cell_lft, ld_cell_rght and battery
  //******************************************************************************
ADC128S iADC(.clk(clk), .rst_n(RST_n), .SS_n(A2D_SS_n), .SCLK(A2D_SCLK), .MISO(A2D_MISO), .MOSI(A2D_MOSI), .rght_ld(rght_ld_stim), .lft_ld(lft_ld_stim), .batt(batt_stim));


////// Instantiate DUT ////////
Segway iDUT(.clk(clk),.RST_n(RST_n),.LED(),.INERT_SS_n(SS_n),.INERT_MOSI(MOSI),
            .INERT_SCLK(SCLK),.INERT_MISO(MISO),.A2D_SS_n(A2D_SS_n),
			.A2D_MOSI(A2D_MOSI),.A2D_SCLK(A2D_SCLK),.A2D_MISO(A2D_MISO),
			.INT(INT),.PWM_rev_rght(PWM_rev_rght),.PWM_frwrd_rght(PWM_frwrd_rght),
			.PWM_rev_lft(PWM_rev_lft),.PWM_frwrd_lft(PWM_frwrd_lft),
			.piezo_n(piezo_n),.piezo(piezo),.RX(RX_TX));


	
//// Instantiate UART_tx (mimics command from BLE module) //////
//// You need something to send the 'g' for go ////////////////
UART_tx iTX(.clk(clk),.rst_n(RST_n),.TX(RX_TX),.trmt(send_cmd),.tx_data(cmd),.tx_done(cmd_sent));



///////outputs//////
//piezo_n
//piezo
//cmd_sent

///////inputs//////
//clk
//RST_n
//rider_lean
//send_cmd
//cmd

integer count, count_all;

initial begin
  //Initialize;		// perhaps you make a task that initializes everything?  
  ////// Start issuing commands to DUT //////


  //STIMULUS TO PRODUCE WAVEFORM/////////

  clk = 1'b0;
  RST_n = 1'b0;
  rider_lean = 16'h0000;
  send_cmd = 1'b0;
  cmd = 8'h00;
  repeat(2) @(posedge clk);
  @(negedge clk);
  RST_n = 1'b1;
  

  @(posedge clk);

  send_cmd = 1'b1;
  cmd = 8'h67;
  @(posedge cmd_sent);
  send_cmd = 1'b0;
 /* repeat(100000) @(posedge clk);
  rider_lean = 16'h1fff;
  repeat(1000000) @(posedge clk);
  rider_lean = 16'h0000;
  repeat(1000000) @(posedge clk);
*/
  
  count = 0;
  count_all = 0;

  //*******************************************************
    //.
	//.	// this is the "guts" of your test
	//.
  //*******************************************************
  
///////////////////////////////////////////////////////////////////////////////////
//TESTS 1 THROUGH 4 test SIGNALS GOING TO PIEZO (en_steer, batt_low, and ovr_spd)//
///////////////////////////////////////////////////////////////////////////////////
  /////////////1//////////////////////
  //test battery high signal
  send_cmd = 1'b1;
  cmd = 8'h67;
  @(posedge clk);
  send_cmd = 1'b0;
  lft_ld_stim = 12'h250;
  rght_ld_stim = 12'h250;
  rider_lean = 16'h00AA;
  
  batt_stim = 12'h810;
  count_all = count_all + 1;
  repeat(100000) @(posedge clk);
  if(!iDUT.pDUT.batt_low) begin		
	$display("%d passed", count_all); count = count + 1; end

//test battery low signal
 ////////////////2////////////////////
  batt_stim = 12'h755;
  count_all = count_all + 1;
  repeat(100000) @(posedge clk);
  if(iDUT.pDUT.batt_low) begin		
	$display("%d passed", count_all); count = count + 1; end


  ///////////////3////////////////// should be moving (straight)
  lft_ld_stim = 12'h250;
  rght_ld_stim = 12'h250;
  rider_lean = 16'h00AA;
  count_all = count_all + 1;
  repeat(100000) @(posedge clk);
  if(iDUT.pDUT.en_steer) begin		//should be high
	$display("%d passed", count_all); count = count + 1; end
  
 ///////////////4////////////////// should be moving too fast
  lft_ld_stim = 12'h201;
  rght_ld_stim = 12'h201;
  rider_lean = 16'h1FFe;
  count_all = count_all + 1;
  repeat(100000) @(posedge clk);		//make sure ths wait is LOW enough
  if(iDUT.pDUT.ovr_spd) begin		//should be high
	$display("%d passed", count_all); count = count + 1; end
  

  
  
  
  
///////////////////////////////////////////////////////////////////////////////////
//TESTS 5 THROUGH 10 test the convergence of theta, omega, and net torque//
///////////////////////////////////////////////////////////////////////////////////
  /////////////////////5///////////////////////
  //theta_platform: (angle of platform is integral of angular velocity)
  lft_ld_stim = $urandom % 4096;
  rght_ld_stim = $urandom %4096;
  rider_lean = 16'h1fff;
  count_all = count_all + 1;
  repeat(500000) @(posedge clk);
  if(iPHYS.theta_platform < 3000 && iPHYS.theta_platform > -3000) begin
	$display("%d passed", count_all); count = count + 1; end
  
  
  /////////////////////6////////////////////
  //theta_platform: (angle of platform is integral of angular velocity)
  lft_ld_stim = $urandom % 4096;
  rght_ld_stim = $urandom %4096;
  rider_lean = 16'h0000;
  count_all = count_all + 1;
  repeat(500000) @(posedge clk);
  if(iPHYS.theta_platform > -3000 && iPHYS.theta_platform < 3000) begin
	$display("%d passed", count_all); count = count + 1; end



  //////////////////7////////////////////////////
  //omega_platform (anglular velocity of platform is integral of net_torque)
  lft_ld_stim = $urandom % 4096;
  rght_ld_stim = $urandom %4096;
  rider_lean = 16'h1fff;
  count_all = count_all + 1;
  repeat(500000) @(posedge clk);
  if(iPHYS.omega_platform > -3000 && iPHYS.omega_platform < 3000) begin
	$display("%d passed", count_all); count = count + 1; end
  
  
  //////////////////8////////////////////////////
  //omega_platform (anglular velocity of platform is integral of net_torque)
  lft_ld_stim = $urandom % 4096;
  rght_ld_stim = $urandom %4096;
  rider_lean = 16'h0000;
  count_all = count_all + 1;
  repeat(500000) @(posedge clk);
  if(iPHYS.omega_platform > -3000 && iPHYS.omega_platform < 3000) begin
	$display("%d passed", count_all); count = count + 1; end
    
  

  
  ////////////////////////9/////////////////////
  // 	net_torque = net torque on platform = rider_lean -  torque_lft - torque_rght.
  lft_ld_stim = $urandom % 4096;
  rght_ld_stim = $urandom %4096;
  rider_lean = 16'h1fff;
  count_all = count_all + 1;
  repeat(500000) @(posedge clk);
  if(iPHYS.net_torque > -3000 && iPHYS.net_torque < 3000) begin
	$display("%d passed", count_all); count = count + 1; end
    
  ////////////////////////10/////////////////////
  // 	net_torque = net torque on platform = rider_lean -  torque_lft - torque_rght.
  lft_ld_stim = $urandom % 4096;
  rght_ld_stim = $urandom %4096;
  rider_lean = 16'h0000;
  count_all = count_all + 1;
  repeat(500000) @(posedge clk);
  if(iPHYS.net_torque > -3000 && iPHYS.net_torque < 3000) begin
	$display("%d passed", count_all); count = count + 1; end
  
  

///////////////////////////////////////////////////////////////////////////////////
//TESTS 11 THROUGH 12 test the rider_off signal//
///////////////////////////////////////////////////////////////////////////////////
  ////////////////////////11/////////////////////
  //rider_off should be asserted
  lft_ld_stim = 12'h000;
  rght_ld_stim = 12'h000;
  count_all = count_all + 1;
  repeat(1000000) @(posedge clk);
  if(iDUT.rider_off) begin
	$display("%d passed", count_all); count = count + 1; end

  ////////////////////////12/////////////////////
  //rider_off should not be asserted
  lft_ld_stim = 12'h201;
  rght_ld_stim = 12'h201;
  count_all = count_all + 1;
  repeat(1000000) @(posedge clk);
  if(!iDUT.rider_off) begin
	$display("%d passed", count_all); count = count + 1; end


///////////////////////////////////////////////////////////////////////////////////
//TESTS 13 THROUGH 14 test the Auth_blk communication block//
///////////////////////////////////////////////////////////////////////////////////

  ////////////////////////13/////////////////////
  send_cmd = 1'b1;
  cmd = 8'h67;
  @(posedge cmd_sent);
  send_cmd = 1'b0;
  count_all = count_all + 1;
//Should be in PWR1, so powered on.
  if(iDUT.pwr_up) begin
	$display("%d passed", count_all); count = count + 1; end
  

////////////////////////14/////////////////////
  send_cmd = 1'b1;
  cmd = 8'h73;
  @(posedge cmd_sent);
  send_cmd = 1'b0;
  count_all = count_all + 1;
//Should be in PWR2, so still powered on.
  if(iDUT.pwr_up) begin
	$display("%d passed", count_all); count = count + 1; end


////////////////////////15/////////////////////
  lft_ld_stim = 12'h001;
  rght_ld_stim = 12'h001;
  send_cmd = 1'b1;
  cmd = 8'h73;
  @(posedge cmd_sent);
  send_cmd = 1'b0;
  count_all = count_all + 1;
//Should be in IDLE because rider_off should be asserted and the stop bit is asserted
  if(!iDUT.pwr_up) begin
	$display("%d passed", count_all); count = count + 1; end

/////////////////////////////////////////////////////////
////////////////////TEST 16//////////////////////////////
//Move back to PWR1 state and rerun tests 5 through 10//
///////////////while rider_lean is negative (16'h2000)//
////////////////////////////////////////////////////////
  send_cmd = 1'b1;
  cmd = 8'h67;
  @(posedge cmd_sent);
  send_cmd = 1'b0;
  count_all = count_all + 1;
  lft_ld_stim = 12'h250;
  rght_ld_stim = 12'h250;
  rider_lean = 16'h2000;
  repeat(1000000) @(posedge clk);
//now should be in PWR1, and theta_platform, omega_platform, and net_torque should all converge
  if(iDUT.pwr_up && !iDUT.rider_off && (iPHYS.net_torque > -3000 && iPHYS.net_torque < 3000) && (iPHYS.omega_platform > -3000 && iPHYS.omega_platform < 3000) && (iPHYS.theta_platform > -3000 && iPHYS.theta_platform < 3000)) begin
	$display("%d passed", count_all); count = count + 1; end
	


  
  $display("%d/%d", count, count_all);
  
  $stop();
end


always
  #10 clk = ~clk;

`include "tb_tasks.v"	// perhaps you have a separate included file that has handy tasks.

endmodule	
