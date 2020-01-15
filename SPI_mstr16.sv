module SPI_mstr16(clk, rst_n, MISO, MOSI, SCLK, SS_n, wrt, cmd, done, rd_data);
	
	input clk, rst_n;
	input wrt;
	input[15:0] cmd;
	output[15:0] rd_data;
	
	//A2D signals
	input logic MISO;
	output logic MOSI, SS_n, done, SCLK;
	
	logic[3:0] bit_count;	//used to count how many bits we have shifted
	logic[4:0] sclk_div;	//counter for clk to sclk conversion
	logic MISO_smpl;
	logic[15:0]  shft_reg;
	
	logic shft, smpl, rst_cnt, init, set_done, clr_done;
	
	typedef enum reg [1:0] {IDLE,START,GO,END} state_t;
	state_t state, nxt_state;	//current state and next state variables. Can have 4 states: IDLE, START, GO, or END
	

	always@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;

	end
	
	always_comb begin
  
		//set default next state to IDLE
		nxt_state = IDLE;
	
		//default outputs to 0
		rst_cnt = 1'b0;
		smpl = 1'b0;
		shft = 1'b0;
		set_done = 1'b0;
		clr_done = 1'b0;	

		case(state)
			IDLE: begin
				rst_cnt = 1'b1;	//always set this to 1 in IDLE state
				if(wrt) begin
					nxt_state = START;
					clr_done = 1'b1; end	//clear done asserted when transition to START
				else begin
					nxt_state = IDLE; end
			end
			START:
				if(sclk_div == 5'b11111)
					nxt_state = GO;
				else
					nxt_state = START;
					
			GO:
				//sample on positive edge of sclk
				if(sclk_div == 5'b01111) begin
					nxt_state = GO;
					smpl = 1'b1; end
				//move to backporch on the last bit
				else if(bit_count == 4'b1111 && sclk_div == 5'b11111) begin		//this has precedence over next condition
					nxt_state = END;
					rst_cnt = 1'b1; end
				//shift on negative edge of sclk
				else if(&sclk_div) begin
					nxt_state = GO;
					shft = 1'b1; end
				else
					nxt_state = GO;

			END:
				//when moving to IDLE state, assert rst_cnt so that SS_n stays high
				if(&sclk_div) begin
					nxt_state = IDLE;
					shft = 1'b1;
					set_done = 1'b1;
					rst_cnt = 1'b1; end
				else
					nxt_state = END;


		endcase
	end
	
	//assign init = &bit_count[3:1];
	
	//flip flop for SS_n
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			SS_n <= 1'b1;		//default is for SS_n to be high
		else if(clr_done)
			SS_n <= 1'b0;
		else if(set_done)
			SS_n <= 1'b1;		//only high when moving from backporch to IDLE
	end
	
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			done <= 1'b0;
		else if(clr_done)
			done <= 1'b0;
		else if(set_done)
			done <= 1'b1;	//only high when moving from IDLE to frontporch
	end
	
	//bit counter for counting how many bits we have shifted
	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			bit_count <= 4'h0;
		else if(shft)
			bit_count <= bit_count + 1'b1;
				
	//clk counter for generating sclk(1/32 of clk)
	always_ff@(posedge clk, negedge rst_n) 
		if(!rst_n)
			sclk_div <= 5'b00000;
		else if(rst_cnt)
			sclk_div <= 5'b10111;
		else
			sclk_div <= sclk_div + 1;

	//this is simply the highest bit of sclk_div. Changes every 16 clks
	assign SCLK = sclk_div[4];
	
	//
	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			MISO_smpl <= 1'b0;
		else if(smpl)
			MISO_smpl <= MISO;
	
	//shift MSB of cmd out and MISO into LSB of shft_reg
	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			shft_reg <= 0;
		else if(wrt)
			shft_reg <= cmd;
		else if(shft)
			shft_reg <= {shft_reg[14:0], MISO_smpl};
			
	assign MOSI = shft_reg[15];
	assign rd_data = shft_reg;	//this will only be meaningful when done is asserted.
	
endmodule  
  
