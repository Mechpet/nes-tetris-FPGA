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
 *
 * @param col : [1:0] column of the window
 * @param row : [1:0] row of the window
 */

module tetromino_rom ( input logic [4:0]	identifier,
							  input logic [2:0] col, row,
							  output logic [1:0] block_template
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
		4'b0110,
		4'b0100,
		4'b0100,
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
	parameter [6:0] O_start = 0;
	parameter [6:0] I_start = 4;
	parameter [6:0] Z_start = 12;
	parameter [6:0] S_start = 20;
	parameter [6:0] T_start = 28;
	parameter [6:0] J_start = 44;
	parameter [6:0] L_start = 60;
	
	logic [6:0] addr;
	logic [3:0] data;
	logic onoroff;
	
	assign data = ROM[addr];
	assign onoroff = (col == 4) ? 0 : data[col];
	
	always_comb begin
		// Determine the address of ROM
		unique case (identifier[4:2])
			3'b000 : begin
				// 'O' in ROM[3:0]
				addr = O_start + row;
				block_template = (onoroff) ? 2'b00 : 2'b11;
			end
			3'b001 : begin
				// 'I' in ROM[11:4]
				addr = I_start + (4 * identifier[0]) + row;
				block_template = (onoroff) ? 2'b00 : 2'b11;
			end
			3'b010 : begin
				// 'Z' in ROM[19:12]
				addr = Z_start + (4 * identifier[0]) + row;
				block_template = (onoroff) ? 2'b01 : 2'b11;
			end
			3'b011 : begin
				// 'S' in ROM[27:20]
				addr = S_start + (4 * identifier[0]) + row;
				block_template = (onoroff) ? 2'b10 : 2'b11;
			end
			3'b100 : begin
				// 'T' in ROM[43:28]
				addr = T_start + (4 * identifier[1:0]) + row;
				block_template = (onoroff) ? 2'b00 : 2'b11;
			end
			3'b101 : begin
				// 'J' in ROM[59:44]
				addr = J_start + (4 * identifier[1:0]) + row;
				block_template = (onoroff) ? 2'b10 : 2'b11;
			end
			3'b110 : begin
				// 'L' in ROM[75:60]
				addr = L_start + (4 * identifier[1:0]) + row;
				block_template = (onoroff) ? 2'b01 : 2'b11;
			end
		endcase
	end
endmodule  