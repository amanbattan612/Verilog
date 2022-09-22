module parity_gen(x, clk, z);
	input x,clk;
	output reg z;
	
	parameter EVEN=0, ODD =1;
	reg state;
	
	always @(posedge clk)
		case(state)
			EVEN : state <= x?ODD:EVEN;
			ODD  : state <= x?EVEN:ODD;
			default : state <= EVEN;
		endcase
	always @(state)
		case(state)
			EVEN : z=0;
			ODD  : z=1;
		endcase
endmodule
