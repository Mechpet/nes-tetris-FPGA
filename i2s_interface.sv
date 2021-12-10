module i2s_processor (input logic i2s_lrclk,
							 input logic i2s_sclk,
							 input logic i2s_dout,
							 output logic i2s_din);
							 
logic [31:0] left_shift_reg;

always_ff @ (posedge i2s_sclk) begin
	// Left shift
	left_shift_reg <= {left_shift_reg[30:0], 0};
end

always_ff @ (posedge i2s_lrclk) begin
	// Parallel load
	
end

assign i2s_din = 1;
endmodule