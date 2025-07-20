module shifter ( input wire [2:0]   control,
                 input wire         flagIn,
                 input wire [31:0]  operantA,
                                    operantB,
                 output reg [31:0]  result );

  wire [ 4:0] s_shiftControl;
  wire [63:0] s_shiftIn, s_shiftStage1, s_shiftStage2, s_shiftStage3, s_shiftStage4, s_shiftStage5;
  
  assign s_shiftIn[63:32] = control == 3'b110 ? {32{operantA[31]}} : {32{1'b0}};
  assign s_shiftIn[31:0]  = operantA;
  assign s_shiftControl = control == 3'b100 ? operantB[4:0] : ~operantB[4:0];
  assign s_shiftStage1 = s_shiftControl[0] == 1'b0 ? s_shiftIn : {s_shiftIn[62:0],1'b0};
  assign s_shiftStage2 = s_shiftControl[1] == 1'b0 ? s_shiftStage1 : {s_shiftStage1[61:0],2'b00};
  assign s_shiftStage3 = s_shiftControl[2] == 1'b0 ? s_shiftStage2 : {s_shiftStage2[59:0],4'h0};
  assign s_shiftStage4 = s_shiftControl[3] == 1'b0 ? s_shiftStage3 : {s_shiftStage3[55:0],8'h00};
  assign s_shiftStage5 = s_shiftControl[4] == 1'b0 ? s_shiftStage4 : {s_shiftStage4[47:0],16'h0000};
  
  always @*
    case (control)
      3'b010 : result <= {operantB[15:0],16'h0000};
      3'b011 : result <= flagIn == 1'b1 ? operantA : operantB;
      3'b100 : result <= s_shiftStage5[31:0];
      3'b101 : result <= s_shiftStage5[62:31];
      3'b110 : result <= s_shiftStage5[62:31];
      3'b111 : result <= s_shiftStage5[62:31] | {s_shiftStage5[30:0],1'b0};
      default: result <= {32{1'b0}};
    endcase
endmodule
