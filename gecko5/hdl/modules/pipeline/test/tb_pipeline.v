module tb_pipeline;

  reg systemClock = 0;
  reg pixelClock = 0;
  reg reset = 0;
  wire href, vsync;
  wire [7:0] camData;

  localparam [1:0] CI_A_READ_LENGTH = 0;
  localparam [1:0] CI_A_WRITE_ADDRESS = 1;
  localparam [1:0] CI_A_START_STOP = 2;

  ov7670Fake fakeCamera (
      .reset(reset),
      .pclk(pixelClock),
      .href(href),
      .vsync(vsync),
      .camData(camData)
  );

  // ci
  reg ciStart = 0;
  reg ciCke = 0;
  reg [7:0] ciN = 0;
  reg [31:0] ciValueA = 0;
  reg [31:0] ciValueB = 0;
  wire [31:0] ciResult = 0;
  wire ciDone;

  // spi
  wire spiSck;
  wire spiMosi;
  wire spiMiso;
  wire spiTransferDone;
  assign spiMiso = spiMosi;

  pipeline #(
  ) pipeline_test (
      .reset(reset),
      .pixelClock(pixelClock),
      .href(href),
      .vsync(vsync),
      .camData(camData),
      .systemClock(systemClock),

      // ci
      .ciStart(ciStart),
      .ciCke(ciCke),
      .ciN(ciN),
      .ciValueA(ciValueA),
      .ciValueB(ciValueB),
      .ciResult(ciResult),
      .ciDone(ciDone),

      .spiSck(spiSck),
      .spiMosi(spiMosi),
      .spiMiso(spiMiso),
      .spiTransferDone(spiTransferDone)
  );

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_pipeline);
    systemClock = 0;
    reset = 1;
  end

  localparam integer unsigned BitsRxShiftReg = 5 * 8 * 16;
  reg [BitsRxShiftReg-1:0] spiRxReg;
  always @(posedge spiSck, posedge reset, posedge spiTransferDone) begin
    if (reset | spiTransferDone) begin
      spiRxReg <= 'b0;
    end else begin
      spiRxReg[BitsRxShiftReg-1:1] <= spiRxReg[BitsRxShiftReg-2:0];
      spiRxReg[0] <= spiMosi;
    end
  end


  always #1 systemClock = ~systemClock;

  always #2 pixelClock = ~pixelClock;

  initial begin
    #4 reset = 0;
    #30
    reset = 1;
    #4 reset = 0;
    #30
    @(posedge vsync)
    $display("first frame complete");
    #1
    @(posedge vsync)
    $display("second frame complete");
    #1
    @(posedge vsync)
    $display("third frame complete");
    #1 $finish;
  end

  realtime capture = 0.0;
  always begin
    #100_000;
    capture = $realtime;
    $display("%t", capture);
  end

endmodule
