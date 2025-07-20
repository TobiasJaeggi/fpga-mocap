module sram32x32DpAr ( input wire         writeClock,
                                          writeEnable,
                       input wire [4:0]   writeAddress,
                       input wire [4:0]   readAddress,
                       input wire [31:0]  writeData,
                       output wire [31:0] dataReadPort);

  reg [31:0] s_memory [31:0];
  
  assign dataReadPort = s_memory[readAddress];
  
  always @(posedge writeClock)
    if (writeEnable == 1'b1) s_memory[writeAddress] <= writeData;
endmodule
