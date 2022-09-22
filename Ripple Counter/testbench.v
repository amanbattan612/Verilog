module t_ripple_counter;
	reg count,reset;
	wire A0,A1,A2,A3;
	
	ripple_counter_4bit M0 (A3,A2,A1,A0,count,reset);
	
	always #5 count = ~count;
	initial
		begin
			$dumpfile("wave.vcd");
          $dumpvars(0,t_ripple_counter);
		end
  
	initial
		begin
			count = 1'b0;
			reset = 1'b1;
			#4 reset = 1'b0;
		end
		
	initial #170 $finish;
		
endmodule
