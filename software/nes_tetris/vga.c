/*
 * vga.c
 * Based on Zuofu Cheng's text_mode_vga_color.c
 *  Created on: Nov 17, 2021
 *      Author: thoms
 */

#include <system.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <alt_types.h>
#include "vga.h"

/** vga_clear
 * Parameters: None.
 *
 * Description: Clear out the memory associated with the
 * VGA controller component.
 *
 * Expected behavior: Line, level, and current score are reset.
 */
void vga_clear() {
	vga_ctrl->LEVEL_LINES = 0x00000000;
	vga_ctrl->SCORE	 	  = 0x00000000;
	for (int i = 0; i < 20; i++) {
		vga_ctrl->BOARD[i] = 0x00000000;
	}
	vga_ctrl->NEXT = 0x00000000;
	for (int i = 0; i < 2044; i++) {
		vga_ctrl->RESERVED[i]	  = 0x00000000;
	}
	vga_ctrl->PALETTE 	  = 0x00000000;
}

/** increase_level
 * Parameters: None.
 *
 * Description: Increment the current level.
 *
 * Expected behavior: Level increases by 1 and no hexadecimal digits are displayed on VGA.
 */
void increase_level() {
	alt_u32 decimal_mask = 0xFFFF0000;
	alt_u32 nine_mask = 0x00090000;
	alt_u32 lines_mask 	 = 0x0000FFFF;
	alt_u32 curr_lines   = vga_ctrl->LEVEL_LINES & lines_mask;

	int zeroth_bit = 16, third_bit = 18;
	while (1) {
		if ( (vga_ctrl->LEVEL_LINES & nine_mask) == nine_mask) {
			decimal_mask <<= 4;
			nine_mask <<= 4;
			vga_ctrl->LEVEL_LINES &= decimal_mask;
			zeroth_bit += 4;
			third_bit += 4;
		}
		else {
			vga_ctrl->LEVEL_LINES += (~decimal_mask + 1 + curr_lines);
			break;
		}
	}
}

/** step_lines
 * Parameters:
 * @step = Number of lines to add to the current line count.
 *
 * Description: Step the current line count by a parameter amount.
 *
 * Expected behavior: Line count increases by the parameter amount and no hexadecimal digits are displayed on VGA.
 */
void step_lines(alt_u8 step) {
	alt_u32 decimal_mask = 0xFFFFFFFF;
	alt_u32 BCD_mask = 0x0000000F;
	alt_u32 max_BCD = 9 - step;

	int zeroth_bit = 0, third_bit = 3;
	while (1) {
		if (decimal_mask == 0xFFFF0000) {
			// Signifies `line count` overflow.
			break;
		}
		if ( (vga_ctrl->LEVEL_LINES & BCD_mask) > max_BCD) {
			decimal_mask <<= 4;
			BCD_mask <<= 4;
			max_BCD <<= 4;
			vga_ctrl->LEVEL_LINES &= decimal_mask;
			zeroth_bit += 4;
			third_bit += 4;
		}
		else {
			vga_ctrl->LEVEL_LINES += (~decimal_mask + step);
			break;
		}
	}
}

// Dark = Color index 1
// Light = Color index 2
void set_palette(alt_u8 new_red1, alt_u8 new_green1, alt_u8 new_blue1, alt_u8 new_red2, alt_u8 new_green2, alt_u8 new_blue2) {
	vga_ctrl->PALETTE &= 0x00000000;
	vga_ctrl->PALETTE |= new_red2 << 21 | new_green2 << 17 | new_blue2 << 13 | new_red1 << 9 | new_green1 << 5 | new_blue1 << 1;
	printf("Palette = %x\n", vga_ctrl->PALETTE);
}

/** test_inc_level_line_values
 * Parameters: None.
 *
 * Description: Testing of incrementing the memory associated with
 * level value and line count.
 *
 * Expected behavior: Line increases (still has alphabet), then the level increases (still has alphabet).
 */
void test_inc_level_line_values() {
	alt_u32 decimal_mask = 0xFFFFFFFF;
	alt_u32 nine_mask = 0x00000009;

	int zeroth_bit = 0, third_bit = 3;
	while (1) {
		if ( (vga_ctrl->LEVEL_LINES & nine_mask) == nine_mask) {
			decimal_mask <<= 4;
			nine_mask <<= 4;
			vga_ctrl->LEVEL_LINES &= decimal_mask;
			zeroth_bit += 4;
			third_bit += 4;
		}
		else {
			vga_ctrl->LEVEL_LINES += (~decimal_mask + 1);
			break;
		}
	}
}

/** test_inc_level_line_values
 * Parameters:
 * @step = Step increment to the memory per cycle.
 *
 * Description: Testing of incrementing the memory associated with
 * level value and line count.
 *
 * Expected behavior: Line increases, then the level increases.
 */
void test_score_values() {
	alt_u32 decimal_mask = 0xFFFFFFFF;
	alt_u32 nine_mask = 0x00000009;

	int zeroth_bit = 0, third_bit = 3;
	while (1) {
		if ( (vga_ctrl->SCORE & nine_mask) == nine_mask) {
			decimal_mask <<= 4;
			nine_mask <<= 4;
			vga_ctrl->SCORE &= decimal_mask;
			zeroth_bit += 4;
			third_bit += 4;
		}
		else {
			vga_ctrl->SCORE += (~decimal_mask + 1);
			break;
		}
	}
}

/** test_board_values
 * Parameters: None.
 *
 * Description: Testing of randomizing the board values.
 *
 * Expected behavior: Random blocks appear in the board per row.
 * There should be 4 visible types of blocks that appear (i.e. the templates).
 */
void test_board_values() {
	for (int i = 0; i < 20; i++) {
		vga_ctrl->BOARD[i] = rand() % 0x000FFFFF;
	}
}

/** test_next_piece
 * Parameters: None.
 *
 * Description: Testing of randomizing the next tetromino piece.
 *
 * Expected behavior: Random tetromino pieces appear in the next block window.
 * The tetromino pieces should be centered in the window in their initial orientations.
 */
void test_next_piece() {
	alt_u32 next_piece_id = rand() % 0x00000007;
	vga_ctrl->NEXT = next_piece_id << 2;
	printf("Next piece was %x\n.", next_piece_id);
}

int main() {
	vga_clear();
	// dark = red, light = green
	set_palette(colors[4].red, colors[4].green, colors[4].blue, colors[2].red, colors[2].green, colors[2].blue);
	usleep(1000);
	alt_u32 counter = 0;
	usleep(1000);
	int game_overing = 0;
	int step = 5000;
	while (1) {
		if (counter % step == 0) {
			if (game_overing || counter % 50000 == 0) {
				vga_ctrl->BOARD[game_overing] |= 0x00100000;
				game_overing++;
				step = 100;
				if (game_overing == 20) {
					game_overing = 0;
					step = 5000;
				}
			}
			else {
				test_board_values();
				test_next_piece();
			}
		}
		if (counter % 10 == 0) {
			test_inc_level_line_values();
		}
		if (counter % 30 == 0) {
			test_score_values();
		}
		counter++;
	}
	return 0;
}
