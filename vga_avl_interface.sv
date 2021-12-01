/************************************************************************
Avalon-MM Interface VGA Text mode display

Register Map:
0x000 = [31:16] Level number, [15:0] Line count
0x001 = [31:0] Score value
0x002-0x015 = 0th row, 1st row, 2nd row, 3rd row, ..., 20th row
0x016 = (for now) Next piece identifier
0x017 = Keycodes
0x018 = Key states 
0x019 = DAS
0x800 = Palette local register 
0X801 = Current piece local register
0x802 = Seed bit #1

************************************************************************/
import my_pkg::*;
import template_pkg::*;
module vga_avl_interface (
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
	
	output logic [3:0]  red, green, blue,	// VGA color channels (mapped to output pins in top-level)
	output logic hs, vs						// VGA HS/VS
);

logic RAM_READ, RAM_WRITE, HW_WRITE, HW_READ;
assign RAM_READ = AVL_READ & ~AVL_ADDR[11] & AVL_CS;
assign RAM_WRITE = AVL_WRITE & ~AVL_ADDR[11] & AVL_CS;

logic [31:0] LOCAL_REGS [1:0];
logic [10:0] HW_ADDR;
logic [31:0] PALETTE, WINDOW, HW_WRITEDATA, HW_READDATA;
logic [31:0] RAM_READDATA, LOCAL_READDATA;
assign AVL_READDATA = (AVL_ADDR[11]) ? LOCAL_READDATA : RAM_READDATA;
assign PALETTE = LOCAL_REGS[palette_index];
assign WINDOW = LOCAL_REGS[window_index];


// A = AVL access
// B = Hardware access
r ram0(
	.address_a(AVL_ADDR[10:0]),
	.address_b(HW_ADDR),
	.byteena_a(AVL_BYTE_EN),
	.clock(CLK),
	.data_a(AVL_WRITEDATA),
	.data_b(HW_WRITEDATA),
	.wren_a(RAM_WRITE),
	.wren_b(HW_WRITE),
	.q_a(RAM_READDATA),
	.q_b(HW_READDATA));

logic pixel_clk, blank, sync, onoroff, inv, Increment;

// VGA Draw flags:
logic draw_board, draw_next, draw_piece, draw_window, game_over;


logic [1:0] board_row_data [15:0];
logic [1:0] resultant_block_template, board_block_template, block_color_index, piece_block_template;
assign resultant_block_template = (draw_piece) ? piece_block_template : board_block_template;

logic [2:0] piece_window_col, piece_window_row;

logic [3:0] bit_index, block_pixel_col, block_pixel_row, pixel_x;
logic [6:0] row, col;
logic [9:0] DrawX, DrawY, displacedDrawX;
assign displacedDrawX = DrawX - 8;

logic [4:0] board_row;
logic [3:0] board_col;

logic [3:0] r, b, g, block_red, block_green, block_blue;
logic [4:0] piece_identifier;

// Font-related
logic [9:0] addr;
logic [15:0] data;

logic [4:0] random;
logic stop_bit;
assign stop_bit = (AVL_ADDR[11] & AVL_CS & AVL_READ);
logic [31:0] random2, random3;
	
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
	.block_template(resultant_block_template),
	.pixel_x(pixel_x),
	.pixel_y(DrawY[3:0]),
	.gameover(game_over),
	.color_index(block_color_index));
tetromino_rom TETROMINO_ROM(
	.identifier(piece_identifier),
	.col(piece_window_col),
	.row(piece_window_row),
	.block_template(piece_block_template));
fibonacci_lfsr_nbit rng(.clk(CLK),
	.reset(RESET),
	.data(random));
GARO rng2 [31:0] (.stop(stop_bit),
	.clk(CLK),
	.reset(RESET),
	.random(random2));
hw_rng rng3(.clk(CLK),
	.reset(RESET),
	.load(1'b0),
	.seed(32'h0),
	.random_state(random3));

assign red = r;
assign green = g;
assign blue = b;

always_ff @ (posedge CLK) begin
	if (RESET) begin
		LOCAL_REGS <= '{default:'0};
	end
	else
	begin	
	if (AVL_CS & AVL_ADDR[11])	// Chip-select indicates operation
		begin
			// Assume that only one operation can be performed at a given time
			if (AVL_WRITE) begin
				unique case (AVL_BYTE_EN)	// Write a subset of the data at register[]
					4'b1111 : LOCAL_REGS[AVL_ADDR - palette_addr] <= AVL_WRITEDATA;
					4'b1100 : LOCAL_REGS[AVL_ADDR - palette_addr][31:16] <= AVL_WRITEDATA[31:16];
					4'b0011 : LOCAL_REGS[AVL_ADDR - palette_addr][15:0] <= AVL_WRITEDATA[15:0];
					4'b1000 : LOCAL_REGS[AVL_ADDR - palette_addr][31:24] <= AVL_WRITEDATA[31:24];
					4'b0100 : LOCAL_REGS[AVL_ADDR - palette_addr][23:16] <= AVL_WRITEDATA[23:16];
					4'b0010 : LOCAL_REGS[AVL_ADDR - palette_addr][15:8] <= AVL_WRITEDATA[15:8];
					4'b0001 : LOCAL_REGS[AVL_ADDR - palette_addr][7:0] <= AVL_WRITEDATA[7:0];
					default : ;
				endcase
			end
			else if (AVL_READ) begin
				if (AVL_ADDR == 12'h802) begin
					LOCAL_READDATA <= random3;
				end
				else begin
					LOCAL_READDATA <= LOCAL_REGS[AVL_ADDR - palette_addr];
				end
			end
		end
	end
end

always_comb begin // Decode electron beam position
		addr = 45 * 16;
		draw_board = 1'b0;
		draw_piece = 1'b0;
		draw_window = 1'b0;
		board_row_data = '{default:'0};
		board_block_template = BLACK;
		board_col = 0;
		board_row = 0;
		game_over = 1'b0;
		col = DrawX >> 4;
		row = DrawY >> 4;
		bit_index = ~DrawX[3:0];
		piece_identifier = 5'h0;
		piece_window_row = 2'b00;
		piece_window_col = 2'b00;
		pixel_x = 0;
		HW_ADDR = 32'h0;
		HW_READ = 1'b0;
		HW_WRITE = 1'b0;
		
		// Static labels look-up table
		if ( (row == score_label_row)
		&& ( (col >= score_label_left_col) && (col <= score_label_right_col) ) ) begin 
		// "SCORE" 
			unique case (col - score_label_left_col)
				0 : addr = start_S + DrawY[3:0]; // 'S'
				1 : addr = start_C + DrawY[3:0]; // 'C'
				2 : addr = start_O + DrawY[3:0]; // 'O'
				3 : addr = start_R + DrawY[3:0]; // 'R'
				4 : addr = start_E + DrawY[3:0]; // 'E'
				default : addr = 45 * 16;
			endcase
		end
		else if ( (row == lines_label_row)
		&& ( (col >= lines_label_left_col) && (col <= lines_label_right_col) ) ) begin
		// "LINES-"
			unique case (col - lines_label_left_col)
				0 : addr = start_L + DrawY[3:0];    // 'L'
				1 : addr = start_I + DrawY[3:0];    // 'I'
				2 : addr = start_N + DrawY[3:0];    // 'N'
				3 : addr = start_E + DrawY[3:0];    // 'E'
				4 : addr = start_S + DrawY[3:0];    // 'S'
				5 : addr = start_dash + DrawY[3:0]; // '-'
				default : addr = 45 * 16;
			endcase
		end
		else if ( (row == level_label_row)
		&& ( (col >= level_label_left_col) && (col <= level_label_right_col) ) ) begin
		// "LEVEL"
			unique case (col - level_label_left_col)
				0, 4 : addr = start_L + DrawY[3:0]; // 'L'
				1, 3 : addr = start_E + DrawY[3:0]; // 'E'
				2 : addr = start_V + DrawY[3:0]; 	  // 'V'
				default : addr = 45 * 16;
			endcase
		end 
		else if ( (row == next_label_row)
		&& ( (col >= next_label_left_col) && (col <= next_label_right_col) ) ) begin
		// "NEXT"
			unique case (col - next_label_left_col)
				0 : addr = start_N + DrawY[3:0]; // 'N'
				1 : addr = start_E + DrawY[3:0]; // 'E'
				2 : addr = start_X + DrawY[3:0]; // 'X'
				3 : addr = start_T + DrawY[3:0]; // 'T'
				default : addr = 45 * 16;
			endcase
		end
		else if ( (row == score_val_row)
		&& ( (col >= score_val_left_col) && (col <= score_val_right_col) ) ) begin
		// 8-digit decimal number representing score value
			HW_ADDR = score_addr;
			unique case (col - score_val_left_col)
				0 : addr = (HW_READDATA[31:28] * 16) + DrawY[3:0];
				1 : addr = (HW_READDATA[27:24] * 16) + DrawY[3:0];
				2 : addr = (HW_READDATA[23:20] * 16) + DrawY[3:0];
				3 : addr = (HW_READDATA[19:16] * 16) + DrawY[3:0];
				4 : addr = (HW_READDATA[15:12] * 16) + DrawY[3:0];
				5 : addr = (HW_READDATA[11:8] * 16) + DrawY[3:0];
				6 : addr = (HW_READDATA[7:4] * 16) + DrawY[3:0];
				7 : addr = (HW_READDATA[3:0] * 16) + DrawY[3:0];
				default : addr = 45 * 16;
			endcase
		end
		else if ( (row == level_val_row)
		&& ( (col >= level_val_left_col) && (col <= level_val_right_col) ) ) begin
		// 4-digit decimal number representing level value
			HW_ADDR = level_lines_addr;
			HW_READ = 1'b1;
			unique case (col - level_val_left_col)
				0 : addr = (HW_READDATA[31:28] * 16) + DrawY[3:0];
				1 : addr = (HW_READDATA[27:24] * 16) + DrawY[3:0];
				2 : addr = (HW_READDATA[23:20] * 16) + DrawY[3:0];
				3 : addr = (HW_READDATA[19:16] * 16) + DrawY[3:0];
				default : addr = 45 * 16;
			endcase
		end
		else if ( (row == lines_val_row)
		&& ( (col >= lines_val_left_col) && (col <= lines_val_right_col) ) ) begin
		// 4-digit decimal number representing line count value
			HW_ADDR = level_lines_addr;
			HW_READ = 1'b1;
			unique case (col - lines_val_left_col)
				0 : addr = (HW_READDATA[15:12] * 16) + DrawY[3:0];
				1 : addr = (HW_READDATA[11:8] * 16) + DrawY[3:0];
				2 : addr = (HW_READDATA[7:4] * 16) + DrawY[3:0];
				3 : addr = (HW_READDATA[3:0] * 16) + DrawY[3:0];
				default : addr = 45 * 16;
			endcase
		end
		else if ( ( (row >= board_top_row) && (row <= board_bottom_row) )
		&& ( (col >= board_left_col) && (col <= board_right_col) ) ) begin
		// 10 by 20 blocks representing the game field
			draw_board = 1'b1;
			pixel_x = DrawX[3:0];
			board_row = row - board_top_row;
			board_col = col - board_left_col;
			HW_ADDR = (row_0_addr + board_row);
			HW_READ = 1'b1;
			game_over = HW_READDATA[20];
			
			if ( ( (board_row >= WINDOW[22:18]) && (board_row <= WINDOW[17:13]) ) 
			&& ( (board_col >= WINDOW[12:9]) && (board_col <= WINDOW[8:5]) ) ) begin
				piece_identifier = WINDOW[4:0];
				piece_window_row = (WINDOW[17:13] <= 10) ? (3 - (WINDOW[17:13] - board_row)) : (board_row - WINDOW[22:18]);
				piece_window_col = (WINDOW[12:9] <= 5) ? (WINDOW[8:5] - board_col) : (3 - (board_col - WINDOW[12:9]));
			end	
			
			if (piece_block_template == BLACK) begin
				unique case (board_col)
					0 : board_block_template = HW_READDATA[1:0];
					1 : board_block_template = HW_READDATA[3:2];
					2 : board_block_template = HW_READDATA[5:4];
					3 : board_block_template = HW_READDATA[7:6];
					4 : board_block_template = HW_READDATA[9:8];
					5 : board_block_template = HW_READDATA[11:10];
					6 : board_block_template = HW_READDATA[13:12];
					7 : board_block_template = HW_READDATA[15:14];
					8 : board_block_template = HW_READDATA[17:16];
					9 : board_block_template = HW_READDATA[19:18];
				endcase
			end
			else begin
				draw_piece = 1'b1;
			end
		end
			/*
			else begin
				resultant_block_template = board_block_template;
			end*/
				/*unique case (board_col)
					0 : resultant_block_template = HW_READDATA[1:0];
					1 : resultant_block_template = HW_READDATA[3:2];
					2 : resultant_block_template = HW_READDATA[5:4];
					3 : resultant_block_template = HW_READDATA[7:6];
					4 : resultant_block_template = HW_READDATA[9:8];
					5 : resultant_block_template = HW_READDATA[11:10];
					6 : resultant_block_template = HW_READDATA[13:12];
					7 : resultant_block_template = HW_READDATA[15:14];
					8 : resultant_block_template = HW_READDATA[17:16];
					9 : resultant_block_template = HW_READDATA[19:18];
				endcase*/
			/*
			HW_ADDR = (row_0_addr + board_row);
			HW_READ = 1'b1;
			draw_board = 1'b1;
			pixel_x = DrawX[3:0];
				unique case (board_col)
					0 : board_block_template = HW_READDATA[1:0];
					1 : board_block_template = HW_READDATA[3:2];
					2 : board_block_template = HW_READDATA[5:4];
					3 : board_block_template = HW_READDATA[7:6];
					4 : board_block_template = HW_READDATA[9:8];
					5 : board_block_template = HW_READDATA[11:10];
					6 : board_block_template = HW_READDATA[13:12];
					7 : board_block_template = HW_READDATA[15:14];
					8 : board_block_template = HW_READDATA[17:16];
					9 : board_block_template = HW_READDATA[19:18];
				endcase*/
				/*
			HW_ADDR = curr_addr;
			HW_READ = 1'b1;
			draw_board = 1'b1;
			pixel_x = DrawX[3:0];
			
			if ( ( (board_row >= HW_READDATA[22:18]) && (board_row <= HW_READDATA[17:13]) ) 
			&& ( (board_col >= HW_READDATA[12:9]) && (board_col <= HW_READDATA[8:5]) ) ) begin
				piece_identifier = HW_READDATA[4:0];
				piece_window_row = (HW_READDATA[17:13] <= 10) ? (3 - (HW_READDATA[17:13] - board_row)) : (board_row - HW_READDATA[22:18]);
				piece_window_col = (HW_READDATA[12:9] <= 5) ? (HW_READDATA[8:5] - board_col) : (3 - (board_col - HW_READDATA[12:9]));
			end*/
			//if (piece_block_template == 2'b11) begin
				// Case: Piece is not on the current block - draw the board.
		//end
		else if ( ( (row >= next_window_top_row) && (row <= next_window_bottom_row) )
		&& ( (col >= next_window_left_col) && (col <= next_window_right_col) ) ) begin
		// 4 by 3 blocks representing the next piece window (to center the piece, need to shift the columns if the piece needs it)
			HW_ADDR = next_addr;
			HW_READ = 1'b1;
			draw_board = 1'b1;
			draw_piece = 1'b1;
			piece_identifier = HW_READDATA[4:0];
			piece_window_row = ( (row - next_window_top_row) + 1);
			unique case (piece_identifier[4:2])
				3'b000, 3'b001 : 
					// All pieces with symmetric initial orientations (no shift)
					begin
						piece_window_col = next_window_right_col - col;
						pixel_x = DrawX[3:0];
					end
				default:
					// All pieces with non-symmetric initial orientations (required shift)
					begin
						piece_window_col = (next_window_right_col - ( (DrawX + 8) >> 4));
						pixel_x = displacedDrawX[3:0];
					end
			endcase
		end
		else begin
			addr = 45 * 16;
		end
		onoroff = data[bit_index];
end

always_ff @ (posedge pixel_clk) begin
	if (RESET || !blank) begin
		r <= 4'h0;
		g <= 4'h0;
		b <= 4'h0;
	end
	else begin
		if (draw_board) begin
		// -> Pixel is colored based on block templates and color palettes.
			unique case (block_color_index)
				BLACK : begin
					r <= 4'b0000;
					g <= 4'b0000;
					b <= 4'b0000;
				end
				DARK : begin
					r <= PALETTE[12:9];
					g <= PALETTE[8:5];
					b <= PALETTE[4:1];
				end
				LIGHT : begin
					r <= PALETTE[24:21];
					g <= PALETTE[20:17];
					b <= PALETTE[16:13];
				end
				WHITE : begin
					r <= 4'b1111;
					g <= 4'b1111;
					b <= 4'b1111;
				end
			endcase
		end
		else begin
		// -> Black and white coloring.
			r <= (onoroff) ? 4'b1111 : 4'b0000;
			g <= (onoroff) ? 4'b1111 : 4'b0000;
			b <= (onoroff) ? 4'b1111 : 4'b0000;
		end
	end
end
endmodule
