module A2D_Intf(clk, rst_n, nxt, lft_ld, rght_ld, batt, MISO, MOSI, SCLK, SS_n);

	//in and outs to a2d
	input clk, rst_n, nxt;
	output logic [11:0] lft_ld;
	output logic [11:0] rght_ld;
	output logic [11:0] batt;
	
	//in and out passed directly to and from SPI_mstr
	input MISO;
	output logic MOSI, SCLK, SS_n;
	
	//outputs from state machine to SPI_mstr
	logic wrt, update;
	
	//input to state maachine from SPI_mstr
	logic done;
	
	//input to spi_mstr from combinational logic
	logic[15:0] cmd, cmd_ff;
	
	//input to flip flops from combinational logic
	logic enL, enR, enB;
	
	//output from spi_mstr to A2D output flipflops
	logic[15:0] rd_data;
	
	//round robin counter (count to 2'b10)
	logic[1:0] counter;
	
	SPI_mstr16 spi(.clk(clk), .rst_n(rst_n), .MISO(MISO), .MOSI(MOSI), .SCLK(SCLK),
					.SS_n(SS_n), .wrt(wrt), .cmd(cmd_ff), .done(done), .rd_data(rd_data));
	
	
	typedef enum reg[1:0]{IDLE, CHANNEL_CONVERT, DEAD_CLK, READ_RESULT} state_t;
		state_t state, nxt_state;
		
	always@(posedge clk)
		cmd_ff <= cmd;
	
	always_ff@(posedge clk, negedge rst_n) begin
		if(!rst_n)
			state<=IDLE;
		else
			state<=nxt_state;
	end

	
	always_comb begin

		nxt_state = IDLE;
		wrt = 1'b0;
		update = 1'b0;
	
		case(state)
			IDLE:
				if(nxt) begin
					wrt =1'b1;
					nxt_state = CHANNEL_CONVERT; end
					
			CHANNEL_CONVERT:
				//when done, go to dead clock and then read result state
				if(done)
					nxt_state = DEAD_CLK;
				else
					nxt_state = CHANNEL_CONVERT;
			//no muxes in the dead clock state. just staying here for one clokc cycle
			DEAD_CLK: begin
				wrt = 1'b1;
				nxt_state = READ_RESULT;
				end
			READ_RESULT:
				//wait for another done signal to finish cycle through the state machine
				if(done) begin
					nxt_state = IDLE;
					update = 1'b1; end
				else
					nxt_state = READ_RESULT;
			
		endcase



	end

	
	
	//counter that counts to 2'b10: 2'b00, 2'b01, 2'b10, 2'b00.....
	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			counter <= 2'b00;
		else if(counter[1] && update)
			counter <= 2'b00;
		else if(update)
			counter <= counter + 1'b1;
	
	
	//counter only counts to 2'b10, so these work...
	assign enL = (counter == 2'b00) & update;		//counter = 2'b00
	assign enB = (counter == 2'b01) & update;	//conter = 2'b01
	assign enR = (counter == 2'b10) & update;	//counter = 2'b10
	
	always_comb
		if(counter == 2'b00)
			cmd = ({2'b00,3'b000,11'h000});
		else if(counter == 2'b01)
			cmd = ({2'b00,3'b101,11'h000});
		else
			cmd = ({2'b00,3'b100,11'h000});
	
	
	//output flipflops controlled by seperate enables ....
	
	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			lft_ld <= 12'h000;
		else if(enL)
			lft_ld <= rd_data[11:0];
			
	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			rght_ld <= 12'h000;
		else if(enR)
			rght_ld <= rd_data[11:0];

	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			batt <= 12'h000;
		else if(enB)
			batt <= rd_data[11:0];			

endmodule
