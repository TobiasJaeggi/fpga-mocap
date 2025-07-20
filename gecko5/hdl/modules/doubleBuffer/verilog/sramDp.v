// write on positive edge, read on negative edge
module sramDp #(
    parameter DATA_WIDTH = 10,
    parameter ADDRESS_WIDTH = 8
    // default config: 1024x8
) (
    input wire clockA,
    input wire writeEnableA,
    input wire [ADDRESS_WIDTH-1:0] addressA,
    input wire [DATA_WIDTH-1:0] dataInA,
    input wire clockB,
    input wire [ADDRESS_WIDTH-1:0] addressB,
    output reg [DATA_WIDTH-1:0] dataOutB
);

  parameter ADDRESS_MAX = 2 << (ADDRESS_WIDTH - 1);
  reg [DATA_WIDTH-1:0] memory[ADDRESS_MAX-1:0];

  always @(posedge clockA) begin
    if (writeEnableA == 1'b1) memory[addressA] <= dataInA;
  end

  always @(negedge clockB) begin
    dataOutB <= memory[addressB];
  end
endmodule