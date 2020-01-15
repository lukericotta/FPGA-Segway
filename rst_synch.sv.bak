module rst_synch(
	input RST_n,
	input clk,
	output logic rst_n);

	logic w;
	
	always_ff@(negedge clk, negedge RST_n) begin
		if(!RST_n)
			w <= 1'b0;
		else
			w <= 1'b1;
	end
	
	always_ff@(negedge clk, negedge RST_n) begin
		if(!RST_n)
			rst_n <= 1'b0;
		else
			rst_n <= w;
	end

endmodule
