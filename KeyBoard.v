module Mouse(input CLOCK_50, inout PS2_CLK, PS2_DAT, output reg[9:0] POS_X, POS_Y, output wire[5:0] W_SELECTED_ZONE, output reg O_selection);
	
	wire received_data_en;
	wire[7:0] received_data;
	reg[7:0] rec;
	reg init = 1;	

	wire clk_25MHZ;
	
	clock_div2 clock_div2(
        .clk(CLOCK_50),
        .div_clock(clk_25MHZ)
    );
	 

	PS2_Controller #(1) mouse(.CLOCK_50(CLOCK_50), .reset(init),
					.PS2_CLK(PS2_CLK), .PS2_DAT(PS2_DAT), .received_data(received_data), .received_data_en(received_data_en));

	reg[5:0] SELECTED_ZONE = 0;
	assign W_SELECTED_ZONE = SELECTED_ZONE;

	wire[15:0]  w_address;
	reg[15:0] address; 
	reg[1:0] address_state;
	wire [23:0]  q;
	
	clickMap a(
	address,
	CLOCK_50,
	0,
	0,
	q);
	
	//updating pos_x and pos_y;
	reg[20:0] temp; // stores POS_X + POS_Y * 250
	reg SELECTED = 0, C_SELECTED = 1;
	reg Y_SIGN, X_SIGN;
	reg[1:0] DATA_STATE = 0;
	reg st;
	always @(posedge CLOCK_50) begin
		init = 0;
	end
	//note that for some reason negative is going down the screen for mouse.
	always @(posedge received_data_en) begin
		if(init == 0) begin
			DATA_STATE = DATA_STATE + 1;
			rec = received_data;
			if(DATA_STATE == 3) begin
				DATA_STATE = 0;
			end
			
			case(DATA_STATE)
				0: begin
					Y_SIGN = received_data[5];
					X_SIGN = received_data[4];
					st = received_data[0];
				end
				1: begin
					if(X_SIGN) begin
						rec = rec - 1;
						rec = rec ^ ((1<<8)-1);
						if(POS_X < (rec>>2)) begin
							POS_X = 0;
						end
						else begin
							
							POS_X = POS_X - (rec>>2);
						end
					end
					else begin
						POS_X = POS_X + (rec>>2); //TODO TUNE THIS
					end
					
				end
				2: begin		
					if(Y_SIGN) begin
						rec = rec - 1;
						rec = rec ^ ((1<<8)-1);
						POS_Y = POS_Y + (rec>>2);
					end
					else begin
						if(POS_Y < (rec>>2)) begin
							POS_Y = 0;
						end
						else begin
							POS_Y = POS_Y - (rec>>2);
						end
					end
					SELECTED = SELECTED + st;
				end
			endcase
			
			
			
			if(POS_X >= 640) begin
				POS_X = 639;
			end
			
			if(POS_Y >= 480) begin
				POS_Y = 479;
			end		
		end
	end
	
	reg S_selection = 0;
	reg S2_selection = 0;
	always @(posedge clk_25MHZ) begin
		O_selection = 0;
		if(SELECTED != C_SELECTED) begin
			C_SELECTED = SELECTED; 
			if(POS_Y < 50 || POS_X >=380) begin
				SELECTED_ZONE = 0;
				O_selection = 1;
			end
			else begin
				//start memory retreival 
				S_selection = 1;
				temp = POS_X + (POS_Y-50) * 380;
				address = temp[17:2];
				address_state = temp[1:0];
			end
		end
		else if(S_selection) begin
			S_selection = 0;
			S2_selection = 1;
		end
		else if(S2_selection) begin
			//read memory
			case(address_state)
				0: SELECTED_ZONE = q[23:18];
				1: SELECTED_ZONE = q[17:12];
				2: SELECTED_ZONE = q[11:6];
				3: SELECTED_ZONE = q[5:0];
			endcase
			S2_selection = 0;
			O_selection = 1;
		end
		else begin
			S2_selection = 0;
			S_selection = 0;
			O_selection = 0;
		end
		
	end
	
endmodule