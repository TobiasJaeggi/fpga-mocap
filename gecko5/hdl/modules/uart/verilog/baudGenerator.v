module baudGenerator ( input wire        clock,
                                         reset,
                       input wire [15:0] baudDivisor,
                       output reg        baudRateX16Tick,
                                         baudRateX2Tick );
  reg [15:0]  s_counterReg;
  reg         s_counterResetReg;
  reg [2:0]   s_baudDivReg;
  wire        s_counterLoad = s_counterReg[15:1] == 15'd0 ? 1'd1 : 1'd0;
  wire [15:0] s_counterNext = (reset == 1'b1 || s_counterLoad == 1'b1) ? baudDivisor : s_counterReg - 16'd1;
  wire [2:0]  s_baudDivNext = (reset == 1'b1) ? 3'd7 : (s_counterLoad == 1'b1) ? s_baudDivReg - 3'd1 : s_baudDivReg;
  wire        s_baudDivIsZero = (s_baudDivReg == 3'd0) ? 1'd1 : 1'd0;

  always @(posedge clock)
    begin
      s_counterResetReg <= reset;
      s_counterReg      <= s_counterNext;
      s_baudDivReg      <= s_baudDivNext;
      baudRateX16Tick   <= (s_counterResetReg == 1'b1) ? 1'b0 : s_counterLoad;
      baudRateX2Tick    <= (s_counterResetReg == 1'b1) ? 1'b0 : s_counterLoad & s_baudDivIsZero;
    end
endmodule
