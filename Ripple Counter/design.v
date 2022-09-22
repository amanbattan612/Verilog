module comp_D_flip_flop(output reg Q,input CLK, reset);
	always @(negedge CLK, posedge reset)
		if(reset) Q<=1'b0;
		else Q<=  ~Q;
endmodule

module ripple_counter_4bit(A3,A2,A1,A0,count,reset);
	output A3,A2,A1,A0;
	input count, reset;
	
	comp_D_flip_flop F0(A0,count,reset);
	comp_D_flip_flop F1(A1,A0,reset);
	comp_D_flip_flop F2(A2,A1,reset);
	comp_D_flip_flop F4(A3,A2,reset);
endmodule
