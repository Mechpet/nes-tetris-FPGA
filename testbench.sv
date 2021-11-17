module testbench();

timeunit 10ns;

timeprecision 1ns;

logic Clk = 1'b0;
logic RESET;
logic [3:0] red, green, blue;
logic hs, vs;

vga_text_avl_interface VGA_INTERFACE(.CLK(Clk),
	.RESET, .AVL_READ(), .AVL_WRITE(), .AVL_CS(), .AVL_BYTE_EN(), .AVL_ADDR(), .AVL_WRITEDATA(), 
	.AVL_READDATA(), .*);
	
always begin : CLOCK_GENERATION
#1 Clk = ~Clk;
end

initial begin: CLOCK_INITIALIZATION
    Clk = 0;
end 

initial begin: TEST_VECTORS
	#2000;
end
endmodule