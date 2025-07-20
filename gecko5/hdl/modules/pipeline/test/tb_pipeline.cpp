#include <stdlib.h>
#include <iostream>
#include <cmath>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vpipeline.h"
//#include "Vpipeline_pipeline.h"
#include "../../../modules/test/simUtils.h"

static constexpr uint32_t WIDTH {640};
static constexpr uint32_t H_FRONT_PORCH {19};
static constexpr uint32_t H_SYNC_PULSE {80};
static constexpr uint32_t H_BACK_PORCH {45};
static constexpr uint32_t PCLK_PER_PIXEL {2};
static constexpr uint32_t PCLK_PER_LINE {(WIDTH + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH + 1) * PCLK_PER_PIXEL}; // + 1 because timing implementation is wrong
static constexpr uint32_t HEIGHT {480};
static constexpr uint32_t V_FRONT_PORCH {10};
static constexpr uint32_t V_SYNC_PULSE {3};
static constexpr uint32_t V_BACK_PORCH {17};
static constexpr uint32_t LINES_PER_FRAME {(HEIGHT + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH)};
static constexpr uint32_t SIM_STEPS_PER_PCLK_CYCLE {2};
static constexpr uint32_t CLOCK_PER_PCLK {8};

#define RESET_CHECKS [&dut, & m_trace](){}

int rgb565(int r, int g, int b){
    return (r << 11) + (g << 5) + (b << 0);
}

int rgb565ToGrayscale(int rgb565){
    int r = (rgb565 >> 11) & 0b11111;
    int g = (rgb565 >> 5) & 0b111111;
    int b = (rgb565 >> 0) & 0b11111;
    // Note that green is weighted more heavily than red and blue
    return (r + g + b) / 3;
}

struct BoundingBox{
    int x0;
    int y0;
    int x1;
    int y1;
};

BoundingBox getBoundingBox(int featureVector){
    constexpr int X_WIDTH = ceil(log2(WIDTH));
    constexpr int Y_WIDTH = ceil(log2(HEIGHT));
    constexpr int X_MASK = pow(2, X_WIDTH) - 1;
    constexpr int Y_MASK = pow(2, Y_WIDTH) - 1;
    // feature vec: bounding box (min X, max X, min Y and max Y coordinates)
    BoundingBox bb;
    bb.x0 = (featureVector >> (X_WIDTH + Y_WIDTH + Y_WIDTH)) && X_MASK;
    bb.x1 = (featureVector >> (Y_WIDTH + Y_WIDTH)) && X_MASK;
    bb.y0 = (featureVector >> (Y_WIDTH)) && Y_MASK;
    bb.y1 = featureVector && Y_MASK;
    return bb;
}

int main(int argc, char** argv, char** env){
    Vpipeline dut;
    Verilated::traceEverOn(true);
    VerilatedVcdC m_trace;
    dut.trace(&m_trace, 5);
    m_trace.open("waveform.vcd");
    vluint64_t sim_time = 0;

    // test valid
    reset(dut, dut.reset, dut.clock, m_trace, sim_time, RESET_CHECKS);
    run(dut, dut.clock, m_trace, sim_time, LINES_PER_FRAME * PCLK_PER_LINE * CLOCK_PER_PCLK);

    //auto bb = getBoundingBox(52953169);
    //std::cout << "x0: " << bb.x0 << " x1: " << bb.x1 << " y0: " << bb.y0 << " y1: " << bb.y1 << std::endl;

    m_trace.close();
    exit(EXIT_SUCCESS);
}