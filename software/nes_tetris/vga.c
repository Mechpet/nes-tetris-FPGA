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
	vga_ctrl->SCORE = 0x00000000;
}

/** test_inc_level_line_values
 * Parameters:
 * @step = Step increment to the memory per cycle.
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
void test_score_values(alt_u32 new_score) {
	vga_ctrl->SCORE = new_score;
}

int main() {
	vga_clear();
	while (1) {
		test_inc_level_line_values(0x01);
		test_score_values(vga_ctrl->LEVEL_LINES);
	}
	return 0;
}
