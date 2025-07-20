module tb_hold;
  localparam NBITS = 4;
  localparam MAX_CONFIG_VALUE = (2**NBITS)-1;

  reg reset;
  reg clock;
  reg signal;
  reg [NBITS-1:0] configDelayFor;
  reg [NBITS-1:0] configHoldFor;
  reg applyConfig;
  wire signalDelayedAndHeld;

  hold #(
    .NBITS(NBITS)
  ) hold_test (
    .clk(clock),
    .reset(reset),
    .s(signal),
    .configDelayFor(configDelayFor),
    .configHoldFor(configHoldFor),
    .applyConfig(applyConfig),
    .h(signalDelayedAndHeld)
  );

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_hold);
    reset = 1;
    clock = 0;
    signal = 0;
    configDelayFor = 0;
    configHoldFor = 0;
    applyConfig = 0;
  end

  always begin
    #1 clock = ~clock;
  end

  initial begin
    #10 reset = 0;

    #2 configDelayFor = int'(MAX_CONFIG_VALUE / 2) + int'(1);
    #0 configHoldFor = int'(MAX_CONFIG_VALUE / 2);
    #1 applyConfig = 1'b1;
    #1 applyConfig = 1'b0;
    #2 signal = 1;
    #2 signal = 0;
    #40

    #2 signal = 1;
    #2 signal = 0;
    #40

    #2 configDelayFor = int'(1);
    #0 configHoldFor = int'(1);
    #1 applyConfig = 1'b1;
    #1 applyConfig = 1'b0;
    #2 signal = 1;
    #2 signal = 0;
    #40

    #2 configDelayFor = int'(0);
    #0 configHoldFor = int'(0);
    #1 applyConfig = 1'b1;
    #1 applyConfig = 1'b0;
    #2 signal = 1;
    #2 signal = 0;
    #40

    #2 signal = 1;
    #10 signal = 0;
    #40

    #2 configDelayFor = int'(MAX_CONFIG_VALUE / 2);
    #0 configHoldFor = int'(0);
    #1 applyConfig = 1'b1;
    #1 applyConfig = 1'b0;
    #2 signal = 1;
    #2 signal = 0;
    #40

    $finish;
  end

endmodule
