#include <stdlib.h>
#include <iostream>
#include <verilated.h>
#include <verilated_vcd_c.h>
#include "VintCounter.h"

vluint64_t sim_time = 0;

void run(VintCounter& dut, VerilatedVcdC& m_trace, vluint64_t steps=1) {
    vluint64_t sim_time_before_run {sim_time};
    while (sim_time < (sim_time_before_run + steps)) {
        dut.clock ^= 1;
        dut.eval();
        m_trace.dump(sim_time);
        sim_time++;
    }
    
}
int main(int argc, char** argv, char** env) {
    VintCounter dut;
    Verilated::traceEverOn(true);
    VerilatedVcdC m_trace;
    dut.trace(&m_trace, 5);
    m_trace.open("waveform.vcd");

    dut.enable = 1;
    dut.reset = 1;
    run(dut, m_trace);
    dut.reset = 0;
 
    run(dut, m_trace, 11);

    run(dut, m_trace, 40);

    dut.reset = 1;
    run(dut, m_trace, 3);
    dut.reset = 0;
    
    run(dut, m_trace, 5);

    dut.clear = 1;
    run(dut, m_trace, 2);
    dut.clear = 0;

    dut.load = 1;
    dut.din = 5;
    run(dut, m_trace, 2);
    dut.load = 0;

    run(dut, m_trace, 5);

    dut.reset = 1;
    run(dut, m_trace, 2);
    dut.reset = 0;

    run(dut, m_trace, 40);

    dut.clear = 1;
    run(dut, m_trace, 2);
    dut.enable = 0;
    run(dut, m_trace, 5);
   

    m_trace.close();

    exit(EXIT_SUCCESS);
}