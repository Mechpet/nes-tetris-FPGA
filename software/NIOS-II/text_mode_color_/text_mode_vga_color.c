/*
 * text_mode_vga_color.c
 * Minimal driver for text mode VGA support
 * This is for Week 2, with color support
 *
 *  Created on: Oct 25, 2021
 *      Author: zuofu
 */

#include <system.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <alt_types.h>
#include "text_mode_vga_color.h"

void textVGAColorClr()
{
	for (int i = 0; i<(ROWS*COLUMNS) * 2; i++)
	{
		vga_ctrl->VRAM[i] = 0x00;
	}
	for (int i = 0; i < 8; i++) {
		vga_ctrl->PALETTE[i] = 0x0000;
	}
}

void textVGADrawColorText(char* str, int x, int y, alt_u8 background, alt_u8 foreground)
{
	int i = 0;
	while (str[i]!=0)
	{
		vga_ctrl->VRAM[(y*COLUMNS + x + i) * 2] = foreground << 4 | background;
		vga_ctrl->VRAM[(y*COLUMNS + x + i) * 2 + 1] = str[i];
		i++;
	}
}

void setColorPalette (alt_u8 color, alt_u8 red, alt_u8 green, alt_u8 blue)
{
	//fill in this function to set the color palette starting at offset 0x0000 2000 (from base)
	alt_u8 i = color >> 1;
	switch (color % 2) {
		case 0:
			vga_ctrl->PALETTE[i] &= 33546240;
			vga_ctrl->PALETTE[i] |= red << 9 | green << 5 | blue << 1;
			break;
		case 1:
			vga_ctrl->PALETTE[i] &= 8190;
			vga_ctrl->PALETTE[i] |= red << 21 | green << 17 | blue << 13;
			break;
		default:
			printf("Unexpected color index = %u\n", color);
	}
}


void textVGAColorScreenSaver()
{
	//This is the function you call for your week 2 demo
	char color_string[80];
    int fg, bg, x, y;
	textVGAColorClr();
	//initialize palette
	for (int i = 0; i < 16; i++)
	{
		/*
i = 0; vga_ctrl->PALETTE[0] = 0
i = 1; vga_ctrl->PALETTE[0] = 81920
i = 2; vga_ctrl->PALETTE[1] = 320
i = 3; vga_ctrl->PALETTE[1] = 1392960
i = 4; vga_ctrl->PALETTE[2] = 5120
i = 5; vga_ctrl->PALETTE[2] = 21054464
i = 6; vga_ctrl->PALETTE[3] = 5280
i = 7; vga_ctrl->PALETTE[3] = 22365344
i = 8; vga_ctrl->PALETTE[4] = 2730
i = 9; vga_ctrl->PALETTE[4] = 11266730
i = 10; vga_ctrl->PALETTE[5] = 3050
i = 11; vga_ctrl->PALETTE[5] = 12577770
i = 12; vga_ctrl->PALETTE[6] = 7850
i = 13; vga_ctrl->PALETTE[6] = 32239274
i = 14; vga_ctrl->PALETTE[7] = 8170
i = 15; vga_ctrl->PALETTE[7] = 33550314
		 */
		printf("i = %4u; (BEFORE) vga_ctrl->PALETTE[%3u] = %32u\n", i, i >> 1, vga_ctrl->PALETTE[i >> 1]);
		setColorPalette (i, colors[i].red, colors[i].green, colors[i].blue);
		printf("i = %4u; vga_ctrl->PALETTE[%3u] = %32u\n", i, i >> 1, vga_ctrl->PALETTE[i >> 1]);
	}
	while (1)
	{
		fg = rand() % 16;
		bg = rand() % 16;
		while (fg == bg)
		{
			fg = rand() % 16;
			bg = rand() % 16;
		}
		sprintf(color_string, "Drawing %s text with %s background", colors[fg].name, colors[bg].name);

		x = rand() % (80-strlen(color_string));
		y = rand() % 30;
		textVGADrawColorText (color_string, x, y, bg, fg);
		usleep (100000);
	}
}

int main() {
	while (1) {
		textVGAColorScreenSaver();
	}
	return 0;
}
