module uartBus #( parameter [31:0] baseAddress = 0 )
               ( input wire         clock,
                                    reset,
                 output wire        irq,
                 
                 // the bus interface
                 input wire         beginTransactionIn,
                                    endTransactionIn,
                                    readNWriteIn,
                                    dataValidIn,
                                    busyIn,
                 input wire [31:0]  addressDataIn,
                 input wire [3:0]   byteEnablesIn,
                 input wire [7:0]   burstSizeIn,
                 output wire [31:0] addressDataOut,
                 output reg         endTransactionOut,
                 output wire        dataValidOut,
                 output reg         busErrorOut,
                 
                 // the external signals
                 input wire         RxD,
                 output wire        TxD);

  // here the bus related signals are defined
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] WAIT = 2'b01;
  localparam [1:0] END  = 2'b10;

  reg [1:0]   s_readStateReg, s_readStateNext;
  reg         s_startTransactionReg, s_transactionActiveReg, s_readNWriteReg, s_dataInValidReg, s_dataOutValidReg;
  reg [3:0]   s_byteEnablesReg, s_requiredByteEnables;
  reg [7:0]   s_burstSizeReg, s_selectedDataIn;
  reg [31:0]  s_busAddressReg, s_dataInReg, s_dataOutReg;
  wire [31:0] s_readValue;
  wire        s_isMyTransaction = (s_transactionActiveReg == 1'b1 && s_busAddressReg[31:3] == baseAddress[31:3] ) ? 1'b1 : 1'b0; // 3 bit address range. baseAddress up to baseAddress + 0x0000_0007
  wire        s_isBusError = ((s_byteEnablesReg != s_requiredByteEnables && s_readNWriteReg == 1'b0) || s_burstSizeReg != 8'd0) ? s_isMyTransaction : 1'b0;
  wire        s_writeDataOutValue = (s_readStateReg == IDLE && s_startTransactionReg == 1'b1 && s_isMyTransaction == 1'b1 && s_readNWriteReg == 1'b1) ? 1'b1 : 1'b0;
  wire        s_resetDataOutValue = (reset == 1'b1 || (s_readStateReg == WAIT && busyIn == 1'b0)) ? 1'b1 : 1'b0;
  
  assign dataValidOut   = s_dataOutValidReg;
  assign addressDataOut = s_dataOutReg;
  
  always @(posedge clock)
    begin
      s_startTransactionReg  <= (reset == 1'b1) ? 1'b0 : beginTransactionIn;
      s_transactionActiveReg <= (reset == 1'b1 || endTransactionIn == 1'b1) ? 1'b1 : (beginTransactionIn == 1'b1) ? 1'b1 : s_transactionActiveReg;
      s_readNWriteReg        <= (reset == 1'b1) ? 1'b0 : (beginTransactionIn == 1'b1) ? readNWriteIn : s_readNWriteReg;
      s_byteEnablesReg       <= (reset == 1'b1) ? 4'd0 : (beginTransactionIn == 1'b1) ? byteEnablesIn : s_byteEnablesReg;
      s_burstSizeReg         <= (reset == 1'b1) ? 8'd0 : (beginTransactionIn == 1'b1) ? burstSizeIn : s_burstSizeReg;
      s_busAddressReg        <= (reset == 1'b1) ? 32'd0 : (beginTransactionIn == 1'b1) ? addressDataIn : s_busAddressReg;
      s_dataInReg            <= (reset == 1'b1) ? 32'd0 : (dataValidIn == 1'b1) ? addressDataIn : s_dataInReg;
      s_dataInValidReg       <= (reset == 1'b1) ? 1'b0 : dataValidIn & s_isMyTransaction & ~s_isBusError & ~s_readNWriteReg;
      s_dataOutReg           <= (s_resetDataOutValue == 1'b1) ? 32'd0 : (s_writeDataOutValue == 1'b1) ? s_readValue : s_dataOutReg;
      s_dataOutValidReg      <= (s_resetDataOutValue == 1'b1) ? 1'b0 : (s_writeDataOutValue == 1'b1) ? 1'b1 : s_dataOutValidReg;
      s_readStateReg         <= (reset == 1'b1) ? IDLE : s_readStateNext;
      endTransactionOut      <= (reset == 1'b1) ? 1'b0 : (s_readStateReg == END) ? 1'b1 : 1'b0;
      busErrorOut            <= (reset == 1'b1 || endTransactionIn == 1'b1) ? 1'b0 : s_isBusError;
    end
  
  always @*
    case (s_readStateReg)
      IDLE    : s_readStateNext <= (s_writeDataOutValue == 1'b1) ? WAIT : IDLE;
      WAIT    : s_readStateNext <= (busyIn == 1'b1) ? WAIT : END;
      default : s_readStateNext <= IDLE;
    endcase
  
  always @*
    case (s_busAddressReg[1:0])
      2'd0    : begin
                  s_requiredByteEnables <= 4'd1;
                  s_selectedDataIn      <= s_dataInReg[7:0];
                end
      2'd1    : begin
                  s_requiredByteEnables <= 4'd2;
                  s_selectedDataIn      <= s_dataInReg[15:8];
                end
      2'd2    : begin
                  s_requiredByteEnables <= 4'd4;
                  s_selectedDataIn      <= s_dataInReg[23:16];
                end
      default : begin
                  s_requiredByteEnables <= 4'd8;
                  s_selectedDataIn      <= s_dataInReg[31:24];
                end
   endcase

  // here the uart registers are defined
  reg [15:0] s_divisorReg;
  reg [7:0]  s_lineControlReg, s_interruptEnableReg, s_scratchReg, s_modemControlReg;
  reg [7:6]  s_fifoControlReg;
  wire [7:0] s_weRegsVector;
  wire       s_TxD;
  
  assign TxD = s_TxD | s_modemControlReg[4];
  
  always @(posedge clock)
    begin
      s_divisorReg[7:0]    <= (reset == 1'b1) ? 8'd0 : (s_weRegsVector[0] == 1'b1 && s_lineControlReg[7] == 1'b1) ? s_selectedDataIn : s_divisorReg[7:0];
      s_divisorReg[15:8]   <= (reset == 1'b1) ? 8'd0 : (s_weRegsVector[1] == 1'b1 && s_lineControlReg[7] == 1'b1) ? s_selectedDataIn : s_divisorReg[15:8];
      s_lineControlReg     <= (reset == 1'b1) ? 8'd0 : (s_weRegsVector[3] == 1'b1) ? s_selectedDataIn : s_lineControlReg;
      s_interruptEnableReg <= (reset == 1'b1) ? 8'd0 : (s_weRegsVector[1] == 1'b1 && s_lineControlReg[7] == 1'b0) ? {5'd0, s_selectedDataIn[2:0]} : s_interruptEnableReg;
      s_scratchReg         <= (reset == 1'b1) ? 8'd0 : (s_weRegsVector[7] == 1'b1) ? s_selectedDataIn : s_scratchReg;
      s_modemControlReg    <= (reset == 1'b1) ? 8'd0 : (s_weRegsVector[4] == 1'b1) ? {3'd0, s_selectedDataIn[4], 4'd0} : s_modemControlReg;
      s_fifoControlReg     <= (reset == 1'b1) ? 2'd0 : (s_weRegsVector[2] == 1'b1) ? s_selectedDataIn[7:6] : s_fifoControlReg;
    end
  genvar n;
  
  generate
    for (n = 0; n < 8 ; n = n + 1)
	   begin : gen
        assign s_weRegsVector[n] = (s_busAddressReg[2:0] == n) ? s_dataInValidReg : 1'b0;
		end
  endgenerate

  // the baud rate generator
  wire s_baudRateX16Tick, s_baudRateX2Tick;

  baudGenerator bdg ( .clock(clock),
                      .reset(reset),
                      .baudDivisor(s_divisorReg),
                      .baudRateX16Tick(s_baudRateX16Tick),
                      .baudRateX2Tick(s_baudRateX2Tick) );
  
  // here the tx path is defined
  wire s_TxFifoRe, s_TxFifoEmpty, s_TxFifoFull, s_TxBusy;
  wire s_TxFifoWe = ~s_TxFifoFull & s_weRegsVector[0] & ~s_lineControlReg[7];
  wire [7:0] s_TxFifoData;
  wire s_resetTxFifo = reset | (s_weRegsVector[2] & s_selectedDataIn[2]);
  
  uartTxFifo TXF ( .clock(clock),
                   .reset(s_resetTxFifo),
                   .fifoRe(s_TxFifoRe),
                   .fifoWe(s_TxFifoWe),
                   .fifoEmpty(s_TxFifoEmpty),
                   .fifoFull(s_TxFifoFull),
                   .dataIn(s_selectedDataIn),
                   .dataOut(s_TxFifoData));
  
  uartTx TXC ( .clock(clock),
               .reset(reset),
               .baudRateX2tick(s_baudRateX2Tick),
               .controlReg(s_lineControlReg[6:0]),
               .fifoData(s_TxFifoData),
               .fifoEmpty(s_TxFifoEmpty),
               .busy(s_TxBusy),
               .fifoReadAck(s_TxFifoRe),
               .uartTxLine(s_TxD) );
  
  // here the Rx path is defined
  reg s_rxFifoReReg, s_lineStatus1Reg;
  wire s_rxFifoEmpty, s_rxFifoWe, s_clearError, s_frameError, s_parityError, s_rxFifoFull, s_overrunError, s_break;
  wire [7:0] s_lineStatusReg, s_rxFifoData, s_receiverBufferReg;
  wire [4:0] s_rxNrOfEntries;
  wire s_resetRxFifo = reset | (s_weRegsVector[2] & s_selectedDataIn[1]);
  wire s_uartRx = (s_modemControlReg[4] == 1'b1) ? s_TxD : RxD;
  
  assign s_lineStatusReg[0] = ~s_rxFifoEmpty;
  assign s_lineStatusReg[1] = s_lineStatus1Reg;
  assign s_lineStatusReg[5] = s_TxFifoEmpty;
  assign s_lineStatusReg[6] = s_TxFifoEmpty & ~s_TxBusy;
  
  always @(posedge clock) 
    begin
      s_rxFifoReReg    <= (s_writeDataOutValue == 1'b1 && s_busAddressReg[2:0] == 3'd0) ? ~s_rxFifoEmpty : 1'b0;
      s_lineStatus1Reg <= (s_clearError == 1'b1 || s_resetRxFifo == 1'b1) ? 1'b0 : s_lineStatus1Reg | s_overrunError;
    end
  
  uartRxFifo RXF ( .clock(clock),
                   .reset(s_resetRxFifo),
                   .fifoRe(s_rxFifoReReg),
                   .fifoWe(s_rxFifoWe),
                   .clearError(s_clearError),
                   .frameErrorIn(s_frameError),
                   .parityErrorIn(s_parityError),
                   .breakIn(s_break),
                   .fifoEmpty(s_rxFifoEmpty),
                   .fifoFull(s_rxFifoFull),
                   .dataIn(s_rxFifoData),
                   .frameErrorOut(s_lineStatusReg[3]),
                   .parityErrorOut(s_lineStatusReg[2]),
                   .breakOut(s_lineStatusReg[4]),
                   .fifoError(s_lineStatusReg[7]),
                   .nrOfEntries(s_rxNrOfEntries),
                   .dataOut(s_receiverBufferReg));

  uartRx RXC ( .clock(clock),
               .reset(reset),
               .baudRateX16Tick(s_baudRateX16Tick),
               .uartRxLine(s_uartRx),
               .fifoFull(s_rxFifoFull),
               .controlReg(s_lineControlReg[5:0]),
               .fifoData(s_rxFifoData),
               .fifoWe(s_rxFifoWe),
               .frameError(s_frameError),
               .breakDetected(s_break),
               .parityError(s_parityError),
               .overrunError(s_overrunError) );

  // here the irq's are defined
  reg s_lineStatusIrq, s_rxAvailableIrq, s_rxAvailableNext, s_txEmptyIrq;
  reg [1:0] s_txEmptyEdgeReg;
  wire s_clear_error = (s_readStateReg == END && s_busAddressReg[2:0] == 3'b101) ? 1'b1 : 1'b0;
  wire s_txEmptyNext = (reset == 1'b1 || s_TxFifoWe == 1'b1 || (s_readStateReg == END && s_busAddressReg[2:0] == 3'b010 && s_rxAvailableIrq == 1'b0 && s_lineStatusIrq == 1'b0)) ? 1'b0 :
                       (s_txEmptyEdgeReg == 2'b01) ? 1'b1 : s_txEmptyIrq;
  wire [7:0] s_interruptIdentReg;
  assign s_interruptIdentReg[7:3] = 5'b11000;
  assign s_interruptIdentReg[2]   = s_lineStatusIrq | s_rxAvailableIrq;
  assign s_interruptIdentReg[1]   = s_lineStatusIrq | s_txEmptyIrq;
  assign s_interruptIdentReg[0]   = ~(s_lineStatusIrq | s_rxAvailableIrq | s_txEmptyIrq);
  assign irq = s_lineStatusIrq | s_rxAvailableIrq | s_txEmptyIrq;
  
  always @(posedge clock)
    begin
      s_lineStatusIrq  <= (reset == 1'b1 || s_clear_error == 1'b1) ? 1'b0 :
                          (s_lineStatusIrq | s_lineStatusReg[4] | s_lineStatusReg[3] | s_lineStatusReg[2] | s_lineStatusReg[1]) & s_interruptEnableReg[2];
      s_rxAvailableIrq <= (reset == 1'b1) ? 1'b0 : s_rxAvailableNext & s_interruptEnableReg[0];
      s_txEmptyEdgeReg <= (reset == 1'b1) ? 2'd0 : {s_txEmptyEdgeReg[0], s_lineStatusReg[6]};
      s_txEmptyIrq     <= s_txEmptyNext;
    end
  
  always @*
    case (s_fifoControlReg)
      2'd0     : s_rxAvailableNext <= s_rxNrOfEntries[4] | s_rxNrOfEntries[3] | s_rxNrOfEntries[2] | s_rxNrOfEntries[1] | s_rxNrOfEntries[0];
      2'd1     : s_rxAvailableNext <= s_rxNrOfEntries[4] | s_rxNrOfEntries[3] | s_rxNrOfEntries[2];
      2'd2     : s_rxAvailableNext <= s_rxNrOfEntries[4] | s_rxNrOfEntries[3];
      default  : s_rxAvailableNext <= (s_rxNrOfEntries[4] == 1'b1 || s_rxNrOfEntries[4:1] == 4'd7) ? 1'b1 : 1'b0;
    endcase
  
  // finally we define the value read out of the core
  assign s_readValue[31:24] = (s_busAddressReg[2] == 1'b1) ? s_scratchReg : s_lineControlReg;
  assign s_readValue[23:16] = (s_busAddressReg[2] == 1'b1) ? 8'd0 : s_interruptIdentReg;
  assign s_readValue[15:8]  = (s_busAddressReg[2] == 1'b1) ? s_lineStatusReg : (s_lineControlReg[7] == 1'b0) ? s_interruptEnableReg : s_divisorReg[15:8];
  assign s_readValue[7:0]   = (s_busAddressReg[2] == 1'b1) ? s_modemControlReg : (s_lineControlReg[7] == 1'b0) ? s_receiverBufferReg : s_divisorReg[7:0];

endmodule
