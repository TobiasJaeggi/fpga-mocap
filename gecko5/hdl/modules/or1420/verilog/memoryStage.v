module memoryStage ( input wire        cpuClock,
                                       cpuReset,
                                       stall,
                     input wire [2:0]  wbLoadMode,
                     input wire [31:0] wbWriteDataIn,
                     input wire [4:0]  wbWriteIndexIn,
                     input wire        wbWriteEnableIn,
                     output reg        wbStageLoadPending,
                     output reg [31:0] wbWriteData,
                     output reg [4:0]  wbWriteIndex,
                     output reg        wbWriteEnable);

  wire s_loadPendingNext = (wbLoadMode == 3'b0) ? 1'b0 : 1'b1;
  
  always @(posedge cpuClock)
    if (cpuReset == 1'b1) 
      begin
        wbWriteEnable      <= 1'b0;
        wbWriteIndex       <= 5'd0;
        wbWriteData        <= 32'd0;
        wbStageLoadPending <= 1'b0;
      end
    else if (stall == 1'b0)
      begin
        wbWriteEnable      <= wbWriteEnableIn;
        wbWriteIndex       <= wbWriteIndexIn;
        wbWriteData        <= wbWriteDataIn;
        wbStageLoadPending <= s_loadPendingNext;
      end

endmodule
