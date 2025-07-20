module sram1024X16Dp ( input wire        clockA,
                                         writeEnableA,
                       input wire [9:0]  addressA,
                       input wire [15:0] dataInA,
                       output reg [15:0] dataOutA,
                       input wire        clockB,
                                         writeEnableB,
                       input wire [9:0]  addressB,
                       input wire [15:0] dataInB,
                       output reg [15:0] dataOutB);

  reg [15:0] memory [1024:0];
  
  always @ (posedge clockA)
    begin
      if (writeEnableA == 1'b1) memory[addressA] <= dataInA;
      dataOutA <= memory[addressA];
    end

  always @ (posedge clockB)
    begin
      if (writeEnableB == 1'b1) memory[addressB] <= dataInB;
      dataOutB <= memory[addressB];
    end
endmodule
