/* Base code source: 
 * http://rdsl.csit-sun.pub.ro/docs/PROIECTARE%20cu%20FPGA%20CURS/lecture6[1].pdf
 * ECE 4514 Sp. 2008 Lecture 6: A Random Number Generator (written in Verilog) by Patrick Schaumont
 *
 * Rest of the code derived from Thomas E. Tkacik's LFSR (2002): 
 * https://link.springer.com/content/pdf/10.1007/3-540-36400-5_32.pdf
 * Based on the polynomial given.
 */


module hw_rng (
	input logic clk, reset, load,
	input logic [31:0] seed,
	output logic [31:0] random_state
);

// LFSR state and CASR state takes on values not equal to 0.
logic [42:0] LFSR_stable, LFSR_working;
logic LFSR_out;
assign LFSR_out = LFSR_working[42];
assign LFSR_stable = LFSR_working;

parameter [42:0] init_seed0 = 43'h1FFEC560B4;
parameter [36:0] init_seed1 = 37'hA5728ECEB;

always_ff @ (posedge clk) begin
	if (reset) begin
		LFSR_working <= init_seed0;
	end
	else begin
		if (load) begin
			LFSR_working[42:32] <= 0;
			LFSR_working[31:0] <= seed;
		end
		else begin /* x^43 + x^41 + x^20 + x + 1 */
			LFSR_working[42] <=  LFSR_working[41];
			LFSR_working[41] <= LFSR_working[40] ^ LFSR_out;
			LFSR_working[40] <= LFSR_working[39];
			LFSR_working[39] <= LFSR_working[38];
			LFSR_working[38] <= LFSR_working[37];
			LFSR_working[37] <= LFSR_working[36];
			LFSR_working[36] <= LFSR_working[35];
			LFSR_working[35] <= LFSR_working[34];
			LFSR_working[34] <= LFSR_working[33];
			LFSR_working[33] <= LFSR_working[32];
			LFSR_working[32] <= LFSR_working[31];
			LFSR_working[31] <= LFSR_working[30];
			LFSR_working[30] <= LFSR_working[29];
			LFSR_working[29] <= LFSR_working[28];
			LFSR_working[28] <= LFSR_working[27];
			LFSR_working[27] <= LFSR_working[26];
			LFSR_working[26] <= LFSR_working[25];
			LFSR_working[25] <= LFSR_working[24];
			LFSR_working[24] <= LFSR_working[23];
			LFSR_working[23] <= LFSR_working[22];
			LFSR_working[22] <= LFSR_working[21];
			LFSR_working[21] <= LFSR_working[20];
			LFSR_working[20] <= LFSR_working[19] ^ LFSR_out;
			LFSR_working[19] <= LFSR_working[18];
			LFSR_working[18] <= LFSR_working[17];
			LFSR_working[17] <= LFSR_working[16];
			LFSR_working[16] <= LFSR_working[15];
			LFSR_working[15] <= LFSR_working[14];
			LFSR_working[14] <= LFSR_working[13];
			LFSR_working[13] <= LFSR_working[12];
			LFSR_working[12] <= LFSR_working[11];
			LFSR_working[11] <= LFSR_working[10];
			LFSR_working[10] <= LFSR_working[9];
			LFSR_working[9] <= LFSR_working[8];
			LFSR_working[8] <= LFSR_working[7];
			LFSR_working[7] <= LFSR_working[6];
			LFSR_working[6] <= LFSR_working[5];
			LFSR_working[5] <= LFSR_working[4];
			LFSR_working[4] <= LFSR_working[3];
			LFSR_working[3] <= LFSR_working[2];
			LFSR_working[2] <= LFSR_working[1];
			LFSR_working[1] <= LFSR_working[0] ^ LFSR_out;
			LFSR_working[0] <= LFSR_working[42];
		end
	end
end


logic [36:0] CASR_stable, CASR_working;
assign CASR_stable = CASR_working;

always_ff @ (posedge clk) begin
	if (reset) begin
		CASR_working <= init_seed1;
	end
	else begin
		if (load) begin
			CASR_working[36:32] <= 0;
			CASR_working[31:0] <= seed;
		end
		else begin /* CA150 for cell 28, else CA90  */
			CASR_working[36] <= CASR_working[35] ^ CASR_working[0];
			CASR_working[35] <= CASR_working[34] ^ CASR_working[36];
			CASR_working[34] <= CASR_working[33] ^ CASR_working[35];
			CASR_working[33] <= CASR_working[32] ^ CASR_working[34];
			CASR_working[32] <= CASR_working[31] ^ CASR_working[33];
			CASR_working[31] <= CASR_working[30] ^ CASR_working[32];
			CASR_working[30] <= CASR_working[29] ^ CASR_working[31];
			CASR_working[29] <= CASR_working[28] ^ CASR_working[30];
			CASR_working[28] <= CASR_working[27] ^ CASR_working[28] ^ CASR_working[29];
			CASR_working[27] <= CASR_working[26] ^ CASR_working[28];
			CASR_working[26] <= CASR_working[25] ^ CASR_working[27];
			CASR_working[25] <= CASR_working[24] ^ CASR_working[26];
			CASR_working[24] <= CASR_working[23] ^ CASR_working[25];
			CASR_working[23] <= CASR_working[22] ^ CASR_working[24];
			CASR_working[22] <= CASR_working[21] ^ CASR_working[23];
			CASR_working[21] <= CASR_working[20] ^ CASR_working[22];
			CASR_working[20] <= CASR_working[19] ^ CASR_working[21];
			CASR_working[19] <= CASR_working[18] ^ CASR_working[20];
			CASR_working[18] <= CASR_working[17] ^ CASR_working[19];
			CASR_working[17] <= CASR_working[16] ^ CASR_working[18];
			CASR_working[16] <= CASR_working[15] ^ CASR_working[17];
			CASR_working[15] <= CASR_working[14] ^ CASR_working[16];
			CASR_working[14] <= CASR_working[13] ^ CASR_working[15];
			CASR_working[13] <= CASR_working[12] ^ CASR_working[14];
			CASR_working[12] <= CASR_working[11] ^ CASR_working[13];
			CASR_working[11] <= CASR_working[10] ^ CASR_working[12];
			CASR_working[10] <= CASR_working[9] ^ CASR_working[11];
			CASR_working[9] <= CASR_working[8] ^ CASR_working[10];
			CASR_working[8] <= CASR_working[7] ^ CASR_working[9];
			CASR_working[7] <= CASR_working[6] ^ CASR_working[8];
			CASR_working[6] <= CASR_working[5] ^ CASR_working[7];
			CASR_working[5] <= CASR_working[4] ^ CASR_working[6];
			CASR_working[4] <= CASR_working[3] ^ CASR_working[5];
			CASR_working[3] <= CASR_working[2] ^ CASR_working[4];
			CASR_working[2] <= CASR_working[1] ^ CASR_working[3];
			CASR_working[1] <= CASR_working[0] ^ CASR_working[2];
			CASR_working[0] <= CASR_working[36] ^ CASR_working[1];
		end
	end
end

always_ff @ (posedge clk) begin
	if (reset) begin
		random_state <= 0;
	end
	else begin
		random_state <= LFSR_stable[31:0] ^ CASR_stable[31:0];
	end
end
endmodule