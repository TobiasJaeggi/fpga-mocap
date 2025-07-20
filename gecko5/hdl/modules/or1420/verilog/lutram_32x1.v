module lutRam32x1 ( input wire       clock,
                                     we,
                                     dataIn,
                    input wire [4:0] writeAddress,
                                     readAddress,
                    output wire      dataOut);

  reg mem [31:0];
  
  assign dataOut = mem[readAddress];
  
  always @(posedge clock)
    if (we == 1'b1) mem[writeAddress] <= dataIn;

endmodule
