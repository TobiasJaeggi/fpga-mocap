module cameraFakeMoving #(
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
  assign s_hsync = ~(s_counterX > ((WIDTH + H_FRONT_PORCH) * PCLK_PER_PIXEL) && (s_counterX < ((WIDTH + H_FRONT_PORCH + H_SYNC_PULSE) * PCLK_PER_PIXEL)));
  assign s_vsync = ~((s_counterY > (HEIGHT + V_FRONT_PORCH)) && (s_counterY < (HEIGHT + V_FRONT_PORCH + V_SYNC_PULSE)));

  // some white rectangles
  localparam SQUARE_WIDTH = 100;
  localparam SQUARE_HEIGTH = 60;

  reg [$clog2(COUNTER_X_MAX):0] squareOriginX; // 1 bit more to prevent imediate overrun if stride results in origin which is out of bounds
  reg [$clog2(COUNTER_Y_MAX):0] squareOriginY; // 1 bit more to prevent imediate overrun if stride results in origin which is out of bounds
  
  wire s_vsyncPosEdge;
  
  edgeDetect vrefEdge (
    .clk(pclk),
    .reset(reset),
    .s(s_vsync),
    .pos(s_vsyncPosEdge)
  );

  localparam STRIDE_X = 'd10;
  localparam STRIDE_Y = 'd8;

  always @(posedge pclk or posedge reset) begin
    if (reset) begin
      squareOriginX <= 0;
      squareOriginY <= 380;
    end else begin
      if (s_vsyncPosEdge == 'b1) begin
        squareOriginX <= (squareOriginX >= WIDTH) ? 'd0 : (squareOriginX + STRIDE_X);
        squareOriginY <= (squareOriginY >= HEIGHT) ? 'd0 : (squareOriginX >= WIDTH) ? (squareOriginY + STRIDE_Y) : squareOriginY;
      end
    end
  end

  wire s_square0 = ((s_counterX > (squareOriginX*2)) && (s_counterX < ((squareOriginX+SQUARE_WIDTH)*2)) && (s_counterY > squareOriginY) && (s_counterY < (squareOriginY+SQUARE_HEIGTH)));

  assign s_square = (s_square0) ? 8'hff : 8'h00;

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
