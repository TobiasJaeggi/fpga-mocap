module sdramFifo ( input wire        clock,
                                     reset,
                                     clearReadFifo,
                                     readPush,
                                     readPop,
                   output wire       readEmpty,
                                     readFull,
                   input wire [31:0] readDataIn,
                   output reg [31:0] readDataOut );

  reg  [8:0] s_readPushAddressReg, s_readPopAddressReg;
  reg        s_readFullReg, s_readEmptyReg;
  wire [8:0] s_readPushAddressNext = s_readPushAddressReg + 9'd1;
  wire [8:0] s_readPopAddressNext = s_readPopAddressReg + 9'd1;
  wire       s_doReadPush = ~s_readFullReg & readPush;
  wire       s_doReadPop  = ~s_readEmptyReg & readPop;
  wire [31:0] s_readData;
  
  assign readEmpty = s_readEmptyReg;
  assign readFull  = s_readFullReg;
  
  always @(posedge clock)
    begin
      s_readEmptyReg <= (clearReadFifo == 1'b1 || reset == 1'b1 || (s_doReadPush == 1'b0 && s_doReadPop == 1'b1 && s_readPopAddressNext == s_readPushAddressReg)) ? 1'b1 :
                        (s_doReadPush == 1'b1 && s_doReadPop == 1'b0) ? 1'b0 : s_readEmptyReg;
      s_readFullReg  <= (clearReadFifo == 1'b1 || reset == 1'b1 || (s_doReadPush == 1'b0 && s_doReadPop == 1'b1)) ? 1'b0 :
                        (s_doReadPush == 1'b1 && s_doReadPop == 1'b0 && s_readPushAddressNext == s_readPopAddressReg) ? 1'b1 : s_readFullReg;
      s_readPushAddressReg <= (clearReadFifo == 1'b1 || reset == 1'b1) ? 8'd0 : (s_doReadPush == 1'b1) ? s_readPushAddressNext : s_readPushAddressReg;
      s_readPopAddressReg  <= (clearReadFifo == 1'b1 || reset == 1'b1) ? 8'd0 : (s_doReadPop == 1'b1) ? s_readPopAddressNext : s_readPopAddressReg;
      readDataOut          <= s_readData;
    end

  sram512X32Dp readMem ( .clockA(clock),
                         .writeEnableA(s_doReadPush),
                         .addressA(s_readPushAddressReg),
                         .dataInA(readDataIn),
                         .dataOutA(),
                         .clockB(~clock),
                         .writeEnableB(1'b0),
                         .addressB(s_readPopAddressReg),
                         .dataInB(32'd0),
                         .dataOutB(s_readData));

endmodule
