/*
 * vga.h
 * Based on Zuofu Cheng's text_mode_vga.h
 *
 *  Created on: Nov 17, 2021
 *      Author: thoms
 */

#ifndef VGA_H_
#define VGA_H_

#define COLUMNS_BLOCKS 10
#define ROWS_BLOCKS 20

#include <system.h>
#include <alt_types.h>

struct VGA_STRUCT {
	alt_u32 LEVEL_LINES;
	alt_u32 SCORE;
};

static volatile struct VGA_STRUCT *vga_ctrl = VGA_CONTROLLER_0_BASE;

void vga_clear();
void test_inc_level_line_values();
void test_score_values(alt_u32 new_score);

#endif /* VGA_H_ */
