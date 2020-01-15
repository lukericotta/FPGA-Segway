module inert_intf(clk, rst_n, vld, ptch, SS_n, SCLK, MOSI, MISO, INT);

	input clk, rst_n;
	output logic vld;
	output signed [15:0] ptch;
	output SS_n, SCLK, MOSI;
	input MISO;
	input INT;

	//connections for SPI_mstr16
	logic wrt, done;
	logic [15:0] cmd, rd_data;


	//connections for inertial_integrator
	logic signed [15:0] ptch_rt;
	logic signed [15:0] AZ;

	//timer reg
	logic [15:0] timer;
	
	//double flop for metastability
	logic INT_ff1, INT_ff2;

	//outputs of state machine
	logic C_P_H, 	   C_P_L,	  C_AZ_H, C_AZ_L;
	//logic pitchH_ff, pitchL_ff, AZH_ff, AZL_ff;

	SPI_mstr16 spi(.clk(clk), .rst_n(rst_n), .MISO(MISO), .MOSI(MOSI), .SCLK(SCLK), .SS_n(SS_n), .wrt(wrt), .cmd(cmd), .done(done), .rd_data(rd_data));
	inertial_integrator inrt(.clk(clk), .rst_n(rst_n), .vld(vld), .ptch_rt(ptch_rt), .AZ(AZ), .ptch(ptch));

	typedef enum reg [3:0] {INIT1, INIT2, INIT3, INIT4, CHECK_INT, pL, pH, AZL, AZH} state_t;
		state_t state, nxt_state;

	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n)
			state <= INIT1;
		else
			state <= nxt_state;
	end

	always_comb begin

		//default outputs and case
		wrt = 1'b0;
		vld = 1'b0;
		cmd = 16'h0D02;
		nxt_state = INIT1;
		C_AZ_H = 1'b0;
		C_AZ_L = 1'b0;
		C_P_H = 1'b0;
		C_P_L = 1'b0;
		
		case(state)
			//first state gets default values
			INIT1: begin
				if(&timer) begin
					wrt = 1'b1;
					nxt_state = INIT2; end
				end
			//second initial state
			INIT2: begin
				cmd = 16'h1053;
				if(&timer[9:0]) begin
					wrt = 1'b1;
					nxt_state = INIT3; end
				else
					nxt_state = INIT2;
				end
			//third initial state
			INIT3: begin
				cmd = 16'h1150;
				if(&timer[9:0]) begin
					wrt = 1'b1;
					nxt_state = INIT4; end
				else
					nxt_state = INIT3;
				end
			//fourth initial state
			INIT4: begin
				cmd = 16'h1460;
				if(&timer[9:0]) begin
					wrt = 1'b1;
					nxt_state = CHECK_INT; end
				else
					nxt_state = INIT4;
				end
			//condition to check if we should sample measurement
			CHECK_INT: begin
				if(INT_ff2 == 1) begin
					nxt_state = pL;
					wrt = 1'b1;
					cmd = 16'hA2xx; //this is the value that will be sent for the pL (next) state
					end
				else
					nxt_state = CHECK_INT;
				end
			//
			pL:begin
				if(done) begin
					nxt_state = pH;
					wrt = 1'b1;
					cmd = 16'hA3xx; //this is the value that will be sent for the pH (next) state
					C_P_L = 1'b1;	//data is done, so rd_data at this clock cycle will be for pL.
					//The cmd assigned in this state is for the next state***
					end
				else
					nxt_state = pL;
				end
			pH:begin
				if(done) begin
					nxt_state = AZL;
					wrt = 1'b1;
					cmd = 16'hACxx; //this is the value that will be sent for the AZL (next) state
					C_P_H = 1'b1;	//data is done, so rd_data at this clock cycle will be for pH.
					//The cmd assigned in this state is for the next state***
					end
				else
					nxt_state = pH;
				end
			AZL:begin
				if(done) begin
					nxt_state = AZH;
					wrt = 1'b1;
					cmd = 16'hADxx;	//this is the value that will be sent for the AZH (next) state
					C_AZ_L = 1'b1;	//data is done, so rd_data at this clock cycle will be for AZL.
					//The cmd assigned in this state is for the next state***
					end
				else
					nxt_state = AZL;
				end
			//AZH state ("default")
			default: begin
				if(done) begin
					nxt_state = CHECK_INT;
					vld = 1'b1;
					C_AZ_H = 1'b1;	//data is done, so rd_data at this clock cycle will be for AZH.
					end
				else
					nxt_state = AZH;
				end

		endcase
	end
	
	//ptch flip flop and holding registers
	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			ptch_rt <= 16'h0000;
		else if(C_P_L)
			ptch_rt <= {ptch_rt[15:8], rd_data[7:0]};
		else if(C_P_H)
			ptch_rt <= {rd_data[7:0], ptch_rt[7:0]};

	always_ff@(posedge clk, negedge rst_n)
		if(!rst_n)
			AZ <= 16'h0000;
		else if(C_AZ_L)
			AZ <= {AZ[15:8], rd_data[7:0]};
		else if(C_AZ_H)
			AZ <= {rd_data[7:0], AZ[7:0]};
	
	always_ff@(posedge clk)
		INT_ff1 <= INT;
	
	always_ff@(posedge clk)
		INT_ff2 <= INT_ff1;

	always@(posedge clk, negedge rst_n)
		if(!rst_n)
			timer <= 16'h0000;
		else
			timer <= timer + 1;
		

endmodule
