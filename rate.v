module rate_divider #(parameter CLOCK_FREQUENCY = 50000000)(input ClockIn, input Reset, input ff, output reg Enable, output reg [1:0] Speed);

	reg [$clog2(CLOCK_FREQUENCY):0] counter;

	always @(posedge ClockIn) begin
	if(Reset) Speed <= 0;
	else if(Speed == 3 && ff) Speed <= 0;
	else if(ff == 1 && Speed != 3) Speed <= Speed + 1;
	else Speed <= Speed;
	end
	

	always @(posedge ClockIn)begin
	if(Reset)begin
	Enable <=1'b0;
	case(Speed)
		2'b00:begin
			counter <= 2;end
		2'b01:begin
			counter <= (CLOCK_FREQUENCY);end
		2'b10:begin
			counter <= (CLOCK_FREQUENCY/2);end
		2'b11:begin
			counter <= (CLOCK_FREQUENCY/4);
	end
	endcase
end
else if(counter==1) begin
		counter <= counter-1;
		Enable<=1'b1;
end
	else if(counter==0) begin
		case(Speed)
		2'b00:begin
			
			Enable<=1'b1;
			counter <= 2;
end
		2'b01:begin
			
			Enable<=1'b1;
			counter <= (CLOCK_FREQUENCY);
end
		2'b10:begin
		
			Enable<=1'b1;
			counter <= (CLOCK_FREQUENCY/2);
end
		2'b11:begin
			
			Enable<=1'b1;
			counter <= (CLOCK_FREQUENCY/4);
			end
	endcase
end
	else begin
			counter <= counter-1;
			Enable <= 1'b0;
	end
	
end

endmodule
