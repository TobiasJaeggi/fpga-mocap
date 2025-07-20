module uartFifoMemory ( input wire         writeClock,
                                           writeEnable,
                        input wire [3:0]   writeAddress,
                        input wire [3:0]   readAddress,
                        input wire [7:0]   writeData,
                        output wire [7:0]  dataReadPort );

  reg [7:0] s_memory [15:0];
  
  assign dataReadPort  = s_memory[readAddress];
  
  always @(posedge writeClock)
    if (writeEnable == 1'b1) s_memory[writeAddress] <= writeData;
endmodule
