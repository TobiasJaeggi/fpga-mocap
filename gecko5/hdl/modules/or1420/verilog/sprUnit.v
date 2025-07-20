module sprUnit ( input wire         cpuClock,
                                    cpuReset,
                                    stall,
                 output reg [31:0]  sprDataOut,
                 input wire [15:0]  sprIndex,
                 input wire         sprWe,
                 input wire [31:0]  sprDataIn,

                 input wire [2:0]   exeExcepMode,
                 input wire         exceptionPrefix,
                 output reg [31:0]  exceptionVector );

  reg [2:0] s_exceptionReg;
  reg [27:0] s_iCacheVectorReg, s_dCacheVectorReg, s_irqVectorReg, s_invalidVectorReg, s_systemVectorReg;

  always @(posedge cpuClock) if (cpuReset == 1'b1) s_exceptionReg <= 3'd0;
                             else if (exeExcepMode != 3'd0 && stall == 1'b0) s_exceptionReg <= exeExcepMode;
  
  always @*
    if (sprIndex[15:8] == 8'd0)
      case (sprIndex[7:0])
        8'h00   : sprDataOut <= {{4{exceptionPrefix}}, 28'd48};
        8'h01   : sprDataOut <= {{4{exceptionPrefix}}, s_iCacheVectorReg};
        8'h02   : sprDataOut <= {{4{exceptionPrefix}}, s_dCacheVectorReg};
        8'h03   : sprDataOut <= {{4{exceptionPrefix}}, s_irqVectorReg};
        8'h04   : sprDataOut <= {{4{exceptionPrefix}}, s_invalidVectorReg};
        8'h05   : sprDataOut <= {{4{exceptionPrefix}}, s_systemVectorReg};
        8'h12   : sprDataOut <= {29'd0,s_exceptionReg};
        default : sprDataOut <= 32'd0;
      endcase
    else sprDataOut <= 32'd0;

  always @*
    case (exeExcepMode)
      3'd1    : exceptionVector <= {{4{exceptionPrefix}}, s_iCacheVectorReg};
      3'd2    : exceptionVector <= {{4{exceptionPrefix}}, s_dCacheVectorReg};
      3'd3    : exceptionVector <= {{4{exceptionPrefix}}, s_irqVectorReg};
      3'd4    : exceptionVector <= {{4{exceptionPrefix}}, s_invalidVectorReg};
      3'd5    : exceptionVector <= {{4{exceptionPrefix}}, s_systemVectorReg};
      default : exceptionVector <= {{4{exceptionPrefix}}, 28'd48};
    endcase
  
  always @(posedge cpuClock)
    begin
      s_iCacheVectorReg  <= (cpuReset == 1'b1) ? 28'd8 : (sprWe == 1'b1 && sprIndex == 16'd1) ? sprDataIn[27:0] : s_iCacheVectorReg;
      s_dCacheVectorReg  <= (cpuReset == 1'b1) ? 28'd16 : (sprWe == 1'b1 && sprIndex == 16'd2) ? sprDataIn[27:0] : s_dCacheVectorReg;
      s_irqVectorReg     <= (cpuReset == 1'b1) ? 28'd24 : (sprWe == 1'b1 && sprIndex == 16'd3) ? sprDataIn[27:0] : s_irqVectorReg;
      s_invalidVectorReg <= (cpuReset == 1'b1) ? 28'd32 : (sprWe == 1'b1 && sprIndex == 16'd4) ? sprDataIn[27:0] : s_invalidVectorReg;
      s_systemVectorReg  <= (cpuReset == 1'b1) ? 28'd40 : (sprWe == 1'b1 && sprIndex == 16'd5) ? sprDataIn[27:0] : s_systemVectorReg;
    end
endmodule
