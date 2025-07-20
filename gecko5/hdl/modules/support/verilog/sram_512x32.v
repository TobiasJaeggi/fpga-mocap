module sram512X32 ( input wire        clock,
                                      writeEnable,
                    input wire [8:0]  address,
                    input wire [31:0] dataIn,
                    output reg [31:0] dataOut);

  reg [31:0] memory [511:0];
  
  always @ (posedge clock)
    begin
      if (writeEnable == 1'b1) memory[address] <= dataIn;
      dataOut <= memory[address];
    end
endmodule
