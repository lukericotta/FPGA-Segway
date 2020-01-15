 module PWM11(input clk, input rst_n, input [10:0] duty, output logic PWM_sig);

	reg [10:0] count;
	
	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) 		//active low async reset
			count <= 11'h000;
		else
			count <= count + 1;
	end	

	always_ff @(posedge clk, negedge rst_n) begin
		if (!rst_n) 		//active low async reset
			PWM_sig <= 1'b0;
		//Now we will keep PWM_sig at 0 and only assert it when count is all zeros
		else if(count >= duty)
			PWM_sig <= 1'b0;
		else if( |count == 0)
			PWM_sig <= 1'b1;
	end	

endmodule
