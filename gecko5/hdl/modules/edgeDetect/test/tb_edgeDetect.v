module tb_edgeDetect;
  reg reset;
  reg clock;
  reg signal;
  wire posEdge;
  wire negEdge;

  edgeDetect edgeDetect_test (
      .clk(clock),
      .reset(reset),
      .s(signal),
      .pos(posEdge),
      .neg(negEdge)
  );

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_edgeDetect);
    reset = 1;
    clock = 0;
    signal = 0;
  end

  
  always begin
    #1 clock = ~clock;
  end



  initial begin
    #10 reset = 0;
    #2 signal = 1;
    #2 signal = 0;
    #4 signal = 1;
    #4 signal = 0;
    #10
    $finish;
  end

endmodule
