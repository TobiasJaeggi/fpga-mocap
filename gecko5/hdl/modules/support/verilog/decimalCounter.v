module decimalCounter ( input wire        clock,
                                          reset,
                                          enable,
                        output wire       isNine,
                        output wire [3:0] countValue );

  reg [3:0] s_countValueReg;
  wire s_isNine = (s_countValueReg == 9) ? enable : 1'b0;
  wire [3:0] s_countValueNext = (reset == 1'b1 || s_isNine == 1'b1) ? 4'd0 : (enable == 1'b0) ? s_countValueReg : s_countValueReg + 4'd1;
  assign countValue = s_countValueReg;
  assign isNine = s_isNine;
  
  always @(posedge clock) s_countValueReg <= (reset == 1'b1) ? 4'd0 : s_countValueNext;
endmodule
