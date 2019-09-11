/**
 * PLL configuration
 *
 * This Verilog module was generated automatically
 * using the icepll tool from the IceStorm project.
 * Use at your own risk.
 *
 * Given input frequency:        25.000 MHz
 * Requested output frequency:  100.000 MHz
 * Achieved output frequency:   100.000 MHz
 */

module pll
(
	// Clocks
	input  	clk_in,
	output 	clk_out,
	// Control and Status signals
	input	reset,
	input 	bypass,
	output 	locked
);

SB_PLL40_CORE #(
	.FEEDBACK_PATH("SIMPLE"),
	.DIVR(4'b0000),			// DIVR =  0
	.DIVF(7'b0011111),		// DIVF = 31
	.DIVQ(3'b011),			// DIVQ =  3
	.FILTER_RANGE(3'b010)	// FILTER_RANGE = 2
)
pll
(
	.LOCK(locked),
	.RESETB(!reset),
	.BYPASS(bypass),
	.REFERENCECLK(clk_in),
	.PLLOUTGLOBAL(clk_out)
);

endmodule
