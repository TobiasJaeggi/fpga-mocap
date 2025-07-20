module logicUnit ( input wire [2:0]   opcode,
                   input wire [31:0]  operantA,
                                      operantB,
                   output reg [31:0]  result );

  always @*
  begin
    case (opcode)
      3'b001 : result <= operantA & operantB;
      3'b010 : result <= operantA | operantB;
      3'b011 : result <= operantA ^ operantB;
      3'b100 : begin
                 result[31:16] <= {16{operantA[15]}};
                 result[15:0]  <= operantA[15:0];
               end
      3'b101 : begin
                 result[31:8] <= {24{operantA[7]}};
                 result[7:0]  <= operantA[7:0];
               end
      3'b110 : begin
                 result[31:16] <= {16{1'b0}};
                 result[15:0]  <= operantA[15:0];
               end
      3'b111 : begin
                 result[31:8] <= {24{1'b0}};
                 result[7:0]  <= operantA[7:0];
               end
      default: result <= {32{1'b0}};
    endcase
  end
endmodule
