module sram512X32Dp ( input wire        clockA,
                                        writeEnableA,
                      input wire [8:0]  addressA,
                      input wire [31:0] dataInA,
                      output reg [31:0] dataOutA,
                      input wire        clockB,
                                        writeEnableB,
                      input wire [8:0]  addressB,
                      input wire [31:0] dataInB,
                      output reg [31:0] dataOutB);

  reg [31:0] memory [511:0];
  
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
