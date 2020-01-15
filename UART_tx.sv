module UART_tx(
	input clk,
	input rst_n,
	input trmt,
	input [7:0] tx_data,
	output logic TX,
	output logic tx_done);
	
	logic [11:0] baud_cnt;
	logic [8:0] tx_shft_reg;
	logic [3:0] bit_cnt;
	logic shift, load, transmitting, set_done, clr_done;

	
	typedef enum reg [1:0] {IDLE,TRANSMIT} state_t;
	state_t state, nxt_state;
	
	//This is the shifter to shift what bit to send. TX is assigned to the LSB of the shift register in combinational below
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			tx_shft_reg <= 9'h1FF;
		else if(load)
			tx_shft_reg <= {tx_data,1'b0};
		else if(shift)
			tx_shft_reg <= {1'b1, tx_shft_reg[8:1]};
		
	end

	assign TX = tx_shft_reg[0];

	//This section will  count the bits sent. Only counts when shift is asserted, otherwise it maintains its value
	always_ff@(posedge clk, negedge rst_n) begin
	
		if(!rst_n)
			bit_cnt <= 4'h0;
		if(load)
			bit_cnt <= 4'h0;
		else if(shift)
			bit_cnt <= bit_cnt + 1;
	

	end

	//The baud count will count until 2604 and then assert shift (Combinational logic below)
	//The bit count will count up once 2604 is reached. Bit_count will count up until the full byte is sent
	always_ff@(posedge clk, negedge rst_n) begin
		
		if(!rst_n)
			baud_cnt <= 12'h000;		
		else if(load | shift)
			baud_cnt <= 12'h000;
		else if(transmitting)
			baud_cnt <= baud_cnt + 1;			

	end


	always@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;

	end

	//This is where we assign shift. Only gets asserted 1 out of every 2604 clock cycles.
	assign shift = (baud_cnt == 12'hA2C) ? (1'b1) : (1'b0);
	
	always_comb begin
		//default state
		nxt_state = IDLE;
		
		//default outputs
		load = 0;
		transmitting = 1;
		set_done = 1;
		clr_done = 1;
				
		//two states. IDLE and TRANSMIT
		case(state)
			IDLE:
				if(trmt) begin
					nxt_state = TRANSMIT;
					load = 1;			//when moving to the TRANSMIT state, we want to load the data
					transmitting = 1;	//now that we will be in the transmit state, we assert transmitting
					set_done = 0;		//we are not done, so set_done is deasserted
					clr_done = 1; end	//clr_done is asserted to clear the data.
				else
					nxt_state = IDLE;

			
			TRANSMIT:
				if(bit_cnt == 4'b1010) begin
					nxt_state = IDLE;
					load = 0;			//when mvoing out of the transmit state, we are no longer loading so we deassert load.
					transmitting = 0;	//now that we will be in the IDLE state, we are no longer transmitting so we deassert the signal
					set_done = 1;		//we are done so we set_done
					clr_done = 0; end
				else begin
					nxt_state = TRANSMIT;
					load = 0;			//This must be deasserted, otherwise the counters will be stuck at 0
					clr_done = 0;
					set_done = 0;
				end
				
			endcase
	
	end

	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			tx_done <= 0;		//deasserted on reset
		else if(clr_done) // || (~clr_done & ~set_done))
			tx_done <= 0;		//deassrted when in the TRANSMIT state
		else if(set_done)
			tx_done <= 1;		//asserted only when moving from TRANMIT to IDLE state (when set_done is asserted)
			
	
	end

endmodule
