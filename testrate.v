module rate_test #(parameter CLOCK_FREQUENCY = 50000000)(input ClockIn, input Reset, output reg Enable);

	reg [$clog2(CLOCK_FREQUENCY*8):0] counter;

	

	always @(posedge ClockIn)begin
	if(Reset)begin
	Enable <=1'b0;
	counter <= 5000000;
	end
	else if(counter==0) begin
		Enable <= 1'b1;
		counter <= 5000000;
	end
	else begin
			counter <= counter-1;
			Enable <= 1'b0;
	end
	
end

endmodule
