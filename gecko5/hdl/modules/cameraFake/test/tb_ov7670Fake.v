module tb_ov7670Fake;

  reg pclk, reset;
  wire href, hsync, vsync;
  wire [7:0] camData;

  ov7670Fake ov7670Fake_test (
      .reset(reset),
      .pclk(pclk),
      .href(href),
      .hsync(hsync),
      .vsync(vsync),
      .camData(camData)
  );

  reg href_clocked, hsync_clocked, vsync_clocked;
  reg [7:0] camData_clocked;
  always @(posedge pclk or posedge reset) begin
    if (reset) begin
      href_clocked <= 0;
      hsync_clocked <= 0;
      vsync_clocked <= 0;
      camData_clocked <= 0;
    end else begin
      href_clocked <= href;
      hsync_clocked <= hsync;
      vsync_clocked <= vsync;
      camData_clocked <= camData;
    end
  end


  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_ov7670Fake);
    pclk = 0;
    reset = 1;
  end

  always begin
    #1 pclk = ~pclk;
  end

  initial begin
    #5 reset = 0;
    #10_000_000 $finish;
  end

  realtime capture = 0.0;
  always begin
    #1_000_000;
    capture = $realtime;
    $display("%t", capture);
  end

endmodule
