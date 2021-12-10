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
#include <time.h>
#include <math.h>
#include <alt_types.h>

#include "altera_avalon_spi.h"
#include "altera_avalon_spi_regs.h"
#include "altera_avalon_pio_regs.h"
#include "sys/alt_irq.h"
#include "usb_kb/GenericMacros.h"
#include "usb_kb/GenericTypeDefs.h"
#include "usb_kb/HID.h"
#include "usb_kb/MAX3421E.h"
#include "usb_kb/transfer.h"
#include "usb_kb/usb_ch9.h"
#include "usb_kb/USB.h"
#include "vga.h"
#include "sgtl5000/sgtl5000.h"

extern HID_DEVICE hid_device;

static BYTE addr = 1; 				//hard-wired USB address
const char* const devclasses[] = { " Uninitialized", " HID Keyboard", " HID Mouse", " Mass storage" };

BYTE GetDriverandReport() {
	BYTE i;
	BYTE rcode;
	BYTE device = 0xFF;
	BYTE tmpbyte;

	DEV_RECORD* tpl_ptr;
	//////printf("Reached USB_STATE_RUNNING (0x40)\n");
	for (i = 1; i < USB_NUMDEVICES; i++) {
		tpl_ptr = GetDevtable(i);
		if (tpl_ptr->epinfo != NULL) {
			//////printf("Device: %d", i);
			//////printf("%s \n", devclasses[tpl_ptr->devclass]);
			device = tpl_ptr->devclass;
		}
	}
	//Query rate and protocol
	rcode = XferGetIdle(addr, 0, hid_device.interface, 0, &tmpbyte);
	if (rcode) {   //error handling
		//////printf("GetIdle Error. Error code: ");
		//////printf("%x \n", rcode);
	} else {
		//////printf("Update rate: ");
		//////printf("%x \n", tmpbyte);
	}
	//////printf("Protocol: ");
	rcode = XferGetProto(addr, 0, hid_device.interface, &tmpbyte);
	if (rcode) {   //error handling
		//////printf("GetProto Error. Error code ");
		//////printf("%x \n", rcode);
	} else {
		//////printf("%d \n", tmpbyte);
	}
	return device;
}

void setLED(int LED) {
	IOWR_ALTERA_AVALON_PIO_DATA(LEDS_PIO_BASE,
			(IORD_ALTERA_AVALON_PIO_DATA(LEDS_PIO_BASE) | (0x001 << LED)));
}

void clearLED(int LED) {
	IOWR_ALTERA_AVALON_PIO_DATA(LEDS_PIO_BASE,
			(IORD_ALTERA_AVALON_PIO_DATA(LEDS_PIO_BASE) & ~(0x001 << LED)));

}

void printSignedHex0(signed char value) {
	BYTE tens = 0;
	BYTE ones = 0;
	WORD pio_val = IORD_ALTERA_AVALON_PIO_DATA(HEX_DIGITS_PIO_BASE);
	if (value < 0) {
		setLED(11);
		value = -value;
	} else {
		clearLED(11);
	}
	//handled hundreds
	if (value / 100)
		setLED(13);
	else
		clearLED(13);

	value = value % 100;
	tens = value / 10;
	ones = value % 10;

	pio_val &= 0x00FF;
	pio_val |= (tens << 12);
	pio_val |= (ones << 8);

	IOWR_ALTERA_AVALON_PIO_DATA(HEX_DIGITS_PIO_BASE, pio_val);
}

void printSignedHex1(signed char value) {
	BYTE tens = 0;
	BYTE ones = 0;
	DWORD pio_val = IORD_ALTERA_AVALON_PIO_DATA(HEX_DIGITS_PIO_BASE);
	if (value < 0) {
		setLED(10);
		value = -value;
	} else {
		clearLED(10);
	}
	//handled hundreds
	if (value / 100)
		setLED(12);
	else
		clearLED(12);

	value = value % 100;
	tens = value / 10;
	ones = value % 10;
	tens = value / 10;
	ones = value % 10;

	pio_val &= 0xFF00;
	pio_val |= (tens << 4);
	pio_val |= (ones << 0);

	IOWR_ALTERA_AVALON_PIO_DATA(HEX_DIGITS_PIO_BASE, pio_val);
}

void setKeycode(WORD keycode0, WORD keycode1, WORD keycode2, WORD keycode3, WORD keycode4, WORD keycode5, unsigned int acc)
{
	static int prev_direction[2], prev_rotation[2], DAS;
	IOWR_ALTERA_AVALON_PIO_DATA(KEYCODE_BASE, keycode0); // was x8002000
	// Current orientation and position of the piece.
	struct piece curr_piece;

	// Supposed orientation and position of the piece if it dropped one block.
	struct piece next_piece, prev_next_piece;
	alt_u32 new_window, prev_new_window, left_window, right_window, top_window, bottom_window;
	int DAS_interval;
	int drop_interval;

	WORD keycode[6] = {keycode0, keycode1, keycode2, keycode3, keycode4, keycode5};

	if (vga_ctrl->ASSERTION & 0x00000004) {
		// In game over screen
		//printf("In game over\n");
		for (unsigned t = 0; t < 6; t++) {
		////printf("Keycode[%d] = %d\n", t, keycode[t]);
			if (keycode[t] != 79 && keycode[t] != 80 && keycode[t] != 81 && keycode[t] != 7 && keycode[t] != 9 && keycode[t] != 40) {
				continue;
			}
			else if (keycode[t] == 7 || keycode[t] == 9 || keycode[t] == 40) {
				vga_ctrl->ASSERTION &= 0xFFFFFFFB;
				vga_ctrl->ASSERTION |= 0x00000002;
				for (int i = 0; i < 20; i++) {
					vga_ctrl->BOARD[i] = 0x00000000;
					vga_ctrl->DELAY = 0x00000000;
					vga_ctrl->LEVEL_LINES = 0x00000000;
				}
				break;
			}
		}
	}
	else if ((vga_ctrl->ASSERTION & 0x00000002) == 0) {
		//printf("In board\n");

		// Indicates held key contributes to the DAS (probably the slowest playstyle)
	if (acc) {
		DAS++;
		if (DAS > 3) {
			DAS_interval = 1;
		}
		else if (DAS > 1) {
			DAS_interval = 2;
		}
		else {
			DAS_interval = 3;
		}
		if (DAS % DAS_interval != 0) {
			return;
		}
	}
	else {
		DAS = 0;
	}

	// Iterate through all keys and determine whether the resulting operation is legal
	for (unsigned t = 0; t < 6; t++) {
		////printf("Keycode[%d] = %d\n", t, keycode[t]);
		if (keycode[t] != 79 && keycode[t] != 80 && keycode[t] != 81 && keycode[t] != 7 && keycode[t] != 9) {
			continue;
		}
		else if (t == 0) {
			////printf("Window = %x\n", vga_ctrl->WINDOW);
			curr_piece = assemble_piece(vga_ctrl->WINDOW);
			next_piece = curr_piece;
			new_window = vga_ctrl->WINDOW;
			if ((vga_ctrl->WINDOW & 0x0000001C) == (T_PIECE << 2)) {
				for (int i = 0; i < 4; i++) {
					//printf("[%d,%d], ", curr_piece.col[i], curr_piece.row[i]);
				}
			}
			//printf("window = %x\n", vga_ctrl->WINDOW);
		}
		prev_new_window = new_window;
		prev_next_piece = next_piece;
		left_window = (new_window & 0x00001E00) >> 9;
		right_window = (new_window & 0x000001E0) >> 5;
		top_window = (new_window & 0x007C0000) >> 18;
		bottom_window = (new_window & 0x0003E000) >> 13;

		if (keycode[t] == 79) {	// Right arrow (move right)
			next_piece.col[0] += 2, next_piece.col[1] += 2, next_piece.col[2] += 2, next_piece.col[3] += 2;
			if (left_window >= 6) {
				new_window += (1 << 9);
			}
			else if (right_window <= 2) {
				new_window += (1 << 5);
			}
			else {
				new_window += (1 << 5 | 1 << 9);
			}

			if ((new_window & 0x0000001C) == (T_PIECE << 2)) {
				for (int i = 0; i < 4; i++) {
					//printf("(%d,%d), ", next_piece.col[i], next_piece.row[i]);
				}
				//printf("new window = %x\n", new_window);
			}
		}
		else if (keycode[t] == 80) {	// Left arrow (move left)
			next_piece.col[0] -= 2, next_piece.col[1] -= 2, next_piece.col[2] -= 2, next_piece.col[3] -= 2;
			if (right_window <= 3) {
				new_window -= (1 << 5);
			}
			else if (left_window >= 7) {
				new_window -= (1 << 9);
			}
			else {
				new_window -= (1 << 5 | 1 << 9);
			}
		}
		else if (keycode[t] == 81) {	// Down arrow (move down)
			next_piece.row[0]++, next_piece.row[1]++, next_piece.row[2]++, next_piece.row[3]++;
			if (bottom_window < 3) {
				new_window += (1 << 13);
			}
			else if (top_window > 15) {
				new_window += (1 << 18);
			}
			else {
				new_window += (1 << 13 | 1 << 18);
			}
			prev_direction[2] = 1;
		}

		else if (keycode[t] == 7 || keycode[t] == 9) {
			if (keycode[t] == 7 && !prev_rotation[0]) {	// D (rotate CW)
				prev_rotation[0] = 1;
				next_piece = rotate_piece(curr_piece, -1);
				new_window = (new_window & 0xFFFFFFFC) | next_piece.orient;
			}
			else {
				prev_rotation[0] = 0;
			}

			if (keycode[t] == 9 && !prev_rotation[1]) {	// F (rotate CCW)
				prev_rotation[1] = 1;
				next_piece = rotate_piece(curr_piece, 1);
				new_window = (new_window & 0xFFFFFFFC) | next_piece.orient;
			}
			else {
				prev_rotation[1] = 0;
			}
		}

		if (!is_legal_world(next_piece)) {
			//printf("Illegal - continue using window = %x\n", prev_new_window);
			for (int i = 0; i < 4; i++) {
				//printf("{%d,%d}, ", prev_next_piece.col[i], prev_next_piece.row[i]);
			}
			new_window = prev_new_window;
			next_piece = prev_next_piece;
		}
	}
	if (is_legal_world(next_piece)) {
		vga_ctrl->WINDOW = new_window;
		//printf("Use: %x\n", new_window);
		for (int i = 0; i < 4; i++) {
			//printf("{%d,%d}, ", next_piece.col[i], next_piece.row[i]);
		}
	}
	}
	else {
		// Level select menu - accept keys: left, right, d, f, enter, 1, 2, 3, 4, 5, 6, 7, 8, 9
		// Numbers determine multipliers to selected level (i.e. if hovering level 3 and press 2, actual level is 3 + 20 = 23).
		//printf("In level select\n");
		//printf("because Assertion = %x\n and ASSERTION & 0x00000002 == %x\n", vga_ctrl->ASSERTION, vga_ctrl->ASSERTION & 0x00000002);
		for (unsigned t = 0; t < 6; t++) {
		////printf("Keycode[%d] = %d\n", t, keycode[t]);
			if ((keycode[t] != 79 && keycode[t] != 80 && keycode[t] != 7 && keycode[t] != 9 && keycode[t] != 40) && ((keycode[t] > 38) || (keycode[t] < 30))) {
				continue;
			}
			if (keycode[t] == 79) { // Right
				if (vga_ctrl->LEVEL_HOVER == 9) {
					vga_ctrl->LEVEL_HOVER = 0;
				}
				else {
					vga_ctrl->LEVEL_HOVER = (vga_ctrl->LEVEL_HOVER + 1) % 10;
				}
				vga_ctrl->SCORE = 0;
			}
			else if (keycode[t] == 80) { //Left
				if (vga_ctrl->LEVEL_HOVER == 0) {
					vga_ctrl->LEVEL_HOVER = 9;
				}
				else {
					vga_ctrl->LEVEL_HOVER = (vga_ctrl->LEVEL_HOVER - 1) % 10;
				}
				vga_ctrl->SCORE = 0;
			}
			else if (keycode[t] == 7 || keycode[t] == 9) {
				vga_ctrl->ASSERTION &= 0xFFFFFFFD;
				vga_ctrl->LEVEL_LINES = convert_to_BDC(vga_ctrl->LEVEL_HOVER) << 16;
				drop_interval = (100 - convert_to_dec(vga_ctrl->LEVEL_LINES >> 16));
				vga_ctrl->DROP_INTERVAL = (drop_interval < 0) ? 1 : drop_interval;
				vga_ctrl->SCORE = 0;
			}
			else if (keycode[t] == 40) {
				vga_ctrl->ASSERTION &= 0xFFFFFFFD;
				vga_ctrl->LEVEL_LINES = convert_to_BDC(vga_ctrl->LEVEL_HOVER + 10) << 16;
				drop_interval = (100 - convert_to_dec(vga_ctrl->LEVEL_LINES >> 16));
				vga_ctrl->DROP_INTERVAL = (drop_interval < 0) ? 1 : drop_interval;
				vga_ctrl->SCORE = 0;
			}
			else {
				vga_ctrl->ASSERTION &= 0xFFFFFFFD;
				vga_ctrl->LEVEL_LINES = convert_to_BDC(vga_ctrl->LEVEL_HOVER + (keycode[t] - 29) * 10) << 16;
				drop_interval = (100 - convert_to_dec(vga_ctrl->LEVEL_LINES >> 16));
				vga_ctrl->DROP_INTERVAL = (drop_interval < 0) ? 1 : drop_interval;
				vga_ctrl->SCORE = 0;
			}
		}
	}
}

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
	for (int i = 0; i < BOARD_ROWS; i++) {
		vga_ctrl->BOARD[i] = 0x00000000;
	}
	vga_ctrl->NEXT = 0x00000000;
	vga_ctrl->FRAME = 0x00000000;
	vga_ctrl->DELAY = 0x00000000;
	vga_ctrl->LINES_CLEARED = 0x00000000;
	vga_ctrl->LEVEL_SELECT = 0x00000000;
	vga_ctrl->LEVEL_HOVER = 0x00000000;
	for (int i = 0; i < RESERVE_LENGTH; i++) {
		vga_ctrl->RESERVED[i]	  = 0x00000000;
	}
	vga_ctrl->PALETTE 	  = 0x00000000;
	vga_ctrl->WINDOW	  = 0x00000000;
	vga_ctrl->ASSERTION = 0x00000002;
	vga_ctrl->DROP_INTERVAL = 0xFFFFFFFFF;
	//printf("vga_ctrl->ASSERTION upon reset is %x\n", vga_ctrl->ASSERTION);
}

// Convert BDC (8 digits) to decimal
alt_u32 convert_to_dec(alt_u32 base) {
    alt_u32 return_number = 0;
    unsigned int digit;
    unsigned int factor;
    unsigned int bdc_mask = 0x0000000F;
    for (unsigned i = 0; i < 8; i++) {
        digit = (base & (bdc_mask << (i * 4))) >> (i * 4);
        factor = pow(10, i);
        return_number += (digit * factor);
    }
    return return_number;
}

// Convert a decimal number (8 digits) to its BDC hexadecimal number (32 bit)
alt_u32 convert_to_BDC(alt_u32 dec) {
    alt_u32 return_number = 0;
    unsigned int number;
    unsigned int digit;
    unsigned int factor;
    unsigned int hex;
    unsigned int bdc_mask = 0x0000000F;
    for (unsigned i = 0; i < 8; i++) {
        number = dec % (int) (pow(10, i + 1));
        factor = pow(10, i);
        digit = number / pow(10, i);
        return_number += (digit << (i * 4));
    }
    return return_number;
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
	vga_ctrl->LEVEL_LINES &= decimal_mask;

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

	int drop_interval = (100 - convert_to_dec(vga_ctrl->LEVEL_LINES >> 16));
	vga_ctrl->DROP_INTERVAL = (drop_interval < 0) ? 1 : drop_interval;
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
	vga_ctrl->PALETTE = new_red2 << 21 | new_green2 << 17 | new_blue2 << 13 | new_red1 << 9 | new_green1 << 5 | new_blue1 << 1;
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
	for (int i = 0; i < BOARD_ROWS; i++) {
		vga_ctrl->BOARD[i] = rand() % ROW_10_MASK;
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
	//////printf("Next piece was %x\n.", next_piece_id);
}

/*
 * ([22:18] Window align top : 0
 * | [17:13] Window align bottom : 1
 * | [12:9] Window align left : 3
 * | [8:5] Window align right : 6
 * | [4:2] Current piece identifier : random
 * | [1:0] Current piece rotation identifier : 2'b00
 */
void test_spawn_current_piece() {
	alt_u32 current_piece_id = random_piece(), active0, active1;
	alt_u32 clear_mask = ROW_10_MASK;
	// Vertical alignment
	vga_ctrl->WINDOW = (current_piece_id << 2 | 0x00000006 << 5 | 0x00000003 << 9 | 0x00000001 << 13);
	//////printf("WINDOW is %x\n", vga_ctrl->WINDOW);
}

// Probe the seed / random number and mod it by 7 to obtain a number within [0, 6]
alt_u8 random_piece() {
	return vga_ctrl->SEED % 0x00000007;
}

void initial_spawn_piece() {
	// Spawn the current piece and the next piece.
	vga_ctrl->WINDOW = (0 << 2 | 0x00000006 << 5 | 0x00000003 << 9 | 0x00000001 << 13);
	//vga_ctrl->WINDOW = (6 << 2 | 0x00000006 << 5 | 0x00000003 << 9 | 0x00000007 << 13 | 0x00000003 << 18);
	spawn_next_piece();
	//////printf("WINDOW is %x\n", vga_ctrl->WINDOW);
}

// (Unused) Generate a new random piece to be used
void spawn_next_piece() {
	alt_u32 next_piece_id = random_piece();
	vga_ctrl->NEXT = next_piece_id << 2;
}

// Set the current piece to the next piece (unused)
void fetch_next_piece() {
	vga_ctrl->WINDOW = (vga_ctrl->NEXT | 0x00000006 << 5 | 0x00000003 << 9 | 0x00000001 << 13);

	spawn_next_piece();
}

// Should be generic checks for legality.
// Check if the dropped world is legal - if so, don't fetch the next piece and drop the current piece.
// If the dropped world is not legal, set the current world as the new world and fetch the next piece.
void drop_curr_piece() {
	alt_u32 inc = 0x00000001;
	alt_u32 piece_identifier = vga_ctrl->WINDOW & 0x0000001F;
	alt_u32 top_window = vga_ctrl->WINDOW & 0x007C0000;
	alt_u32 bottom_window = vga_ctrl->WINDOW & 0x0003E000;

	// Current orientation and position of the piece.
	struct piece curr_piece = assemble_piece(vga_ctrl->WINDOW);

	// Supposed orientation and position of the piece if it dropped one block.
	struct piece next_piece = curr_piece;
	for (unsigned i = 0; i < 4; i++) {
		next_piece.row[i]++;
	}

	if (!is_legal_world(curr_piece) && top_window == 0) {
		// Game Over
		//////printf("Game.\n");
		game_over_sequence();
	}
	else if (is_legal_world(next_piece)) {
		//////printf("Is a legal world.\n");
		alt_u32 bottom_inc = 0x00002000;
		alt_u32 top_inc = (bottom_window >= 0x00006000) ? inc << 18 : 0;

		vga_ctrl->WINDOW += (bottom_inc | top_inc);
	}
	else {
		////printf("Fix the piece on the board that is %x\n.", vga_ctrl->WINDOW);
		fill_board(curr_piece);
		//clear_lines();
		fetch_next_piece();
	}
}

// Increase lines and score by the `lines cleared` reg amount
void increase_lines_and_score() {
	alt_u32 lines_increase = vga_ctrl->LINES_CLEARED;
	alt_u32 score_increase = compute_score(lines_increase);	// decimal
	step_lines(lines_increase);
	alt_u32 score_decimal = convert_to_dec(vga_ctrl->SCORE) + score_increase;
	vga_ctrl->SCORE = convert_to_BDC(score_decimal);
}

// Simple NES calculation for score given # lines cleared
alt_u32 compute_score(alt_u32 lines_cleared) {
	alt_u32 level = convert_to_dec((vga_ctrl->LEVEL_LINES & 0xFFFF0000) >> 16);
	switch (lines_cleared) {
		case 1:
			return 40 * (level + 1);
		case 2:
			return 100 * (level + 1);
		case 3:
			return 300 * (level + 1);
		case 4:
			return 1200 * (level + 1);
	}
	return 0;
}

// Write to the board (aka RAM slots) with the current piece to be fixed
void fill_board(struct piece curr_piece) {
	alt_u8 template_block;
	switch (curr_piece.type) {
		case O_PIECE: case I_PIECE: case T_PIECE:
			template_block = WHITE_MASK;
			break;
		case Z_PIECE: case L_PIECE:
			template_block = LIGHT_MASK;
			break;
		case S_PIECE: case J_PIECE:
			template_block = DARK_MASK;
			break;
	}
	for (unsigned block = 0; block < 4; block++) {
		vga_ctrl->BOARD[curr_piece.row[block]] |= template_block << curr_piece.col[block];
	}
}

// Check if a DROP (increment in row), ROTATION (change in orient), or SHIFT (change in col) is valid.
enum bool is_legal_world(struct piece new_piece) {
	// If any checks fail, return `FALSE`. Return `TRUE` at the end of the function.
	// Check if the new piece is within the boundaries of the board.
	unsigned prev_col = 0, prev_row = 0;

	for (unsigned block = 0; block < 4; block++) {
		if (new_piece.row[block] < 0 || new_piece.row[block] > 19 || new_piece.col[block] < 0 || new_piece.col[block] > 18) {
			////printf("Piece is out of bounds.\n");
			////printf("Specifically, (col,row) = (%d,%d)\n", new_piece.col[block], new_piece.row[block]);
			return ILLEGAL;
		}

		// Check if the new piece does not collide with another block on the board.
		alt_u32 board_block_data = vga_ctrl->BOARD[new_piece.row[block]] & (ROW_1_MASK << new_piece.col[block]);
		if (board_block_data) {
			////printf("Piece conflicts with the board.\n");
			return ILLEGAL;
		}

		if (new_piece.row[block] < prev_row) {
			return ILLEGAL;
		}
		else if (new_piece.row[block] == prev_row){
			if (new_piece.col[block] <= prev_col) {
				return ILLEGAL;
			}
		}

		prev_col = new_piece.col[block];
		prev_row = new_piece.row[block];
	}

	// Passed all checks for `FALSE` legality.
	return LEGAL;
}


// Convert struct piece to its supposed rotated form
struct piece rotate_piece(struct piece curr_piece, int dir) {
	struct piece return_piece;
	return_piece.type = curr_piece.type;
	return_piece.orient = curr_piece.orient + dir;

	switch (curr_piece.type) {
	case O_PIECE:
		return_piece = curr_piece;
		break;
	case I_PIECE:
		switch (return_piece.orient) {
		case INITIAL: case INITIAL_FLIPPED:
			return_piece.col[0] = curr_piece.col[0] - 4;
			return_piece.col[1] = curr_piece.col[0] - 2;
			return_piece.col[2] = curr_piece.col[0];
			return_piece.col[3] = curr_piece.col[0] + 2;

			return_piece.row[0] = return_piece.row[1] = return_piece.row[2] = return_piece.row[3] = curr_piece.row[2];
			break;
		case CW: case CCW:
			return_piece.col[0] = return_piece.col[1] = return_piece.col[2] = return_piece.col[3] = curr_piece.col[2];
			return_piece.row[0] = curr_piece.row[0] - 4;
			return_piece.row[1] = curr_piece.row[0] - 2;
			return_piece.row[2] = curr_piece.row[0];
			return_piece.row[3] = curr_piece.row[0] + 2;
			break;
		}
		break;
	case Z_PIECE:
		switch (return_piece.orient) {
		case INITIAL: case INITIAL_FLIPPED:
			return_piece.col[0] = curr_piece.col[1] - 2;
			return_piece.col[1] = return_piece.col[2] = curr_piece.col[1];
			return_piece.col[3] = curr_piece.col[0];

			return_piece.row[0] = return_piece.row[1] = curr_piece.row[2];
			return_piece.row[2] = return_piece.row[3] = curr_piece.row[3];
			break;
		case CW: case CCW:
			return_piece.col[0] = return_piece.col[2] = curr_piece.col[3];
			return_piece.col[1] = return_piece.col[3] = curr_piece.col[2];

			return_piece.row[0] = curr_piece.row[0] - 2;
			return_piece.row[1] = return_piece.row[2] = curr_piece.row[0];
			return_piece.row[3] = curr_piece.row[2];
			break;
		}
		break;
	case S_PIECE:
		switch (return_piece.orient) {
		case INITIAL: case INITIAL_FLIPPED:
			return_piece.col[0] = return_piece.col[3] = curr_piece.col[0];
			return_piece.col[1] = curr_piece.col[2];
			return_piece.col[2] = curr_piece.col[0] - 2;

			return_piece.row[0] = return_piece.row[1] = curr_piece.row[2];
			return_piece.row[2] = return_piece.row[3] = curr_piece.row[3];
			break;
		case CW: case CCW:
			return_piece.col[0] = return_piece.col[1] = curr_piece.col[0];
			return_piece.col[2] = return_piece.col[3] = curr_piece.col[1];

			return_piece.row[0] = curr_piece.row[0] - 2;
			return_piece.row[1] = return_piece.row[2] = curr_piece.row[0];
			return_piece.row[3] = curr_piece.row[2];
			break;
		}
		break;
	case T_PIECE:
		switch (return_piece.orient) {
		case INITIAL:	// pivot: [3]
			return_piece.col[0] = curr_piece.col[3] - 2;
			return_piece.col[1] = return_piece.col[3] = curr_piece.col[3];
			return_piece.col[2] = curr_piece.col[3] + 2;

			return_piece.row[0] = return_piece.row[1] = return_piece.row[2] = curr_piece.row[3] - 2;
			return_piece.row[3] = curr_piece.row[3];
			break;
		case CW:
			switch (curr_piece.orient) {
			case INITIAL:
				return_piece.col[0] = return_piece.col[2] = return_piece.col[3] = curr_piece.col[1];
				return_piece.col[1] = curr_piece.col[0];

				return_piece.row[0] = curr_piece.row[0] - 2;
				return_piece.row[1] = return_piece.row[2] = curr_piece.row[0];
				return_piece.row[3] = curr_piece.row[3];
				break;
			case INITIAL_FLIPPED:
				return_piece.col[0] = return_piece.col[2] = return_piece.col[3] = curr_piece.col[0];
				return_piece.col[1] = curr_piece.col[1];

				return_piece.row[0] = curr_piece.row[0];
				return_piece.row[1] = return_piece.row[2] = curr_piece.row[1];
				return_piece.row[3] = curr_piece.row[3] + 2;
				break;
			}
			break;
			case INITIAL_FLIPPED:	// pivot: [3]
				return_piece.col[0] = return_piece.col[2] = curr_piece.col[3];
				return_piece.col[1] = curr_piece.col[3] - 2;
				return_piece.col[3] = curr_piece.col[3] + 2;

				return_piece.row[0] = curr_piece.row[3] - 4;
				return_piece.row[1] = return_piece.row[2] = return_piece.row[3] = curr_piece.row[3] - 2;
				break;
			case CCW:
				switch (curr_piece.orient) {
				case INITIAL:
					return_piece.col[0] = return_piece.col[1] = return_piece.col[3] = curr_piece.col[1];
					return_piece.col[2] = curr_piece.col[2];

					return_piece.row[0] = curr_piece.row[0] - 2;
					return_piece.row[1] = return_piece.row[2] = curr_piece.row[0];
					return_piece.row[3] = curr_piece.row[3];
					break;
				case INITIAL_FLIPPED:
					return_piece.col[0] = return_piece.col[1] = return_piece.col[3] = curr_piece.col[0];
					return_piece.col[2] = curr_piece.col[3];

					return_piece.row[0] = curr_piece.row[0];
					return_piece.row[1] = return_piece.row[2] = curr_piece.row[1];
					return_piece.row[3] = curr_piece.row[1] + 2;
					break;
				}
				break;
			}
		break;
	case J_PIECE:
		switch (return_piece.orient) {
		case INITIAL:	// pivot: 0
			return_piece.col[0] = curr_piece.col[0] - 2;
			return_piece.col[1] = curr_piece.col[0];
			return_piece.col[2] = return_piece.col[3] = curr_piece.col[0] + 2;

			return_piece.row[0] = return_piece.row[1] = return_piece.row[2] = curr_piece.row[0] + 2;
			return_piece.row[3] = curr_piece.row[0] + 4;
			break;
		case CW:
			switch (curr_piece.orient) {
			case INITIAL:
				return_piece.col[0] = return_piece.col[1] = return_piece.col[3] = curr_piece.col[1];
				return_piece.col[2] = curr_piece.col[0];

				return_piece.row[0] = curr_piece.row[0] - 2;
				return_piece.row[1] = curr_piece.row[0];
				return_piece.row[2] = return_piece.row[3] = curr_piece.row[3];
				break;
			case INITIAL_FLIPPED:
				return_piece.col[0] = return_piece.col[1] = return_piece.col[3] = curr_piece.col[2];
				return_piece.col[2] = curr_piece.col[0];

				return_piece.row[0] = curr_piece.row[0];
				return_piece.row[1] = curr_piece.row[1];
				return_piece.row[2] = return_piece.row[3] = curr_piece.row[1] + 2;
				break;
			}
			break;
		case INITIAL_FLIPPED:	// pivot: 3
			return_piece.col[0] = return_piece.col[1] = curr_piece.col[3] - 2;
			return_piece.col[2] = curr_piece.col[3];
			return_piece.col[3] = curr_piece.col[3] + 2;

			return_piece.row[0] = curr_piece.row[3] - 4;
			return_piece.row[1] = return_piece.row[2] = return_piece.row[3] = curr_piece.row[3] - 2;
			break;
		case CCW:
			switch (curr_piece.orient) {
			case INITIAL:
				return_piece.col[0] = return_piece.col[2] = return_piece.col[3] = curr_piece.col[1];
				return_piece.col[1] = curr_piece.col[2];

				return_piece.row[0] = return_piece.row[1] = curr_piece.row[0] - 2;
				return_piece.row[2] = curr_piece.row[0];
				return_piece.row[3] = curr_piece.row[0] + 2;
				break;
			case INITIAL_FLIPPED:
				return_piece.col[0] = return_piece.col[2] = return_piece.col[3] = curr_piece.col[2];
				return_piece.col[1] = curr_piece.col[3];

				return_piece.row[0] = return_piece.row[1] = curr_piece.row[0];
				return_piece.row[2] = curr_piece.row[1];
				return_piece.row[3] = curr_piece.row[1] + 2;
				break;
			}
			break;
		}
		break;
	case L_PIECE:
		switch (return_piece.orient) {
		case INITIAL:
			switch (curr_piece.orient) {
			case CW:
				return_piece.col[0] = return_piece.col[3] = curr_piece.col[0];
				return_piece.col[1] = curr_piece.col[1];
				return_piece.col[2] = curr_piece.col[1] + 2;

				return_piece.row[0] = return_piece.row[1] = return_piece.row[2] = curr_piece.row[2];
				return_piece.row[3] = curr_piece.row[3];
				break;
			case CCW:
				return_piece.col[0] = return_piece.col[3] = curr_piece.col[0] - 2;
				return_piece.col[1] = curr_piece.col[0];
				return_piece.col[2] = curr_piece.col[3];

				return_piece.row[0] = return_piece.row[1] = return_piece.row[2] = curr_piece.row[1];
				return_piece.row[3] = curr_piece.row[3];
				break;
			}
			break;
		case CW:
			switch (curr_piece.orient) {
			case INITIAL:
				return_piece.col[0] = curr_piece.col[0];
				return_piece.col[1] = return_piece.col[2] = return_piece.col[3] = curr_piece.col[1];

				return_piece.row[0] = return_piece.row[1] = curr_piece.row[0] - 2;
				return_piece.row[2] = curr_piece.row[0];
				return_piece.row[3] = curr_piece.row[3];
				break;
			case INITIAL_FLIPPED:
				return_piece.col[0] = curr_piece.col[1];
				return_piece.col[1] = return_piece.col[2] = return_piece.col[3] = curr_piece.col[2];

				return_piece.row[0] = return_piece.row[1] = curr_piece.row[0];
				return_piece.row[2] = curr_piece.row[1];
				return_piece.row[3] = curr_piece.row[1] + 2;
				break;
			}
			break;
		case INITIAL_FLIPPED:
			switch (curr_piece.orient) {
			case CW:
				return_piece.col[0] = return_piece.col[3] = curr_piece.col[1] + 2;
				return_piece.col[1] = curr_piece.col[0];
				return_piece.col[2] = curr_piece.col[1];

				return_piece.row[0] = curr_piece.row[0];
				return_piece.row[1] = return_piece.row[2] = return_piece.row[3] = curr_piece.row[2];
				break;
			case CCW:
				return_piece.col[0] = return_piece.col[3] = curr_piece.col[3];
				return_piece.col[1] = curr_piece.col[0] - 2;
				return_piece.col[2] = curr_piece.col[1];

				return_piece.row[0] = curr_piece.row[0];
				return_piece.row[1] = return_piece.row[2] = return_piece.row[3] = curr_piece.row[1];
				break;
			}
			break;
		case CCW:
			switch (curr_piece.orient) {
			case INITIAL:
				return_piece.col[0] = return_piece.col[1] = return_piece.col[2] = curr_piece.col[1];
				return_piece.col[3] = curr_piece.col[2];

				return_piece.row[0] = curr_piece.row[0] - 2;
				return_piece.row[1] = curr_piece.row[0];
				return_piece.row[2] = return_piece.row[3] = curr_piece.row[3];
				break;
			case INITIAL_FLIPPED:
				return_piece.col[0] = return_piece.col[1] = return_piece.col[2] = curr_piece.col[2];
				return_piece.col[3] = curr_piece.col[0];

				return_piece.row[0] = curr_piece.row[0];
				return_piece.row[1] = curr_piece.row[1];
				return_piece.row[2] = return_piece.row[3] = curr_piece.row[1] + 2;
				break;
			}
			break;
		}
		break;
	}
	return return_piece;
}

// Should be hard-coded generation of the structures.
/* piece:
 * 	  row in [0, 19]
 *    col in [0, 18] multiples of 2 {0, 2, 4, 6, 8, 10, 12, 14, 16, 18}
 *
 */
struct piece assemble_piece(alt_u32 piece_memory) {
	struct piece return_piece;

	// Need to check for edge cases.

	// Obtain the fields from the WINDOW memory.
	return_piece.type = (piece_memory & 0x0000001C) >> 2;
	return_piece.orient = (piece_memory & 0x00000003);
	alt_u32 top_window = (piece_memory & 0x007C0000) >> 18;
	alt_u32 bottom_window = (piece_memory & 0x0003E000) >> 13;
	alt_u32 left_window = (piece_memory & 0x00001E00) >> 9;
	alt_u32 right_window = (piece_memory & 0x000001E0) >> 5;

	alt_u8 left_col, right_col, bottom_row;

	switch (return_piece.type) {
		case O_PIECE:
			// 'O' piece
			// 0 1
			// 2 3
			/* bottom_row = (if the piece is touching the bottom of the board -> the bottom of the window) (else it is levitating one above the bottom of the window every time)*/
			bottom_row = bottom_window;
			if (right_window == 2) {
				left_col = left_window;
			}
			else {
				left_col = left_window + 1;
			}

			if (left_window == 7) {
				right_col = right_window;
			}
			else {
				right_col = right_window - 1;
			}
			//left_col = (right_window == 2) ? left_window : (left_window + 1);
			//right_col = (left_window == 7) ? right_window : (right_window - 1);
			return_piece.col[0] = return_piece.col[2] = left_col;
			return_piece.row[0] = return_piece.row[1] = bottom_row - 1;
			return_piece.col[1] = return_piece.col[3] = right_col;
			return_piece.row[2] = return_piece.row[3] = bottom_row;
			break;
		case I_PIECE:
			switch (return_piece.orient) {
				case INITIAL: case INITIAL_FLIPPED:
					// 'I' piece flat
					// 0 1 2 3
					bottom_row = bottom_window - 1;
					left_col = left_window;
					if (right_window != left_col + 3) {
						left_col = -50;
					}
					for (int i = 0; i < 4; i++) {
						return_piece.col[i] = left_col + i;
						return_piece.row[i] = bottom_row;
					}
					break;
				case CW: case CCW:
					// 'I' piece vertical (say right_col is the sole column)
					// 0
					// 1
					// 2
					// 3
					bottom_row = bottom_window;
					if (left_window == 7) {
						right_col = right_window;
					}
					else {
						right_col = right_window - 1;
					}

					for (int i = 0; i < 4; i++) {
						return_piece.col[i] = right_col;
						return_piece.row[i] = bottom_row - (3 - i);
					}
					break;
			}
			break;
		case Z_PIECE:
			switch (return_piece.orient) {
				case INITIAL: case INITIAL_FLIPPED:
					// 'Z' piece flat
					// 0 1
					//   2 3
					bottom_row = bottom_window;
					return_piece.col[0] = right_window - 2;
					return_piece.col[1] = return_piece.col[2] = right_window - 1;
					return_piece.col[3] = right_window;

					return_piece.row[0] = return_piece.row[1] = bottom_row - 1;
					return_piece.row[2] = return_piece.row[3] = bottom_row;
					break;
				case CW: case CCW:
					// 'Z' piece rotated
					//   0
					// 1 2
					// 3
					bottom_row = bottom_window;
					return_piece.col[0] = return_piece.col[2] = right_window;
					return_piece.col[1] = return_piece.col[3] = right_window - 1;

					return_piece.row[0] = bottom_row - 2;
					return_piece.row[1] = return_piece.row[2] = bottom_row - 1;
					return_piece.row[3] = bottom_row;
					break;
			}
			break;
		case S_PIECE:
			switch (return_piece.orient) {
				case INITIAL: case INITIAL_FLIPPED:
					// 'S' piece flat
					//   0 1
					// 2 3
					bottom_row = bottom_window;
					return_piece.col[0] = return_piece.col[3] = right_window - 1;
					return_piece.col[1] = right_window;
					return_piece.col[2] = right_window - 2;

					return_piece.row[0] = return_piece.row[1] = bottom_row - 1;
					return_piece.row[2] = return_piece.row[3] = bottom_row;
					break;
				case CW: case CCW:
					// 'S' piece rotated
					// 0
					// 1 2
					//   3
					bottom_row = bottom_window;
					return_piece.col[0] = return_piece.col[1] = right_window - 1;
					return_piece.col[2] = return_piece.col[3] = right_window;

					return_piece.row[0] = bottom_row - 2;
					return_piece.row[1] = return_piece.row[2] = bottom_row - 1;
					return_piece.row[3] = bottom_row;
					break;
			}
			break;
		case T_PIECE:
			switch (return_piece.orient) {
				case INITIAL:
					// 'T' piece
					// 0 1 2
					//   3
					bottom_row = bottom_window;
					return_piece.col[0] = right_window - 2;
					return_piece.col[1] = return_piece.col[3] = right_window - 1;
					return_piece.col[2] = right_window;

					return_piece.row[0] = return_piece.row[1] = return_piece.row[2] = bottom_row - 1;
					return_piece.row[3] = bottom_row;
					break;
				case CW:
					//   0
					// 1 2
					//   3
					bottom_row = bottom_window;

					if (left_window == 7) {
						left_col = left_window;
					}
					else {
						left_col = right_window - 3;
					}
					return_piece.col[0] = return_piece.col[2] = return_piece.col[3] = left_col + 2;
					return_piece.col[1] = left_col + 1;

					return_piece.row[0] = bottom_row - 2;
					return_piece.row[1] = return_piece.row[2] = bottom_row - 1;
					return_piece.row[3] = bottom_row;
					break;
				case INITIAL_FLIPPED:
					//   0
					// 1 2 3
					bottom_row = bottom_window;
					return_piece.col[0] = return_piece.col[2] = right_window - 1;
					return_piece.col[1] = right_window - 2;
					return_piece.col[3] = right_window;

					return_piece.row[0] = bottom_row - 1;
					return_piece.row[1] = return_piece.row[2] = return_piece.row[3] = bottom_row;
					break;
				case CCW:
					// 0
					// 1 2
					// 3
					bottom_row = bottom_window;
					return_piece.col[0] = return_piece.col[1] = return_piece.col[3] = right_window - 1;
					return_piece.col[2] = right_window;

					return_piece.row[0] = bottom_row - 2;
					return_piece.row[1] = return_piece.row[2] = bottom_row - 1;
					return_piece.row[3] = bottom_row;
					break;
			}
			break;
		case J_PIECE:
			switch (return_piece.orient) {
				case INITIAL:
					// 0 1 2
					//     3
					bottom_row = bottom_window;
					return_piece.col[0] = right_window - 2;
					return_piece.col[1] = right_window - 1;
					return_piece.col[2] = return_piece.col[3] = right_window;

					return_piece.row[0] = return_piece.row[1] = return_piece.row[2] = bottom_row - 1;
					return_piece.row[3] = bottom_row;
					break;
				case CW:
					//   0
					//   1
					// 2 3
					bottom_row = bottom_window;
					if (left_window == 7) {
						right_col = right_window;
					}
					else {
						right_col = right_window - 1;
					}
					return_piece.col[0] = return_piece.col[1] = return_piece.col[3] = right_col;
					return_piece.col[2] = right_col - 1;

					return_piece.row[0] = bottom_row - 2;
					return_piece.row[1] = bottom_row - 1;
					return_piece.row[2] = return_piece.row[3] = bottom_row;
					break;
				case INITIAL_FLIPPED:
					// 0
					// 1 2 3
					bottom_row = bottom_window;

					return_piece.col[0] = return_piece.col[1] = right_window - 2;
					return_piece.col[2] = right_window - 1;
					return_piece.col[3] = right_window;

					return_piece.row[0] = bottom_row - 1;
					return_piece.row[1] = return_piece.row[2] = return_piece.row[3] = bottom_row;
					break;
				case CCW:
					// 0 1
					// 2
					// 3
					bottom_row = bottom_window;
					return_piece.col[0] = return_piece.col[2] = return_piece.col[3] = right_window - 1;
					return_piece.col[1] = right_window;

					return_piece.row[0] = return_piece.row[1] = bottom_row - 2;
					return_piece.row[2] = bottom_row - 1;
					return_piece.row[3] = bottom_row;
					break;
			}
			break;
		case L_PIECE:
			switch (return_piece.orient) {
				case INITIAL:
					// 0 1 2
					// 3
					bottom_row = bottom_window;
					return_piece.col[0] = return_piece.col[3] = right_window - 2;
					return_piece.col[1] = right_window - 1;
					return_piece.col[2] = right_window;

					return_piece.row[0] = return_piece.row[1] = return_piece.row[2] = bottom_row - 1;
					return_piece.row[3] = bottom_row;

					break;
				case CW:
					// 0 1
					//   2
					//   3
					bottom_row = bottom_window;
					if (left_window == 7) {
						right_col = right_window;
					}
					else {
						right_col = right_window - 1;
					}
					return_piece.col[0] = right_col - 1;
					return_piece.col[1] = return_piece.col[2] = return_piece.col[3] = right_col;

					return_piece.row[0] = return_piece.row[1] = bottom_row - 2;
					return_piece.row[2] = bottom_row - 1;
					return_piece.row[3] = bottom_row;
					break;
				case INITIAL_FLIPPED:
					//     0
					// 1 2 3
					bottom_row = bottom_window;
					return_piece.col[0] = return_piece.col[3] = right_window;
					return_piece.col[1] = right_window - 2;
					return_piece.col[2] = right_window - 1;

					return_piece.row[0] = bottom_row - 1;
					return_piece.row[1] = return_piece.row[2] = return_piece.row[3] = bottom_row;
					break;
				case CCW:
					// 0
					// 1
					// 2 3
					bottom_row = bottom_window;
					return_piece.col[0] = return_piece.col[1] = return_piece.col[2] = right_window - 1;
					return_piece.col[3] = right_window;

					return_piece.row[0] = bottom_row - 2;
					return_piece.row[1] = bottom_row - 1;
					return_piece.row[2] = return_piece.row[3] = bottom_row;
					break;
			}
			break;
	}

	for (int i = 0; i < 4; i++) {
		return_piece.col[i] *= 2;
	}

	return return_piece;
}

// (Unused)
void game_over_sequence() {
	for (unsigned i = 0; i < 20; i++) {
		if (vga_ctrl->BOARD[i] & GAMEOVER_MASK) {
			continue;
		}
		else {
			vga_ctrl->BOARD[i] |= GAMEOVER_MASK;
			return;
		}
	}
}

int main() {
	vga_clear();
	SGTL_setup();	// Unused / unfinished (tried looking for information about it on the day before the project was due)
	// dark = red, light = green
	set_palette(colors[4].red, colors[4].green, colors[4].blue, colors[2].red, colors[2].green, colors[2].blue);
	alt_u32 counter = 0;
	BYTE rcode;
	BOOT_MOUSE_REPORT buf;		//USB mouse report
	BOOT_KBD_REPORT kbdbuf;

	BYTE runningdebugflag = 0;//flag to dump out a bunch of information when we first get to USB_STATE_RUNNING
	BYTE errorflag = 0; //flag once we get an error device so we don't keep dumping out state info
	BYTE device;
	WORD keycode;

	//////printf("initializing MAX3421E...\n");
	MAX3421E_init();
	//////printf("initializing USB...\n");
	USB_init();

	int to_clear = 0, prev_lines = 0, curr_lines = 0;

	initial_spawn_piece();
	while (1) {
		MAX3421E_Task();
		USB_Task();
		if (GetUsbTaskState() == USB_STATE_RUNNING) {
			if (vga_ctrl->LINES_CLEARED != 0) {
				////printf("Assert clear\n");
				increase_lines_and_score();
				curr_lines += vga_ctrl->LINES_CLEARED;
				vga_ctrl->LINES_CLEARED = 0x00000000;
				if (curr_lines - prev_lines >= 10) {
					increase_level();
					set_palette(vga_ctrl->SEED & 0x000000FF, rand(), (vga_ctrl->SEED & 0x00FF0000) >> 16, rand() * 2, (vga_ctrl->SEED & 0xFF000000) >> 24, (vga_ctrl->SEED & 0x0000FF00) >> 8);
					prev_lines += 10;
				}
				////printf("Done");
				////printf("LINES CLEARED = %d\n", vga_ctrl->LINES_CLEARED);
			}
			if (vga_ctrl->ASSERTION & 0x00000004) {
				vga_ctrl->DROP_INTERVAL = 0xFFFFFFFFF;
			}

			if (!runningdebugflag) {
				runningdebugflag = 1;
				setLED(9);
				device = GetDriverandReport();
			}
			else if (device == 1) {
				//run keyboard debug polling
				////printf("Polling\n");
				rcode = kbdPoll(&kbdbuf);
				if (rcode == hrNAK) {
					////printf("keycode[0] = %d\n", kbdbuf.keycode[0]);
					setKeycode(kbdbuf.keycode[0], kbdbuf.keycode[1], kbdbuf.keycode[2], kbdbuf.keycode[3], kbdbuf.keycode[4], kbdbuf.keycode[5], 1);
					continue;
					//kbdbuf.keycode[0] = 0; //NAK means no new data
				} else if (rcode) {
					continue;
					////printf("Rcode: ");
					////printf("%x \n", rcode);
				}
				else {
					setKeycode(kbdbuf.keycode[0], kbdbuf.keycode[1], kbdbuf.keycode[2], kbdbuf.keycode[3], kbdbuf.keycode[4], kbdbuf.keycode[5], 0);
				}
				printSignedHex0(kbdbuf.keycode[0]);
				printSignedHex1(kbdbuf.keycode[1]);
			}

			else if (device == 2) {
				rcode = mousePoll(&buf);
				if (rcode == hrNAK) {
					//NAK means no new data
					continue;
				} else if (rcode) {
					//////printf("Rcode: ");
					//////printf("%x \n", rcode);
					continue;
				}
				//////printf("X displacement: ");
				//////printf("%d ", (signed char) buf.Xdispl);
				printSignedHex0((signed char) buf.Xdispl);
				//////printf("Y displacement: ");
				//////printf("%d ", (signed char) buf.Ydispl);
				printSignedHex1((signed char) buf.Ydispl);
				//////printf("Buttons: ");
				//////printf("%x\n", buf.button);
				if (buf.button & 0x04)
					setLED(2);
				else
					clearLED(2);
				if (buf.button & 0x02)
					setLED(1);
				else
					clearLED(1);
				if (buf.button & 0x01)
					setLED(0);
				else
					clearLED(0);
			}
		} else if (GetUsbTaskState() == USB_STATE_ERROR) {
			//////printf("Error checking\n");
			if (!errorflag) {
				errorflag = 1;
				clearLED(9);
				//////printf("USB Error State\n");
				//print out string descriptor here
			}
		} else //not in USB running state
		{

			//////printf("USB task state: ");
			//////printf("%x\n", GetUsbTaskState());
			if (runningdebugflag) {	//previously running, reset USB hardware just to clear out any funky state, HS/FS etc
				runningdebugflag = 0;
				MAX3421E_init();
				USB_init();
			}
			errorflag = 0;
			clearLED(9);
		}


	}
	return 0;
}
