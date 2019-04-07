module top(input clk_25mhz, output led);

reg [23:0] counter = 0;
assign led = counter[23];
always @(posedge clk_25mhz) counter <= counter + 1;

endmodule