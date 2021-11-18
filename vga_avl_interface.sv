/************************************************************************
Avalon-MM Interface VGA Text mode display

Register Map:
0x000 = [31:16] Level number, [15:0] Line count
0x001 = [31:0] Score value
0x002-0x015 = 0th row, 1st row, 2nd row, 3rd row, ..., 20th row
0x100 = Palette local register 

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

logic RAM_WRITE, RAM_READ;
assign RAM_WRITE = AVL_WRITE & ~AVL_ADDR[11] & AVL_CS;
logic [11:0] AVL_READADDR, HW_READADDR;
logic [31:0] PALETTE;
assign AVL_READADDR = (AVL_READ) ? AVL_ADDR[10:0] : HW_READADDR;

ram ram0(
	.byteena_a(AVL_BYTE_EN),
	.clock(CLK),
	.data(AVL_WRITEDATA),
	.rdaddress(AVL_READADDR),
	.wraddress(AVL_ADDR[10:0]),
	.wren(RAM_WRITE),
	.q(AVL_READDATA));

logic pixel_clk, blank, sync, onoroff, inv, Increment;

logic draw_board;
logic [1:0] board_row_data [15:0];
logic [1:0] block_template, block_color_index;

logic [3:0] bit_index;
logic [6:0] row, col;
logic [9:0] DrawX, DrawY;

logic [3:0] r, b, g, block_red, block_green, block_blue;

// Font-related
logic [9:0] addr;
logic [15:0] data;
	
//Declare submodules..e.g. VGA controller, ROMS, etc
vga_controller VGA_CONTROLLER(
	.Clk(CLK), 
	.Reset(RESET), 
	.hs(hs), 
	.vs(vs), 
	.pixel_clk(pixel_clk), 
	.blank(blank), 
	.sync(sync), 
	.DrawX(DrawX), 
	.DrawY(DrawY));
font_rom_upscaled FONT_ROM(
	.addr(addr), 
	.data(data));
block_memory BLOCK_ROM(
	.block_template(block_template),
	.pixel_x(DrawX[3:0]),
	.pixel_y(DrawY[3:0]),
	.gameover(1'b0),
	.color_index(block_color_index));

assign red = r;
assign green = g;
assign blue = b;

always_ff @ (posedge CLK) begin
	if (RESET)
		PALETTE <= 32'h0000;	// Reset palette to 0
	else
	begin	
	if (AVL_CS & AVL_ADDR[11])	// Chip-select indicates operation
		begin
			// Assume that only one operation can be performed at a given time
			if (AVL_WRITE) begin
				unique case (AVL_BYTE_EN)	// Write a subset of the data at register[]
					4'b1111 : PALETTE <= AVL_WRITEDATA;
					4'b1100 : PALETTE[31:16] <= AVL_WRITEDATA[31:16];
					4'b0011 : PALETTE[15:0] <= AVL_WRITEDATA[15:0];
					4'b1000 : PALETTE[31:24] <= AVL_WRITEDATA[31:24];
					4'b0100 : PALETTE[23:16] <= AVL_WRITEDATA[23:16];
					4'b0010 : PALETTE[15:8] <= AVL_WRITEDATA[15:8];
					4'b0001 : PALETTE[7:0] <= AVL_WRITEDATA[7:0];
					default : ;
				endcase
			end
		end
	end
end

always_comb begin // Decode electron beam position
		addr = 45 * 16;
		draw_board = 1'b0;
		board_row_data = '{default:'0};
		block_template = 2'b00;
		col = DrawX >> 4;
		row = DrawY >> 4;
		bit_index = ~DrawX[3:0];
		HW_READADDR = 0;
		
		// Static labels look-up table
		if (row == score_label_row && (col >= score_label_left_col && col <= score_label_right_col)) begin 
			unique case (col)
				28 : addr = start_S + DrawY[3:0]; // 'S'
				29 : addr = start_C + DrawY[3:0]; // 'C'
				30 : addr = start_O + DrawY[3:0]; // 'O'
				31 : addr = start_R + DrawY[3:0]; // 'R'
				32 : addr = start_E + DrawY[3:0]; // 'E'
				default : addr = 45 * 16;
			endcase
		end
		else if (row == lines_label_row && (col >= lines_label_left_col && col <= lines_label_right_col)) begin
			unique case (col)
				15 : addr = start_L + DrawY[3:0];    // 'L'
				16 : addr = start_I + DrawY[3:0];    // 'I'
				17 : addr = start_N + DrawY[3:0];    // 'N'
				18 : addr = start_E + DrawY[3:0];    // 'E'
				19 : addr = start_S + DrawY[3:0];    // 'S'
				20 : addr = start_dash + DrawY[3:0]; // '-'
				default : addr = 45 * 16;
			endcase
		end
		else if (row == level_label_row && (col >= level_label_left_col && col <= level_label_right_col)) begin
			unique case (col)
				28, 32 : addr = start_L + DrawY[3:0]; // 'L'
				29, 31 : addr = start_E + DrawY[3:0]; // 'E'
				30 : addr = start_V + DrawY[3:0]; 	  // 'V'
				default : addr = 45 * 16;
			endcase
		end 
		else if (row == score_val_row && (col >= score_val_left_col && col <= score_val_right_col)) begin
			HW_READADDR = 1;
			unique case (col)
				25 : addr = AVL_READDATA[31:28] * 16 + DrawY[3:0];
				26 : addr = AVL_READDATA[27:24] * 16 + DrawY[3:0];
				27 : addr = AVL_READDATA[23:20] * 16 + DrawY[3:0];
				28 : addr = AVL_READDATA[19:16] * 16 + DrawY[3:0];
				29 : addr = AVL_READDATA[15:12] * 16 + DrawY[3:0];
				30 : addr = AVL_READDATA[11:8] * 16 + DrawY[3:0];
				31 : addr = AVL_READDATA[7:4] * 16 + DrawY[3:0];
				32 : addr = AVL_READDATA[3:0] * 16 + DrawY[3:0];
				default : addr = 45 * 16;
			endcase
		end
		else if (row == level_val_row && (col >= level_val_left_col && col <= level_val_right_col)) begin
			HW_READADDR = 0;
			unique case (col)
				29 : addr = AVL_READDATA[31:28] * 16 + DrawY[3:0];
				30 : addr = AVL_READDATA[27:24] * 16 + DrawY[3:0];
				31 : addr = AVL_READDATA[23:20] * 16 + DrawY[3:0];
				32 : addr = AVL_READDATA[19:16] * 16 + DrawY[3:0];
				default : addr = 45 * 16;
			endcase
		end
		else if (row == lines_val_row && (col >= lines_val_left_col && col <= lines_val_right_col)) begin
			HW_READADDR = 0;
			unique case (col)
				21 : addr = AVL_READDATA[15:12] * 16 + DrawY[3:0];
				22 : addr = AVL_READDATA[11:8] * 16 + DrawY[3:0];
				23 : addr = AVL_READDATA[7:4] * 16 + DrawY[3:0];
				24 : addr = AVL_READDATA[3:0] * 16 + DrawY[3:0];
				default : addr = 45 * 16;
			endcase
		end
		else if ((row >= board_top_row && row <= board_bottom_row) && (col >= board_left_col && col <= board_right_col)) begin
			HW_READADDR = 2;
			draw_board = 1'b1;
			board_row_data = '{AVL_READDATA[31:30], AVL_READDATA[29:28], AVL_READDATA[27:26], AVL_READDATA[25:24], AVL_READDATA[23:22], AVL_READDATA[21:20], AVL_READDATA[19:18], AVL_READDATA[17:16], AVL_READDATA[15:14], AVL_READDATA[13:12], AVL_READDATA[11:10], AVL_READDATA[9:8], AVL_READDATA[7:6], AVL_READDATA[5:4], AVL_READDATA[3:2], AVL_READDATA[1:0]};
			block_template = board_row_data[col - board_left_col];
		end
		else begin
			addr = 45 * 16;
		end
		onoroff = data[bit_index];
end


//handle drawing (may either be combinational or sequential - or both).
always_ff @ (posedge pixel_clk) begin
	if (RESET || !blank) begin
		r <= 4'h0;
		g <= 4'h0;
		b <= 4'h0;
	end
	else begin
		if (draw_board) begin
			unique case (block_color_index)
				2'b00 : begin
					r <= 4'h0;
					g <= 4'h0;
					b <= 4'h0;
				end
				2'b01 : begin
					r <= PALETTE[12:9];
					g <= PALETTE[8:5];
					b <= PALETTE[4:1];
				end
				2'b10 : begin
					r <= PALETTE[24:21];
					g <= PALETTE[20:17];
					b <= PALETTE[16:13];
				end
				2'b11 : begin
					r <= 4'b1111;
					g <= 4'b1111;
					b <= 4'b1111;
				end
			endcase
		end
		else begin
			r <= (onoroff) ? 4'b1111 : 4'h0 ;
			g <= (onoroff) ? 4'b1111 : 4'h0 ;
			b <= (onoroff) ? 4'b1111 : 4'h0 ;
		end
	end
end
endmodule
