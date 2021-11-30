module fibonacci_lfsr_nbit(
	input logic clk,
	input logic reset,
	output logic [4:0] data);
	
   parameter BITS = 5;

   logic [4:0] data_next;
   always_comb begin
      data_next = data;
      repeat (BITS) begin
         data_next = {(data_next[4] ^ data_next[1]), data_next[4:1]};
      end
   end

   always_ff @ (posedge clk) begin
      if (reset) begin
         data <= 5'h1F;
		end
      else begin
         data <= data_next;
      end
   end
endmodule