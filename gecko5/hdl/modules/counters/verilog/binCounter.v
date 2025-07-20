module binCounter #(parameter NBITS = 4) (
  input wire clock,
  input wire reset,
  input wire clear,
  input wire load,
  input wire enable,
  input wire [NBITS-1:0] din,
  output wire max_pulse,
  output wire [NBITS-1:0] dout
);

localparam MAX = (2**NBITS)-1;
reg[NBITS-1:0] s_stateNext, s_stateReg;

//TODO: async reset
always @(posedge clock)
begin
  s_stateReg <= (reset == 1'b1) ? 0 : s_stateNext;
end

// NSL
assign s_stateNext =  clear ? 0 :
                      load ? din : 
                      enable ? s_stateReg + 1 : 
                      s_stateReg;  

// OL
assign max_pulse = (s_stateReg == MAX) ? 1 : 0;
assign dout = s_stateReg;

endmodule
