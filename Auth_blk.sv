module Auth_blk (clk, rst_n, RX, rider_off, pwr_up);

input clk, rst_n, RX, rider_off;
output logic pwr_up;

logic rx_rdy;
logic [7:0] rx_data;
logic clr_rx_rdy;

logic g, s;

typedef enum reg[1:0]{OFF, PWR1, PWR2} state_t;
state_t state, nxt_state;

UART_rcv RCV(.clk(clk), .rst_n(rst_n), .RX(RX), .clr_rdy(clr_rx_rdy), .rx_data(rx_data), .rdy(rx_rdy));

always_ff@(posedge clk, negedge rst_n) begin
	if(!rst_n)
		state<=OFF;
	else
		state<=nxt_state;
end

assign g = (rx_data == 8'h67) && rx_rdy;
assign s = (rx_data == 8'h73) && rx_rdy;

always_comb begin

	nxt_state = OFF;
	pwr_up = 1'b0;
	clr_rx_rdy = 1'b0;
	
	case(state)
		OFF:
			if(g) begin
				nxt_state = PWR1;
				pwr_up = 1'b1;
				clr_rx_rdy = 1'b1; end
		PWR1:
			if(rider_off && s) begin
				nxt_state = OFF;
				pwr_up = 1'b0; end
			else if(s && !rider_off) begin
				nxt_state = PWR2;
				pwr_up = 1'b1;
				clr_rx_rdy = 1'b1; end
			else begin
				nxt_state = PWR1;
				pwr_up = 1'b1;
				clr_rx_rdy = 1'b0; end
		PWR2:
			if(rx_rdy && g) begin
				nxt_state = PWR1;
				pwr_up = 1'b1;
				clr_rx_rdy = 1'b1; end
			else if(rider_off) begin
				nxt_state = OFF;
				pwr_up = 1'b0; end
			else begin
				pwr_up = 1'b1;
				clr_rx_rdy = 1'b0;
				nxt_state = PWR2; end
				
	endcase



end

endmodule