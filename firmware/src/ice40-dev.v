module top
(
    input CLK_25M,
    output LED,
    // EBI Signals
    inout EBI_A1D0,
    inout EBI_A2D1,
    inout EBI_A3D2,
    inout EBI_A4D3,
    inout EBI_A5D4,
    inout EBI_A6D5,
    inout EBI_A7D6,
    inout EBI_A8D7,
    inout EBI_A9D8,
    inout EBI_A10D9,
    inout EBI_A11D10,
    inout EBI_A12D11,
    inout EBI_A13D12,
    inout EBI_A14D13,
    inout EBI_A15D14,
    inout EBI_A16D15,
    input EBI_ALE,
    input EBI_CSn,
    input EBI_REn,
    input EBI_WEn
);

/// Clocks ///
wire clk_25M;
wire clk_100M;

SB_GB_IO clk_25M_global_buffer
(
    .PACKAGE_PIN(CLK_25M),
    .GLOBAL_BUFFER_OUTPUT(clk_25M)
);

pll pll_100M
(
    .clk_in(clk_25M),
    .clk_out(clk_100M),
    .reset(1'b0),
    .bypass(1'b0),
    .locked()
);
/// Clocks ///

/// BRAM ///
reg  [12:0] bram_addr;
reg  [15:0] bram_data_in;
reg  [15:0] bram_data_out;
reg         bram_we = 1'b0;

bram ram
(
    .clk(clk_100M),
    .addr(bram_addr),
    .data_in(bram_data_in),
    .data_out(bram_data_out),
    .we(bram_we)
);
/// BRAM ///

/// EBI Interface ///
wire [15:0] ebi_ad_in;
reg  [15:0] ebi_ad_out = 16'b0;
reg  [16:0] ebi_addr = 17'b0;
reg  [1:0]  ebi_state = 2'd0;
wire        ebi_ale;
wire        ebi_ncs;
wire        ebi_nre;
wire        ebi_nwe;

localparam EBI_STATE_ALE_WAIT = 2'd0,
           EBI_STATE_RDWR_WAIT = 2'd1,
           EBI_STATE_BRAM_WR_PENDING = 2'd2;

localparam EBI_BANK_REG = 4'b0000,
           EBI_BANK_BRAM = 4'b0001;

localparam EBI_REG_DUMMY0 = 13'h0000,
           EBI_REG_DUMMY1 = 13'h0002;

SB_IO #(
    .PIN_TYPE(6'b1010_01),
    .PULLUP(1'b0)
)
ebi_adbus [15:0]
(
    .PACKAGE_PIN({EBI_A16D15, EBI_A15D14, EBI_A14D13, EBI_A13D12, EBI_A12D11, EBI_A11D10, EBI_A10D9, EBI_A9D8, EBI_A8D7, EBI_A7D6, EBI_A6D5, EBI_A5D4, EBI_A4D3, EBI_A3D2, EBI_A2D1, EBI_A1D0}),
    .OUTPUT_ENABLE(!ebi_nre),
    .D_OUT_0(ebi_ad_out),
    .D_IN_0(ebi_ad_in)
);

always @(posedge clk_100M)
    begin
        if(ebi_ncs) // Reset when not selected
            begin
                ebi_ad_out <= 16'b0;
                ebi_addr <= 17'b0;
                ebi_state <= EBI_STATE_ALE_WAIT;
            end
        else
            begin
                case(ebi_state)
                    EBI_STATE_ALE_WAIT:
                        begin
                            if(!ebi_ale) // Latch address in when ALE active
                                begin
                                    ebi_addr <= {ebi_ad_in, 1'b0};

                                    if(ebi_ad_in[15:12] == EBI_BANK_BRAM)
                                        bram_addr[12:0] <= {ebi_ad_in[11:0], 1'b0};

                                    ebi_state <= EBI_STATE_RDWR_WAIT;
                                end
                        end
                    EBI_STATE_RDWR_WAIT:
                        begin
                            if(!ebi_nre) // Read operation
                                begin
                                    ebi_state <= EBI_STATE_ALE_WAIT; // A read operation does not need additional wait states, return to "idle" state

                                    case (ebi_addr[16:13])
                                        EBI_BANK_REG:
                                            begin
                                                case (ebi_addr[12:0]) // Register address
                                                    EBI_REG_DUMMY0:
                                                        ebi_ad_out <= 16'hAAAA; // Dummy
                                                    EBI_REG_DUMMY1:
                                                        ebi_ad_out <= 16'h5555; // Dummy
                                                    default:
                                                        ebi_ad_out <= 16'h0000;
                                                endcase
                                            end
                                        EBI_BANK_BRAM:
                                            begin
                                                ebi_ad_out <= bram_data_out;
                                            end
                                        default:
                                            ebi_ad_out <= 16'h0000;
                                    endcase
                                end
                            else if(!ebi_nwe) // Write operation
                                begin
                                    case (ebi_addr[16:13])
                                        EBI_BANK_REG:
                                            begin
                                                ebi_state <= EBI_STATE_ALE_WAIT; // A register write operation does not need additional wait states, return to "idle" state

                                                case (ebi_addr[12:0])
                                                    13'h0000:
                                                        ebi_ad_out <= 16'hAAAA; // Dummy
                                                    13'h0002:
                                                        ebi_ad_out <= 16'h5555; // Dummy
                                                    default:
                                                        ebi_ad_out <= 16'h0000;
                                                endcase
                                            end
                                        EBI_BANK_BRAM:
                                            begin
                                                ebi_state <= EBI_STATE_BRAM_WR_PENDING; // Wait state to complete BRAM write

                                                bram_data_in <= ebi_ad_in;
                                                bram_we <= 1'b1; // Assert write enable
                                            end
                                        default:
                                            ebi_ad_out <= 16'h0000;
                                    endcase
                                end
                        end
                    EBI_STATE_BRAM_WR_PENDING:
                        begin
                            ebi_state <= EBI_STATE_ALE_WAIT; // Return to "idle" state

                            bram_we <= 1'b0; // Deassert write enable
                        end
                    default:
                        ebi_state <= EBI_STATE_ALE_WAIT; // Return to "idle" state
                endcase
            end
    end
/// EBI Interface ///

reg [23:0] led_div = 0;

always @(posedge clk_25M)
    begin
        led_div <= led_div + 1;
    end

assign LED = led_div[23];
assign EBI_ALE = ebi_ale;
assign EBI_CSn = ebi_ncs;
assign EBI_REn = ebi_nre;
assign EBI_WEn = ebi_nwe;

endmodule