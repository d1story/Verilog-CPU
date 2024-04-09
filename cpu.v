module cpu(input clk, input reset, input [79:0] programcommand, input readable, input [51:0] memoryval,
input CPU_RUN, input CPU_STEP, input enable,
output wire [4:0] memory_address, output wire [51:0] accumuvalue, output reg [63:0] setmemory, output wire [1:0] outstate, output wire [4:0] program_counter, output wire [79:0] instruction_reg, output wire error, output setmem);

	wire [3:0] commandwire;
	wire decodewire, scalarwire, initializewire, checkSpacewire, checkSpace2wire, checkSpace3wire, checkSpaceJw, checkcommw, finaladdw;
	wire errorwire1, errorwire2;
	wire [4:0] setcounterw;
	wire ldx1wire, ldx2wire, ldy1wire, ldy2wire, lax1w, lax2w, ldpc1w, ldpc2w;
	wire ms5w, ms4w, ms3w, ms2w, ls5w, ls4w, ls3w, ls2w, ls1w;
	wire multiw, multixw, multiyw, multipcw;
	wire jumpw;
	wire memorygetter;
	wire decodefinish, cyclefinish;

	wire ldaccw, vgw, ldaddw, ldsbw, ldmltw, ldvw, ldtw, lcrw, lngw, pausew;
	wire imemw,sendaccw, ioutw;
	wire setmem1, setmem2, setmem3;
	wire [63:0] setcountervalue, valueout;
	wire useCNTwire;


	fsm u0(.clk(clk), .enable(enable), .reset(reset), .CPU_RUN(CPU_RUN), .CPU_STEP(CPU_STEP), .finish_decode(decodefinish), .error(errorwire1 || errorwire2), .memoryavailable(readable), .filter_command(commandwire), 
.get_mem(memorygetter), .finish(cyclefinish), .decode(decodewire), .valuegetter(vgw), .ldacc(ldaccw), 
.ldadd(ldaddw), .ldsb(ldsbw), .ldmlt(ldmltw), .ldv(ldvw), .ldt(ldtw), .lcr(lcrw), .lng(lngw),
.initialize_mem(imemw), 
.sendacc(sendaccw), .initialout(ioutw), .pause(pausew), .outstate(outstate));

	cpu_datapath u1(.clk(clk), .reset(reset), .memory(memoryval), .programmemory(programcommand), 
.ldacc(ldaccw), .valuegetter(vgw), .get_mem(memorygetter), .ldadd(ldaddw), .ldsb(ldsbw), .ldmlt(ldmltw), .ldv(ldvw), .ldt(ldtw), .lcr(lcrw), .lng(lngw), .initialize_mem(imemw), .sendacc(sendaccw), .pause(pausew),
.accumulator(accumuvalue), .instructionreg(instruction_reg),
.readytostore(setmem1),
.error(errorwire2));

	decoder_machine u2(.clk(clk), .reset(reset), .use_memory(readable), .decode(decodewire), .scalar(scalarwire), .error(error), .initialize(initializewire), .jumping(jumpw), .checkSpace(checkSpacewire), .checkSpace2(checkSpace2wire), .checkSpace3(checkSpace3wire), .ldx1(ldx1wire), .ldx2(ldx2wire), .ldy1(ldy1wire), .ldy2(ldy2wire), .lax1(lax1w), .lax2(lax2w),
.ms5(ms5w), .ms4(ms4w), .ms3(ms3w), .ms2(ms2w), .ls5(ls5w), .ls4(ls4w), .ls3(ls3w), .ls2(ls2w), .ls1(ls1w),
.multli(multiw), .multix(multixw), .multiy(multiyw), .multipc(multipcw), .ldpc1(ldpc1w), .ldpc2(ldpc2w), .checkSpaceJ(checkSpaceJw), .finish(decodefinish), .finaladd(finaladdw), .checkCommand(checkcommw));

	decoder u3(.clk(clk), .reset(reset), .decode(decodewire), .checkCommand(checkcommw), .checkSpace(checkSpacewire), .checkSpace2(checkSpace2wire), .checkSpace3(checkSpace3wire), .checkSpaceJ(checkSpaceJw), .program_value(programcommand), .ldx1(ldx1wire), .ldx2(ldx2wire), .ldy1(ldy1wire), .ldy2(ldy2wire), .lax1(lax1w), .lax2(lax2w), .ldpc1(ldpc1w), .ldpc2(ldpc2w),
.ms5(ms5w), .ms4(ms4w), .ms3(ms3w), .ms2(ms2w), .ls5(ls5w), .ls4(ls4w), .ls3(ls3w), .ls2(ls2w), .ls1(ls1w),
.multli(multiw), .multix(multixw), .multiy(multiyw), .multipc(multipcw), .finaladd(finaladdw),
.command(commandwire), .finish(decodefinish), .value(valueout), .mem_index(memory_address), .program_counter(setcounterw), .error(errorwire1), .initialize(initializewire), .scalar(scalarwire), .jumping(jumpw));

program_counter u4(.clk(clk), .reset(reset), .finishcycle(cyclefinish), .jumping(jumpw), .mem_value(memoryval), .setcounter(setcounterw), .programcounter(program_counter), .newmem_value(setcountervalue), .writing(setmem3), .useCNT(useCNTwire));

assign setmem = sendaccw  || setmem3 || ioutw;
assign error = errorwire1 || errorwire2;

always@(*) begin
	//if(useCNTwire) setmemory = setcountervalue;
	
	//else 
	//setmemory = valueout;

	if(sendaccw) setmemory = accumuvalue;

	else setmemory = valueout;

end


endmodule





module fsm(input clk, input enable, input reset, input CPU_RUN, input CPU_STEP, input finish_decode, input memoryavailable, input [3:0] filter_command, input error,
output reg get_mem, output reg finish, output reg decode, output reg valuegetter, output reg ldacc, 
output reg ldadd, output reg ldsb, output reg ldmlt, output reg ldv,output reg ldt, output reg lcr, output reg lng,
output reg initialize_mem, 
output reg sendacc, output reg initialout, output reg pause, output reg [1:0] outstate);

	reg [4:0] current_state;
	reg [4:0] next_state;
	reg [5:0] iwaittime;
	reg iwaitfinish;


	localparam
		FETCH = 5'd0,
		DECODE = 5'd1,
		GETVALUE = 5'd2,
		EXECUTE = 5'd3,
		LOAD = 5'd4,
		ADD = 5'd5,
		SUBTRACT = 5'd6,
		MULTIPLY = 5'd7,
		DIVIDE = 5'd8,
		DOT = 5'd9,
		CROSS = 5'd10,
		ANGLE = 5'd11,
		STORE = 5'd12,
		JUMP = 5'd13,
		INITIALIZE = 5'd14,
		PAUSE = 5'd15,
		WAITFETCH = 5'd16,
		INITIALIZE_OUT = 5'd17,
		ERROR = 5'd18;
		
		
		always@(posedge clk) begin
		if(reset) begin
			iwaittime <= 30;
			iwaitfinish <=0;
		end
		else if(iwaittime == 0) begin
			iwaitfinish <= 1;
			iwaittime <= 50;
		end
		else if(current_state == INITIALIZE_OUT || current_state == STORE || current_state == FETCH) begin
			iwaittime <= iwaittime - 1;
		end
		else begin
			iwaittime <= 30;
			iwaitfinish <= 0;
			end
		
		end

	always @(*)
		begin: state_table
			case (current_state)
				WAITFETCH: next_state = (memoryavailable && (CPU_RUN || CPU_STEP) && (enable || CPU_STEP)) ? FETCH : WAITFETCH;

				FETCH: next_state = ((CPU_STEP || CPU_RUN) && iwaitfinish && (CPU_STEP || enable)) ? DECODE : FETCH;
					
				DECODE:begin 
					next_state = (finish_decode && (enable || CPU_STEP) && (CPU_STEP || CPU_RUN)) ? GETVALUE : DECODE;

				end

				GETVALUE: next_state = memoryavailable ? EXECUTE : GETVALUE;
			
				EXECUTE: begin
					if(memoryavailable)begin
					if(filter_command == 0) next_state = JUMP;
					else if(filter_command == 1) next_state = INITIALIZE;
					else if(filter_command == 2) next_state = LOAD;
					else if(filter_command == 3) next_state = STORE;
					else if(filter_command == 4) next_state = ADD;
					else if(filter_command == 5) next_state = SUBTRACT;
					else if(filter_command == 6) next_state = MULTIPLY;
					else if(filter_command == 7) next_state = DIVIDE;
					else if(filter_command == 8) next_state = DOT;
					else if(filter_command == 9) next_state = CROSS;
					else if(filter_command == 10) next_state = ANGLE;
					else next_state = FETCH;
					end
					else next_state = EXECUTE;
				end

				LOAD: next_state = PAUSE;

				ADD: next_state = PAUSE;

				SUBTRACT: next_state = PAUSE;

				MULTIPLY: next_state = PAUSE;

				DIVIDE: next_state = PAUSE;

				DOT: next_state = PAUSE;

				CROSS: next_state = PAUSE;

				ANGLE: next_state = PAUSE;

				STORE: next_state = iwaitfinish ? PAUSE : STORE;

				JUMP: next_state = PAUSE;

				INITIALIZE: next_state = INITIALIZE_OUT;

				INITIALIZE_OUT: next_state = iwaitfinish ? PAUSE : INITIALIZE_OUT;

				PAUSE: begin 
				if(error == 1)begin next_state = ERROR;
				end
				else begin next_state = WAITFETCH;
				end
				end

				ERROR: next_state = ERROR;

			endcase
		end

		always @(*) begin: enable_signals
			
			get_mem = 0;
			ldacc = 0;
			decode = 0;
			initialize_mem = 0;
			valuegetter = 0;
			sendacc = 0;
			pause = 0;
			ldadd = 0;
			ldsb = 0;
			ldmlt = 0;
			ldv = 0;
			ldt = 0;
			lcr = 0;
			lng = 0;
			initialout = 0;
			finish = 0;

			case(current_state)
				WAITFETCH: begin
					outstate = 0;
				end
				
				FETCH: begin
					get_mem = 1;
					outstate = 0;
				end

				DECODE: begin
					decode = 1;
					outstate = 1;
				end

				GETVALUE: begin
					valuegetter = 1;
				end

				EXECUTE: begin
					outstate = 2;
				end

				LOAD: begin
					ldacc = 1;
					outstate = 2;
				end

				ADD: begin
					ldadd = 1;
					outstate = 2;
				end

				SUBTRACT: begin
					ldsb = 1;
					outstate = 2;
				end

				MULTIPLY: begin
					ldmlt = 1;
					outstate = 2;
				end

				DIVIDE: begin
					ldv = 1;
					outstate = 2;
				end

				DOT: begin
					ldt = 1;
					outstate = 2;
				end

				CROSS: begin
					lcr = 1;
					outstate = 2;
				end

				ANGLE: begin
					lng = 1;
					outstate = 2;
				end

				STORE: begin
					sendacc = 1;
					outstate = 2;
				end

				JUMP: begin
				outstate = 2;
				end

				INITIALIZE: begin
					initialize_mem = 1;
					outstate = 2;
				end

				INITIALIZE_OUT: begin
					initialout = 1;
					outstate = 2;
				end

				PAUSE: begin
					pause = 1;
					finish = 1;
					outstate = 2;
				end
				
				ERROR: begin
					
				end

			endcase
		end
	always @(posedge clk) begin
		if(reset) begin
			current_state <= WAITFETCH;
			
		end
		else begin
			current_state <= next_state;
		end
	end
endmodule

module program_counter(input clk, input reset, input finishcycle, input jumping, input [51:0] mem_value, input [4:0] setcounter, output reg [4:0] programcounter, output reg [51:0] newmem_value, output reg writing, output reg useCNT);
	reg [5:0] waittime;
	always @(posedge clk) begin
		if(reset) begin
			programcounter <= 0;
			writing <= 0;
			newmem_value <= 0;
			useCNT <= 0;
		end
		else if(!jumping && finishcycle)begin
			programcounter <= programcounter +1;
			writing <= 0;
			useCNT <= 0;
		end
		else if(jumping && finishcycle && mem_value != 0)begin
			programcounter <= setcounter;
		end
		else if(jumping && finishcycle && mem_value == 0)begin
			programcounter <= programcounter + 1;
		end
		else begin
			programcounter <= programcounter;
			useCNT <= 0;
		end
	end
endmodule

module cpu_datapath(input clk, input reset, input [51:0] memory, input [79:0] programmemory, 
input ldacc, input valuegetter, input get_mem, input ldadd, input ldsb, input ldmlt, input ldv, input ldt, input lcr, input lng, input initialize_mem, input sendacc, input pause,
output reg [51:0] accumulator, output reg [79:0] instructionreg,
output reg readytostore,
output reg error);
	



	always @(posedge clk) begin
	

		if(reset)begin
			accumulator <= 0;
			readytostore <= 0;
			error <= 0;
		end
		else if(get_mem) begin
			instructionreg <= programmemory;
		end
		else if(valuegetter) begin
			
		end
		else if(ldacc) begin
			accumulator <= memory;
		end
		else if(ldadd) begin
			if(accumulator[51:50] == memory[51:50])
				if(memory[51:50] == 2'b00) accumulator[49:25] <= accumulator[49:25] + memory[49:25];
				else begin
					accumulator[49:25] <= accumulator[49:25] + memory[49:25];
					accumulator[24:0] <= accumulator[24:0] + memory[24:0];
				end
			else
				error <= 1;
		end
		else if(ldsb) begin
			if(accumulator[51:50] == memory[51:50])
				if(memory[51:50] == 2'b00) accumulator[49:25] <= accumulator[49:25] - memory[49:25];
				else begin
					accumulator[49:25] <= accumulator[49:25] - memory[49:25];
					accumulator[24:0] <= accumulator[24:0] - memory[24:0];
				end
			else
				error <= 1;
		end
		else if(ldmlt) begin
			if(memory[51:50] == 2'b00 && accumulator[51:50] == 2'b00) begin
				accumulator[49:25] <= accumulator[49:25] * memory[49:25];
			end
			else begin
				accumulator[49:25] <= accumulator[49:25] * memory[49:25];
				accumulator[24:0] <= accumulator[24:0] * memory[49:25];
			end
		end
		else if(ldv) begin
			if(memory[51:50] == 2'b00 && accumulator[51:50] == 2'b00) begin
				accumulator[49:25] <= accumulator[49:25] / memory[49:25];
			end

			else begin
					accumulator[49:25] <= accumulator[49:25] / memory[49:25];
					accumulator[24:0] <= accumulator[24:0] / memory[49:25];
			end
		end
		else if(ldt) begin
			accumulator[49:0] <= accumulator[49:25] * memory[49:25] + accumulator[24:0] * memory[24:0];
			accumulator[51:0] <= 2'b00;
		end

		else if(lcr) begin
			accumulator[49:0] <= accumulator[49:25] * memory[24:0] - accumulator[24:0] * memory[49:25];
		end
		else if(lng) begin
			accumulator[49:0] <= accumulator[49:0] / memory[49:0];
		end

		else if(sendacc) begin
			readytostore <= 1;
		end
		else if(pause) begin
			readytostore <= 0;
			
		end

	end
endmodule

module decoder_machine(input clk, input reset, input use_memory, input decode, input scalar, input error, input initialize, input jumping,
output reg checkSpace, output reg checkSpace2, output reg checkSpace3, output reg ldx1, output reg ldx2, output reg ldy1, output reg ldy2, output reg lax1, output reg lax2, 
output reg ms5, output reg ms4, output reg ms3, output reg ms2, output reg ls5, output reg ls4, output reg ls3, output reg ls2, output reg ls1,
output reg multli, output reg multix, output reg multiy, output reg multipc, output reg ldpc1, output reg ldpc2, output reg checkSpaceJ, output reg finish, output reg finaladd, output reg checkCommand);

	reg [5:0] current_state, next_state;
	reg [4:0] waittime;
	reg finishwait;

	localparam
		START = 6'd0,
		FIND_COMMAND = 6'd1,
		CHECK_SPACE = 6'd2,
		LOADX = 6'd3,
		ADDX = 6'd4,
		LOADY = 6'd5,
		ADDY = 6'd6,
		CHECK_SPACE2 = 6'd7,
		CHECK_SPACE3 = 6'd8,
		iLOADADDRESS1 = 6'd9,
		iADDADDRESS2 = 6'd10,
		LOADADDRESS1 = 6'd11, 
		ADDADDRESS2 = 6'd12,
		MULTIPLYADDRESS = 6'd13,
		MULTIPLYX = 6'd14,
		MULTIPLYY = 6'd15,
		CHECK_SPACEJ = 6'd16, 
		LOADPC1 = 6'd17,
		LOADPC2 = 6'd18,
		MULTIPLYPC = 6'd19,
		LOADS5 =6'd20,
		LOADS4 =6'd21,
		LOADS3 =6'd22,
		LOADS2 =6'd23,
		LOADS1 =6'd24,
		MULTIS5= 6'd25,
		MULTIS4 =6'd26,
		MULTIS3 =6'd27,
		MULTIS2 =6'd28,
		OUTPUT = 6'd29,
		WAITFORCHECK = 6'd30,
		FINISHD = 6'd31;



		


	always @(*)
		begin: state_table
			case (current_state)

				START: next_state = decode && finishwait ? FIND_COMMAND : START;
				FIND_COMMAND: next_state = CHECK_SPACE;
				CHECK_SPACE: next_state = initialize ? iLOADADDRESS1 : LOADADDRESS1;
				LOADADDRESS1: next_state = MULTIPLYADDRESS;
				MULTIPLYADDRESS: next_state = initialize ? iADDADDRESS2 : ADDADDRESS2;
				ADDADDRESS2: next_state = jumping ? CHECK_SPACEJ : OUTPUT;
				iLOADADDRESS1: next_state = MULTIPLYADDRESS;
				iADDADDRESS2: next_state = CHECK_SPACE2;
				LOADX: next_state = MULTIPLYX;
				MULTIPLYX: next_state = ADDX;
				ADDX: next_state = LOADY;
				LOADY: next_state = MULTIPLYY;
				MULTIPLYY: next_state = ADDY;
				ADDY: next_state = OUTPUT;
				OUTPUT: next_state = FINISHD;
				FINISHD: next_state = START;
				CHECK_SPACE2: next_state = CHECK_SPACE3;
				CHECK_SPACE3: next_state = WAITFORCHECK;
				CHECK_SPACEJ: next_state = LOADPC1;
				WAITFORCHECK: next_state = scalar ? LOADS5 : LOADX;
				LOADPC1:next_state = MULTIPLYPC;
				MULTIPLYPC: next_state = LOADPC2;
				LOADPC2: next_state = OUTPUT;
				LOADS5: next_state = MULTIS5;
				LOADS4: next_state =  MULTIS4;
				LOADS3: next_state = MULTIS3;
				LOADS2: next_state = MULTIS2;
				LOADS1: next_state = OUTPUT;
				MULTIS5: next_state = LOADS4;
				MULTIS4: next_state =LOADS3;
				MULTIS3: next_state =LOADS2;
				MULTIS2: next_state =LOADS1;
				default: next_state = START;
			endcase
		end

	always @(posedge clk)begin

	if(reset) begin
		waittime <= 20;
		finishwait <= 0;
	end
	else if(waittime == 0) begin
		waittime <= 20;
		finishwait <= 1;
	end
	else if (current_state == START)begin
		waittime <= waittime - 1;
	end
	else begin
		waittime <= 20;
	end
	
	end

	

	always @(*) begin: enable_signals
		checkCommand = 0;
		checkSpace = 0;
		checkSpace2 = 0;
		checkSpace3 = 0;
		finish = 0;
		lax1 = 0;
		lax2 = 0;
		ldx1 = 0;
		ldx2 = 0;
		ldy1 = 0;
		ldy2 = 0;
		multli = 0;
		multix = 0;
		multiy = 0;
		ls5 = 0;
		ls4 = 0;
		ls3 = 0;
		ls2 = 0;
		ls1 = 0;
		ms5 = 0;
		ms4 = 0;
		ms3 = 0;
		ms2 = 0;
		checkSpaceJ = 0;
		ldpc1 = 0;
		ldpc2 = 0;
		multipc = 0;
		finaladd = 0;

		case(current_state)
			START: begin

			end

			FIND_COMMAND: checkCommand = 1;

			CHECK_SPACE: checkSpace = 1;

			CHECK_SPACE2: checkSpace2 = 1;

			CHECK_SPACE3: checkSpace3 = 1;

			LOADADDRESS1: lax1 = 1;

			ADDADDRESS2: lax2 = 1;

			MULTIPLYADDRESS: multli = 1;
			MULTIPLYX: multix = 1;
			MULTIPLYY: multiy = 1;

			iLOADADDRESS1: lax1 = 1;
			iADDADDRESS2: lax2 = 1;
			LOADX: ldx1 = 1;
			ADDX: ldx2 = 1;
			LOADY: ldy1 = 1;
			ADDY: ldy2 = 1;
			LOADS5: ls5 = 1;
			LOADS4: ls4 = 1;
			LOADS3: ls3 = 1;
			LOADS2: ls2 = 1;
			LOADS1: ls1 = 1;
			MULTIS5: ms5 = 1;
			MULTIS4: ms4 = 1;
			MULTIS3: ms3 = 1;
			MULTIS2: ms2 = 1;
			CHECK_SPACEJ: checkSpaceJ = 1;
			LOADPC1: ldpc1 = 1;
			MULTIPLYPC: multipc = 1;
			LOADPC2: ldpc2 = 1;

			OUTPUT: finaladd = 1;
			FINISHD: finish = 1;
		endcase
	end
	
	always@(posedge clk)
		begin
        	if(reset)begin
            		current_state <= START;
		end
        	else begin
			current_state <= next_state;
   		end
	end
endmodule


module decoder (input clk, input reset, input decode, input checkCommand, input checkSpace, input checkSpace2, input checkSpace3, input checkSpaceJ, input [79:0] program_value, input ldx1, input ldx2, input ldy1, input ldy2, input lax1, input lax2, input ldpc1, input ldpc2,
input ms5, input ms4, input ms3, input ms2, input ls5, input ls4, input ls3, input ls2, input ls1,
input multli, input multix, input multiy, input multipc, input finish, input finaladd,
output reg [3:0] command, output reg [63:0] value, output reg [4:0] mem_index, output reg [4:0] program_counter, output reg error, output reg initialize, output reg scalar, output reg jumping);

	reg signed [24:0] xval, yval;
	reg signed [24:0] scalareg;
	reg signed [24:0] scalaregholder;
	reg negativity;
	
	localparam
		space = 8'd0,
		a = 8'd1,
		b = 8'd2,
		c = 8'd3,
		d = 8'd4,
		e = 8'd5,
		f = 8'd6,
		g = 8'd7,
		h = 8'd8,
		i = 8'd9,
		j = 8'd10,
		k = 8'd11,
		l = 8'd12,
		n = 8'd13,
		o = 8'd14,
		p = 8'd15,
		q = 8'd16,
		r = 8'd17,
		s = 8'd18,
		t = 8'd19,
		u = 8'd20,
		v = 8'd21,
		x = 8'd22,
		y = 8'd23,
		z = 8'd24,
		zero = 8'd25,
		one = 8'd26,
		two = 8'd27,
		three = 8'd28,
		four = 8'd29,
		five = 8'd30,
		six = 8'd31,
		seven = 8'd32,
		eight = 8'd33,
		nine = 8'd34,
		left_bracket = 8'd35,
		neg_sign = 8'd36,
		right_bracket = 8'd37;



		always @(posedge clk) begin
			if(reset)begin
				command <= 0;
				xval <= 0;
				yval <= 0;
				value <= 0;
				error <= 0;
				mem_index <= 0;
				negativity <= 0;
				scalar <= 0;
				program_counter <= 0;
				initialize <= 0;
				jumping <= 0;
				scalareg <= 0;
				scalaregholder <= 0;

			end
			else if(checkCommand)begin
				scalar <= 0;
				scalareg <= 0;
				scalaregholder <= 0;
				if(program_value[79:72] == j && program_value[71:64] == p)begin
					command <= 0;
					initialize <= 0;
					jumping <= 1;
				end
				else if(program_value[79:72] == i)begin
					command <= 1;
					initialize <= 1;
					jumping <= 0;
				end
				else if(program_value[79:72] == l && program_value[71:64] == d)begin
					command <= 2;
					initialize <= 0;
					jumping <= 0;
				end
				else if(program_value[79:72] == s && program_value[71:64] == t)begin
					command <= 3;
					initialize <= 0;
					jumping <= 0;
				end
				else if(program_value[79:72] == a && program_value[71:64] == d)begin
					command <= 4;
					initialize <= 0;
					jumping <= 0;
				end
				else if(program_value[79:72] == s && program_value[71:64] == b)begin
					command <= 5;
					initialize <= 0;
					jumping <= 0;
				end
				else if(program_value[79:72] == x && program_value[71:64] == x)begin
					command <= 6;
					initialize <= 0;
					jumping <= 0;

				end
				else if(program_value[79:72] == d && program_value[71:64] == v)begin
					command <= 7;
					initialize <= 0;
					jumping <= 0;
				end
				else if(program_value[79:72] == d && program_value[71:64] == t)begin
					command <= 8;
					initialize <= 0;
					jumping <= 0;
				end
				else if(program_value[79:72] == c && program_value[71:64] == r)begin
					command <= 9;
					initialize <= 0;
					jumping <= 0;
				end
				else if(program_value[79:72] == a && program_value[71:64] == n)begin
					command <= 10;
					initialize <= 0;
					jumping <= 0;
				end
				else begin
				 error <= 1;
				 jumping <= 0;
				end

			end
			else if (checkSpace)begin
				if(initialize == 1 && program_value[71:64] != space) begin
					error <= 1;
				end
				else if(initialize != 1 && program_value[63:56] != space) begin
					error <= 1;
				end
				else error <= error;

			end
			else if (checkSpace2)begin
				if(program_value[47:40] != space) begin
					error<=1;
				end
				else error <= error;

			end
			else if (checkSpace3)begin
				if(program_value[23:16] != space) begin
					scalar <= 1;
				end
				else error <= error;

			end

			else if (checkSpaceJ)begin
				if(program_value[39:32] != space) begin
					error <= 1;
				end
				else error <= error;

			end

			else if(initialize == 1 && lax1 == 1)begin
				if(program_value[63:56] != space)begin
					case(program_value[63:56])
						zero: mem_index <= 4'd0;
						one: mem_index <= 4'd1;
						two: mem_index <= 4'd2;
						three: mem_index <= 4'd3;
						four: error<=1;
						five: error<=1;
						six: error<=1;
						seven: error<=1;
						eight: error<=1;
						nine: error<=1;
					endcase
				end
				else error <= 1;
			end

			else if(multli == 1)begin
				mem_index <= mem_index * 10;
			end

			else if(multix == 1)begin
				xval <= xval * 10;
			end

			else if(multiy == 1)begin
				yval <= yval * 10;
			end
			else if(ms5 == 1)begin
				scalareg <= scalareg + scalaregholder * 10000;
			end

			else if(ms4 == 1)begin
				scalareg <= scalareg + scalaregholder * 1000;
			end

			else if(ms3 == 1)begin
				scalareg <= scalareg + scalaregholder * 100;
			end

			else if(ms2 == 1)begin
				scalareg <= scalareg + scalaregholder * 10;
			end

			else if(multipc == 1)begin
				program_counter <= program_counter * 10;
			end

			else if(initialize == 1 && lax2 == 1)begin
				if(program_value[55:48] != space)begin
					case(program_value[55:48])
						zero: mem_index <= mem_index + 4'd0;
						one: mem_index <= mem_index + 4'd1;
						two: mem_index <= mem_index + 4'd2;
						three: mem_index <= mem_index + 4'd3;
						four: mem_index <= mem_index + 4'd4;
						five: mem_index <= mem_index + 4'd5;
						six: mem_index <= mem_index + 4'd6;
						seven: mem_index <= mem_index + 4'd7;
						eight: mem_index <= mem_index + 4'd8;
						nine: mem_index <= mem_index + 4'd9;
					endcase
				end
				else error <= 1;
			end
			else if(initialize == 0 && lax1 == 1)begin
				case(program_value[55:48])
					zero: mem_index <= 4'd0;
					one: mem_index <= 4'd1;
					two: mem_index <= 4'd2;
					three: mem_index <= 4'd3;
					four: error<=1;
					five: error<=1;
					six: error<=1;
					seven: error<=1;
					eight: error<=1;
					nine: error<=1;
					default: error<=1;
				endcase
			end
			else if(initialize == 0 && lax2 == 1)begin
				case(program_value[47:40])
					zero: mem_index <= mem_index + 4'd0;
					one: mem_index <= mem_index + 4'd1;
					two: mem_index <= mem_index + 4'd2;
					three: mem_index <= mem_index + 4'd3;
					four: mem_index <= mem_index + 4'd4;
					five: mem_index <= mem_index + 4'd5;
					six: mem_index <= mem_index + 4'd6;
					seven: mem_index <= mem_index + 4'd7;
					eight: mem_index <= mem_index + 4'd8;
					nine: mem_index <= mem_index + 4'd9;
					default: error<=1;
				endcase
			end

			

			else if(ldx1 == 1)begin
				case(program_value[39:32])
					zero: xval <= 0;
					one: xval <= 25'd1;
					two: xval <= 25'd2;
					three: xval <= 25'd3;
					four: xval <= 25'd4;
					five: xval <= 25'd5;
					six: xval <= 25'd6;
					seven: xval <= 25'd7;
					eight: xval <= 25'd8;
					nine: xval <= 25'd9;
					neg_sign: begin
						negativity <= 1;
						xval<=0;
					end
					default: error<=1;
				endcase
			end
			
			else if(ldx2 == 1 && negativity == 1)begin
				case(program_value[31:24])
					zero: xval <= 0;
					one: xval <= -25'd1;
					two: xval <= -25'd2;
					three: xval <= -25'd3;
					four: xval <= -25'd4;
					five: xval <= -25'd5;
					six: xval <= -25'd6;
					seven: xval <= -25'd7;
					eight: xval <= -25'd8;
					nine: xval <= -25'd9;
					default: error<=1;
				endcase
			end

			else if(ldx2 == 1 && negativity == 0)begin
				case(program_value[31:24])
					zero: xval <= 0;
					one: xval <= xval + 25'd1;
					two: xval <= xval + 25'd2;
					three: xval <= xval + 25'd3;
					four: xval <= xval + 25'd4;
					five: xval <= xval + 25'd5;
					six: xval <= xval + 25'd6;
					seven: xval <= xval + 25'd7;
					eight: xval <= xval + 25'd8;
					nine: xval <= xval + 25'd9;

					default: error<=1;
				endcase
			end

			else if(ldy1 == 1)begin
				case(program_value[15:8])
					zero: yval <= 0;
					one: yval <= 25'd1;
					two: yval <= 25'd2;
					three: yval <= 25'd3;
					four: yval <= 25'd4;
					five: yval <= 25'd5;
					six: yval <= 25'd6;
					seven: yval <= 25'd7;
					eight: yval <= 25'd8;
					nine: yval <= 25'd9;
					neg_sign: begin
						negativity <= 1;
						xval<=0;
					end
					default: error<=1;
				endcase
			end
			
			else if(ldy2 == 1 && negativity == 1)begin
				case(program_value[7:0])
					zero: yval <= 0;
					one: yval <= -25'd1;
					two: yval <= -25'd2;
					three: yval <= -25'd3;
					four: yval <= -25'd4;
					five: yval <= -25'd5;
					six: yval <= -25'd6;
					seven: yval <= -25'd7;
					eight: yval <= -25'd8;
					nine: yval <= -25'd9;
					default: error<=1;
				endcase
			end

			else if(ldy2 == 1 && negativity == 0)begin
				case(program_value[7:0])
					zero: yval <= 0;
					one: yval <= yval + 25'd1;
					two: yval <= yval + 25'd2;
					three: yval <= yval + 25'd3;
					four: yval <= yval + 25'd4;
					five: yval <= yval + 25'd5;
					six: yval <= yval + 25'd6;
					seven: yval <= yval + 25'd7;
					eight: yval <= yval + 25'd8;
					nine: yval <= yval + 25'd9;

					default: error<=1;
				endcase
			end

			else if(ls5 == 1)begin
				case(program_value[39:32])
					zero: scalaregholder <= 0;
					one: scalaregholder <= 25'd1;
					two: scalaregholder <= 25'd2;
					three: scalaregholder <= 25'd3;
					four: scalaregholder <= 25'd4;
					five: scalaregholder <= 25'd5;
					six: scalaregholder <=  25'd6;
					seven: scalaregholder <=  25'd7;
					eight: scalaregholder <= 25'd8;
					nine: scalaregholder <= 25'd9;
					neg_sign: begin
						negativity <= 1;
						scalaregholder<=0;
					end
					default: error<=1;
				endcase
			end

			else if(ls4 == 1 && negativity == 1)begin
				case(program_value[31:24])
					zero: scalaregholder <= 0;
					one: scalaregholder <= -25'd1;
					two: scalaregholder <= -25'd2;
					three: scalaregholder <= -25'd3;
					four: scalaregholder <= -25'd4;
					five: scalaregholder <= -25'd5;
					six: scalaregholder <= -25'd6;
					seven: scalaregholder <= -25'd7;
					eight: scalaregholder <= -25'd8;
					nine: scalaregholder <= -25'd9;
					default: error<=1;
				endcase
			end

			else if(ls3 == 1 && negativity == 1)begin
				case(program_value[23:16])
					zero: scalaregholder <= 0;
					one: scalaregholder <= -25'd1;
					two: scalaregholder <= -25'd2;
					three: scalaregholder <= -25'd3;
					four: scalaregholder <= -25'd4;
					five: scalaregholder <= -25'd5;
					six: scalaregholder <= -25'd6;
					seven: scalaregholder <= -25'd7;
					eight: scalaregholder <= -25'd8;
					nine: scalaregholder <= -25'd9;
					default: error<=1;
				endcase
			end

			else if(ls2 == 1 && negativity == 1)begin
				case(program_value[15:8])
					zero: scalaregholder <= 0;
					one: scalaregholder <= -25'd1;
					two: scalaregholder <= -25'd2;
					three: scalaregholder <= -25'd3;
					four: scalaregholder <= -25'd4;
					five: scalaregholder <= -25'd5;
					six: scalaregholder <= -25'd6;
					seven: scalaregholder <= -25'd7;
					eight: scalaregholder <= -25'd8;
					nine: scalaregholder <= -25'd9;
					default: error<=1;
				endcase
			end

			else if(ls1 == 1 && negativity == 1)begin
				case(program_value[7:0])
					zero: scalaregholder <= 0;
					one: scalaregholder <= -25'd1;
					two: scalaregholder <= -25'd2;
					three: scalaregholder <= -25'd3;
					four: scalaregholder <= -25'd4;
					five: scalaregholder <= -25'd5;
					six: scalaregholder <= -25'd6;
					seven: scalaregholder <= -25'd7;
					eight: scalaregholder <= -25'd8;
					nine: scalaregholder <= -25'd9;
					default: error<=1;
				endcase
			end

			else if(ls4 == 1 && negativity == 0)begin
				case(program_value[31:24])
					zero: scalaregholder <= 0;
					one: scalaregholder <=  25'd1;
					two: scalaregholder <= 25'd2;
					three: scalaregholder <= 25'd3;
					four: scalaregholder <= 25'd4;
					five: scalaregholder <= 25'd5;
					six: scalaregholder <= 25'd6;
					seven: scalaregholder <= 25'd7;
					eight: scalaregholder <= 25'd8;
					nine: scalaregholder <= 25'd9;
					default: error<=1;
				endcase
			end

			else if(ls3 == 1 && negativity == 0)begin
				case(program_value[23:16])
					zero: scalaregholder <= 0;
					one: scalaregholder <=  25'd1;
					two: scalaregholder <= 25'd2;
					three: scalaregholder <= 25'd3;
					four: scalaregholder <= 25'd4;
					five: scalaregholder <= 25'd5;
					six: scalaregholder <= 25'd6;
					seven: scalaregholder <= 25'd7;
					eight: scalaregholder <= 25'd8;
					nine: scalaregholder <= 25'd9;
					default: error<=1;
				endcase
			end

			else if(ls2 == 1 && negativity == 0)begin
				case(program_value[15:8])
					zero: scalaregholder <= 0;
					one: scalaregholder <=  25'd1;
					two: scalaregholder <= 25'd2;
					three: scalaregholder <= 25'd3;
					four: scalaregholder <= 25'd4;
					five: scalaregholder <= 25'd5;
					six: scalaregholder <= 25'd6;
					seven: scalaregholder <= 25'd7;
					eight: scalaregholder <= 25'd8;
					nine: scalaregholder <= 25'd9;
					default: error<=1;
				endcase
			end


			else if(ls1 == 1 && negativity == 0)begin
				case(program_value[7:0])
					zero: scalareg <= scalareg;
					one: scalareg <= scalareg + 25'd1;
					two: scalareg <=scalareg + 25'd2;
					three: scalareg <= scalareg+25'd3;
					four: scalareg <= scalareg+25'd4;
					five: scalareg <= scalareg+25'd5;
					six: scalareg <= scalareg+25'd6;
					seven: scalareg <= scalareg+25'd7;
					eight: scalareg <= scalareg+25'd8;
					nine: scalareg <= scalareg+25'd9;
					default: error<=1;
				endcase
			end

			else if(ldpc1 == 1)begin
				case(program_value[31:24])
					zero: program_counter <= 0;
					one: program_counter <=  5'd1;
					two: program_counter <= 5'd2;
					three: program_counter <= 5'd3;
					four: error<=1;
					five: error<=1;
					six: error<=1;
					seven: error<=1;
					eight: error<=1;
					nine: error<=1;
					default: error<=1;
				endcase
			end

			else if(ldpc2 == 1)begin
				case(program_value[23:16])
					zero: program_counter <= program_counter + 0;
					one: program_counter <=  program_counter +5'd1;
					two: program_counter <= program_counter +5'd2;
					three: program_counter <= program_counter +5'd3;
					four: program_counter <= program_counter +5'd4;
					five: program_counter <= program_counter +5'd5;
					six: program_counter <= program_counter +5'd6;
					seven: program_counter <= program_counter +5'd7;
					eight: program_counter <= program_counter +5'd8;
					nine: program_counter <= program_counter +5'd9;
					default: error<=1;
				endcase
			end
			
			else if(finaladd == 1)begin
				value[63:52] <= 0;
				if(scalar == 1)begin
					value[51:50] <= 2'b00;
					value[49:25] <= scalareg;
					value[24:0] <= 0;
				end

				else begin
					value[51:50] <= 2'b01;
					value[49:25] <= xval;
					value[24:0] <= yval;
				end
			end
			else begin
				value <= value;
			end
		end

endmodule