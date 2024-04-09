module clock_50_to_3000(input CLOCK_50, output reg CLOCK_3000, input reset);
	reg[15:0] CNT = 0;
	always@(posedge CLOCK_50) begin
		if(reset) CNT = 0;
		CNT = CNT + 1;
		CLOCK_3000 = 0;
		if(CNT == 16667) begin
			CNT = 0;
			CLOCK_3000 = 1;
		end
	end

endmodule


module DE1_SoC_Audio (
	// Inputs
	CLOCK_50,
	KEY,
	
	AUD_ADCDAT,

	clickEN,
	
	// Bidirectionals
	AUD_BCLK,
	AUD_ADCLRCK,
	AUD_DACLRCK,

	FPGA_I2C_SDAT,

	// Outputs
	AUD_XCK,
	AUD_DACDAT,

	FPGA_I2C_SCLK
);

/*****************************************************************************
 *                           Parameter Declarations                          *
 *****************************************************************************/


/*****************************************************************************
 *                             Port Declarations                             *
 *****************************************************************************/
// Inputs
input				CLOCK_50;
input		[3:0]	KEY;

input				AUD_ADCDAT;
input clickEN;
// Bidirectionals
inout				AUD_BCLK;
inout				AUD_ADCLRCK;
inout				AUD_DACLRCK;

inout				FPGA_I2C_SDAT;

// Outputs
output				AUD_XCK;
output				AUD_DACDAT;

output				FPGA_I2C_SCLK;

/*****************************************************************************
 *                 Internal Wires and Registers Declarations                 *
 *****************************************************************************/
// Internal Wires
wire				audio_in_available;
wire		[31:0]	left_channel_audio_in;
wire		[31:0]	right_channel_audio_in;
wire				read_audio_in;

wire				audio_out_allowed;
wire		[31:0]	left_channel_audio_out;
wire		[31:0]	right_channel_audio_out;
wire				write_audio_out;

wire CLOCK_3000;

// Internal Registers

reg [18:0] delay_cnt;
wire [18:0] delay;

reg snd;

// State Machine Registers

/*****************************************************************************
 *                         CLOCK DIVIDER to 3000HZ                           *
 *****************************************************************************/


/*****************************************************************************
 *                             Sequential Logic                              *
 *****************************************************************************/

always @(posedge CLOCK_50)
	if(delay_cnt == delay) begin
		delay_cnt <= 0;
		snd <= !snd;
	end else delay_cnt <= delay_cnt + 1;

/*****************************************************************************
 *                            Combinational Logic                            *
 *****************************************************************************/


wire [15:0] sound;
reg [20:0] SumSound;
wire [11:0]w_click_ADR;
reg [11:0]click_ADR;
wire[15:0] sound2;

always@(*) begin
	if(click_ADR != 0)
		SumSound = sound2;
	else SumSound = sound;
end


assign read_audio_in			= audio_in_available & audio_out_allowed;

assign left_channel_audio_out	= left_channel_audio_in + (SumSound<<14);
assign right_channel_audio_out	= right_channel_audio_in + (SumSound<<14);
assign write_audio_out			= audio_in_available & audio_out_allowed;

/*****************************************************************************
 *                              Internal Modules                             *
 *****************************************************************************/
wire [14:0]w_audio_ADR;
reg [14:0]audio_ADR;

assign w_audio_ADR = audio_ADR;

always @(posedge CLOCK_3000) begin
	if(~KEY[0]) audio_ADR = 0;
	audio_ADR = audio_ADR + 1;
	if(audio_ADR == 30094)
		audio_ADR = 0;
end 

audioMem am(w_audio_ADR,CLOCK_50,sound);


assign w_click_ADR = click_ADR;

always @(posedge CLOCK_3000 or posedge clickEN) begin
	if(clickEN) click_ADR = 1000;
	else if(click_ADR != 0) begin
		click_ADR = click_ADR + 1;
		if(click_ADR == 2613)
			click_ADR = 0;
	end
end

assign w_click_ADR = click_ADR;

audClick ac(
	w_click_ADR,
	CLOCK_50,
	sound2);

clock_50_to_3000 a(
	.CLOCK_50(CLOCK_50),
	.reset(~KEY[0]),
	.CLOCK_3000(CLOCK_3000)
);
 
Audio_Controller Audio_Controller (
	// Inputs
	.CLOCK_50						(CLOCK_50),
	.reset						(~KEY[0]),

	.clear_audio_in_memory		(),
	.read_audio_in				(read_audio_in),
	
	.clear_audio_out_memory		(),
	.left_channel_audio_out		(left_channel_audio_out),
	.right_channel_audio_out	(right_channel_audio_out),
	.write_audio_out			(write_audio_out),

	.AUD_ADCDAT					(AUD_ADCDAT),

	// Bidirectionals
	.AUD_BCLK					(AUD_BCLK),
	.AUD_ADCLRCK				(AUD_ADCLRCK),
	.AUD_DACLRCK				(AUD_DACLRCK),


	// Outputs
	.audio_in_available			(audio_in_available),
	.left_channel_audio_in		(left_channel_audio_in),
	.right_channel_audio_in		(right_channel_audio_in),

	.audio_out_allowed			(audio_out_allowed),

	.AUD_XCK					(AUD_XCK),
	.AUD_DACDAT					(AUD_DACDAT)

);

avconf #(.USE_MIC_INPUT(1)) avc (
	.FPGA_I2C_SCLK					(FPGA_I2C_SCLK),
	.FPGA_I2C_SDAT					(FPGA_I2C_SDAT),
	.CLOCK_50					(CLOCK_50),
	.reset						(~KEY[0])
);

endmodule

