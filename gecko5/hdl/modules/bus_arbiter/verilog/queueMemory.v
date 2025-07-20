module queueMemory ( input wire         writeClock,
                                        writeEnable,
                     input wire [4:0]   writeAddress,
                     input wire [4:0]   readAddress,
                     input wire [31:0]  writeData,
                     output reg [31:0]  dataReadPort );

  reg [31:0] s_memory [31:0];
  
  always @(posedge writeClock)
    begin
      dataReadPort <= s_memory[readAddress];
      if (writeEnable == 1'b1) s_memory[writeAddress] <= writeData;
    end
endmodule
