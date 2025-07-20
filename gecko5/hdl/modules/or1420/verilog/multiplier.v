module multiplier ( input wire         doMultiply,
                    input wire [31:0]  operantA,
                                       operantB,
                    output wire [31:0] result );
  assign result = doMultiply == 1'b0 ? {32{1'b0}} : operantA*operantB;
endmodule
