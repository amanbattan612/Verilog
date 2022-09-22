module parity_test;
	reg clk,x;  
    wire z;
	
	parity_gen PAR(x,clk,z);
	
	initial
      	begin
			clk = 1'b0;
          $monitor($time," x=%b z=%b",x, z);
        end
	
	always #5 clk = ~clk;
	
	initial
		begin
			#2 x=0;  #10 x=1;  #10 x=1;  #10 x=1;
			#10 x=0;  #10 x=1;  #10 x=1;  #10 x=0;
			#10 x=0;  #10 x=1;  #10 x=1;  #10 x=0;
			#10 $finish;
		end
endmodule
