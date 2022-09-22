module seq_test;
	reg x,clk,rst;
	wire z;
	
	seq_detect SEQ(x,clk,rst,z);
	
	initial
		begin
			clk = 1'b0; rst = 1'b1;
			#15 rst = 1'b0;
			$monitor($time," x=%b z=%b", x,z);
		end
		
	always #5 clk = ~clk;
	
	initial
		begin
			#12 x=0;  #10 x=0;  #10 x=1;  #10 x=1;
			#10 x=0;  #10 x=1;  #10 x=1;  #10 x=0;
			#10 x=0;  #10 x=1;  #10 x=1;  #10 x=0;
			#10 $finish;
		end
endmodule
