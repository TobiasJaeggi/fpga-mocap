#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vov7670Fake.h"

vluint64_t sim_time = 0;
static constexpr uint64_t PCLK_DIVIDER{4U};
static constexpr uint64_t PCLK_PER_PIXEL{2U};
static constexpr uint64_t CLK_PER_PIXEL{PCLK_DIVIDER*PCLK_PER_PIXEL};
static constexpr uint64_t APPROX_CLK_OVERHEAD_PER_FRAME{5000U};

static constexpr uint64_t FRAME_WIDTH{640U};
static constexpr uint64_t FRAME_HEIGHT{480U};
static constexpr uint64_t FRAME_SIZE{FRAME_WIDTH*FRAME_HEIGHT};

void run(Vov7670Fake& dut, VerilatedVcdC& m_trace, vluint64_t steps=1) {
    vluint64_t sim_time_before_run {sim_time};
    while (sim_time < (sim_time_before_run + steps)) {
        dut.clock ^= 1;
        dut.eval();
        m_trace.dump(sim_time);
        sim_time++;
    }
    
}
int main(int argc, char** argv, char** env) {
    Vov7670Fake dut;
    Verilated::traceEverOn(true);
    VerilatedVcdC m_trace;
    dut.trace(&m_trace, 5);
    m_trace.open("waveform.vcd");
    
    dut.reset = 1;
    run(dut, m_trace,2);
    dut.reset = 0;

    run(dut, m_trace, (FRAME_SIZE*CLK_PER_PIXEL+APPROX_CLK_OVERHEAD_PER_FRAME)*2*5); // TODO: no magic numbers please

    run(dut, m_trace,10); // some extra pixels

    dut.reset = 1;
    run(dut, m_trace, 2);
    dut.reset = 0;
    
    run(dut, m_trace, 40); // some extra pixels to check after reset

    m_trace.close();
    exit(EXIT_SUCCESS);
}