// Use clocks to 
module random_generator ( 
	input logic master_CLK,
	input logic CLK0, CLK1, CLK2, CLK3, CLK4, CLK5, CLK6, CLK7, CLK8, CLK9, CLK10, CLK11, CLK12, CLK13, CLK14, CLK15,
	input logic CLK16, CLK17, CLK18, CLK19, CLK20, CLK21, CLK22, CLK23, CLK24, CLK25, CLK26, CLK27, CLK28, CLK29, CLK30, CLK31,
	input logic RESET,
	
	
	// Avalon-MM Slave Signals
	input  logic AVL_READ,					// Avalon-MM Read
	input  logic AVL_CS,					// Avalon-MM Chip Select
	output logic [31:0] AVL_READDATA		// Avalon-MM Read Data
);

register seed [31:0] (
	.CLK(master_CLK),
	.RESET(RESET),
	.D('{CLK0, CLK1, CLK2, CLK3, CLK4, CLK5, CLK6, CLK7, CLK8, CLK9, CLK10, CLK11, CLK12, CLK13, CLK14, CLK15, CLK16, CLK17, CLK18, CLK19, CLK20, CLK21, CLK22, CLK23, CLK24, CLK25, CLK26, CLK27, CLK28, CLK29, CLK30, CLK31}),
	.Q(AVL_READDATA)
);
endmodule