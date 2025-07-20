`timescale 1ps / 1ps

module tb_generic_fifo_dc;

reg clock, reset;
wire pclk, href, hsync, vsync;
wire [7:0] camData;
generic_fifo_dc generic_fifo_dc_test(
    .clock(clock),
    .reset(reset)
);

initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb_generic_fifo_dc);
    clock = 0;
    reset = 1;
end

always begin
    #5 clock = ~clock;
end

initial begin
    #15 reset = 0;
    #1000
    $finish;
end

endmodule
