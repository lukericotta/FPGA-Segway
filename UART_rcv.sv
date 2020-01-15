module UART_rcv(
	input clk,
	input rst_n,
	input RX,
	input clr_rdy,
	output logic [7:0] rx_data,
	output logic rdy);
	
	logic RX_meta, RX_safe;				//RX regsiters used for metastability
	logic [11:0] baud_cnt, input_shift;	//input_shift used to determine what the baud_count should be: 2604 or 1302
	logic [8:0] rx_shft_reg;
	logic [3:0] bit_cnt;
	logic shift, start, receiving, set_rdy; //outputs of state machine

	
	typedef enum reg [1:0] {IDLE,RECEIVE} state_t;
	state_t state, nxt_state;
	
	//This is the shifter to shift what bit to receive
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			rx_shft_reg <= 9'h1FF;
		else if(shift) begin
			rx_shft_reg <= {RX_safe, rx_shft_reg[8:1]};
		end
		
	end
	
	assign rx_data = rx_shft_reg[7:0];	//in the end, rx_shft_reg[7:0] = tx_data
	
	//need this for metastability
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			RX_safe <= 0;
		else begin
			RX_meta <= RX;
			RX_safe <= RX_meta; end
	end

	//This section will  count the bits received. Only counts when shift is asserted, otherwise it maintains its value
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			bit_cnt <= 4'h0;
		else if(start)
			bit_cnt <= 4'h0;
		else if(shift)
			bit_cnt <= bit_cnt + 1;
	

	end

	assign input_shift = start ? (1302) : (2604);		//choose 
	
	//The baud count will count down to 0 from 2604 (or 1302) and then assert shift (Combinational logic below)
	//The bit count will count up once 0 is reached. Bit_count will count up until the full byte is received
	always_ff@(posedge clk, negedge rst_n) begin
		
		if(!rst_n)
			baud_cnt <= input_shift;		
		else if(start | shift)
			baud_cnt <= input_shift;
		else if(receiving)
			baud_cnt <= baud_cnt - 1;		

	end


	always@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state <= IDLE;
		else
			state <= nxt_state;

	end

	//This is where we assign shift. Only gets asserted 1 out of every 2604 clock cycles.
	assign shift = (baud_cnt == 12'h000) ? (1'b1) : (1'b0);
	
	always_comb begin
		//default state
		nxt_state = IDLE;

		//default outputs
		start = 0;
		receiving = 1;
		set_rdy = 1;
		
		case(state)
			IDLE:
				if(~RX_safe) begin
					nxt_state = RECEIVE;
					start = 1;			//when moving to the RECEIVE state, we want to start receiving the data
					receiving = 1;	//now that we will be in the receive state, we assert receiving
					set_rdy = 0;		//we are not done, so set_done is deasserted
					//clr_rdy = 1;
					end	//clr_done is asserted to clear the data.
				else
					nxt_state = IDLE;

			
			RECEIVE:
				if(bit_cnt == 4'b1010) begin
					nxt_state = IDLE;
					start = 0;			//when moving out of the receive state, we are no longer reading so we deassert start.
					receiving = 0;	//now that we will be in the IDLE state, we are no longer receving so we deassert the signal
					set_rdy = 1;		//we are ready so we set ready
					end
				else begin
					nxt_state = RECEIVE;
					start = 0;			//This must be deasserted, otherwise the counters will be stuck at 0
					set_rdy = 0;
					receiving = 1;
				end
				
		endcase
		

	
	end

	always_ff@(posedge clk, negedge rst_n) begin

		if(!rst_n)
			rdy <= 0;		//deasserted on reset
		else if(clr_rdy | start)
			rdy <= 0;		//deassrted when in the TRANSMIT state
		else if(set_rdy)
			rdy <= 1;		//asserted only when moving from TRANMIT to IDLE state (when set_done is asserted)
	
	end

endmodule
