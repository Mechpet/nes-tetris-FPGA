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

parameter [6:0] level_sel_left_col = 12;
parameter [6:0] level_sel_right_col = 16;
parameter [6:0] level_sel_row = 9;

parameter [6:0] lvl_zero_col = 10;
parameter [6:0] lvl_zero_row = 12;

parameter [6:0] lvl_one_col = 12;
parameter [6:0] lvl_one_row = 12;

parameter [6:0] lvl_two_col = 14;
parameter [6:0] lvl_two_row = 12;

parameter [6:0] lvl_three_col = 16;
parameter [6:0] lvl_three_row = 12;

parameter [6:0] lvl_four_col = 18;
parameter [6:0] lvl_four_row = 12;

parameter [6:0] lvl_five_col = 10;
parameter [6:0] lvl_five_row = 14;

parameter [6:0] lvl_six_col = 12;
parameter [6:0] lvl_six_row = 14;

parameter [6:0] lvl_seven_col = 14;
parameter [6:0] lvl_seven_row = 14;

parameter [6:0] lvl_eight_col = 16;
parameter [6:0] lvl_eight_row = 14;

parameter [6:0] lvl_nine_col = 18;
parameter [6:0] lvl_nine_row = 14;

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

parameter [11:0] level_lines_addr = 12'h0;
parameter [11:0] score_addr = 12'h01;
parameter [11:0] row_0_addr = 12'h02;
parameter [11:0] next_addr = 12'h016;
parameter [11:0] frame_ctr_addr = 12'h017;
parameter [11:0] delay_ctr_addr = 12'h018;
parameter [11:0] lines_cleared_addr = 12'h019;
parameter [11:0] level_ctr_addr = 12'h01A;
parameter [11:0] level_hovered_addr = 12'h01B;
parameter [11:0] palette_addr = 12'h800;
parameter [11:0] window_addr = 12'h801;

parameter assert_drop = 32'h1;
parameter assert_generate = 32'h2;

parameter [4:0] palette_index = 0;
parameter [4:0] window_index = 1;
parameter [4:0] random_index = 2;
parameter [4:0] assertion_index = 3;
parameter [4:0] interval_index = 4;

parameter assert_clear = 1;

endpackage