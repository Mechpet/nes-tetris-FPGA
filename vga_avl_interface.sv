/************************************************************************
Avalon-MM Interface VGA Text mode display

Register Map:
0x000-0x0257 : VRAM, 80x30 (2400 byte, 600 word) raster order (first column then row)
0x258        : control register

VRAM Format:
X->
[ 31  30-24][ 23  22-16][ 15  14-8 ][ 7    6-0 ]
[IV3][CODE3][IV2][CODE2][IV1][CODE1][IV0][CODE0]

IVn = Draw inverse glyph
CODEn = Glyph code from IBM codepage 437

Control Register Format:
[[31-25][24-21][20-17][16-13][ 12-9][ 8-5 ][ 4-1 ][   0    ] 
[[RSVD ][FGD_R][FGD_G][FGD_B][BKG_R][BKG_G][BKG_B][RESERVED]

VSYNC signal = bit which flips on every Vsync (time for new frame), used to synchronize software
BKG_R/G/B = Background color, flipped with foreground when IVn bit is set
FGD_R/G/B = Foreground color, flipped with background when Inv bit is set

************************************************************************/
import my_pkg::*;
module vga_avl_interface (
	// Avalon Clock Input, note this clock is also used for VGA, so this must be 50Mhz
	// We can put a clock divider here in the future to make this IP more generalizable
	input logic CLK,
	
	// Avalon Reset Input
	input logic RESET,
	
	// Avalon-MM Slave Signals
	input  logic AVL_READ,					// Avalon-MM Read
	input  logic AVL_WRITE,					// Avalon-MM Write
	input  logic AVL_CS,					// Avalon-MM Chip Select
	input  logic [3:0] AVL_BYTE_EN,			// Avalon-MM Byte Enable
	input  logic [11:0] AVL_ADDR,			// Avalon-MM Address
	input  logic [31:0] AVL_WRITEDATA,		// Avalon-MM Write Data
	output logic [31:0] AVL_READDATA,		// Avalon-MM Read Data
	
	// Exported Conduit (mapped to VGA port - make sure you export in Platform Designer)
	output logic [3:0]  red, green, blue,	// VGA color channels (mapped to output pins in top-level)
	output logic hs, vs						// VGA HS/VS
);

logic RAM_WRITE;
assign RAM_WRITE = AVL_WRITE & ~AVL_ADDR[11];

logic [11:0] AVL_READADDR;
logic [31:0] RAM_READDATA, PALETTE_READDATA;

assign AVL_READDATA = (AVL_ADDR[11]) ? PALETTE_READDATA : RAM_READDATA;

/*
byte_enabled_simple_dual_port_ram ram0
(
 .we(RAM_WRITE), 
 .clk(CLK),
 .waddr(AVL_ADDR[10:0]),
 .raddr(AVL_READADDR),
 .be(AVL_BYTE_EN),
 .wdata(AVL_WRITEDATA),
 .q(RAM_READDATA)
);*/
ram ram0
(.byteena_a(AVL_BYTE_EN),
	.clock(CLK),
	.data(AVL_WRITEDATA),
	.rdaddress(AVL_READADDR),
	.wraddress(AVL_ADDR[10:0]),
	.wren(RAM_WRITE),
	.q(RAM_READDATA));

logic [31:0] PALETTE [7:0]; // Palette register data

//put other local variables here
// `onoroff` refers to whether a pixel at (DrawX, DrawY) on the VGA should be background (0) or foreground (1)
// `inv` refers to whether a pixel at (DrawX, DrawY) was inverted
// `bit_index` refers to the bit position/index in the ASCII 8-bit data (0 -> bit at data[0])
// `char_index` refers to the character position/index in the registers (0 -> data at register[7:0])
// `row` refers to the row of the character to be displayed (0 -> left of VGA)
// `col` refers to the column of the character to be displayed (0 -> top of VGA)
logic pixel_clk, blank, sync, onoroff, inv, Increment;
logic [2:0] bit_index, char_index;
logic [6:0] row, col;
logic [11:0] reg_index;
logic [9:0] DrawX, DrawY;
logic bg_bit, fg_bit;
logic [3:0] palette_bg_index, palette_fg_index, palette_bg_reg, palette_fg_reg, palette_addr;
logic [3:0] r, b, g, br, bg, bb, fr, fg, fb;

// Font-related
logic [9:0] addr;
logic [7:0] data;
	
//Declare submodules..e.g. VGA controller, ROMS, etc
vga_controller VGA_CONTROLLR(.Clk(CLK), .Reset(RESET), .hs(hs), .vs(vs), .pixel_clk(pixel_clk), .blank(blank), .sync(sync), .DrawX(DrawX), .DrawY(DrawY));
font_rom FONT_ROM(.addr(addr), .data(data));

assign red = r;
assign green = g;
assign blue = b;

// Read and write from AVL interface to register block, note that READ waitstate = 1, so this should be in always_ff
always_ff @(posedge CLK) begin
	if (RESET)
		PALETTE <= '{default:'0};	// Reset all registers to 0
	else
	begin	
	if (AVL_CS & AVL_ADDR[11])	// Chip-select indicates operation
		begin
			palette_addr <= AVL_ADDR - 12'h800;
			// Assume that only one operation can be performed at a given time
			if (AVL_WRITE)
			begin
				unique case (AVL_BYTE_EN)	// Write a subset of the data at register[]
					4'b1111 : PALETTE[palette_addr] <= AVL_WRITEDATA;
					4'b1100 : PALETTE[palette_addr][31:16] <= AVL_WRITEDATA[31:16];
					4'b0011 : PALETTE[palette_addr][15:0] <= AVL_WRITEDATA[15:0];
					4'b1000 : PALETTE[palette_addr][31:24] <= AVL_WRITEDATA[31:24];
					4'b0100 : PALETTE[palette_addr][23:16] <= AVL_WRITEDATA[23:16];
					4'b0010 : PALETTE[palette_addr][15:8] <= AVL_WRITEDATA[15:8];
					4'b0001 : PALETTE[palette_addr][7:0] <= AVL_WRITEDATA[7:0];
					default : ;
				endcase
			end
			else if (AVL_READ)
				PALETTE_READDATA <= PALETTE[palette_addr];
		end
	end
end

always_comb
begin // Decode electron beam position
		col = DrawX >> 3;
		row = DrawY >> 3;
		bit_index = ~DrawX[2:0];
		if (row == score_label_row && (col >= score_label_left_col && col <= score_label_right_col))
		begin //Fetch font data (LUT)
			unique case (col)
				68 : addr = start_S + DrawY[2:0]; // 'S'
				69 : addr = start_C + DrawY[2:0]; // 'C'
				70 : addr = start_O + DrawY[2:0]; // 'O'
				71 : addr = start_R + DrawY[2:0]; // 'R'
				72 : addr = start_E + DrawY[2:0]; // 'E'
			endcase
		end
		else
			addr = 9'h2D * 8;
		onoroff = data[bit_index];
end


//handle drawing (may either be combinational or sequential - or both).
always_ff @ (posedge pixel_clk) begin
	if (RESET || !blank) // If don't need to display, then display black
	begin
		r <= 4'h0;
		g <= 4'h0;
		b <= 4'h0;
	end
	else 	// If need to display, paint the current pixel
	begin
		r <= (onoroff) ? 4'b1111 : 4'h0 ;
		g <= (onoroff) ? 4'b1111 : 4'h0 ;
		b <= (onoroff) ? 4'b1111 : 4'h0 ;
	end
end
endmodule
