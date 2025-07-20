module graphicsController #( parameter [31:0] baseAddress = 32'h00000000) // maximum height supported is 720
                          ( input wire         clock,
                                               reset,
                            
                            output wire [9:0]  graphicsWidth,
                            output wire [9:0]  graphicsHeight,
                            // here we define the interface to the pixel buffer
                            input wire         newScreen,
                                               newLine,
                            output wire        bufferWe,
                            output wire [8:0]  bufferAddress,
                            output wire [31:0] bufferData,
                            output wire        writeIndex,
                            output wire        dualPixel,
                                               grayscale,

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
                            output reg         readNotWriteOut,
                            output reg [3:0]   byteEnablesOut,
                            output reg [7:0]   burstSizeOut,
                            output wire [31:0] addressDataOut);
  /*
   * This module implements a memory mapped slave that has following memory map (baseAddress+):
   * 0 -> The width of the graphic area (read-write) (maximum value is 640) (1<<31 gives double pixel, here maximum value 320)
   * 4 -> The height of the graphic area (read-write) (maximum value is 720) (1<<31 gives double line, here maximum value 360)
   * 8 -> The color mode: 1 for RGB565 16 bits/pixel (default), 2 for grayscale 8bits/pixel
   * C -> The start address of the frame/pixel buffer (read-write). It needs to be word-alligned
   *      (bits 1,0 need to be 0) otherwise the module is disabled. The graphic screen will be
   *      black if the modules is disabled.
   * 
   * Furthermore, it provides a DMA-master that reads the pixels from the bus if the modules is
   * enabled.
   *
   */
  
  localparam [3:0] IDLE = 4'd0, REQUEST = 4'd1, INIT = 4'd2, READ = 4'd3, ERROR = 4'd4, WRITE_BLACK = 4'd5, INIT_WRITE_BLACK = 4'd6, READ_DONE = 4'd7, REQUEST1 = 4'd8, INIT1 = 4'd9, READ1 = 4'd10;

  /*
   *
   * Here we define the bus slave part
   *
   */
  reg [31:0] s_busAddressReg, s_graphicBaseAddressReg, s_currentPixelAddressReg;
  reg [31:0] s_busDataInReg, s_busDataOutReg;
  reg [31:0] s_selectedData;
  reg [3:0]  s_dmaState, s_dmaStateNext;
  reg [9:0]  s_graphicsWidthReg;
  reg [9:0]  s_graphicsHeightReg;
  reg        s_startTransactionReg, s_transactionActiveReg, s_busDataInValidReg, s_readNotWriteReg;
  reg        s_endTransactionReg, s_dataValidOutReg, s_startTransactionOutReg, s_writeRegisterReg, s_endTransactionInReg;
  reg        s_dualLineReg, s_dualPixelReg, s_grayScaleReg;
  wire       s_isMyTransaction = (s_busAddressReg[31:4] == baseAddress[31:4]) ? s_transactionActiveReg : 1'b0;  // 4 bit address range. baseAddress up to baseAddress + 0x0000_000F
  wire [9:0] s_graphicsWidth = (s_busDataInReg[31] == 1'b1 && s_busDataInReg[9:0] > 10'd320) ? 10'd640 :
                               (s_busDataInReg[31] == 1'b1) ? {s_busDataInReg[8:0], 1'b0} :
                               (s_busDataInReg[9:0] > 10'd640) ? 10'd640 : s_busDataInReg[9:0];
  wire [9:0] s_graphicsHeight = (s_busDataInReg[31] == 1'b1 && s_busDataInReg[9:0] > 10'd360) ? 10'd720 :
                                (s_busDataInReg[31] == 1'b1) ? {s_busDataInReg[8:0],1'b0} :
                                (s_busDataInReg[9:0] > 10'd720) ? 10'd720 : s_busDataInReg[9:0];
  wire       s_dualBurst = (s_graphicsWidthReg[9:0] > 10'd512) ? ~s_dualPixelReg & ~s_grayScaleReg : 1'b0;
  wire [9:0] s_burstSize = (s_dualBurst == 1'b0 && s_dualPixelReg == 1'b1 && s_grayScaleReg == 1'b1) ? {2'b0, s_graphicsWidthReg[9:2]} - 10'd2 :
                           (s_dualBurst == 1'b0 && (s_dualPixelReg == 1'b1 || (s_dualPixelReg == 1'b0 && s_grayScaleReg == 1'b1))) ? {1'b0, s_graphicsWidthReg[9:1]} - 10'd2 :
                           (s_dualBurst == 1'b0) ? s_graphicsWidthReg[9:0] - 10'd2 :
                           (s_dmaState == INIT) ? 10'd510 : s_graphicsWidthReg[9:0] - 10'd514;
  
  assign dualPixel = s_dualPixelReg;
  assign grayscale = s_grayScaleReg;
  
  always @*
    case (s_busAddressReg[3:2])
      2'd0    : s_selectedData <= (s_dualPixelReg == 1'b0) ? {22'd0, s_graphicsWidthReg} : {s_dualPixelReg,22'd0, s_graphicsWidthReg[9:1]};
      2'd1    : s_selectedData <= (s_dualLineReg == 1'b0) ? {22'd0, s_graphicsHeightReg} : {s_dualLineReg,22'd0, s_graphicsHeightReg[9:1]};
      2'd2    : s_selectedData <= {30'd0,s_grayScaleReg,~s_grayScaleReg};
      default : s_selectedData <= s_graphicBaseAddressReg;
    endcase
  
  always @(posedge clock)
    begin
      s_busAddressReg         <= (reset == 1'b1) ? 32'd0 : (beginTransactionIn == 1'b1) ? addressDataIn : s_busAddressReg;
      s_readNotWriteReg       <= (reset == 1'b1) ? 1'd0 : (beginTransactionIn == 1'b1) ? readNotWriteIn : s_readNotWriteReg;
      s_startTransactionReg   <= beginTransactionIn & ~reset;
      s_transactionActiveReg  <= (reset == 1'b1 || endTransactionIn == 1'b1 || busErrorIn == 1'b1) ? 1'b0 : 
                                 (beginTransactionIn == 1'b1) ? 1'b1 : s_transactionActiveReg;
      s_busDataInReg          <= (dataValidIn == 1'b1) ? addressDataIn : s_busDataInReg;
      s_busDataInValidReg     <= dataValidIn;
      s_writeRegisterReg      <= dataValidIn & s_isMyTransaction & ~s_readNotWriteReg;
      s_graphicBaseAddressReg <= (reset == 1'b1) ? 32'd1 : 
                                 (s_writeRegisterReg == 1'b1 && s_busAddressReg[3:2] == 2'b11) ? s_busDataInReg : s_graphicBaseAddressReg;
      s_graphicsWidthReg      <= (reset == 1'b1) ? 10'd512 :
                                 (s_writeRegisterReg == 1'b1 && s_busAddressReg[3:2] == 2'b00) ? s_graphicsWidth : s_graphicsWidthReg;
      s_dualPixelReg          <= (reset == 1'b1) ? 1'b0 : 
                                 (s_writeRegisterReg == 1'b1 && s_busAddressReg[3:2] == 2'b00) ? s_busDataInReg[31] : s_dualPixelReg;
      s_grayScaleReg          <= (reset == 1'b1) ? 1'b0 :
                                 (s_writeRegisterReg == 1'b1 && s_busAddressReg[3:2] == 2'b10) ? s_busDataInReg[1] : s_grayScaleReg;
      s_graphicsHeightReg     <= (reset == 1'b1) ? 10'd512 :
                                 (s_writeRegisterReg == 1'b1 && s_busAddressReg[3:2] == 2'b01) ? s_graphicsHeight : s_graphicsHeightReg;
      s_dualLineReg           <= (reset == 1'b1) ? 1'b0 :
                                 (s_writeRegisterReg == 1'b1 && s_busAddressReg[3:2] == 2'b01) ? s_busDataInReg[31] : s_dualLineReg;
      s_endTransactionReg     <= s_startTransactionReg & s_isMyTransaction & s_readNotWriteReg;
      s_dataValidOutReg       <= s_startTransactionReg & s_isMyTransaction & s_readNotWriteReg;
      s_busDataOutReg         <= (s_startTransactionReg == 1'b1 && s_isMyTransaction == 1'b1 && s_readNotWriteReg == 1'b1) ? s_selectedData :
                                 (s_dmaState == INIT || s_dmaState == INIT1) ? s_currentPixelAddressReg : 32'd0;
      s_startTransactionOutReg<= (s_dmaState == INIT || s_dmaState == INIT1) ? 1'b1 : 1'b0;
      byteEnablesOut          <= (s_dmaState == INIT || s_dmaState == INIT1) ? 4'hF : 4'd0;
      readNotWriteOut         <= (s_dmaState == INIT || s_dmaState == INIT1) ? 1'b1 : 1'b0;
      burstSizeOut            <= (s_dmaState == INIT || s_dmaState == INIT1) ? s_burstSize[8:1] : 8'd0;
      s_endTransactionInReg   <= endTransactionIn & ~reset;
    end
  
  assign endTransactionOut   = s_endTransactionReg;
  assign dataValidOut        = s_dataValidOutReg;
  assign addressDataOut      = s_busDataOutReg;
  assign beginTransactionOut = s_startTransactionOutReg;
  assign graphicsWidth       = s_graphicsWidthReg;
  assign graphicsHeight      = s_graphicsHeightReg;

  /*
   *
   * Here the dma-controller is defined
   *
   */

  reg [9:0] s_writeAddressReg;
  reg       s_writeIndexReg;
  reg       s_lineCountReg;
  wire      s_requestData = newScreen | (newLine & ~s_dualLineReg) | (newLine & s_dualLineReg & s_lineCountReg);
  
  assign requestTransaction = (s_dmaState == REQUEST || s_dmaState == REQUEST1) ? 1'd1 : 1'd0;
  assign bufferData         = (s_dmaState == WRITE_BLACK) ? 32'd0 : s_busDataInReg;
  assign bufferAddress      = s_writeAddressReg[8:0];
  assign bufferWe           = (s_dmaState == WRITE_BLACK) ? 1'd1 : 
                              (s_dmaState == READ || s_dmaState == READ1) ? s_busDataInValidReg : 1'd0;
  assign writeIndex         = s_writeIndexReg;

  always @*
    case (s_dmaState)
      IDLE             : s_dmaStateNext <= (s_requestData == 1'b1 && s_graphicBaseAddressReg[1:0] == 2'd0) ? REQUEST :
                                           (s_requestData == 1'b1) ? INIT_WRITE_BLACK : IDLE;
      REQUEST          : s_dmaStateNext <= (transactionGranted == 1'b1) ? INIT : REQUEST;
      INIT             : s_dmaStateNext <= READ;
      READ             : s_dmaStateNext <= (busErrorIn == 1'b1 && endTransactionIn == 1'b0) ? ERROR :
                                           (busErrorIn == 1'b1) ? IDLE : 
                                           (s_endTransactionInReg == 1'b1 && s_dualBurst == 1'b0) ? READ_DONE :
                                           (s_endTransactionInReg == 1'b1) ? REQUEST1 : READ;
      REQUEST1         : s_dmaStateNext <= (transactionGranted == 1'b1) ? INIT1 : REQUEST1;
      INIT1            : s_dmaStateNext <= READ1;
      READ1            : s_dmaStateNext <= (busErrorIn == 1'b1 && endTransactionIn == 1'b0) ? ERROR :
                                           (busErrorIn == 1'b1) ? IDLE : 
                                           (s_endTransactionInReg == 1'b1) ? READ_DONE : READ1;
      INIT_WRITE_BLACK : s_dmaStateNext <= WRITE_BLACK;
      WRITE_BLACK      : s_dmaStateNext <= (s_writeAddressReg[9] == 1'b1) ? IDLE : WRITE_BLACK;
      ERROR            : s_dmaStateNext <= (s_endTransactionInReg == 1'b1) ? IDLE : ERROR;
      default          : s_dmaStateNext <= IDLE;
    endcase
  
  always @(posedge clock)
    begin
      s_lineCountReg           <= (reset == 1'd1 || newScreen == 1'd1) ? 1'd0 : (newLine == 1'd1) ? ~s_lineCountReg : s_lineCountReg;
      s_writeIndexReg          <= (reset == 1'd1) ? 1'b0 : (s_dmaState == READ_DONE || (s_dmaState == WRITE_BLACK && s_writeAddressReg[9] == 1'b1)) ? ~s_writeIndexReg : s_writeIndexReg;
      s_dmaState               <= (reset == 1'd1) ? IDLE : s_dmaStateNext;
      s_writeAddressReg        <= (s_dmaState == INIT_WRITE_BLACK || reset == 1'd1 || s_dmaState == INIT) ? 10'd0 : 
                                  ((s_writeAddressReg[9] == 1'd0 && s_dmaState == WRITE_BLACK) ||
                                   ((s_dmaState == READ || s_dmaState == READ1) && s_busDataInValidReg == 1'd1)) ? s_writeAddressReg + 10'd1 : s_writeAddressReg;
      s_currentPixelAddressReg <= (reset == 1'b1) ? 32'd0 :
                                  (newScreen == 1'b1) ? s_graphicBaseAddressReg :
                                  (s_busDataInValidReg == 1'b1 && (s_dmaState == READ || s_dmaState == READ1)) ? s_currentPixelAddressReg + 32'd4 : s_currentPixelAddressReg;
    end
endmodule
