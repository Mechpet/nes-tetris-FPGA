module register ( 
	input logic CLK,
	input logic RESET,
	input logic D,
	
	output logic Q
);

always_ff @ (posedge CLK) begin
	if (RESET) begin
		Q <= 1'b0;
	end
	else begin
		Q <= D;
	end
end
endmodule