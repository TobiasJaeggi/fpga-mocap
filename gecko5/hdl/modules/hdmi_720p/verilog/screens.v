module screens #( parameter [31:0] baseAddress = 32'h00000000,
                  parameter [26:0] pixelClockFrequency = 27'd60000000,
                  parameter [26:0] cursorBlinkFrequency = 27'd1)
               ( input wire         pixelClockIn,
                                    clock,
                                    reset,
                                    testPicture,
                                    dualText,

                 // Ci interface for screen 1
                 input wire [7:0]   ci1N,
                 input wire [31:0]  ci1DataA,
                                    ci1DataB,
                 input wire         ci1Start,
                                    ci1Cke,
                 output wire        ci1Done,
                 output wire [31:0] ci1Result,

                 // Ci interface for screen 2
                 input wire [7:0]   ci2N,
                 input wire [31:0]  ci2DataA,
                                    ci2DataB,
                 input wire         ci2Start,
                                    ci2Cke,
                 output wire        ci2Done,
                 output wire [31:0] ci2Result,
                 
                 // here the bus interface is defined
                 output wire        requestTransaction,
                 input wire         transactionGranted,
                 input wire         beginTransactionIn,
                                    endTransactionIn,
                                    readNotWriteIn,
                                    dataValidIn,
                                    busErrorIn,
                 input wire [31:0]  addressDataIn,
                 input wire [3:0]   byteEnablesIn,
                 input wire [7:0]   burstSizeIn,
                 output wire        beginTransactionOut,
                                    endTransactionOut,
                                    dataValidOut,
                                    readNotWriteOut,
                 output wire [3:0]  byteEnablesOut,
                 output wire [7:0]  burstSizeOut,
                 output wire [31:0] addressDataOut,
                 input wire         pixelClkX2,
`ifdef GECKO5Education
                 output wire [4:0]  hdmiRed,
                                    hdmiBlue,
                 output wire [5:0]  hdmiGreen,
`else // this is for the GECKO4Education with an external single/dual HDMI-PMOD
                 output wire [3:0]  red,
                                    green,
                                    blue,
`endif
                 output wire        pixelClock,
                 output wire        horizontalSync,
                                    verticalSync,
                                    activePixel
);
  // the pixelclock is 60MHz  
  localparam [10:0] halfScreen = 640;
  localparam [ 9:0] verticalScreenSize = 720;
  localparam [ 9:0] verticalHalfSize = (verticalScreenSize >> 1);
  localparam [26:0] cursorBlinkReloadValue = (pixelClockFrequency/(cursorBlinkFrequency<<1)) - 27'd1;
  
  wire s_requestPixel, s_newScreen, s_nextLine, s_hSyncIn, s_vSyncIn, s_grayscale;
  reg [ 2:0] s_hSyncOut, s_vSyncOut, s_activeOut;
  reg s_testPicture;
  reg [ 4:0] s_redPixel, s_BluePixel;
  reg [ 5:0] s_greenPixel;
  wire [10:0] s_pixelIndex;
  wire [ 9:0] s_lineIndex;
  wire [ 9:0] s_graphicsWidth;
  wire [10:0] graphicLeftMargin = (halfScreen - {1'd0, s_graphicsWidth}) >> 1;
  wire [10:0] graphicLineBegin  = halfScreen+graphicLeftMargin;
  wire [10:0] graphicLineEnd    = graphicLineBegin + {1'd0, s_graphicsWidth};
  wire [9:0]  s_graphicsHeight;
  wire [9:0]  graphicTopMargin = (verticalScreenSize - s_graphicsHeight) >> 1;
  wire [9:0]  graphicScreenEnd = graphicTopMargin + s_graphicsHeight;
  wire [10:0] s_screenOffset1, s_screenOffset2;
  
  // we synchronize the testpicture with the new-screen
  always @(posedge pixelClockIn) s_testPicture = (reset == 1'b1) ? 1'b0 : (s_newScreen == 1'b1) ? testPicture : s_testPicture;
  
  // we map the core
  hdmi_720p generator (.pixelClockIn(pixelClockIn),
                       .reset(reset),
                       .testPicture(s_testPicture),
                       .pixelClkX2(pixelClkX2),
`ifdef GECKO5Education
                       .hdmiRed(hdmiRed),
                       .hdmiGreen(hdmiGreen),
                       .hdmiBlue(hdmiBlue),
`else
                       .red(red),
                       .green(green),
                       .blue(blue),
`endif
                       .pixelClock(pixelClock),
                       .horizontalSync(horizontalSync),
                       .verticalSync(verticalSync),
                       .activePixel(activePixel),
                       .pixelIndex(s_pixelIndex),
                       .lineIndex(s_lineIndex),
                       .requestPixel(s_requestPixel),
                       .newScreen(s_newScreen),
                       .nextLine(s_nextLine),
                       .hSyncOut(s_hSyncIn),
                       .vSyncOut(s_vSyncIn),
                       .hSyncIn(s_hSyncOut[2]),
                       .vSyncIn(s_vSyncOut[2]),
                       .activeIn(s_activeOut[2]),
                       .redIn(s_redPixel),
                       .blueIn(s_BluePixel),
                       .greenIn(s_greenPixel) );

  // here we define the screen parameters
  reg[ 1:0]   s_textContent, s_isInGraphicRegion;
  wire [ 9:0] s_textScreen1Start = s_screenOffset1[9:0]; 
  wire [ 9:0] s_textScreen1Stop  = (dualText == 1'b1) ? verticalHalfSize - 10'd8 : verticalScreenSize - s_screenOffset1[9:0];
  wire [ 9:0] s_textScreen2Start = (dualText == 1'b1) ? verticalHalfSize + 10'd8 : verticalScreenSize;
  wire [ 9:0] s_textScreen2Stop = verticalScreenSize - s_screenOffset2[9:0];
  wire [ 9:0] s_inScreen1 = (dualText == 1'b1) ? verticalHalfSize : verticalScreenSize;
  wire        s_inTextScreen2 = (s_lineIndex >= s_textScreen2Start) ? dualText : 1'b0;
  
  always @(posedge pixelClockIn)
    begin
      s_hSyncOut             <= {s_hSyncOut[1:0],s_hSyncIn};
      s_vSyncOut             <= {s_vSyncOut[1:0],s_vSyncIn};
      s_activeOut            <= {s_activeOut[1:0],s_requestPixel};
      s_isInGraphicRegion[1] <= s_isInGraphicRegion[0];
      s_isInGraphicRegion[0] <= ((s_lineIndex >= graphicTopMargin) && 
                                 (s_lineIndex < graphicScreenEnd) &&
                                 (s_pixelIndex >= graphicLineBegin) &&
                                 (s_pixelIndex <= graphicLineEnd)) ? s_requestPixel : 1'b0;
      s_textContent[1]       <= s_textContent[0];
      s_textContent[0]       <= ((s_pixelIndex < halfScreen && 
                                  ((s_pixelIndex >= s_screenOffset1 && s_lineIndex < s_inScreen1) ||
                                   (s_pixelIndex >= s_screenOffset2 && s_lineIndex > s_inScreen1))) &&
                                 ((s_lineIndex < s_textScreen1Stop && s_lineIndex >= s_textScreen1Start) || 
                                  (s_lineIndex >= s_textScreen2Start && s_lineIndex < s_textScreen2Stop))) ? s_requestPixel : 1'd0;
    end
  
  // here the screen controllers are defined
  reg         s_delayedDualTextReg;
  wire [9:0]  s_screen2LineIndex = s_lineIndex - s_textScreen2Start;
  wire        s_text1RamWe;
  wire [7:0]  s_text1RamData;
  wire [12:0] s_text1RamAddress, s_text1RamLookupAddress;
  wire [2:0]  s_text1BitSelector, s_text1LineIndex;
  wire [15:0] s_text1ForeGroundColor, s_text1BackGroundColor;
  wire        s_text1CursorVisible;
  wire        s_text2RamWe;
  wire [7:0]  s_text2RamData;
  wire [12:0] s_text2RamAddress, s_text2RamLookupAddress;
  wire [2:0]  s_text2BitSelector, s_text2LineIndex;
  wire [15:0] s_text2ForeGroundColor, s_text2BackGroundColor;
  wire        s_text2CursorVisible;
  wire        s_resetText = reset | (s_delayedDualTextReg ^ dualText);
  
  always @(posedge clock) s_delayedDualTextReg <= dualText;
  
  textController #(.defaultForeGroundColor(16'b1111111111100000),
                   .defaultBackGroundColor(16'b0000000000011111),
                   .customIntructionNr(8'd0),
                   .defaultSmallChars(1'd1) ) textC1
                  (.clock(clock),
                   .pixelClock(pixelClockIn),
                   .reset(s_resetText),
                   .dualText(dualText),
                   .pixelIndex(s_pixelIndex),
                   .lineIndex(s_lineIndex),
                   .screenOffset(s_screenOffset1),
                   // here we define the custom instruction interface
                   .ciN(ci1N),
                   .ciDataA(ci1DataA),
                   .ciDataB(ci1DataB),
                   .ciStart(ci1Start),
                   .ciCke(ci1Cke),
                   .ciDone(ci1Done),
                   .ciResult(ci1Result),
                   // here we define the interface to the ram and screen controller
                   .ramWe(s_text1RamWe),
                   .ramData(s_text1RamData),
                   .ramAddress(s_text1RamAddress),
                   .ramLookupAddress(s_text1RamLookupAddress),
                   .asciiBitSelector(s_text1BitSelector),
                   .asciiLineIndex(s_text1LineIndex),
                   .foreGroundColor(s_text1ForeGroundColor),
                   .backGroundColor(s_text1BackGroundColor),
                   .cursorVisible(s_text1CursorVisible) );

  textController #(.defaultForeGroundColor(16'b1111100000011111),
                   .defaultBackGroundColor(16'b0000011111111111),
                   .customIntructionNr(8'd0),
                   .defaultSmallChars(1'd1) ) textC2
                  (.clock(clock),
                   .pixelClock(pixelClockIn),
                   .reset(s_resetText),
                   .dualText(dualText),
                   .pixelIndex(s_pixelIndex),
                   .lineIndex(s_screen2LineIndex),
                   .screenOffset(s_screenOffset2),
                   // here we define the custom instruction interface
                   .ciN(ci2N),
                   .ciDataA(ci2DataA),
                   .ciDataB(ci2DataB),
                   .ciStart(ci2Start),
                   .ciCke(ci2Cke),
                   .ciDone(ci2Done),
                   .ciResult(ci2Result),
                   // here we define the interface to the ram and screen controller
                   .ramWe(s_text2RamWe),
                   .ramData(s_text2RamData),
                   .ramAddress(s_text2RamAddress),
                   .ramLookupAddress(s_text2RamLookupAddress),
                   .asciiBitSelector(s_text2BitSelector),
                   .asciiLineIndex(s_text2LineIndex),
                   .foreGroundColor(s_text2ForeGroundColor),
                   .backGroundColor(s_text2BackGroundColor),
                   .cursorVisible(s_text2CursorVisible) );

  // here the text buffers are defined
  wire [7:0]  s_asciiChar1, s_asciiChar2;
  wire        s_ram1We = (dualText == 1'b1) ? s_text1RamWe : s_text1RamWe & ~s_text1RamAddress[12];
  wire [11:0] s_ram2LookupAddress = (dualText == 1'b1) ? s_text2RamLookupAddress[11:0] : s_text1RamLookupAddress[11:0];
  wire [11:0] s_ram2WriteAddress = (dualText == 1'b1) ? s_text2RamAddress[11:0] : s_text1RamAddress[11:0];
  wire        s_ram2We = (dualText == 1'b1) ? s_text2RamWe : s_text1RamWe & s_text1RamAddress[12];
  wire [7:0]  s_ram2Data = (dualText == 1'b1) ? s_text2RamData : s_text1RamData;
  reg         s_asciiSelector;
  
  always @(posedge pixelClockIn) s_asciiSelector <= s_text1RamLookupAddress[12]&~dualText;

  dualPortRam4k asciiRam1 ( .address2(s_text1RamLookupAddress[11:0]),
                            .clock2(pixelClockIn),
                            .dataOut2(s_asciiChar1),
                            .address1(s_text1RamAddress[11:0]),
                            .clock1(clock),
                            .writeEnable(s_ram1We),
                            .dataIn1(s_text1RamData));

  dualPortRam4k asciiRam2 ( .address2(s_ram2LookupAddress),
                            .clock2(pixelClockIn),
                            .dataOut2(s_asciiChar2),
                            .address1(s_ram2WriteAddress),
                            .clock1(clock),
                            .writeEnable(s_ram2We),
                            .dataIn1(s_ram2Data));
  
  // lookup the bit pattern
  wire [6:0] s_asciiChar = (s_inTextScreen2 == 1'b1 || s_asciiSelector == 1'b1) ? s_asciiChar2[6:0] : s_asciiChar1[6:0];
  wire [2:0] s_asciiLineIndex = (s_inTextScreen2 == 1'b1) ? s_text2LineIndex : s_text1LineIndex;
  wire [7:0] s_asciiBits;
  wire [2:0] s_aciiBitSelector = (s_inTextScreen2 == 1'b1) ? s_text2BitSelector : s_text1BitSelector;
  wire       s_asciiBit = s_asciiBits[s_aciiBitSelector];
  
  charRom asciiRom ( .clock(pixelClockIn),
                     .address({s_asciiChar,s_asciiLineIndex}),
                     .data(s_asciiBits) );
  
  // here the cursor related signals are defined
  reg[26:0] s_cursorBlinkCounterReg;
  reg       s_cursorOnReg;
  reg[1:0]  s_drawCursorReg;

  
  always @(posedge pixelClockIn)
    begin
      s_cursorBlinkCounterReg <= (reset == 1'b1 || s_cursorBlinkCounterReg == 27'd0) ? cursorBlinkReloadValue : s_cursorBlinkCounterReg - 27'd1;
      s_cursorOnReg           <= (reset == 1'b1) ? 1'b0 : (s_cursorBlinkCounterReg == 27'd0) ? ~s_cursorOnReg : s_cursorOnReg;
      s_drawCursorReg[1]      <= s_drawCursorReg[0];
      s_drawCursorReg[0]      <= s_cursorOnReg & (s_text1CursorVisible || (s_text2CursorVisible & s_inTextScreen2));
    end
  
  // here the text RGB colors are defined
  reg [7:0]   s_selectedGrayData;
  wire [15:0] s_textOnColor = (s_inTextScreen2 == 1'b1) ? s_text2ForeGroundColor : s_text1ForeGroundColor;
  wire [15:0] s_textOffColor = (s_inTextScreen2 == 1'b1) ? s_text2BackGroundColor : s_text1BackGroundColor;
  wire[4:0]   s_textRed   = (s_drawCursorReg[1] == 1'b1 || s_asciiBit == 1'b1) ? s_textOnColor[15:11] : s_textOffColor[15:11];
  wire[5:0]   s_textGreen = (s_drawCursorReg[1] == 1'b1 || s_asciiBit == 1'b1) ? s_textOnColor[10:5] : s_textOffColor[10:5];
  wire[4:0]   s_textBlue  = (s_drawCursorReg[1] == 1'b1 || s_asciiBit == 1'b1) ? s_textOnColor[4:0] : s_textOffColor[4:0];
  
  // here the graphics line buffer is defined
  reg [9:0]   s_readPixelCounterReg;
  reg [1:0]   s_graySelectReg;
  reg         s_selectReg;
  reg         s_nextGraphicLineReg;
  wire [9:0]  s_readPixelCounterNext = (s_nextLine == 1'b1) ? 9'd0 :
                                       (s_isInGraphicRegion[1] == 1'b1) ? s_readPixelCounterReg + 10'd1 : s_readPixelCounterReg;
  wire [31:0] s_dualPixelData1, s_dualPixelData2;
  wire [31:0] s_dualPixelData = (s_writeIndex == 1'b1) ? s_dualPixelData1 : s_dualPixelData2;
  wire [15:0] s_grayPixel = {s_selectedGrayData[7:3],s_selectedGrayData[7:2],s_selectedGrayData[7:3]};
  wire [15:0] s_pixelData = (s_grayscale == 1'b1) ? s_grayPixel : (s_selectReg == 1'b1) ? s_dualPixelData[31:16] : s_dualPixelData[15:0];
  wire [31:0] s_pixelWriteData;
  wire [8:0]  s_pixelWriteAddress;
  wire        s_pixelWe, s_newScreenSlow, s_newLineSlow, s_writeIndex, s_dualPixel;
  wire [8:0]  s_pixelReadAddress = ((s_dualPixel == 1'b1 && s_grayscale == 1'b0) || (s_dualPixel == 1'b0 && s_grayscale == 1'b1)) ? {1'b0,s_readPixelCounterReg[9:2]} : 
                                    (s_dualPixel == 1'b1) ? {2'b0,s_readPixelCounterReg[9:3]} : s_readPixelCounterReg[9:1];

  always @*
    case (s_graySelectReg)
       2'd0   : s_selectedGrayData <= s_dualPixelData[7:0];
       2'd1   : s_selectedGrayData <= s_dualPixelData[15:8];
       2'd3   : s_selectedGrayData <= s_dualPixelData[23:16];
       default: s_selectedGrayData <= s_dualPixelData[31:0];
     endcase

  always @(posedge pixelClockIn)
    begin
      s_readPixelCounterReg <= s_readPixelCounterNext;
      s_selectReg           <= (s_dualPixel == 1'b1) ? s_readPixelCounterReg[1] : s_readPixelCounterReg[0];
      s_graySelectReg       <= (s_dualPixel == 1'b1) ? s_readPixelCounterReg[2:1] : s_readPixelCounterReg[1:0];
      s_nextGraphicLineReg  <= (reset == 1'b1) ? 1'b0 : s_isInGraphicRegion[1] & ~s_isInGraphicRegion[0];
    end

  dualPortRam2k LineBuffer1 ( .address1(s_pixelWriteAddress),
                              .address2(s_pixelReadAddress),
                              .clock1(clock),
                              .clock2(pixelClockIn),
                              .writeEnable(s_pixelWe & ~s_writeIndex),
                              .dataIn1(s_pixelWriteData),
                              .dataOut2(s_dualPixelData1));
  dualPortRam2k LineBuffer2 ( .address1(s_pixelWriteAddress),
                              .address2(s_pixelReadAddress),
                              .clock1(clock),
                              .clock2(pixelClockIn),
                              .writeEnable(s_pixelWe & s_writeIndex),
                              .dataIn1(s_pixelWriteData),
                              .dataOut2(s_dualPixelData2));

  synchroFlop syncNewScreen ( .clockIn(pixelClockIn),
                              .clockOut(clock),
                              .reset(reset),
                              .D(s_newScreen),
                              .Q(s_newScreenSlow) );
                      
  synchroFlop syncNewLine ( .clockIn(pixelClockIn),
                            .clockOut(clock),
                            .reset(reset),
                            .D(s_nextGraphicLineReg),
                            .Q(s_newLineSlow) );
                      
  graphicsController #( .baseAddress(baseAddress)) graphics
                      ( .clock(clock),
                        .reset(reset),
                        .graphicsWidth(s_graphicsWidth),
                        .graphicsHeight(s_graphicsHeight),
                        .newScreen(s_newScreenSlow),
                        .newLine(s_newLineSlow),
                        .bufferWe(s_pixelWe),
                        .bufferAddress(s_pixelWriteAddress),
                        .bufferData(s_pixelWriteData),
                        .writeIndex(s_writeIndex),
                        .dualPixel(s_dualPixel),
                        .grayscale(s_grayscale),
                        .requestTransaction(requestTransaction),
                        .transactionGranted(transactionGranted),
                        .beginTransactionIn(beginTransactionIn),
                        .endTransactionIn(endTransactionIn),
                        .readNotWriteIn(readNotWriteIn),
                        .dataValidIn(dataValidIn),
                        .busErrorIn(busErrorIn),
                        .addressDataIn(addressDataIn),
                        .byteEnablesIn(byteEnablesIn),
                        .burstSizeIn(burstSizeIn),
                        .beginTransactionOut(beginTransactionOut),
                        .endTransactionOut(endTransactionOut),
                        .dataValidOut(dataValidOut),
                        .readNotWriteOut(readNotWriteOut),
                        .byteEnablesOut(byteEnablesOut),
                        .burstSizeOut(burstSizeOut),
                        .addressDataOut(addressDataOut)); 

  // finally we build up the screen
  always @(posedge pixelClockIn)
  begin
   s_greenPixel           <= (s_textContent[1] == 0 && s_isInGraphicRegion[1] == 0) ? 6'b001111 : (s_textContent[1] == 1'b1) ? s_textGreen :  s_pixelData[10:5];
   s_BluePixel            <= (s_textContent[1] == 0 && s_isInGraphicRegion[1] == 0) ? 5'b00111 : (s_textContent[1] == 1'b1) ? s_textBlue : s_pixelData[4:0];
   s_redPixel             <= (s_textContent[1] == 0 && s_isInGraphicRegion[1] == 0) ? 5'b00111 : (s_textContent[1] == 1'b1) ? s_textRed : s_pixelData[15:11];
  end
  
endmodule
