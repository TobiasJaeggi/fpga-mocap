module dCacheSpm ( input wire        clock,
                   input wire [3:0]  byteWe,
                   input wire [10:0]  address,
                   input wire [31:0] dataIn,
                   output reg [31:0] dataOut );

reg [7:0] byteRam0 [0:2047];
reg [7:0] byteRam1 [0:2047];
reg [7:0] byteRam2 [0:2047];
reg [7:0] byteRam3 [0:2047];

  always @(posedge clock)
    begin
      if (byteWe[0] == 1'b1) byteRam0[address] <= dataIn[7:0];
      dataOut[7:0] <= byteRam0[address];
    end

  always @(posedge clock)
    begin
      if (byteWe[1] == 1'b1) byteRam1[address] <= dataIn[15:8];
      dataOut[15:8] <= byteRam1[address];
    end

  always @(posedge clock)
    begin
      if (byteWe[2] == 1'b1) byteRam2[address] <= dataIn[23:16];
      dataOut[23:16] <= byteRam2[address];
    end

  always @(posedge clock)
    begin
      if (byteWe[3] == 1'b1) byteRam3[address] <= dataIn[31:24];
      dataOut[31:24] <= byteRam3[address];
    end
endmodule

