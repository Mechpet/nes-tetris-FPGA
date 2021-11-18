/*
 * vga.h
 * Based on Zuofu Cheng's text_mode_vga.h
 *
 *  Created on: Nov 17, 2021
 *      Author: thoms
 */

#ifndef VGA_H_
#define VGA_H_

#include <system.h>
#include <alt_types.h>

struct VGA_STRUCT {
	alt_u32 LEVEL_LINES;
	alt_u32 SCORE;
	alt_u32 ROW_0;
	alt_u32 RESERVED[2045];
	alt_u32 PALETTE;
};

static volatile struct VGA_STRUCT *vga_ctrl = VGA_CONTROLLER_0_BASE;


struct COLOR{
	char name [20];
	alt_u8 red;
	alt_u8 green;
	alt_u8 blue;
};

static struct COLOR colors[]={
    {"black",          0x0, 0x0, 0x0},
	{"blue",           0x0, 0x0, 0xa},
    {"green",          0x0, 0xa, 0x0},
	{"cyan",           0x0, 0xa, 0xa},
    {"red",            0xa, 0x0, 0x0},
	{"magenta",        0xa, 0x0, 0xa},
    {"brown",          0xa, 0x5, 0x0},
	{"light gray",     0xa, 0xa, 0xa},
    {"dark gray",      0x5, 0x5, 0x5},
	{"light blue",     0x5, 0x5, 0xf},
    {"light green",    0x5, 0xf, 0x5},
	{"light cyan",     0x5, 0xf, 0xf},
    {"light red",      0xf, 0x5, 0x5},
	{"light magenta",  0xf, 0x5, 0xf},
    {"yellow",         0xf, 0xf, 0x5},
	{"white",          0xf, 0xf, 0xf}
};

void vga_clear();
void increase_level();
void step_lines(alt_u8 step);
void set_palette(alt_u8 new_red1, alt_u8 new_green1, alt_u8 new_blue1, alt_u8 new_red2, alt_u8 new_green2, alt_u8 new_blue2);


void test_inc_level_line_values();
void test_inc_level_line_values2();
void test_score_values(alt_u32 new_score);
void test_row_0_values();

#endif /* VGA_H_ */
