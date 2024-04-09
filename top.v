//HUGE CHANGE of plans not possible if the numbers are not stored in ascii vga can't update fast enough
//thus we need another memory that would store the numbers. We will have a module that comes right before VGA and converts all memory into ASCII


module top(input CLOCK_50, inout PS2_CLK, PS2_DAT, PS2_CLK2, PS2_DAT2, 
						output [9:0]VGA_B, VGA_R, VGA_G,
						output VGA_HS, VGA_VS, VGA_SYNC_N, VGA_CLK, VGA_BLANK_N, 
						input [3:0]KEY,
						input [9:0]SW
						,output [9:0]LEDR,
						input AUD_ADCDAT,
						inout AUD_BCLK, AUD_ADCLRCK, AUD_DACLRCK, FPGA_I2C_SDAT,
						output AUD_XCK, AUD_DACDAT, FPGA_I2C_SCLK,
						output wire [6:0] HEX0, HEX1, HEX2, HEX3, HEX4, HEX5);
	wire reset;
	assign reset = !KEY[0];

	//mouse to VGA 
	wire [9:0] POS_X, POS_Y;
	//mouse to keybaord;
	wire [5:0] SELECTED_ZONE;
	wire O_selection;
	
	//CPU to VGA
	wire[4:0] C_FETCH;
	wire[79:0] C_EXEC;
	wire[51:0] C_ACCUM;
	wire CPU_ERROR;
	wire [1:0]  CPU_STATE;

	assign C_FETCH = I_PROG_ADDRESS;

	//Memory to CPU
	wire W_EN_MEM;
	wire[4:0] I_MEM_ADDRESS, I_PROG_ADDRESS;
	wire[79:0] I_PROG_REQ;
	wire[63:0] I_MEM;
	wire [51:0] I_MEM_REQ;
	wire IO_DISABLED;
	
	//ratedividercpu
	wire enable, enable2;

	//while cpu isn't here
	//assign W_EN_MEM = 0;

	//CPU CONTROLS
	parameter UI = 2'd0;
	parameter CPU = 2'd1;

	reg[1:0] state = 0;
	
	wire CPU_START, CPU_SPEEDUP, CPU_STEP, CPU_RESET;
	reg rCPU_START, rCPU_SPEEDUP, rCPU_STEP, rCPU_RESET;
	reg r_resetMEM = 0;

	assign CPU_START = rCPU_START;
	assign CPU_SPEEDUP = rCPU_SPEEDUP;
	assign CPU_STEP = rCPU_STEP;
	assign CPU_RESET = rCPU_RESET;
	
	always @(posedge CLOCK_50) begin
		if(reset) begin
			rCPU_START = 0;
			state = 0;
		end
		r_resetMEM = 0;
		rCPU_STEP = 0;
		rCPU_SPEEDUP = 0;
		rCPU_STEP = 0;
		if(O_selection) begin
			case(SELECTED_ZONE)
				1: begin
					//speed up the cpu.
					if(state == CPU) begin
						rCPU_SPEEDUP = 1;
					end
				end
				5: begin
					//start the program
					rCPU_START = 1;
					state = 1;
				end
				6: begin
					//step over
					if(state == CPU) begin
						rCPU_STEP = 1;
					end
				end
				7: begin
					//reset
					if(state == CPU) begin
						r_resetMEM = 1;
						state = UI;
					end
				end
				8: begin
					//stop the program
					//note the CPU should also reset the speed to 1.
					if(state == CPU) begin
						rCPU_START = 0;
					end
				end
			endcase
		end
	end
	
	
	
	
	MemoryController memorycontroller(.CLOCK_50(CLOCK_50),
						 .W_EN_MEM(W_EN_MEM && CPU_START && ~CPU_ERROR), 
						 .I_PROG_ADDRESS(I_PROG_ADDRESS), 
						 .I_MEM_ADDRESS(I_MEM_ADDRESS),
						 .I_MEM(I_MEM),
						 .IO_DISABLED(IO_DISABLED),
						 .I_PROG_REQ(I_PROG_REQ), .I_MEM_REQ(I_MEM_REQ), 
						 .reset(reset), .SELECTED_ZONE(SELECTED_ZONE), .PS2_CLK(PS2_CLK2), .PS2_DAT(PS2_DAT2),
						 .VGA_B(VGA_B), .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_HS(VGA_HS),
						 .VGA_VS(VGA_VS), .VGA_SYNC_N(VGA_SYNC_N), .VGA_CLK(VGA_CLK), .VGA_BLANK_N(VGA_BLANK_N),
						 .C_FETCH(C_FETCH), .C_EXEC(C_EXEC),
						 .C_ACCUM(C_ACCUM), .POS_X(POS_X), .POS_Y(POS_Y),
						 .CPU_STATE(CPU_STATE), .CPU_ERROR(CPU_ERROR));
	
	Mouse mouse(.CLOCK_50(CLOCK_50), .PS2_CLK(PS2_CLK), .PS2_DAT(PS2_DAT), .POS_X(POS_X), .POS_Y(POS_Y),
					.W_SELECTED_ZONE(SELECTED_ZONE), .O_selection(O_selection));

	assign LEDR[5] = W_EN_MEM;
	assign LEDR[4:0] = I_PROG_ADDRESS;
	assign LEDR[7] = CPU_ERROR;
	assign LEDR[6] = reset;
	assign LEDR[9:8] = CPU_STATE;
	assign HEX0 = I_MEM[6:0];
	assign HEX1 = I_MEM[13:7];
	assign HEX2 = I_MEM[20:14];
	assign HEX3 = I_MEM[27:21];
	assign HEX4 = I_MEM[34:28];
	assign HEX5 = I_MEM[41:35];
	
	
	
	
	
	//remember to revert to I_MEM
	cpu u17(.clk(enable2), .reset(reset), .programcommand(I_PROG_REQ), .readable(!(IO_DISABLED)), .memoryval(I_MEM_REQ),
				.CPU_RUN(CPU_START), .CPU_STEP(!KEY[3]), .enable(enable),
				.memory_address(I_MEM_ADDRESS), .accumuvalue(C_ACCUM), .setmemory(I_MEM), .outstate(CPU_STATE), .program_counter(I_PROG_ADDRESS), .instruction_reg(C_EXEC), .error(CPU_ERROR), .setmem(W_EN_MEM));


	rate_divider #(.CLOCK_FREQUENCY(50000000) ) u18(.ClockIn(CLOCK_50), .Reset(reset), .ff(!KEY[2]), .Enable(enable));
	rate_test #(.CLOCK_FREQUENCY(50000000) ) u19(.ClockIn(CLOCK_50), .Reset(reset), .Enable(enable2));
							
endmodule


