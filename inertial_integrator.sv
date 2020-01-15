//Created and worked on by Luciano Ricotta and Snithika Kalakoti
module inertial_integrator(clk, rst_n, vld, ptch_rt, AZ, ptch);

	input clk, rst_n, vld;
	input signed [15:0] ptch_rt;
	input signed [15:0] AZ;
	output signed [15:0] ptch;
	
	logic signed [26:0] ptch_int;	 //register
	
	//extras - wires (combinational)
	logic signed [26:0] ptch_acc_product, fusion_ptch_offset;
	logic signed [15:0] ptch_rt_comp, ptch_acc;
	logic signed [15:0] AZ_comp;
	
	//constants
	localparam PTCH_RT_OFFSET = 16'h03C2;
	localparam AZ_OFFSET = 16'hFE80;
	
	//aithmetic and concatenation operations
	assign AZ_comp = AZ - $signed(AZ_OFFSET);
	assign ptch_rt_comp = ptch_rt - PTCH_RT_OFFSET;
	assign ptch_acc_product = AZ_comp*$signed(327);
	assign ptch_acc = {{3{ptch_acc_product[25]}},ptch_acc_product[25:13]};
	assign ptch = ptch_int[26:11];
	
	//this is the "constant" that is added to ptch_int
	assign fusion_ptch_offset = (ptch_acc > ptch) ? 1024 : -1024;
	

	//flip flop where vld is the enable
	always@(posedge clk, negedge rst_n)
		if(!rst_n)
			ptch_int <= 27'h0000000;
		else if(vld)
			ptch_int <= ptch_int - {{11{ptch_rt_comp[15]}},ptch_rt_comp} + fusion_ptch_offset;	//this math is performed when vld is high


endmodule
