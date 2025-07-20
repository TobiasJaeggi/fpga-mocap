#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vbinarize.h"
#include "Vbinarize_binarize.h"
#include "../../test/simUtils.h"

#define RESET_CHECKS [&dut, & m_trace](){ \
    ASSERT(dut.valid == 0, m_trace); \
}

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

int main(int argc, char** argv, char** env){
    Vbinarize dut;
    Verilated::traceEverOn(true);
    VerilatedVcdC m_trace;
    dut.trace(&m_trace, 5);
    m_trace.open("waveform.vcd");
    vluint64_t sim_time = 0;
    run(dut, dut.pclk, m_trace, sim_time, 2);

    // test byte index
    reset(dut, dut.reset, dut.pclk, m_trace, sim_time, RESET_CHECKS);
    for(int i = 0; i < 3; i++){
        dut.href = 1;
        for(int j = 0; j < 10; j++){
            run(dut, dut.pclk, m_trace, sim_time, 2, [&dut, &m_trace]()->void{ASSERT(dut.binarize->byteIndex == 0, m_trace);});
            run(dut, dut.pclk, m_trace, sim_time, 2, [&dut, &m_trace]()->void{ASSERT(dut.binarize->byteIndex == 1, m_trace);});

        }
        dut.href = 0;
        run(dut, dut.pclk, m_trace, sim_time, 4);
    }

    reset(dut, dut.reset, dut.pclk, m_trace, sim_time, RESET_CHECKS);
    for(int i = 0; i < 3; i++){
        dut.href = 1;
        for(int j = 0; j < 8; j++){
            run(dut, dut.pclk, m_trace, sim_time, 2, [&dut, &m_trace]()->void{ASSERT(dut.binarize->byteIndex == 0, m_trace);});
            run(dut, dut.pclk, m_trace, sim_time, 2, [&dut, &m_trace]()->void{ASSERT(dut.binarize->byteIndex == 1, m_trace);});

        }
        dut.href = 0;
        run(dut, dut.pclk, m_trace, sim_time, 2);
    }

    reset(dut, dut.reset, dut.pclk, m_trace, sim_time, RESET_CHECKS);
    for(int i = 0; i < 3; i++){
        dut.href = 1;
        run(dut, dut.pclk, m_trace, sim_time, 2, [&dut, &m_trace]()->void{ASSERT(dut.binarize->byteIndex == 0, m_trace);});
        dut.href = 0;
        run(dut, dut.pclk, m_trace, sim_time, 2);
    }

    // test valid 1
    reset(dut, dut.reset, dut.pclk, m_trace, sim_time, RESET_CHECKS);
    dut.href = 1;
    run(dut, dut.pclk, m_trace, sim_time, 4, [&dut, &m_trace]()->void{ASSERT(dut.valid == 0, m_trace);}); // clock first full pixel, valid delayed by 1 cloclk cycle
    for(int i = 0; i < 5; i++){
        run(dut, dut.pclk, m_trace, sim_time, 2, [&dut, &m_trace]()->void{ASSERT(dut.valid == 1, m_trace);});
        run(dut, dut.pclk, m_trace, sim_time, 2, [&dut, &m_trace]()->void{ASSERT(dut.valid == 0, m_trace);});
    }
    dut.href = 0;
    run(dut, dut.pclk, m_trace, sim_time, 2, [&dut, &m_trace]()->void{ASSERT(dut.valid == 1, m_trace);});
    run(dut, dut.pclk, m_trace, sim_time, 2, [&dut, &m_trace]()->void{ASSERT(dut.valid == 0, m_trace);});

    // test rgb565 pixel
    int8_t pixel = 0x00;
    int8_t pixel_old = 0x00;
    reset(dut, dut.reset, dut.pclk, m_trace, sim_time, RESET_CHECKS);
    dut.href = 1;
    for(int j = 0; j < 10; j++){
        ASSERT(dut.binarize->rgb565Pixel == ((pixel_old << 8) + pixel), m_trace);
        dut.camData=pixel;
        run(dut, dut.pclk, m_trace, sim_time, 2);
        pixel_old = pixel;
    }
    dut.href = 0;

    // test over threshold 1
    reset(dut, dut.reset, dut.pclk, m_trace, sim_time, RESET_CHECKS);
    dut.href = 1;
    dut.threshold = rgb565ToGrayscale(rgb565(0b00111, 0b000111, 0b00111));
    pixel = rgb565(0b01111, 0b101111, 0b11111);
    dut.camData = (pixel >> 8) & 0xFF;
    run(dut, dut.pclk, m_trace, sim_time, 2); // clock in first byte
    dut.camData = (pixel >> 0) & 0xFF;
    run(dut, dut.pclk, m_trace, sim_time, 2); // clock in second byte
    ASSERT(dut.valid == 0, m_trace);
    // don't care about bin if valid is 0
    // output delayed by 1 clock cycle
    run(dut, dut.pclk, m_trace, sim_time, 2);
    ASSERT(dut.valid == 1, m_trace);
    ASSERT(dut.bin == 1, m_trace);
    dut.href = 0;


    // test over threshold 2
    reset(dut, dut.reset, dut.pclk, m_trace, sim_time, RESET_CHECKS);
    dut.href = 1;
    dut.threshold = rgb565ToGrayscale(rgb565(0b00001, 0b000001, 0b00001));
    pixel = rgb565(0b00011, 0b000101, 0b00110);
    dut.camData = (pixel >> 8) & 0xFF;
    run(dut, dut.pclk, m_trace, sim_time, 2); // clock in first byte
    dut.camData = (pixel >> 0) & 0xFF;
    run(dut, dut.pclk, m_trace, sim_time, 2); // clock in second byte
    ASSERT(dut.valid == 0, m_trace);
    // don't care about bin if valid is 0
    // output delayed by 1 clock cycle
    run(dut, dut.pclk, m_trace, sim_time, 2);
    ASSERT(dut.valid == 1, m_trace);
    ASSERT(dut.bin == 1, m_trace);
    dut.href = 0;

    // test under threshold 1
    reset(dut, dut.reset, dut.pclk, m_trace, sim_time, RESET_CHECKS);
    dut.href = 1;
    dut.threshold = rgb565ToGrayscale(rgb565(0b10000, 0b100000, 0b10000));
    pixel = rgb565(0b01111, 0b101111, 0b11111);
    dut.camData = (pixel >> 8) & 0xFF;
    run(dut, dut.pclk, m_trace, sim_time, 2); // clock in first byte
    dut.camData = (pixel >> 0) & 0xFF;
    run(dut, dut.pclk, m_trace, sim_time, 2); // clock in second byte
    ASSERT(dut.valid == 0, m_trace);
    // don't care about bin if valid is 0
    // output delayed by 1 clock cycle
    run(dut, dut.pclk, m_trace, sim_time, 2);
    ASSERT(dut.valid == 1, m_trace);
    ASSERT(dut.bin == 0, m_trace);
    dut.href = 0;

    // test under threshold 2
    reset(dut, dut.reset, dut.pclk, m_trace, sim_time, RESET_CHECKS);
    dut.href = 1;
    dut.threshold = rgb565ToGrayscale(rgb565(0b00111, 0b000111, 0b00111));
    pixel = rgb565(0b00011, 0b000011, 0b00010);
    dut.camData = (pixel >> 8) & 0xFF;
    run(dut, dut.pclk, m_trace, sim_time, 2); // clock in first byte
    dut.camData = (pixel >> 0) & 0xFF;
    run(dut, dut.pclk, m_trace, sim_time, 2); // clock in second byte
    ASSERT(dut.valid == 0, m_trace);
    // don't care about bin if valid is 0
    // output delayed by 1 clock cycle
    run(dut, dut.pclk, m_trace, sim_time, 2);
    ASSERT(dut.valid == 1, m_trace);
    ASSERT(dut.bin == 0, m_trace);
    dut.href = 0;


    // TODO: full frame test

    m_trace.close();
    exit(EXIT_SUCCESS);
}