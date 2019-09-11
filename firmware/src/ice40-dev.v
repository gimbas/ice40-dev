module top(input clk, output LED);

reg [23:0] counter = 0;
assign LED = counter[23];
always @(posedge clk) counter <= counter + 1;

endmodule