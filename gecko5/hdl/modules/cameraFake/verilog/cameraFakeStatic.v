module cameraFakeStatic#(
  parameter PCLK_PER_PIXEL = 1,
  parameter WIDTH = 1280,
  parameter H_FRONT_PORCH = 19,
  parameter H_SYNC_PULSE = 80,
  parameter H_BACK_PORCH = 45,
  parameter HEIGHT = 800,
  parameter V_FRONT_PORCH = 10,
  parameter V_SYNC_PULSE = 3,
  parameter V_BACK_PORCH = 17
) (
    input wire reset,
    input wire pclk,
    output wire href,
    output wire hsync,
    output wire vsync,
    output wire [7:0] camData
);

  localparam COUNTER_X_MAX = (WIDTH + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH) * PCLK_PER_PIXEL;
  localparam COUNTER_Y_MAX = (HEIGHT + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH);
  reg [$clog2(COUNTER_X_MAX)-1:0] s_counterX = 0;
  reg [$clog2(COUNTER_Y_MAX)-1:0] s_counterY = 0;

  wire s_counterXMaxed = (s_counterX == COUNTER_X_MAX);
  wire s_counterYMaxed = (s_counterY == COUNTER_Y_MAX);

  always @(posedge pclk or posedge reset) begin
    if (reset) s_counterX <= 0;
    else begin
      if (s_counterXMaxed) s_counterX <= 0;
      else s_counterX <= s_counterX + 1;
    end
  end

  always @(posedge pclk or posedge reset) begin
    if (reset) s_counterY <= 0;
    else begin
      if (s_counterXMaxed) begin
        if (s_counterYMaxed) s_counterY <= 0;
        else s_counterY <= s_counterY + 1;
      end
    end
  end

  wire s_href;
  wire s_hsync;
  wire s_vsync;
  wire [7:0] s_square;
  assign s_href = (s_counterY < HEIGHT) && (s_counterX < (WIDTH * PCLK_PER_PIXEL));
  // according to ov7670 datasheet, HSYNC is active low
  assign s_hsync = ~(s_counterX > ((WIDTH + H_FRONT_PORCH) * PCLK_PER_PIXEL) && (s_counterX < ((WIDTH + H_FRONT_PORCH + H_SYNC_PULSE) * PCLK_PER_PIXEL)));
  // according to ov7670 datasheet, VSYNC is active high. However i2c sequence then configures VSYNC negative
  assign s_vsync = ~((s_counterY > (HEIGHT + V_FRONT_PORCH)) && (s_counterY < (HEIGHT + V_FRONT_PORCH + V_SYNC_PULSE)));

  // some white rectangles
  wire s_square0 = ((s_counterX > (40 * PCLK_PER_PIXEL)) && (s_counterX < ((40 + 300) * PCLK_PER_PIXEL)) && (s_counterY > 40) && (s_counterY < (40 + 60)));
  wire s_square1 = ((s_counterX > (40 * PCLK_PER_PIXEL)) && (s_counterX < ((40 + 300) * PCLK_PER_PIXEL)) && (s_counterY > 160) && (s_counterY < (160 + 60)));
  wire s_square2 = ((s_counterX > (40 * PCLK_PER_PIXEL)) && (s_counterX < ((40 + 300) * PCLK_PER_PIXEL)) && (s_counterY > 280) && (s_counterY < (280 + 60)));
  wire s_square3 = ((s_counterX > (40 * PCLK_PER_PIXEL)) && (s_counterX < ((40 + 300) * PCLK_PER_PIXEL)) && (s_counterY > 400) && (s_counterY < (400 + 60)));
  wire s_square4 = ((s_counterX > (40 * PCLK_PER_PIXEL)) && (s_counterX < ((40 + 300) * PCLK_PER_PIXEL)) && (s_counterY > 640) && (s_counterY < (640 + 60)));
  wire s_square5 = ((s_counterX > (40 * PCLK_PER_PIXEL)) && (s_counterX < ((40 + 1200) * PCLK_PER_PIXEL)) && (s_counterY > 720) && (s_counterY < (720 + 60)));
  wire s_square6 = ((s_counterX > (40 * PCLK_PER_PIXEL)) && (s_counterX < ((40 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 400) && (s_counterY < (400 + 300)));
  wire s_square7 = ((s_counterX > (290 * PCLK_PER_PIXEL)) && (s_counterX < ((290 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 400) && (s_counterY < (400 + 300)));
  wire s_square8 = ((s_counterX > (160 * PCLK_PER_PIXEL)) && (s_counterX < ((160 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 520) && (s_counterY < (520 + 60)));
  wire s_square9 = ((s_counterX > (400 * PCLK_PER_PIXEL)) && (s_counterX < ((400 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 40) && (s_counterY < (40 + 300)));
  wire s_square10 = ((s_counterX > (520 * PCLK_PER_PIXEL)) && (s_counterX < ((520 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 40) && (s_counterY < (40 + 300)));
  wire s_square11 = ((s_counterX > (640 * PCLK_PER_PIXEL)) && (s_counterX < ((640 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 40) && (s_counterY < (40 + 300)));
  wire s_square12 = ((s_counterX > (400 * PCLK_PER_PIXEL)) && (s_counterX < ((400 + 300) * PCLK_PER_PIXEL)) && (s_counterY > 400) && (s_counterY < (400 + 60)));
  wire s_square13 = ((s_counterX > (400 * PCLK_PER_PIXEL)) && (s_counterX < ((400 + 300) * PCLK_PER_PIXEL)) && (s_counterY > 640) && (s_counterY < (640 + 60)));
  wire s_square14 = ((s_counterX > (640 * PCLK_PER_PIXEL)) && (s_counterX < ((640 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 400) && (s_counterY < (400 + 300)));
  wire s_square15 = ((s_counterX > (760 * PCLK_PER_PIXEL)) && (s_counterX < ((760 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 40) && (s_counterY < (40 + 300)));
  wire s_square16 = ((s_counterX > (760 * PCLK_PER_PIXEL)) && (s_counterX < ((760 + 300) * PCLK_PER_PIXEL)) && (s_counterY > 280) && (s_counterY < (280 + 60)));
  wire s_square17 = ((s_counterX > (760 * PCLK_PER_PIXEL)) && (s_counterX < ((760 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 400) && (s_counterY < (400 + 300)));
  wire s_square18 = ((s_counterX > (760 * PCLK_PER_PIXEL)) && (s_counterX < ((760 + 300) * PCLK_PER_PIXEL)) && (s_counterY > 400) && (s_counterY < (400 + 60)));
  wire s_square19 = ((s_counterX > (1000 * PCLK_PER_PIXEL)) && (s_counterX < ((1000 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 400) && (s_counterY < (400 + 300)));
  wire s_square20 = ((s_counterX > (1140 * PCLK_PER_PIXEL)) && (s_counterX < ((1140 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 520) && (s_counterY < (520 + 60)));
  wire s_square21 = ((s_counterX > (940 * PCLK_PER_PIXEL)) && (s_counterX < ((940 + 300) * PCLK_PER_PIXEL)) && (s_counterY > 40) && (s_counterY < (40 + 60)));
  wire s_square22 = ((s_counterX > (1180 * PCLK_PER_PIXEL)) && (s_counterX < ((1180 + 60) * PCLK_PER_PIXEL)) && (s_counterY > 40) && (s_counterY < (40 + 300)));

  assign s_square = (s_square0 || s_square1 || s_square2 || s_square3 ||
                     s_square4 || s_square5 || s_square6 || s_square7 ||
                     s_square8 || s_square9 || s_square10 || s_square11 ||
                     s_square12 || s_square13 || s_square14 || s_square15 ||
                     s_square16 || s_square17 || s_square18 || s_square19 ||
                     s_square20 || s_square21 || s_square22 ) ? 8'hFF : 8'h00;
  // clocked output to hold signal steady
  reg href_clocked, hsync_clocked, vsync_clocked;
  reg [7:0] camData_clocked;
  always @(posedge pclk or posedge reset) begin
    if (reset == 1) begin
      href_clocked <= 1;
      hsync_clocked <= 1;
      vsync_clocked <= 1;
      camData_clocked <= 0;
    end else begin
      href_clocked <= s_href;
      hsync_clocked <= s_hsync;
      vsync_clocked <= s_vsync;
      camData_clocked <= s_square;
    end
  end

  assign href = href_clocked;
  assign hsync = hsync_clocked;
  assign vsync = vsync_clocked;
  assign camData = camData_clocked;

endmodule
