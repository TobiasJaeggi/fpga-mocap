module registerFile ( input wire         cpuClock,
                                         stall,
                                         inExceptionMode,
                                         writeEnable,
                      input wire [4:0]   readAddrA,
                                         readAddrB,
                                         writeAddr,
                      input wire [31:0]  writeData,
                      output wire [31:0] dataA,
                                         dataB);
  wire s_we = (stall == 1'b0) ? writeEnable : 1'b0;
  wire [31:0] s_dataA, s_dataB;
  genvar n;
  
  assign dataA = (readAddrA == 5'd0) ? 32'd0 : s_dataA;
  assign dataB = (readAddrB == 5'd0) ? 32'd0 : s_dataB;
  
  generate 
    for (n = 0 ; n < 32 ; n = n + 1)
    begin : makeregs
      lutRam32x1 ram1 ( .clock(cpuClock),
                        .we(s_we),
                        .dataIn(writeData[n]),
                        .writeAddress(writeAddr),
                        .readAddress(readAddrA),
                        .dataOut(s_dataA[n]));
      lutRam32x1 ram2 ( .clock(cpuClock),
                        .we(s_we),
                        .dataIn(writeData[n]),
                        .writeAddress(writeAddr),
                        .readAddress(readAddrB),
                        .dataOut(s_dataB[n]));
    end
  endgenerate
  
endmodule
