module edgeDetect(
    input wire clk,
    input wire reset,
    input wire s,
    output wire pos,
    output wire neg
  );

  reg[1:0]  detectReg = 2'b0;
  wire negEdge = ~detectReg[0] & detectReg[1];
  wire posEdge = detectReg[0] & ~detectReg[1];

  always @(posedge clk or posedge reset) begin
    if (reset) detectReg <= 2'b0;
    else detectReg <= {detectReg[0], s};
  end

  assign pos = posEdge;
  assign neg = negEdge;

endmodule