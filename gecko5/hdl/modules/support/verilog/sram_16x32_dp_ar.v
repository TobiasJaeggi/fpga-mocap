module sram16x32DpAr ( input wire         writeClock,
                                          writeEnable,
                       input wire [3:0]   writeAddress,
                       input wire [3:0]   readAddress,
                       input wire [31:0]  writeData,
                       output wire [31:0] dataWritePort,
                                          dataReadPort );

  reg [31:0] s_memory [15:0];
  
  assign dataWritePort = s_memory[writeAddress];
  assign dataReadPort  = s_memory[readAddress];
  
  always @(posedge writeClock)
    if (writeEnable == 1'b1) s_memory[writeAddress] <= writeData;
endmodule
