module top(input CLK_25MHZ, output LED);

reg [23:0] counter = 0;
assign LED = counter[23];
always @(posedge CLK_25MHZ) counter <= counter + 1;

endmodule