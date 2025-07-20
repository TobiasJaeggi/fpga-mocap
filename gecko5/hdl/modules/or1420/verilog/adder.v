module adder ( input wire         flagIn,
                                  carryIn,
               input wire [1:0]   opcode,
               input wire [3:0]   flagMode,
               input wire [31:0]  operantA,
                                  operantB,
               output reg         flagOut,
               output wire        carryOut,
               output wire [31:0] result );

  wire s_equal = operantA == operantB ? 1'b1 : 1'b0;
  wire s_lessUnsigned = operantA < operantB ? 1'b1 : 1'b0;
  wire signed [31:0] signedA = operantA;
  wire signed [31:0] signedB = operantB;
  wire s_lessSigned = signedA < signedB ? 1'b1 : 1'b0;
  wire [32:0] s_oppA = {1'b0,operantA};
  reg [32:0] s_oppB, s_carryIn;
  wire [32:0] s_sum = s_oppA+s_oppB+s_carryIn;
  
  assign result = s_sum[31:0];
  assign carryOut = s_sum[32];
  
  always @*
  begin
    case (opcode)
      2'b10   : begin
                  s_oppB          <= {1'b0,operantB};
                  s_carryIn[32:1] <= {32{1'b0}};
                  s_carryIn[0]    <= carryIn;
                end
      2'b11   : begin
                  s_oppB          <= {1'b0,~operantB};
                  s_carryIn[32:1] <= {32{1'b0}};
                  s_carryIn[0]    <= 1'b1;
                end
      default : begin
                  s_oppB    <= {1'b0,operantB};
                  s_carryIn <= {33{1'b0}};
                end
    endcase
  end
  
  always @*
  begin
    case (flagMode)
      4'b0000 : flagOut <= s_equal;
      4'b0001 : flagOut <= ~s_equal;
      4'b0010 : flagOut <= ~(s_lessUnsigned | s_equal);
      4'b0011 : flagOut <= ~s_lessUnsigned;
      4'b0100 : flagOut <= s_lessUnsigned;
      4'b0101 : flagOut <= s_lessUnsigned | s_equal;
      4'b1010 : flagOut <= ~(s_lessSigned | s_equal);
      4'b1011 : flagOut <= ~s_lessSigned;
      4'b1100 : flagOut <= s_lessSigned;
      4'b1101 : flagOut <= s_lessSigned | s_equal;
      default : flagOut <= flagIn;
    endcase
  end
endmodule
