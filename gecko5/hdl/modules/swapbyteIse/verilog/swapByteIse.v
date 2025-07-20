module swapByte #(parameter [7:0]  customIntructionNr = 8'd0)
                 (input wire [7:0]   ciN,
                  input wire [31:0]  ciDataA,
                                     ciDataB,
                  input wire         ciStart,
                                     ciCke,
                  output wire        ciDone,
                  output wire [31:0] ciResult);

  wire s_isMyCustomInstruction = (ciN == customIntructionNr) ? ciStart & ciCke : 1'b0;
  
  wire [31:0] s_swappedData = (ciDataB[0] == 1'b0) ? {ciDataA[7:0], ciDataA[15:8], ciDataA[23:16], ciDataA[31:24]} :
                                                     {ciDataA[23:16], ciDataA[31:24], ciDataA[7:0], ciDataA[15:8]};

  assign ciDone = s_isMyCustomInstruction;
  assign ciResult = (s_isMyCustomInstruction == 1'b1) ? s_swappedData : 32'd0;

endmodule
