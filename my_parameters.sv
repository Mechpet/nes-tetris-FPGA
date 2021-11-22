package my_pkg;

parameter [6:0] score_label_left_col = 29;
parameter [6:0] score_label_right_col = 33;
parameter [6:0] score_label_row = 5;

parameter [6:0] lines_label_left_col = 15;
parameter [6:0] lines_label_right_col = 20;
parameter [6:0] lines_label_row = 3;

parameter [6:0] level_label_left_col = 29;
parameter [6:0] level_label_right_col = 33;
parameter [6:0] level_label_row = 18;

parameter [6:0] score_val_left_col = 26;
parameter [6:0] score_val_right_col = 33;
parameter [6:0] score_val_row = 6;

parameter [6:0] lines_val_left_col = 21;
parameter [6:0] lines_val_right_col = 24;
parameter [6:0] lines_val_row = 3;

parameter [6:0] level_val_left_col = 29;
parameter [6:0] level_val_right_col = 32;
parameter [6:0] level_val_row = 19;

parameter [6:0] board_left_col = 15;
parameter [6:0] board_right_col = 24;
parameter [6:0] board_top_row = 5;
parameter [6:0] board_bottom_row = 24;

parameter [6:0] next_label_left_col = 29;
parameter [6:0] next_label_right_col = 32;
parameter [6:0] next_label_row = 9;

parameter [6:0] next_window_left_col = 29;
parameter [6:0] next_window_right_col = 32;
parameter [6:0] next_window_top_row = 10; // Displaced 
parameter [6:0] next_window_bottom_row = 12;

parameter [9:0] start_S = 28 * 16;
parameter [9:0] start_C = 12 * 16;
parameter [9:0] start_O = 24 * 16;
parameter [9:0] start_R = 27 * 16;
parameter [9:0] start_E = 14 * 16;
parameter [9:0] start_L = 21 * 16;
parameter [9:0] start_I = 18 * 16;
parameter [9:0] start_N = 23 * 16;
parameter [9:0] start_V = 31 * 16;
parameter [9:0] start_dash = 40 * 16;
parameter [9:0] start_X = 33 * 16;
	parameter [9:0] start_T = 29 * 16;

parameter [11:0] level_lines_addr = 0;
parameter [11:0] score_addr = 1;
parameter [11:0] row_0_addr = 2;
parameter [11:0] next_addr = 22;

endpackage