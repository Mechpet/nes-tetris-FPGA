// External keycode -> SoC -> AVALON
module key_handler (
	input logic clk,
	input logic [7:0] keycode,
	output logic [7:0] key_data,
	output logic key_state
);

logic [7:0] prev_keycode = 0;

always_ff @ (posedge clk) begin
	key_data <= keycode;
	prev_keycode <= key_data;
end

assign key_state = (prev_keycode != keycode);
endmodule