module clock_div2(input clk, output div_clock);
    reg counter = 0;
    always @(posedge clk) begin
        counter <= ~counter;
    end
    assign div_clock = counter;
endmodule

module hcounter(input clk_25MHZ, output reg [15:0] H_COUNTER, output reg E_V_COUNTER, input reset);
	 always @(posedge clk_25MHZ or posedge reset) begin
		  if (reset) begin
				H_COUNTER <=0;
			end
        else begin 
				if (H_COUNTER == 799) begin
					H_COUNTER <= 0;
					E_V_COUNTER <= 1;
				end 
			  else begin
					H_COUNTER <= H_COUNTER + 1;
					E_V_COUNTER <= 0;
			  end
			end
    end
endmodule

module vcounter(input E_V_COUNTER, output reg [15:0] V_COUNTER, input reset);
    always @(posedge E_V_COUNTER or posedge reset) begin
	     if (reset) begin
				V_COUNTER<=0;
			end
        else begin
				if (V_COUNTER == 524) begin
					V_COUNTER <= 0;
			  end 
			  else begin
					V_COUNTER <= V_COUNTER + 1;
			  end
			end
    end

endmodule

