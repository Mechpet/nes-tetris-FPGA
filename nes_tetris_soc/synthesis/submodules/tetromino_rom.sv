/** tetromino_rom:
 * Contains read-only memory pertaining to the tetromino pieces.
 * - Upscaled from an initial 8px by 8px to 16px by 16px.
 * - Tried to preserve the visual style of the font but add smoothness.
 * 1.0 - Try a basic 4 by 4 window first.
 *
 * @param identifier : [4:2] piece identifier | [1:0] rotation identifier
 * Piece ID Mapping (piece id : template)
 * 000 - 'O' : 00
 * 001 - 'I' : 00
 * 010 - 'Z' : 01
 * 011 - 'S' : 10
 * 100 - 'T' : 00
 * 101 - 'J' : 10
 * 110 - 'L' : 01
 *
 * Rotation ID Mapping (rotation id : description)
 * 00 - Initial / spawn orientation
 * 01 - Clockwise rotation from 00
 * 10 - Clockwise rotation from 01
 * 11 - Clockwise rotation from 10
 *
 * @param identifier : [4:0] identifier of the piece
 * @param col : [1:0] column of the window (0 - left)
 * @param row : [1:0] row of the window (0 - top)
 * @param map_en : Enable bit for computing the mapping of the piece
 * @param right_edge : Argument for the mapping - if on, this signifies that the piece is on the rightmost edge and has `param` columns cropped on the right
 * @param left_edge : [1:0] Argument for the mapping - if on, this signifies that the piece is on the leftmost edge and has `param` columns cropped on the left
 * @param bottom_edge : Argument for the mapping - if on, this signifies that the piece is on the bottommost edge and has `param` rows cropped on the bottom
 * @param top_edge : [1:0] Argument for the mapping - if on, this signiies that the piece is on the topmost edge and has `param` rows cropped on the top
 */
import template_pkg::*;
module tetromino_rom ( input logic [4:0]	identifier,
							  input logic [2:0] col, row,
							  input logic right_edge, bottom_edge,
							  input logic [1:0] left_edge, top_edge,
							  output logic [1:0] block_template,
							  output logic [3:0] window_map [3:0],
							  output logic [7:0] template_map
							  );

	// ROM definition				
	parameter [0:75][3:0] ROM = {
		// 'O' - All (2-bit: 00, 01, 10, 11)
		4'b0000,
		4'b0000,
		4'b0110,
		4'b0110,
		// 'I' - Flat (2-bit: 00)
		4'b0000,
		4'b0000,
		4'b1111,
		4'b0000,
		// 'I' - Upright (2-bit: 01)
		4'b0010,
		4'b0010,
		4'b0010,
		4'b0010,
		// 'Z' - Flat (2-bit: 00)
		4'b0000,
		4'b0000,
		4'b0110,
		4'b0011,
		// 'Z' - Upright (2-bit: 01)
		4'b0000,
		4'b0001,
		4'b0011,
		4'b0010,
		// 'S' - Flat (2-bit: 00)
		4'b0000,
		4'b0000,
		4'b0011,
		4'b0110,
		// 'S' - Upright (2-bit: 01)
		4'b0000,
		4'b0010,
		4'b0011,
		4'b0001,
		// 'T' - Initial (2-bit: 00)
		4'b0000,
		4'b0000,
		4'b0111,
		4'b0010,
		// 'T' - Pointing left (2-bit: 01)
		4'b0000,
		4'b0010,
		4'b0110,
		4'b0010,
		// 'T' - Flat (2-bit: 10)
		4'b0000,
		4'b0010,
		4'b0111,
		4'b0000,
		// 'T' - Pointing right (2-bit: 11)
		4'b0000,
		4'b0010,
		4'b0011,
		4'b0010,
		// 'J' - Initial (2-bit: 00)
		4'b0000,
		4'b0000,
		4'b0111,
		4'b0001,
		// 'J' - J-shape (2-bit: 01)
		4'b0000,
		4'b0010,
		4'b0010,
		4'b0110,
		// 'J' - Initial flipped (2-bit: 10)
		4'b0000,
		4'b0100,
		4'b0111,
		4'b0000,		
		// 'J' - Overhang (2-bit: 11)
		4'b0000,
		4'b0011,
		4'b0010,
		4'b0010,
		// 'L' - Initial (2-bit: 00)
		4'b0000,
		4'b0000,
		4'b0111,
		4'b0100,
		// 'L' - Overhand (2-bit: 01)
		4'b0000,
		4'b0110,
		4'b0010,
		4'b0010,
		// 'L' - Initial flipped (2-bit: 10)
		4'b0000,
		4'b0001,
		4'b0111,
		4'b0000,
		// 'L' - L-shape (2-bit: 11)
		4'b0000,
		4'b0010,
		4'b0010,
		4'b0011
	};
	
	logic [1:0] on_template;
	logic [6:0] addr;
	logic [3:0] innate_data, final_data;
	logic onoroff;
	
	assign innate_data = ROM[addr + row];
	assign onoroff = (col == 4) ? 0 : final_data[3 - col];
	assign block_template = (onoroff) ? on_template : BLACK;
	
	always_comb begin
		// Determine the address of ROM
		unique case (identifier[4:2])
			3'b000 : begin
				// 'O' in ROM[3:0]
				addr = O_start;
				on_template = WHITE;
			end
			3'b001 : begin
				// 'I' in ROM[11:4]
				addr = I_start + (4 * identifier[0]);
				on_template = WHITE;
			end
			3'b010 : begin
				// 'Z' in ROM[19:12]
				addr = Z_start + (4 * identifier[0]);
				on_template = LIGHT;
			end
			3'b011 : begin
				// 'S' in ROM[27:20]
				addr = S_start + (4 * identifier[0]);
				on_template = DARK;
			end
			3'b100 : begin
				// 'T' in ROM[43:28]
				addr = T_start + (4 * identifier[1:0]);
				on_template = WHITE;
			end
			3'b101 : begin
				// 'J' in ROM[59:44]
				addr = J_start + (4 * identifier[1:0]);
				on_template = DARK;
			end
			3'b110 : begin
				// 'L' in ROM[75:60]
				addr = L_start + (4 * identifier[1:0]);
				on_template = LIGHT;
			end
		endcase
		
		// Index : Description
		//   0   : Bottommost row
		//   1   : Second bottomost row
		//   2   : Second topmost row
		//   3   : Topmost row
		if (left_edge) begin
			window_map = '{ROM[addr] << left_edge, ROM[addr + 1] << left_edge, ROM[addr + 2] << left_edge, ROM[addr + 3] << left_edge};
		end
		else begin
			window_map = '{ROM[addr], ROM[addr + 1], ROM[addr + 2], ROM[addr + 3]};
		end
			
		if (top_edge) begin
			case (top_edge) 
				2'b01 : begin
					window_map = '{window_map[2], window_map[1], window_map[0], 0};
				end
				2'b10 : begin
					window_map = '{window_map[1], window_map[0], 0, 0};
				end
			endcase
		end
		/*
		else if (bottom_edge) begin
			window_map = '{window_map[2], window_map[1], window_map[0], 0};
		end*/
		
		final_data = window_map[3 - row];
		
		template_map = {(final_data[0]) ? on_template : BLACK, (final_data[1]) ? on_template : BLACK, (final_data[2]) ? on_template : BLACK, (final_data[3]) ? on_template : BLACK};
	end
endmodule  