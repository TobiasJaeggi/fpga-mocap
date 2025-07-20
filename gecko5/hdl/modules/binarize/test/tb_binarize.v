module tb_binarize;

  reg sysclk, pclk, reset, href, vsync;
  reg [7:0] camData;
  wire bin, valid, hrefOut, vrefOut;
  wire [7:0] camDataOut;
  binarize bin_test (
      .pclk(pclk),
      .reset(reset),
      .href(href),
      .vsync(vsync),
      .camData(camData),

      .bin(bin),
      .valid(valid),
      .hrefBin(hrefOut),
      .vsyncBin(vsyncOut),
      .camDataBin(camDataOut),

      .systemClock(sysclk),
      // ci  
      .ciStart(1'd0),
      .ciCke(1'd0),
      .ciN(8'd0),
      .ciValueA(32'd0),
      .ciValueB(32'd0)
  );

  task sendPixel(input [15:0] pixel);
    begin
      @(posedge pclk) #0 camData = pixel[15:8];
      #1 @(posedge pclk) #0 camData = pixel[7:0];
    end
  endtask

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_binarize);
    sysclk = 0;
    pclk = 0;
    reset = 1;
    href = 0;
    vsync = 0;
    camData = 0;
  end

  always begin
    #5 pclk = ~pclk;
  end

  always begin
    #1 sysclk = ~sysclk;
  end

  initial begin
    #15 reset = 0;
    #10 @(posedge pclk) #0 href = 1;
    #0 camData = 'hde;
    #1 @(posedge pclk) #0 camData = 'had;
    #1 @(negedge pclk) #1 sendPixel('hbeef);
    #1 sendPixel('h1863);  // mean is 3
    #1 sendPixel('h69ad);  // mean is 13
    #1 sendPixel('h28a5);  // mean is 5
    #1 sendPixel('h618c);  // mean is 12
    #1 sendPixel('hdead);
    #1 sendPixel('hbeef);
    #1 @(posedge pclk) #0 href = 0;
    #20 $finish;
  end

endmodule

