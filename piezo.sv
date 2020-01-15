
module piezo(clk, rst_n, piezo, piezo_n, en_steer, ovr_spd, batt_low);
input logic clk; // 50MHz clk
// with 50MHz clk, 95Hz, 190Hz, etc... are easy because clks can be counted in powers of two

// 95Hz : 524,288clks == 2^19 (bit [19] changes after that many clk edges)
// 190Hz: 262,144clks == 2^18
// 381Hz: 131,072 == 2^17 
// 763Hz: 65,536 == 2^16 (en_steer)
// 1525Hz: 32,768 == 2^15 (batt_low)
// 3052Hz: 16,384 == 2^14 (ovr_spd)
// 6104Hz: 8,192 = 2^13 (TOO HIGH)

// counting seconds with 50MHz clk
// 2^22 == 4,194,304clks : 0.08s (750bpm)
// 2^23 == 8,388,608clks : 0.17s (352bmp)
// 2^24 == 16,777,216clks : 0.34s (176bpm)
// 2^25 == 33,554,432clks : 0.67s (90bpm) (en_steer)
// 2^26 == 67,108,864clks : 1.34s (44bpm)
// 2^27 == 134,217,728clks: 2.68s

output logic piezo, piezo_n;
// output to piezo should form a digital sqauare wave
// wave should have frequency between 300Hz and 7kHz

input logic rst_n, en_steer, ovr_spd, batt_low;
// en_steer should have a short burst about every 1-2 seconds (no slower) (NOT ANNOYING)
// ovr_spd should be ALARMING
// batt_low should be able to occur at same time as ovr_spd

logic unsigned [27:0] clk_cnt;
logic clk_clr;

always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		piezo = 0;
	else begin

		
		if (batt_low) begin

			// play batt_low signal during first 0.67s of the 2.68s period
			if (~|clk_cnt[27:25]) begin
				// sets pitch		   sets pulse length
				if (clk_cnt[15] && clk_cnt[22])
					piezo = 1;
				else
					piezo = 0;
			end else if (ovr_spd) begin // when not playing batt_low signal, if ovr_spd

				if (clk_cnt[14])
					piezo = 1;
				else
					piezo = 0;
			end else if (en_steer) begin // when not playing batt_low signal, if en_steer

				if (clk_cnt[16] && ~clk_cnt[25])
					piezo = 1;
				else
					piezo = 0;
			end else // else silence between batt_low pulses
				piezo = 0;
		end else if (ovr_spd) begin // ovr_spd takes priority over en_steer

			if (clk_cnt[14])
				piezo = 1;
			else
				piezo = 0;
		end else if (en_steer) begin

			if (clk_cnt[16] && ~clk_cnt[25])
				piezo = 1;
			else
				piezo = 0;
		end else
			piezo = 0;
	end
end

always @(posedge clk, negedge rst_n) begin
	if (!rst_n)
		clk_cnt <= 0;
	else if (clk_clr)
		clk_cnt <= 0;
	else
		clk_cnt <= clk_cnt + 1;
end

assign piezo_n = ~piezo;

endmodule
