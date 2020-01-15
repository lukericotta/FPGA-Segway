module steer_en #(parameter fast_sim=0)
(clk, rst_n, ld_cell_diff, ld_cell_sum, en_steer, rider_off);

  localparam MIN_RIDER_WEIGHT = 12'h200;

  input clk;				// 50MHz clock
  input rst_n;				// Active low asynch reset
  input [11:0] ld_cell_diff, ld_cell_sum;
  //input tmr_full;			// asserted when timer reaches 1.3 sec
  //input sum_gt_min;			// asserted when left and right load cells together exceed min rider weight
  //input sum_lt_min;			// asserted when left_and right load cells are less than min_rider_weight

  /////////////////////////////////////////////////////////////////////////////
  // HEY BUDDY...you are a moron.  sum_gt_min would simply be ~sum_lt_min. Why
  // have both signals coming to this unit??  ANSWER: What if we had a rider
  // (a child) who's weigth was right at the threshold of MIN_RIDER_WEIGHT?
  // We would enable steering and then disable steering then enable it again,
  // ...  We would make that child crash(children are light and flexible and 
  // resilient so we don't care about them, but it might damage our Segway).
  // We can solve this issue by adding hysteresis.  So sum_gt_min is asserted
  // when the sum of the load cells exceeds MIN_RIDER_WEIGHT + HYSTERESIS and
  // sum_lt_min is asserted when the sum of the load cells is less than
  // MIN_RIDER_WEIGHT - HYSTERESIS.  Now we have noise rejection for a rider
  // who's wieght is right at the threshold.  This hysteresis trick is as old
  // as the hills, but very handy...remember it.
  //////////////////////////////////////////////////////////////////////////// 

  //input diff_gt_eigth;		// asserted if load cell difference exceeds 1/8 sum (rider not situated)
  //input diff_gt_15_16;		// asserted if load cell difference is great (rider stepping off)
  //output logic clr_tmr;			// clears the 1.3sec timer
  output logic en_steer;	// enables steering (goes to balance_cntrl)
  output logic rider_off;			// pulses high for one clock on transition back to initial state
  
  logic [25:0] counter;
  logic tmr_full, sum_gt_min, sum_lt_min, diff_gt_eigth, diff_gt_15_16, clr_tmr, sum_gt_min_ff, sum_lt_min_ff, diff_gt_eigth_ff, diff_gt_15_16_ff;
  // You fill out the rest...use good SM coding practices ///
  
  assign diff_gt_eigth = (ld_cell_diff > (ld_cell_sum/8)) ? 1'b1 : 1'b0;	// asserted if load cell difference exceeds 1/8 sum (rider not situated)
  assign diff_gt_15_16 = (ld_cell_diff > ((ld_cell_sum*15)/16)) ? 1'b1: 1'b0;		// asserted if load cell difference is great (rider stepping off)
  assign sum_gt_min = (ld_cell_sum > MIN_RIDER_WEIGHT) ? 1'b1 : 1'b0;			// asserted when left and right load cells together exceed min rider weight
  assign sum_lt_min = (ld_cell_sum < MIN_RIDER_WEIGHT) ? 1'b1 : 1'b0;			// asserted when left_and right load cells are less than min_rider_weight
  

  //using enumerated types here to make the code  more readable. There will be 3 states, but only two variables of type 'state_t'.
  typedef enum reg [1:0] {IDLE,WAIT,STEER_EN} state_t;
  state_t state, nxt_state;	//current state and next state variables. Can have 3 values: IDLE, WAIT, and STEER_EN

  always@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		state <= IDLE;
	else
		state <= nxt_state;

  end
  
  //flip flops to reduce critical path
  always@(posedge clk)
	sum_gt_min_ff <= sum_gt_min;
	
  always@(posedge clk)
	sum_lt_min_ff <= sum_lt_min;
	
  always@(posedge clk)
	diff_gt_15_16_ff <= diff_gt_15_16;
	
  always@(posedge clk)
	diff_gt_eigth_ff <= diff_gt_eigth;

  always_comb begin
  
	//set default next state to IDLE
	nxt_state = IDLE;
	
	//default outputs to 0
	en_steer = 1'b0;
	clr_tmr = 1'b0;
	rider_off = 1'b0;
	
	case(state)
		IDLE:
			if(sum_gt_min_ff) begin
				nxt_state = WAIT;
				clr_tmr = 1'b1;
				rider_off = 1'b0; end
			else begin
				nxt_state = IDLE;
				rider_off = 1'b1;
			end
		WAIT:
			if(sum_lt_min_ff) begin	//sum_lt_min replaces ~sum_gt_min
				nxt_state = IDLE;
				rider_off = 1'b1; end
			else if(diff_gt_eigth_ff) begin
				nxt_state = WAIT;
				clr_tmr = 1'b1; end
//			else if(!diff_gt_eigth_ff)			//This is covered in the else
//				nxt_state = WAIT;
			else if(tmr_full) begin
				en_steer = 1'b1;
				nxt_state = STEER_EN; end
			else
				nxt_state = WAIT;

		STEER_EN:
			if(sum_lt_min_ff) begin	//sum_lt_min replaces ~sum_gt_min
				nxt_state = IDLE;
				rider_off = 1'b1; end
			else if (diff_gt_15_16_ff) begin
				nxt_state = WAIT;
				clr_tmr = 1'b1;  end
//			else if(!diff_gt_15_16_ff) begin		//This is covered in the else
//				nxt_state = STEER_EN;
//				en_steer = 1'b1;
			else begin
				nxt_state = STEER_EN;	
				en_steer = 1'b1; end


	endcase
	
	
end

//make the timer
always@(posedge clk, negedge rst_n)
	if(!rst_n) begin
		counter <= 26'h0000000; end
	else if(clr_tmr) begin
		counter <= 26'h0000000; end
	else if(&counter) begin
		counter <= 26'h0000000; end
	else if(&counter[14:0] && fast_sim) begin
		counter <= 26'h0000000; end
	else begin
		counter <= counter + 1; end
		
always@(posedge clk, negedge rst_n)
	if(!rst_n) begin
		tmr_full <= 1'b0; end
	else if(clr_tmr) begin
		tmr_full <= 1'b0; end
	else if(&counter) begin
		tmr_full <= 1'b1;  end
	else if(&counter[14:0] && fast_sim) begin
		tmr_full <= 1'b1; end
	else begin
		tmr_full <= 1'b0; end
  
endmodule
