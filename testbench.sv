module testbench();
timeunit 10ns;

timeprecision 1ns;

logic Clk = 1'b0;
logic RESET;
logic [3:0] red, green, blue;
logic hs, vs;
	// Avalon-MM Slave Signals
logic AVL_READ, AVL_WRITE, AVL_CS;
logic [3:0] AVL_BYTE_EN;
logic [11:0] AVL_ADDR;
logic [31:0] AVL_WRITEDATA;	
logic [31:0] AVL_READDATA;	

vga_avl_interface VGA_INTERFACE(.CLK(Clk),
	.RESET, .AVL_READ, .AVL_WRITE, .AVL_CS, .AVL_BYTE_EN, .AVL_ADDR, .AVL_WRITEDATA, 
	.AVL_READDATA, .*);
	
always begin : CLOCK_GENERATION
#1 Clk = ~Clk;
end

initial begin: CLOCK_INITIALIZATION
	Clk = 0;
end 

initial begin: TEST_VECTORS
	RESET = 1'b1;
	#3
	RESET = 1'b0;
	AVL_ADDR = 12'h800;
	AVL_WRITE = 1'b1;
	AVL_CS = 1'b1;
	AVL_BYTE_EN = 4'b1111;
	AVL_WRITEDATA = 32'h00141400;
	#1
	AVL_CS = 1'b0;
	#3
	AVL_ADDR = 12'h002;
	AVL_WRITEDATA = 32'h06000000;
	AVL_CS = 1'b1;
	#1
	AVL_CS = 1'b0;
	#3
	AVL_ADDR = 12'h003;
	AVL_WRITEDATA = 32'h06000000;
	AVL_CS = 1'b1;
	#1
	AVL_CS = 1'b0;
	#3
	AVL_ADDR = 12'h017;
	AVL_WRITE = 1'b1;
	AVL_CS = 1'b1;
	AVL_BYTE_EN = 4'b1111;
	AVL_WRITEDATA = (32'h0 << 2) | (32'h00000006 << 5) | (32'h00000003 << 9) | (32'h00000001 << 13);
	#1
	AVL_CS = 1'b0;
	/*
	#3
	AVL_ADDR = 12'h017;
	AVL_WRITE = 1'b1;
	AVL_CS = 1'b1;
	AVL_BYTE_EN = 4'b1111;
	AVL_WRITEDATA = (32'h1 << 2) | (32'h00000006 << 5) | (32'h00000003 << 9) | (32'h00000001 << 13);*/
end
endmodule