
#ifndef SIMUTILS_H
#define SIMUTILS_H

#include <verilated.h>

// custom assert handler based on reply of Eugene Magdalits https://stackoverflow.com/questions/3692954/add-custom-messages-in-assert
#define ASSERT(Expr, Trace) \
    customAssert(#Expr, Expr, __FILE__, __LINE__, Trace)

#define ASSERT_FL(Expr, Trace, File, Line) \
    customAssert(#Expr, Expr, File, Line, Trace)

void customAssert(const char* expr_str, bool expr, const char* file, int line, VerilatedVcdC& m_trace){
    if (!expr){
        std::cerr << "Assert failed:\t"
            << "Expected:\t" << expr_str << "\n"
            << "Source:\t\t" << file << ", line " << line << "\n";
        m_trace.close();
        exit(EXIT_FAILURE);
    }
}

/**
 *  \brief run the simulation for a number of steps, optionally run check at each step.
 *  \param DUT device under test
 *  \param clock clock signal
 *  \param m_trace trace file
 *  \param sim_time simulation time
 *  \param steps number of steps to run
 *  \param check function to run at each step
 *  \return void
 */
template <typename DUT>
void run(DUT& dut, CData& clock, VerilatedVcdC& m_trace, vluint64_t& sim_time, vluint64_t steps=1, std::function<void()> check=[]()->void{}){
    vluint64_t sim_time_before_run {sim_time};
    while (sim_time < (sim_time_before_run + steps)) {
        clock ^= 1;
        dut.eval();
        sim_time++;
        m_trace.dump(sim_time);
        check();
    }   
}

/**
 *  \brief reset the DUT, optionally run check after the reset.
 *  \param DUT device under test
 *  \param m_trace trace file
 *  \param sim_time simulation time
 *  \param check function to after reset
 *  \return void
 */
template <typename DUT>
void reset(DUT& dut, CData& reset, CData& clock, VerilatedVcdC& m_trace, vluint64_t& sim_time, std::function<void()> check=[]()->void{}){
    reset = 1;
    run(dut, clock, m_trace, sim_time, 1);
    reset = 0;
    run(dut, clock, m_trace, sim_time, 1);
    check();
}
#endif // SIMUTILS_H

