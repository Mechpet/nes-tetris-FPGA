module testbench();
timeunit 100ns;

timeprecision 1ns;

logic Clk = 1'b0;
logic RESET;
logic [3:0] red, green, blue;
logic hs, vs;
	// Avalon-MM Slave Signals
logic AVL_READ, AVL_WRITE, AVL_CS, en;
logic [3:0] AVL_BYTE_EN;
logic [11:0] AVL_ADDR;
logic [31:0] AVL_WRITEDATA;	
logic [31:0] AVL_READDATA;	
logic [4:0] random_out;
logic random_bit, stop_bit;
logic load;
logic [31:0] seed, random_state;

vga_avl_interface VGA_INTERFACE(.CLK(Clk),
	.RESET, .AVL_READ, .AVL_WRITE, .AVL_CS, .AVL_BYTE_EN, .AVL_ADDR, .AVL_WRITEDATA, 
	.AVL_READDATA, .*);
	
fibonacci_lfsr_nbit ro(.clk(Clk),
	.reset(RESET),
	.data(random_out));
	
hw_rng h(.clk(Clk),
	.reset(RESET),
	.load(load),
	.seed(seed),
	.random_state(random_state));
	
always begin : CLOCK_GENERATION
#1 Clk = ~Clk;
end

initial begin : CLOCK_INITIALIZATION
	Clk = 0;
end 


/*
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
end*/
initial begin: TEST_VECTORS
	RESET = 1'b1;
	#5
	RESET = 1'b0;
	#500
	load = 1'b1;
	seed = 32'h1F;
	#20
	load = 1'b0;
end
endmodule