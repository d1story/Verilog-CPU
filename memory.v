//todo give the cpu a way to read the memory
module MemoryController(input CLOCK_50,
			input W_EN_MEM,
			input [4:0] I_PROG_ADDRESS, I_MEM_ADDRESS,
			input [64:0] I_MEM, 
			output wire IO_DISABLED,
			output wire[79:0] I_PROG_REQ, I_MEM_REQ, inout PS2_CLK, PS2_DAT,
         input[5:0] SELECTED_ZONE, 
			output reg [9:0]VGA_B, VGA_R, VGA_G,
			output reg VGA_HS, VGA_VS, VGA_SYNC_N, VGA_CLK, VGA_BLANK_N,
			input wire[4:0] C_FETCH,
			input wire[79:0] C_EXEC,
			input wire[51:0]C_ACCUM,
			input [9:0] POS_X, POS_Y,
			input reset,
			input [1:0] CPU_STATE,
			input CPU_ERROR);

	//double check that VGA_REQ goes through correctly dispite a change in size.
	
/*****************************************************************************
 *                           CLOCK declarations + modules                    *
 *****************************************************************************/
	wire clk_25MHZ;
	
	clock_div2 clock_div2(
        .clk(CLOCK_50),
        .div_clock(clk_25MHZ)
    );

/*****************************************************************************
 *                           VGA declarations                     			 *
 *****************************************************************************/

	//VGA dec
	wire [15:0] H_COUNTER;
	wire E_V_COUNTER;
	wire [15:0] V_COUNTER;

	parameter C_VERT_NUM_PIXELS  = 10'd480;
	parameter C_VERT_SYNC_START  = 10'd493;
	parameter C_VERT_SYNC_END    = 10'd494; //(C_VERT_SYNC_START + 2 - 1); 

	parameter C_HORZ_NUM_PIXELS  = 10'd640;
	parameter C_HORZ_SYNC_START  = 10'd659;
	parameter C_HORZ_SYNC_END    = 10'd754; //(C_HORZ_SYNC_START + 96 - 1); 

	//stuff for reading and writing from block ram
	wire mem_EN;
	wire [15:0]data_To_MEM;
	
	wire [15:0]w_address, outMem;
	reg [2:0]addressState = 0;
	reg [15:0]address = 0, m_address = 0, a_address = 0;
	reg [1:0]color;
	reg [30:0]temp;
	reg [15:0] ASCII[37:0][15:0];
	assign w_address = a_address;
	
	//stuff for intracting with memory
	reg r_mem_EN;
	reg [15:0]r_data_To_MEM;
	assign mem_EN = r_mem_EN;
	assign data_To_MEM = r_data_To_MEM;
	
	reg VGA_HS1, VGA_VS1, VGA_BLANK_N1;
	
	//get the snap shots from CPU
	reg[79:0] SC_FETCH, SC_EXEC, SC_ACCUM;

	//for VGA to memory
	//making sure all the X positions are the start of memory address to make my own life easier.
	parameter upperX = 10'd152;
	parameter upperY = 10'd57;
	parameter deltaX = 10'd128;
	parameter deltaY = 10'd26;
	
	reg [4:0]relPosY, relPosY1, characterCNT, characterCNT1;
	reg [9:0]absPosX, absPosY, absPosY1, absPosX1;
	reg [4:0]boxX1, boxY1, boxX, boxY;
	reg [79:0] PROGRAM, VGA_MEMORY;


/*****************************************************************************
 *                           VGA submodules                    				 *
 *****************************************************************************/

    hcounter hcounter(
        .clk_25MHZ(clk_25MHZ),
        .H_COUNTER(H_COUNTER),
        .E_V_COUNTER(E_V_COUNTER),
		  .reset(reset)
    );

    vcounter vcounter(
        .E_V_COUNTER(E_V_COUNTER),
        .V_COUNTER(V_COUNTER),
		  .reset(reset)
    );

	
	initImage a(
		w_address,
		CLOCK_50,
		data_To_MEM, 
		mem_EN,
		outMem);

/*****************************************************************************
 *                           KEYBOARD declarations			                 *
 *****************************************************************************/

	wire received_data_en;
	wire[7:0] received_data;

	//store the ascii code of the letter u gonna change
	reg [7:0]CHARINBUFF;

	reg released = 0;



/*****************************************************************************
 *                           MEMORY declarations			                 *
 *****************************************************************************/

	//NOT SURE IF I need to update this to normal memory
	reg VGA_SNAP_EN;
	assign IO_DISABLED = VGA_SNAP_EN;
	
	integer k;
	
	//this also serves as program address.
	reg[5:0] iter_CNT;
	
	reg VGA_USING_MEM;

	wire [4:0]w_VGAM_ADR;
	wire [107:0]w_VGAM_DAT, w_VGAM_OUT;
	wire w_VGAM_WEN;

	reg [4:0]VGAM_ADR;
	reg VGAM_WEN;
	reg [107:0]VGAM_DAT;
	
	assign w_VGAM_WEN = VGAM_WEN;
	assign w_VGAM_ADR = VGAM_ADR;
	assign w_VGAM_DAT = VGAM_DAT;
	

	wire [63:0] w_MEM_OUTa, w_MEM_OUTb;
	
	wire [4:0]w_PROG_ADR;
	wire w_PROG_WEN;
	wire [107:0]w_PROG_DAT, w_PROG_OUT;
	assign I_PROG_REQ = w_PROG_OUT; 

	reg [4:0]PROG_ADR;
	reg [107:0]PROG_DAT;

	assign w_PROG_ADR = PROG_ADR;
	assign w_PROG_DAT = PROG_DAT;

	reg [51:0] MEMORY;
	
	
	
/*****************************************************************************
 *                        MEMORY INTERMODULE declarations  		  				  *
 *****************************************************************************/

	//this also serves as program address. DO NOT uncomment already declared
	//reg[4:0] iter_CNT;

	reg [4:0] VGA_TO_VGAM_ADR;
	
	reg[79:0] pendingUpdate;
	
	reg [4:0] VGA_TO_PROG_ADR;
	
	reg PROG_MEM_CHANGE, L_PROG_MEM_CHANGE, L2_PROG_MEM_CHANGE;
	
	reg [3:0]tempCNT;
	
	assign w_PROG_WEN = (L2_PROG_MEM_CHANGE != PROG_MEM_CHANGE);
	
	
	
/*****************************************************************************
 *                           KEYBOARD submodules			                 *
 *****************************************************************************/

	PS2_Controller keyboard(.CLOCK_50(CLOCK_50), .reset(reset),
					.PS2_CLK(PS2_CLK), .PS2_DAT(PS2_DAT), .received_data(received_data), .received_data_en(received_data_en));


/*****************************************************************************
 *                           VGA memory interface                   		 *
 *****************************************************************************/
	//address is for reading
	//m_address is for writing
	always @(*)begin
		//when writing actual address is the same a write address else use read address.
		if(mem_EN) a_address = m_address;
		else a_address = address;
	end

/*****************************************************************************
 *                           VGA outputs			                 		 *
 *****************************************************************************/

	reg [5:0]tempZONE;
	always @(*) begin
		VGA_SYNC_N = 0;
		VGA_CLK = clk_25MHZ;
		VGA_HS1 <= ~((H_COUNTER >= C_HORZ_SYNC_START) && (H_COUNTER <= C_HORZ_SYNC_END));
		VGA_VS1 <= ~(( V_COUNTER >= C_VERT_SYNC_START) && ( V_COUNTER <= C_VERT_SYNC_END));
		VGA_HS <= VGA_HS1;
		VGA_VS <= VGA_VS1;
		
		//- Current X and Y is valid pixel range
		VGA_BLANK_N1 <= ((H_COUNTER < C_HORZ_NUM_PIXELS) && ( V_COUNTER < C_VERT_NUM_PIXELS));	
		VGA_BLANK_N <= VGA_BLANK_N1;
		
		  if((H_COUNTER < C_HORZ_NUM_PIXELS) && ( V_COUNTER < C_VERT_NUM_PIXELS)) begin
				if(H_COUNTER >= POS_X && H_COUNTER<POS_X+8 && V_COUNTER >= POS_Y && V_COUNTER<POS_Y + 8) begin
					VGA_R = 1023; //2^10 - 1 
					VGA_G = 0;
					VGA_B = 0;
				end
				else begin
					temp = H_COUNTER+V_COUNTER*C_HORZ_NUM_PIXELS;
					address <= temp[18:3];
					temp = temp - 1;
					addressState <= temp[2:0];

					case (addressState)
						0: color = outMem[15:14];
						1: color = outMem[13:12];
						2: color = outMem[11:10];
						3: color = outMem[9:8];
						4: color = outMem[7:6];
						5: color = outMem[5:4];
						6: color = outMem[3:2];
						7: color = outMem[1:0];
						default: color = 2;
					endcase
					
					case (color)

						0: begin
							VGA_R = 1023; //2^10 - 1 
							VGA_G = 1023;
							VGA_B = 1023;
						end
						1: begin
							VGA_R = 0;
							VGA_G = 0;
							VGA_B = 0;
						end
						2: begin
							VGA_R = 0;
							VGA_G = 0;
							VGA_B = 1023;
						end
					endcase
					
					if(color == 1) begin
						if(CPU_STATE == 0 && H_COUNTER >= 20 && H_COUNTER <90 && V_COUNTER >= 55 && V_COUNTER < 75) begin
							VGA_R = 904;
							VGA_G = 996;
							VGA_B = 1016;
						end

						if(CPU_STATE == 1 && H_COUNTER >= 20 && H_COUNTER <90 && V_COUNTER >= 75 && V_COUNTER < 95) begin
							VGA_R = 904;
							VGA_G = 996;
							VGA_B = 1016;
						end

						if(CPU_STATE == 2 && H_COUNTER >= 20 && H_COUNTER <90 && V_COUNTER >= 95 && V_COUNTER < 115) begin
							VGA_R = 904;
							VGA_G = 996;
							VGA_B = 1016;
						end

						if(SELECTED_ZONE == 1 && H_COUNTER >= 10 && H_COUNTER <70 && V_COUNTER >= 400 && V_COUNTER < 450)begin
							VGA_R = 904;
							VGA_G = 996;
							VGA_B = 1016;
						end
						
						if(SELECTED_ZONE == 5 && H_COUNTER >= 10 && H_COUNTER <70 && V_COUNTER >= 350 && V_COUNTER < 400)begin
							VGA_R = 904;
							VGA_G = 996;
							VGA_B = 1016;
						end
						
						if(SELECTED_ZONE == 6 && H_COUNTER >= 10 && H_COUNTER <70 && V_COUNTER >= 300 && V_COUNTER < 340)begin
							VGA_R = 904;
							VGA_G = 996;
							VGA_B = 1016;
						end
						
						if(SELECTED_ZONE == 7 && H_COUNTER >= 70 && H_COUNTER <120 && V_COUNTER >= 400 && V_COUNTER < 450)begin
							VGA_R = 904;
							VGA_G = 996;
							VGA_B = 1016;
						end
						
						if(SELECTED_ZONE == 8 && H_COUNTER >= 70 && H_COUNTER <100 && V_COUNTER >= 350 && V_COUNTER < 400)begin
							VGA_R = 904;
							VGA_G = 996;
							VGA_B = 1016;
						end
					end

					if(color == 0 && SELECTED_ZONE>=9 && SELECTED_ZONE< 41) begin
						tempZONE = SELECTED_ZONE - 9;
						if((H_COUNTER >= upperX + (tempZONE>>4)*deltaX) && 
							(H_COUNTER < upperX + (tempZONE>>4)*deltaX + 80) &&
							(V_COUNTER >= upperY + (tempZONE[3:0])*deltaY) &&
							(V_COUNTER < upperY + (tempZONE[3:0])*deltaY + 16)
						) begin
							VGA_R = 904;
							VGA_G = 996;
							VGA_B = 1016;
						end
					end
					
					if(color == 0 && CPU_ERROR == 1) begin
						VGA_R = 0;
						VGA_G = 1023;
						VGA_B = 0;
					end
				end
				
		  end
		  else begin
				addressState <= 0;
				address <= 0;
				VGA_B = 0;
				VGA_R = 0;
				VGA_G = 0;
		  end
		  
    end

/*****************************************************************************
 *                KEYBOARD Parser +   KEYBOARD to memory communication 		 *
 *****************************************************************************/	
	//for the letter count bram
	wire [3:0]w_LETTER_DAT, w_LETTER_OUT;
	reg [3:0]LETTER_DAT;
	assign w_LETTER_DAT = LETTER_DAT;

	LETTER_CNT L_CNT(
		w_PROG_ADR,
		CLOCK_50,
		w_LETTER_DAT,
		w_PROG_WEN,
		w_LETTER_OUT);

	reg [5:0]ACT_ZONE;

	//use to be posedge received_data_en
	always @(posedge CLOCK_50) begin
			if(reset) begin
				PROG_MEM_CHANGE = 0;
			end
			else if(received_data == 8'hF0) begin
				if(CHARINBUFF != 40 && SELECTED_ZONE>=9 && SELECTED_ZONE< 41) begin
					ACT_ZONE = SELECTED_ZONE - 9;
					tempCNT = w_LETTER_OUT;
					pendingUpdate = w_PROG_OUT;
					if(CHARINBUFF == 38 && tempCNT > 0) begin
						tempCNT = tempCNT - 1;
						//ensuring that the write enable gets turned off
						PROG_MEM_CHANGE = !PROG_MEM_CHANGE;
						case(tempCNT)
							0: pendingUpdate[79:72] = 8'b0;
							1: pendingUpdate[71:64] = 8'b0;
							2: pendingUpdate[63:56] = 8'b0;
							3: pendingUpdate[55:48] = 8'b0;
							4: pendingUpdate[47:40] = 8'b0;
							5: pendingUpdate[39:32] = 8'b0;
							6: pendingUpdate[31:24] = 8'b0;
							7: pendingUpdate[23:16] = 8'b0;
							8: pendingUpdate[15:8] = 8'b0;
							9: pendingUpdate[7:0] = 8'b0;
							default: pendingUpdate = pendingUpdate;
						endcase
					end
					else begin
						if(CHARINBUFF != 38 && tempCNT<10) begin
							case(tempCNT)
								0: pendingUpdate[79:72] = CHARINBUFF;
								1: pendingUpdate[71:64] = CHARINBUFF;
								2: pendingUpdate[63:56] = CHARINBUFF;
								3: pendingUpdate[55:48] = CHARINBUFF;
								4: pendingUpdate[47:40] = CHARINBUFF;
								5: pendingUpdate[39:32] = CHARINBUFF;
								6: pendingUpdate[31:24] = CHARINBUFF;
								7: pendingUpdate[23:16] = CHARINBUFF;
								8: pendingUpdate[15:8] = CHARINBUFF;
								9: pendingUpdate[7:0] = CHARINBUFF;
								default: pendingUpdate = pendingUpdate;
							endcase
							tempCNT  = tempCNT + 1;
							//ensuring that the write enable gets turned off
							PROG_MEM_CHANGE = !PROG_MEM_CHANGE;
						end
						else begin
							tempCNT  = tempCNT;
							pendingUpdate = pendingUpdate;
						end
					end

					PROG_DAT = pendingUpdate;
					LETTER_DAT = tempCNT;
				end
			end

			case(received_data)
				8'h29: CHARINBUFF = 0;
				8'h1C: CHARINBUFF = 1;
				8'h32: CHARINBUFF = 2;
				8'h21: CHARINBUFF = 3;
				8'h23: CHARINBUFF = 4;
				8'h24: CHARINBUFF = 5;
				8'h2B: CHARINBUFF = 6;
				8'h34: CHARINBUFF = 7;
				8'h33: CHARINBUFF = 8;
				8'h43: CHARINBUFF = 9;
				8'h3B: CHARINBUFF = 10;
				8'h42: CHARINBUFF = 11;
				8'h4B: CHARINBUFF = 12;
				8'h31: CHARINBUFF = 13;
				8'h44: CHARINBUFF = 14;
				8'h4D: CHARINBUFF = 15;
				8'h15: CHARINBUFF = 16;
				8'h2D: CHARINBUFF = 17;
				8'h1B: CHARINBUFF = 18;
				8'h2C: CHARINBUFF = 19;
				8'h3C: CHARINBUFF = 20;
				8'h2A: CHARINBUFF = 21;
				8'h22: CHARINBUFF = 22;
				8'h35: CHARINBUFF = 23;
				8'h1A: CHARINBUFF = 24;
				8'h45: CHARINBUFF = 25;
				8'h16: CHARINBUFF = 26;
				8'h1E: CHARINBUFF = 27;
				8'h26: CHARINBUFF = 28;
				8'h25: CHARINBUFF = 29;
				8'h2E: CHARINBUFF = 30;
				8'h36: CHARINBUFF = 31;
				8'h3D: CHARINBUFF = 32;
				8'h3E: CHARINBUFF = 33;
				8'h46: CHARINBUFF = 34;
				8'h4E: CHARINBUFF = 36;
				8'h66: CHARINBUFF = 38;
				default: CHARINBUFF = 40;
			endcase	
	end

/*****************************************************************************
 *                           MEMORY submodules			 		                *
 *****************************************************************************/
	//extend the ports?
	valMem val_mem(
		I_MEM_ADDRESS,
		w_VGAM_ADR,
		CLOCK_50,
		I_MEM,
		0,
		W_EN_MEM,
		0,
		I_MEM_REQ,
		w_MEM_OUTb);

	asciiMem vga_mem(
		w_VGAM_ADR,
		CLOCK_50,
		w_VGAM_DAT, 
		w_VGAM_WEN && !W_EN_MEM,
		w_VGAM_OUT);

	asciiMem prog(
		w_PROG_ADR,
		CLOCK_50,
		w_PROG_DAT, 
		w_PROG_WEN,
		w_PROG_OUT);

/*****************************************************************************
 *                         MEMORY internal updates    					 	 *
 *****************************************************************************/

	reg[99:0] num1, pnum1, num2, pnum2;
	reg[8:0] ascRem1, ascRem2;
	reg st1,st2;
	integer i,j;
	
	reg[79:0] update_mem;

	parameter scan = 0;
	parameter updating = 1;
	reg [1:0]Trans_State = 0;

	reg L_EN_MEM;

	always @(posedge clk_25MHZ) begin
		VGAM_WEN = 0;
		if(reset) begin
			iter_CNT = 0;
		end
		else if(VGA_USING_MEM == 0 && !W_EN_MEM) begin
			case(Trans_State)
				0: begin
					Trans_State = 1;
					iter_CNT = iter_CNT + 1;
					if(iter_CNT == 32)
						iter_CNT = 0;
				end
				1: Trans_State = 2;
            2: Trans_State = 3;
				3: begin
					VGAM_WEN = 1;
					st1 = 0;
					st2 = 0;
					update_mem = 0;
					MEMORY = w_MEM_OUTb;
					case(MEMORY[51:50]) 
						0: begin
							num1 = MEMORY[48:25];
							if(MEMORY[49]) begin
								update_mem[79:72] = 36;
								num1 = num1 - 1;
								num1 = num1 ^ ((1<<24)-1);
							end
							for (i=0;i<9;i = i + 1) begin
								//approximating division by ten
								if(!st1) begin
									pnum1 = num1;
									num1 = (num1 * 64'd3602879701896397)>>55;
									pnum1 = pnum1 - num1*10;
									case(pnum1)
										0: ascRem1 = 25;
										1: ascRem1 = 26;
										2: ascRem1 = 27;
										3: ascRem1 = 28;
										4: ascRem1 = 29;
										5: ascRem1 = 30;
										6: ascRem1 = 31;
										7: ascRem1 = 32;
										8: ascRem1 = 33;
										9: ascRem1 = 34;
										default: ascRem1 = 0;
									endcase
									//always use the remainder to find ascii
									if(num1 == 0) begin
										st1 = 1;
										update_mem[71:64] = ascRem1;
									end
									else if(num1<10) begin
										update_mem[63:56] = ascRem1;
									end
									else if(num1<100) begin
										update_mem[55:48] = ascRem1;
									end
									else if(num1<1000) begin
										update_mem[47:40] = ascRem1;
									end
									else if(num1<10000) begin
										update_mem[39:32] = ascRem1;
									end
									else if(num1<100000) begin
										update_mem[31:24] = ascRem1;
									end
									else if(num1<1000000) begin
										update_mem[23:16] = ascRem1;
									end
									else if(num1<10000000) begin
										update_mem[15:8] = ascRem1;
									end
									else if(num1<100000000) begin
										update_mem[7:0] = ascRem1;
									end
								end
							end
						end
						1: begin
							num1 = MEMORY[48:25];
							if(MEMORY[49]) begin
								update_mem[79:72] = 36;
								num1 = num1 - 1;
								num1 = num1 ^ ((1<<24)-1);
							end
							for (i=0;i<9;i = i + 1) begin
								if(!st1) begin
									pnum1 = num1;
									num1 = (num1 * 64'd3602879701896397)>>55;
									pnum1 = pnum1 - num1*10;
									case(pnum1)
										0: ascRem1 = 25;
										1: ascRem1 = 26;
										2: ascRem1 = 27;
										3: ascRem1 = 28;
										4: ascRem1 = 29;
										5: ascRem1 = 30;
										6: ascRem1 = 31;
										7: ascRem1 = 32;
										8: ascRem1 = 33;
										9: ascRem1 = 34;
										default: ascRem1 = 0;
									endcase
									if(num1 == 0) begin
										st1 = 1;
										update_mem[71:64] = ascRem1;
										case(i)
											0: update_mem[47:40] = 25;
											1: update_mem[47:40] = 25;
											2: update_mem[47:40] = 25;
											3: update_mem[47:40] = 25;
											4: update_mem[47:40] = 26;
											5: update_mem[47:40] = 27;
											6: update_mem[47:40] = 28;
											7: update_mem[47:40] = 29;
											8: update_mem[47:40] = 30;
										endcase
									end
									else if(num1<10) begin
										update_mem[63:56] = ascRem1;
									end
									else if(num1<100) begin
										update_mem[55:48] = ascRem1;
									end
								end
							end
							
							num2 = MEMORY[23:0];
							if(MEMORY[24]) begin
								num2 = num2 - 1;
								num2 = num2 ^ ((1<<24)-1);
							end
							for (j=0;j<9;j = j + 1) begin
								if(!st2) begin
									pnum2 = num2;
									num2 = (num2 * 64'd3602879701896397)>>55;
									pnum2 = pnum2 - num2*10;
									case(pnum2)
										0: ascRem2 = 25;
										1: ascRem2 = 26;
										2: ascRem2 = 27;
										3: ascRem2 = 28;
										4: ascRem2 = 29;
										5: ascRem2 = 30;
										6: ascRem2 = 31;
										7: ascRem2 = 32;
										8: ascRem2 = 33;
										9: ascRem2 = 34;
										default: ascRem2 = 0;
									endcase
									if(num2 == 0) begin
										st2 = 1;
										update_mem[31:24] = ascRem2;
										case(j)
											0: update_mem[7:0] = 25;
											1: update_mem[7:0] = 25;
											2: update_mem[7:0] = 25;
											3: update_mem[7:0] = 25;
											4: update_mem[7:0] = 26;
											5: update_mem[7:0] = 27;
											6: update_mem[7:0] = 28;
											7: update_mem[7:0] = 29;
											8: update_mem[7:0] = 30;
										endcase
									end
									else if(num2<10) begin
										update_mem[23:16] = ascRem2;
									end
									else if(num2<100) begin
										update_mem[15:8] = ascRem2;
									end
									else update_mem = update_mem;
								end
							end
						end
					endcase
					VGAM_DAT = update_mem;
					Trans_State = scan;
				end
			endcase
		end
	end



/*****************************************************************************
 *                           MEMORY memory interface    			 		 *
 *****************************************************************************/

	always @(*)begin
		if(VGA_USING_MEM == 0) begin
			VGAM_ADR =  iter_CNT;
		end
		else begin
			VGAM_ADR = VGA_TO_VGAM_ADR;
		end
	end

	reg VGA_SNAP_EN1;
	//have the data from prog ready to go note is it exteremly unlikely that they change zone and type in the same clock50 cycle.
	//TODO force SELECTED ZONE to <9 if cpu is running.
	always @(posedge clk_25MHZ) begin
		
		if(VGA_SNAP_EN1 == 1) begin
			PROG_ADR = VGA_TO_PROG_ADR;
		end
		else if(SELECTED_ZONE>=9 && SELECTED_ZONE< 41) begin
			//only in here should  w_PROG_WEN be set to true
			PROG_ADR = SELECTED_ZONE - 9;
		end
		else begin
			PROG_ADR = I_PROG_ADDRESS;
		end
		L2_PROG_MEM_CHANGE = L_PROG_MEM_CHANGE;
		L_PROG_MEM_CHANGE = PROG_MEM_CHANGE;
		VGA_SNAP_EN1 = VGA_SNAP_EN;
	end


/*****************************************************************************
 *               VGA editing video memory from memory memory	              *
 *****************************************************************************/		
	reg entered; 
	reg [99:0]Cnum1, Cpnum1, Cnum2, Cpnum2;
	reg [79:0] AC_FETCH, AC_ACCUM;
	reg [7:0] CascRem1, CascRem2;
	reg [4:0] CPU_CHAR_CNT, CPU_Y_CNT, CPU_PRINTED;
	reg [9:0] CPU_ABS_POS_Y, CPU_ABS_POS_X;
	reg Cst1, Cst2;
	integer ii, jj, kk;

	always @(posedge clk_25MHZ) begin
		r_mem_EN = 0;
		r_data_To_MEM = 0;
		VGA_SNAP_EN = 0;
		m_address = 0;
		VGA_USING_MEM = 0;
		PROGRAM = w_PROG_OUT;
		VGA_MEMORY = w_VGAM_OUT;

		if(V_COUNTER >= C_VERT_NUM_PIXELS) begin

			//ensure that the memory is fetched
			if(entered == 1) begin

				if(boxX1 < 2) begin
					case(characterCNT)
						0: r_data_To_MEM = ASCII[PROGRAM[79:72]][relPosY1];
						1: r_data_To_MEM = ASCII[PROGRAM[71:64]][relPosY1];
						2: r_data_To_MEM = ASCII[PROGRAM[63:56]][relPosY1];
						3: r_data_To_MEM = ASCII[PROGRAM[55:48]][relPosY1];
						4: r_data_To_MEM = ASCII[PROGRAM[47:40]][relPosY1];
						5: r_data_To_MEM = ASCII[PROGRAM[39:32]][relPosY1];
						6: r_data_To_MEM = ASCII[PROGRAM[31:24]][relPosY1];
						7: r_data_To_MEM = ASCII[PROGRAM[23:16]][relPosY1];
						8: r_data_To_MEM = ASCII[PROGRAM[15:8]][relPosY1];
						9: r_data_To_MEM = ASCII[PROGRAM[7:0]][relPosY1];
						default: r_data_To_MEM = 0;
					endcase
				end
				else if(boxX1<4) begin
					case(characterCNT)
						0: r_data_To_MEM = ASCII[VGA_MEMORY[79:72]][relPosY1];
						1: r_data_To_MEM = ASCII[VGA_MEMORY[71:64]][relPosY1];
						2: r_data_To_MEM = ASCII[VGA_MEMORY[63:56]][relPosY1];
						3: r_data_To_MEM = ASCII[VGA_MEMORY[55:48]][relPosY1];
						4: r_data_To_MEM = ASCII[VGA_MEMORY[47:40]][relPosY1];
						5: r_data_To_MEM = ASCII[VGA_MEMORY[39:32]][relPosY1];
						6: r_data_To_MEM = ASCII[VGA_MEMORY[31:24]][relPosY1];
						7: r_data_To_MEM = ASCII[VGA_MEMORY[23:16]][relPosY1];
						8: r_data_To_MEM = ASCII[VGA_MEMORY[15:8]][relPosY1];
						9: r_data_To_MEM = ASCII[VGA_MEMORY[7:0]][relPosY1];
						default: r_data_To_MEM = 0;
					endcase
				end

				r_mem_EN = 1;
				m_address = (absPosY1 + relPosY1)*80 + (absPosX1>>3) + characterCNT1;
				//(absPosY + relPosY)*80 every 80 address is one row. (absPosX>>3) 8 pixels are represented in one memaddress.
			end
			entered = 1;
			relPosY1 = relPosY;
			characterCNT1 = characterCNT;
			boxX1 = boxX;
			boxY1 = boxY;
			absPosX1 = absPosX;
			absPosY1 = absPosY;

			//iterating through each box.
			if((absPosX<550)) begin
				VGA_SNAP_EN = 1;
				if(absPosY>450) begin
					absPosY = upperY;
					absPosX = absPosX + deltaX;
					characterCNT = 0;
					boxY = 0;
					boxX = boxX + 1;
				end

				relPosY = relPosY + 1;
					
				if(relPosY == 16) begin
					characterCNT = characterCNT + 1;
					relPosY = 0;
				end
				
				//goto next box if outputed all 10 character.
				if(characterCNT == 10) begin
					characterCNT = 0;
					boxY = boxY + 1;
					absPosY = absPosY + deltaY;
				end
			end

			//note that boxX1 lags boxX by one so the memory is always ready.
			if(boxX < 2) VGA_TO_PROG_ADR = (boxX)*16+boxY;
			else VGA_TO_PROG_ADR = 0;

			if(boxX < 4 && boxX >= 2) begin
				VGA_TO_VGAM_ADR = (boxX-2)*16+boxY;
				//Set this signal so that memory self-update knows to stop
				VGA_USING_MEM = 1;
			end
			else begin
				VGA_TO_VGAM_ADR = 0;
				VGA_USING_MEM = 0;
			end

			if(boxX >=4) begin
                case(CPU_PRINTED) 
                    0: begin
                        case(CPU_CHAR_CNT)
                            0: r_data_To_MEM = ASCII[AC_FETCH[79:72]][CPU_Y_CNT];
                            1: r_data_To_MEM = ASCII[AC_FETCH[71:64]][CPU_Y_CNT];
                            2: r_data_To_MEM = ASCII[AC_FETCH[63:56]][CPU_Y_CNT];
                            3: r_data_To_MEM = ASCII[AC_FETCH[55:48]][CPU_Y_CNT];
                            4: r_data_To_MEM = ASCII[AC_FETCH[47:40]][CPU_Y_CNT];
                            5: r_data_To_MEM = ASCII[AC_FETCH[39:32]][CPU_Y_CNT];
                            6: r_data_To_MEM = ASCII[AC_FETCH[31:24]][CPU_Y_CNT];
                            7: r_data_To_MEM = ASCII[AC_FETCH[23:16]][CPU_Y_CNT];
                            8: r_data_To_MEM = ASCII[AC_FETCH[15:8]][CPU_Y_CNT];
                            9: r_data_To_MEM = ASCII[AC_FETCH[7:0]][CPU_Y_CNT];
                            default: r_data_To_MEM = 0;
                        endcase
                    end
                    1: begin
                        case(CPU_CHAR_CNT)
                            0: r_data_To_MEM = ASCII[C_EXEC[79:72]][CPU_Y_CNT];
                            1: r_data_To_MEM = ASCII[C_EXEC[71:64]][CPU_Y_CNT];
                            2: r_data_To_MEM = ASCII[C_EXEC[63:56]][CPU_Y_CNT];
                            3: r_data_To_MEM = ASCII[C_EXEC[55:48]][CPU_Y_CNT];
                            4: r_data_To_MEM = ASCII[C_EXEC[47:40]][CPU_Y_CNT];
                            5: r_data_To_MEM = ASCII[C_EXEC[39:32]][CPU_Y_CNT];
                            6: r_data_To_MEM = ASCII[C_EXEC[31:24]][CPU_Y_CNT];
                            7: r_data_To_MEM = ASCII[C_EXEC[23:16]][CPU_Y_CNT];
                            8: r_data_To_MEM = ASCII[C_EXEC[15:8]][CPU_Y_CNT];
                            9: r_data_To_MEM = ASCII[C_EXEC[7:0]][CPU_Y_CNT];
                            default: r_data_To_MEM = 0;
                        endcase
                    end
                    2: begin
                        case(CPU_CHAR_CNT)
                            0: r_data_To_MEM = ASCII[AC_ACCUM[79:72]][CPU_Y_CNT];
                            1: r_data_To_MEM = ASCII[AC_ACCUM[71:64]][CPU_Y_CNT];
                            2: r_data_To_MEM = ASCII[AC_ACCUM[63:56]][CPU_Y_CNT];
                            3: r_data_To_MEM = ASCII[AC_ACCUM[55:48]][CPU_Y_CNT];
                            4: r_data_To_MEM = ASCII[AC_ACCUM[47:40]][CPU_Y_CNT];
                            5: r_data_To_MEM = ASCII[AC_ACCUM[39:32]][CPU_Y_CNT];
                            6: r_data_To_MEM = ASCII[AC_ACCUM[31:24]][CPU_Y_CNT];
                            7: r_data_To_MEM = ASCII[AC_ACCUM[23:16]][CPU_Y_CNT];
                            8: r_data_To_MEM = ASCII[AC_ACCUM[15:8]][CPU_Y_CNT];
                            9: r_data_To_MEM = ASCII[AC_ACCUM[7:0]][CPU_Y_CNT];
                            default: r_data_To_MEM = 0;
                        endcase
                    end
                endcase

                if(CPU_PRINTED < 3) begin
					r_mem_EN = 1;
					m_address = (CPU_ABS_POS_Y + CPU_Y_CNT)*80 + (CPU_ABS_POS_X>>3) + CPU_CHAR_CNT;

					CPU_Y_CNT = CPU_Y_CNT + 1;
					if(CPU_Y_CNT == 16) begin
						CPU_CHAR_CNT = CPU_CHAR_CNT + 1;
						CPU_Y_CNT = 0;
					end

					if(CPU_CHAR_CNT == 10) begin
						CPU_CHAR_CNT = 0;
						CPU_ABS_POS_Y = CPU_ABS_POS_Y + 42;
						CPU_PRINTED = CPU_PRINTED + 1;
					end
				end
			end

		end
		else begin
			boxX = 0;
			boxY = 0;
			relPosY = 0;
			entered = 0;
			characterCNT = 0;
			absPosX = upperX;
			absPosY = upperY;
            CPU_CHAR_CNT = 0;
            CPU_Y_CNT = 0;
            CPU_PRINTED = 0;
			CPU_ABS_POS_Y = 123;
			CPU_ABS_POS_X = 24;
		end
	end


/*****************************************************************************
 *                           VGA ASCII initialization 				         *
 *****************************************************************************/

	always @(posedge reset) begin
		ASCII[0][0] = 0;
		ASCII[0][1] = 0;
		ASCII[0][2] = 0;
		ASCII[0][3] = 0;
		ASCII[0][4] = 0;
		ASCII[0][5] = 0;
		ASCII[0][6] = 0;
		ASCII[0][7] = 0;
		ASCII[0][8] = 0;
		ASCII[0][9] = 0;
		ASCII[0][10] = 0;
		ASCII[0][11] = 0;
		ASCII[0][12] = 0;
		ASCII[0][13] = 0;
		ASCII[0][14] = 0;
		ASCII[0][15] = 0;

		ASCII[1][0] = 0;
		ASCII[1][1] = 0;
		ASCII[1][2] = 0;
		ASCII[1][3] = 0;
		ASCII[1][4] = 0;
		ASCII[1][5] = 5456;
		ASCII[1][6] = 20500;
		ASCII[1][7] = 5460;
		ASCII[1][8] = 20;
		ASCII[1][9] = 20;
		ASCII[1][10] = 20500;
		ASCII[1][11] = 20564;
		ASCII[1][12] = 5396;
		ASCII[1][13] = 0;
		ASCII[1][14] = 0;
		ASCII[1][15] = 0;

		ASCII[2][0] = 0;
		ASCII[2][1] = 0;
		ASCII[2][2] = 20480;
		ASCII[2][3] = 20480;
		ASCII[2][4] = 20480;
		ASCII[2][5] = 20816;
		ASCII[2][6] = 21524;
		ASCII[2][7] = 20500;
		ASCII[2][8] = 20500;
		ASCII[2][9] = 20500;
		ASCII[2][10] = 20500;
		ASCII[2][11] = 21524;
		ASCII[2][12] = 20816;
		ASCII[2][13] = 0;
		ASCII[2][14] = 0;
		ASCII[2][15] = 0;

		ASCII[3][0] = 0;
		ASCII[3][1] = 0;
		ASCII[3][2] = 0;
		ASCII[3][3] = 0;
		ASCII[3][4] = 0;
		ASCII[3][5] = 5456;
		ASCII[3][6] = 20500;
		ASCII[3][7] = 20480;
		ASCII[3][8] = 20480;
		ASCII[3][9] = 20480;
		ASCII[3][10] = 20480;
		ASCII[3][11] = 20500;
		ASCII[3][12] = 5456;
		ASCII[3][13] = 0;
		ASCII[3][14] = 0;
		ASCII[3][15] = 0;

		ASCII[4][0] = 0;
		ASCII[4][1] = 0;
		ASCII[4][2] = 20;
		ASCII[4][3] = 20;
		ASCII[4][4] = 20;
		ASCII[4][5] = 5396;
		ASCII[4][6] = 20;
		ASCII[4][7] = 20564;
		ASCII[4][8] = 20500;
		ASCII[4][9] = 20500;
		ASCII[4][10] = 20564;
		ASCII[4][11] = 20;
		ASCII[4][12] = 5396;
		ASCII[4][13] = 0;
		ASCII[4][14] = 0;
		ASCII[4][15] = 0;

		ASCII[5][0] = 0;
		ASCII[5][1] = 0;
		ASCII[5][2] = 0;
		ASCII[5][3] = 0;
		ASCII[5][4] = 0;
		ASCII[5][5] = 5456;
		ASCII[5][6] = 20500;
		ASCII[5][7] = 21844;
		ASCII[5][8] = 20480;
		ASCII[5][9] = 20480;
		ASCII[5][10] = 20480;
		ASCII[5][11] = 20500;
		ASCII[5][12] = 5456;
		ASCII[5][13] = 0;
		ASCII[5][14] = 0;
		ASCII[5][15] = 0;

		ASCII[6][0] = 0;
		ASCII[6][1] = 0;
		ASCII[6][2] = 256;
		ASCII[6][3] = 5120;
		ASCII[6][4] = 5120;
		ASCII[6][5] = 21760;
		ASCII[6][6] = 5120;
		ASCII[6][7] = 5120;
		ASCII[6][8] = 5120;
		ASCII[6][9] = 5120;
		ASCII[6][10] = 5120;
		ASCII[6][11] = 5120;
		ASCII[6][12] = 5120;
		ASCII[6][13] = 0;
		ASCII[6][14] = 0;
		ASCII[6][15] = 0;

		ASCII[7][0] = 0;
		ASCII[7][1] = 0;
		ASCII[7][2] = 0;
		ASCII[7][3] = 0;
		ASCII[7][4] = 0;
		ASCII[7][5] = 5396;
		ASCII[7][6] = 20564;
		ASCII[7][7] = 20500;
		ASCII[7][8] = 20500;
		ASCII[7][9] = 20500;
		ASCII[7][10] = 20500;
		ASCII[7][11] = 20564;
		ASCII[7][12] = 5396;
		ASCII[7][13] = 20;
		ASCII[7][14] = 20;
		ASCII[7][15] = 21840;

		ASCII[8][0] = 0;
		ASCII[8][1] = 0;
		ASCII[8][2] = 20480;
		ASCII[8][3] = 20480;
		ASCII[8][4] = 20480;
		ASCII[8][5] = 20816;
		ASCII[8][6] = 21524;
		ASCII[8][7] = 20500;
		ASCII[8][8] = 20500;
		ASCII[8][9] = 20500;
		ASCII[8][10] = 20500;
		ASCII[8][11] = 20500;
		ASCII[8][12] = 20500;
		ASCII[8][13] = 0;
		ASCII[8][14] = 0;
		ASCII[8][15] = 0;

		ASCII[9][0] = 0;
		ASCII[9][1] = 0;
		ASCII[9][2] = 20480;
		ASCII[9][3] = 0;
		ASCII[9][4] = 0;
		ASCII[9][5] = 20480;
		ASCII[9][6] = 20480;
		ASCII[9][7] = 20480;
		ASCII[9][8] = 20480;
		ASCII[9][9] = 20480;
		ASCII[9][10] = 20480;
		ASCII[9][11] = 20480;
		ASCII[9][12] = 20480;
		ASCII[9][13] = 0;
		ASCII[9][14] = 0;
		ASCII[9][15] = 0;

		ASCII[10][0] = 0;
		ASCII[10][1] = 0;
		ASCII[10][2] = 20480;
		ASCII[10][3] = 0;
		ASCII[10][4] = 0;
		ASCII[10][5] = 20480;
		ASCII[10][6] = 20480;
		ASCII[10][7] = 20480;
		ASCII[10][8] = 20480;
		ASCII[10][9] = 20480;
		ASCII[10][10] = 20480;
		ASCII[10][11] = 20480;
		ASCII[10][12] = 20480;
		ASCII[10][13] = 20480;
		ASCII[10][14] = 20480;
		ASCII[10][15] = 0;

		ASCII[11][0] = 0;
		ASCII[11][1] = 0;
		ASCII[11][2] = 20480;
		ASCII[11][3] = 20480;
		ASCII[11][4] = 20480;
		ASCII[11][5] = 20560;
		ASCII[11][6] = 20736;
		ASCII[11][7] = 21504;
		ASCII[11][8] = 20736;
		ASCII[11][9] = 20736;
		ASCII[11][10] = 20736;
		ASCII[11][11] = 20736;
		ASCII[11][12] = 20560;
		ASCII[11][13] = 0;
		ASCII[11][14] = 0;
		ASCII[11][15] = 0;

		ASCII[12][0] = 0;
		ASCII[12][1] = 0;
		ASCII[12][2] = 20480;
		ASCII[12][3] = 20480;
		ASCII[12][4] = 20480;
		ASCII[12][5] = 20480;
		ASCII[12][6] = 20480;
		ASCII[12][7] = 20480;
		ASCII[12][8] = 20480;
		ASCII[12][9] = 20480;
		ASCII[12][10] = 20480;
		ASCII[12][11] = 20480;
		ASCII[12][12] = 20480;
		ASCII[12][13] = 0;
		ASCII[12][14] = 0;
		ASCII[12][15] = 0;

		ASCII[13][0] = 0;
		ASCII[13][1] = 0;
		ASCII[13][2] = 0;
		ASCII[13][3] = 0;
		ASCII[13][4] = 0;
		ASCII[13][5] = 21840;
		ASCII[13][6] = 20500;
		ASCII[13][7] = 20500;
		ASCII[13][8] = 20500;
		ASCII[13][9] = 20500;
		ASCII[13][10] = 20500;
		ASCII[13][11] = 20500;
		ASCII[13][12] = 20500;
		ASCII[13][13] = 0;
		ASCII[13][14] = 0;
		ASCII[13][15] = 0;

		ASCII[14][0] = 0;
		ASCII[14][1] = 0;
		ASCII[14][2] = 0;
		ASCII[14][3] = 0;
		ASCII[14][4] = 0;
		ASCII[14][5] = 5456;
		ASCII[14][6] = 16404;
		ASCII[14][7] = 20500;
		ASCII[14][8] = 20500;
		ASCII[14][9] = 20500;
		ASCII[14][10] = 20500;
		ASCII[14][11] = 16388;
		ASCII[14][12] = 5456;
		ASCII[14][13] = 0;
		ASCII[14][14] = 0;
		ASCII[14][15] = 0;

		ASCII[15][0] = 0;
		ASCII[15][1] = 0;
		ASCII[15][2] = 0;
		ASCII[15][3] = 0;
		ASCII[15][4] = 0;
		ASCII[15][5] = 16720;
		ASCII[15][6] = 21524;
		ASCII[15][7] = 16404;
		ASCII[15][8] = 16404;
		ASCII[15][9] = 21524;
		ASCII[15][10] = 21524;
		ASCII[15][11] = 21844;
		ASCII[15][12] = 16720;
		ASCII[15][13] = 16384;
		ASCII[15][14] = 16384;
		ASCII[15][15] = 16384;

		ASCII[16][0] = 0;
		ASCII[16][1] = 0;
		ASCII[16][2] = 0;
		ASCII[16][3] = 0;
		ASCII[16][4] = 0;
		ASCII[16][5] = 5396;
		ASCII[16][6] = 20564;
		ASCII[16][7] = 20500;
		ASCII[16][8] = 20500;
		ASCII[16][9] = 20500;
		ASCII[16][10] = 20500;
		ASCII[16][11] = 20564;
		ASCII[16][12] = 5396;
		ASCII[16][13] = 20;
		ASCII[16][14] = 20;
		ASCII[16][15] = 20;

		ASCII[17][0] = 0;
		ASCII[17][1] = 0;
		ASCII[17][2] = 0;
		ASCII[17][3] = 0;
		ASCII[17][4] = 0;
		ASCII[17][5] = 20736;
		ASCII[17][6] = 21504;
		ASCII[17][7] = 20480;
		ASCII[17][8] = 20480;
		ASCII[17][9] = 20480;
		ASCII[17][10] = 20480;
		ASCII[17][11] = 20480;
		ASCII[17][12] = 20480;
		ASCII[17][13] = 0;
		ASCII[17][14] = 0;
		ASCII[17][15] = 0;

		ASCII[18][0] = 0;
		ASCII[18][1] = 0;
		ASCII[18][2] = 0;
		ASCII[18][3] = 0;
		ASCII[18][4] = 0;
		ASCII[18][5] = 5456;
		ASCII[18][6] = 20500;
		ASCII[18][7] = 5376;
		ASCII[18][8] = 80;
		ASCII[18][9] = 20500;
		ASCII[18][10] = 20500;
		ASCII[18][11] = 20500;
		ASCII[18][12] = 5456;
		ASCII[18][13] = 0;
		ASCII[18][14] = 0;
		ASCII[18][15] = 0;

		ASCII[19][0] = 0;
		ASCII[19][1] = 0;
		ASCII[19][2] = 20480;
		ASCII[19][3] = 20480;
		ASCII[19][4] = 20480;
		ASCII[19][5] = 21504;
		ASCII[19][6] = 20480;
		ASCII[19][7] = 20480;
		ASCII[19][8] = 20480;
		ASCII[19][9] = 20480;
		ASCII[19][10] = 20480;
		ASCII[19][11] = 20480;
		ASCII[19][12] = 21504;
		ASCII[19][13] = 0;
		ASCII[19][14] = 0;
		ASCII[19][15] = 0;

		ASCII[20][0] = 0;
		ASCII[20][1] = 0;
		ASCII[20][2] = 0;
		ASCII[20][3] = 0;
		ASCII[20][4] = 0;
		ASCII[20][5] = 20500;
		ASCII[20][6] = 20500;
		ASCII[20][7] = 20500;
		ASCII[20][8] = 20500;
		ASCII[20][9] = 20500;
		ASCII[20][10] = 20500;
		ASCII[20][11] = 20564;
		ASCII[20][12] = 5396;
		ASCII[20][13] = 0;
		ASCII[20][14] = 0;
		ASCII[20][15] = 0;

		ASCII[21][0] = 0;
		ASCII[21][1] = 0;
		ASCII[21][2] = 0;
		ASCII[21][3] = 0;
		ASCII[21][4] = 0;
		ASCII[21][5] = 20500;
		ASCII[21][6] = 20500;
		ASCII[21][7] = 20500;
		ASCII[21][8] = 20500;
		ASCII[21][9] = 5200;
		ASCII[21][10] = 5200;
		ASCII[21][11] = 256;
		ASCII[21][12] = 256;
		ASCII[21][13] = 0;
		ASCII[21][14] = 0;
		ASCII[21][15] = 0;

		ASCII[22][0] = 0;
		ASCII[22][1] = 0;
		ASCII[22][2] = 0;
		ASCII[22][3] = 0;
		ASCII[22][4] = 0;
		ASCII[22][5] = 20500;
		ASCII[22][6] = 5200;
		ASCII[22][7] = 1344;
		ASCII[22][8] = 256;
		ASCII[22][9] = 256;
		ASCII[22][10] = 5200;
		ASCII[22][11] = 21584;
		ASCII[22][12] = 20500;
		ASCII[22][13] = 0;
		ASCII[22][14] = 0;
		ASCII[22][15] = 0;

		ASCII[23][0] = 0;
		ASCII[23][1] = 0;
		ASCII[23][2] = 0;
		ASCII[23][3] = 0;
		ASCII[23][4] = 0;
		ASCII[23][5] = 20500;
		ASCII[23][6] = 20500;
		ASCII[23][7] = 5200;
		ASCII[23][8] = 5200;
		ASCII[23][9] = 256;
		ASCII[23][10] = 256;
		ASCII[23][11] = 256;
		ASCII[23][12] = 256;
		ASCII[23][13] = 256;
		ASCII[23][14] = 256;
		ASCII[23][15] = 5120;

		ASCII[24][0] = 0;
		ASCII[24][1] = 0;
		ASCII[24][2] = 0;
		ASCII[24][3] = 0;
		ASCII[24][4] = 0;
		ASCII[24][5] = 21844;
		ASCII[24][6] = 80;
		ASCII[24][7] = 256;
		ASCII[24][8] = 256;
		ASCII[24][9] = 256;
		ASCII[24][10] = 256;
		ASCII[24][11] = 5120;
		ASCII[24][12] = 21844;
		ASCII[24][13] = 0;
		ASCII[24][14] = 0;
		ASCII[24][15] = 0;

		ASCII[25][0] = 0;
		ASCII[25][1] = 0;
		ASCII[25][2] = 5456;
		ASCII[25][3] = 20500;
		ASCII[25][4] = 20500;
		ASCII[25][5] = 20500;
		ASCII[25][6] = 20500;
		ASCII[25][7] = 20500;
		ASCII[25][8] = 20500;
		ASCII[25][9] = 20500;
		ASCII[25][10] = 20500;
		ASCII[25][11] = 20500;
		ASCII[25][12] = 5456;
		ASCII[25][13] = 0;
		ASCII[25][14] = 0;
		ASCII[25][15] = 0;

		ASCII[26][0] = 0;
		ASCII[26][1] = 0;
		ASCII[26][2] = 256;
		ASCII[26][3] = 256;
		ASCII[26][4] = 5376;
		ASCII[26][5] = 20736;
		ASCII[26][6] = 256;
		ASCII[26][7] = 256;
		ASCII[26][8] = 256;
		ASCII[26][9] = 256;
		ASCII[26][10] = 256;
		ASCII[26][11] = 256;
		ASCII[26][12] = 256;
		ASCII[26][13] = 0;
		ASCII[26][14] = 0;
		ASCII[26][15] = 0;

		ASCII[27][0] = 0;
		ASCII[27][1] = 0;
		ASCII[27][2] = 5456;
		ASCII[27][3] = 20500;
		ASCII[27][4] = 20;
		ASCII[27][5] = 20;
		ASCII[27][6] = 20;
		ASCII[27][7] = 20;
		ASCII[27][8] = 20;
		ASCII[27][9] = 80;
		ASCII[27][10] = 256;
		ASCII[27][11] = 5120;
		ASCII[27][12] = 21844;
		ASCII[27][13] = 0;
		ASCII[27][14] = 0;
		ASCII[27][15] = 0;

		ASCII[28][0] = 0;
		ASCII[28][1] = 0;
		ASCII[28][2] = 5456;
		ASCII[28][3] = 20500;
		ASCII[28][4] = 20;
		ASCII[28][5] = 20;
		ASCII[28][6] = 5456;
		ASCII[28][7] = 20;
		ASCII[28][8] = 20;
		ASCII[28][9] = 20;
		ASCII[28][10] = 20;
		ASCII[28][11] = 20500;
		ASCII[28][12] = 5456;
		ASCII[28][13] = 0;
		ASCII[28][14] = 0;
		ASCII[28][15] = 0;

		ASCII[29][0] = 0;
		ASCII[29][1] = 0;
		ASCII[29][2] = 80;
		ASCII[29][3] = 336;
		ASCII[29][4] = 80;
		ASCII[29][5] = 5200;
		ASCII[29][6] = 5200;
		ASCII[29][7] = 5200;
		ASCII[29][8] = 20560;
		ASCII[29][9] = 21844;
		ASCII[29][10] = 80;
		ASCII[29][11] = 80;
		ASCII[29][12] = 80;
		ASCII[29][13] = 0;
		ASCII[29][14] = 0;
		ASCII[29][15] = 0;

		ASCII[30][0] = 0;
		ASCII[30][1] = 0;
		ASCII[30][2] = 5460;
		ASCII[30][3] = 5120;
		ASCII[30][4] = 5120;
		ASCII[30][5] = 20480;
		ASCII[30][6] = 21840;
		ASCII[30][7] = 20;
		ASCII[30][8] = 20;
		ASCII[30][9] = 20;
		ASCII[30][10] = 20;
		ASCII[30][11] = 20500;
		ASCII[30][12] = 5456;
		ASCII[30][13] = 0;
		ASCII[30][14] = 0;
		ASCII[30][15] = 0;

		ASCII[31][0] = 0;
		ASCII[31][1] = 0;
		ASCII[31][2] = 5456;
		ASCII[31][3] = 20500;
		ASCII[31][4] = 20480;
		ASCII[31][5] = 20480;
		ASCII[31][6] = 21840;
		ASCII[31][7] = 20500;
		ASCII[31][8] = 20500;
		ASCII[31][9] = 20500;
		ASCII[31][10] = 20500;
		ASCII[31][11] = 20500;
		ASCII[31][12] = 5456;
		ASCII[31][13] = 0;
		ASCII[31][14] = 0;
		ASCII[31][15] = 0;

		ASCII[32][0] = 0;
		ASCII[32][1] = 0;
		ASCII[32][2] = 21844;
		ASCII[32][3] = 80;
		ASCII[32][4] = 80;
		ASCII[32][5] = 80;
		ASCII[32][6] = 80;
		ASCII[32][7] = 256;
		ASCII[32][8] = 256;
		ASCII[32][9] = 5120;
		ASCII[32][10] = 5120;
		ASCII[32][11] = 5120;
		ASCII[32][12] = 5120;
		ASCII[32][13] = 0;
		ASCII[32][14] = 0;
		ASCII[32][15] = 0;

		ASCII[33][0] = 0;
		ASCII[33][1] = 0;
		ASCII[33][2] = 5456;
		ASCII[33][3] = 20500;
		ASCII[33][4] = 20500;
		ASCII[33][5] = 0;
		ASCII[33][6] = 5456;
		ASCII[33][7] = 16388;
		ASCII[33][8] = 20500;
		ASCII[33][9] = 20500;
		ASCII[33][10] = 20500;
		ASCII[33][11] = 16388;
		ASCII[33][12] = 5456;
		ASCII[33][13] = 0;
		ASCII[33][14] = 0;
		ASCII[33][15] = 0;

		ASCII[34][0] = 0;
		ASCII[34][1] = 0;
		ASCII[34][2] = 5456;
		ASCII[34][3] = 16388;
		ASCII[34][4] = 20500;
		ASCII[34][5] = 20500;
		ASCII[34][6] = 20500;
		ASCII[34][7] = 16404;
		ASCII[34][8] = 5460;
		ASCII[34][9] = 20;
		ASCII[34][10] = 20;
		ASCII[34][11] = 20500;
		ASCII[34][12] = 5456;
		ASCII[34][13] = 0;
		ASCII[34][14] = 0;
		ASCII[34][15] = 0;

		ASCII[35][0] = 0;
		ASCII[35][1] = 0;
		ASCII[35][2] = 16384;
		ASCII[35][3] = 5120;
		ASCII[35][4] = 5120;
		ASCII[35][5] = 256;
		ASCII[35][6] = 256;
		ASCII[35][7] = 256;
		ASCII[35][8] = 256;
		ASCII[35][9] = 256;
		ASCII[35][10] = 256;
		ASCII[35][11] = 256;
		ASCII[35][12] = 256;
		ASCII[35][13] = 5120;
		ASCII[35][14] = 20480;
		ASCII[35][15] = 16384;

		ASCII[36][0] = 0;
		ASCII[36][1] = 0;
		ASCII[36][2] = 0;
		ASCII[36][3] = 0;
		ASCII[36][4] = 0;
		ASCII[36][5] = 0;
		ASCII[36][6] = 0;
		ASCII[36][7] = 0;
		ASCII[36][8] = 0;
		ASCII[36][9] = 21760;
		ASCII[36][10] = 0;
		ASCII[36][11] = 0;
		ASCII[36][12] = 0;
		ASCII[36][13] = 0;
		ASCII[36][14] = 0;
		ASCII[36][15] = 0;

		ASCII[37][0] = 0;
		ASCII[37][1] = 0;
		ASCII[37][2] = 256;
		ASCII[37][3] = 5120;
		ASCII[37][4] = 0;
		ASCII[37][5] = 20480;
		ASCII[37][6] = 20480;
		ASCII[37][7] = 20480;
		ASCII[37][8] = 20480;
		ASCII[37][9] = 20480;
		ASCII[37][10] = 20480;
		ASCII[37][11] = 20480;
		ASCII[37][12] = 20480;
		ASCII[37][13] = 5120;
		ASCII[37][14] = 5120;
		ASCII[37][15] = 256;
	end


endmodule




module line_Mem_Parser(input wire[79:0] data, output wire[7:0]o1,o2,o3,o4,o5,o6,o7,o8,o9,o10);
	assign o1 = data[79:72];
	assign o2 = data[71:64];
	assign o3 = data[63:56];
	assign o4 = data[55:48];
	assign o5 = data[47:40];
	assign o6 = data[39:32];
	assign o7 = data[31:24];
	assign o8 = data[23:16];
	assign o9 = data[15:8];
	assign o10 = data[7:0];
endmodule
