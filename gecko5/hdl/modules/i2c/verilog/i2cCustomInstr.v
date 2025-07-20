module i2cCustomInstr #( parameter CLOCK_FREQUENCY = 12000000,
                         parameter I2C_FREQUENCY = 1000000,
                         parameter [7:0] CUSTOM_ID = 8'h00)
                      ( input wire         clock,
                                           reset,
                                           ciStart,
                                           ciCke,
                        input wire [7:0]   ciN,
                        input wire [31:0]  ciOppA,
                        output wire        ciDone,
                                           SCL,
                        output wire [31:0] result,
                        inout wire         SDA);

  reg  s_startedI2cReg, s_doneReg, s_oldBusyReg;
  reg [31:0] s_inDataReg;
  wire s_busy, s_ackError;
  wire [7:0] s_i2cData;
  wire s_isMyCi = (ciN == CUSTOM_ID) ? ciStart & ciCke & ~s_startedI2cReg : 1'd0;
  wire s_startedI2cNext = (reset == 1'b1 || s_doneReg == 1'b1) ? 1'b0 : (s_isMyCi == 1'b1) ? 1'b1 : s_startedI2cReg;
  wire s_doneNext = (reset == 1'b1) ? 1'b0 : s_oldBusyReg & ~s_busy;
  wire s_startI2cRead  = ciOppA[24] & s_isMyCi;
  wire s_startI2cWrite = ~ciOppA[24] & s_isMyCi;
  
  assign ciDone = s_doneReg;
  assign result = (s_doneReg == 1'b0) ? 32'd0 : {s_ackError,23'd0,s_i2cData};
  
  always @(posedge clock)
    begin
      s_startedI2cReg <= s_startedI2cNext;
      s_oldBusyReg    <= s_busy & ~reset;
      s_doneReg       <= s_doneNext;
      s_inDataReg     <= (s_isMyCi == 1'b1) ? ciOppA : s_inDataReg;
    end

  i2cMaster #( .CLOCK_FREQUENCY(CLOCK_FREQUENCY),
               .I2C_FREQUENCY(I2C_FREQUENCY)) master
             ( .clock(clock),
               .reset(reset),
               .startWrite(s_startI2cWrite),
               .startRead(s_startI2cRead),
               .address(s_inDataReg[31:25]),
               .regIn(s_inDataReg[15:8]),
               .dataIn(s_inDataReg[7:0]),
               .dataOut(s_i2cData),
               .ackError(s_ackError),
               .busy(s_busy),
               .SCL(SCL),
               .SDA(SDA) );
endmodule
