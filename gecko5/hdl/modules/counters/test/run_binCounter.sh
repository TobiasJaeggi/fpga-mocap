#!/bin/bash
FILENAME="binCounter"
verilator -Wall --trace -cc ../verilog/$FILENAME.v --exe tb_$FILENAME.cpp
ret=$?
if [ $ret -ne 0 ]; then
    echo "verilator failed"
    exit 1
fi
make -C obj_dir -f V$FILENAME.mk V$FILENAME
ret=$?
if [ $ret -ne 0 ]; then
    echo "make failed"
    exit 2
fi
./obj_dir/V$FILENAME
gtkwave waveform.vcd >/dev/null 2>&1 & 
ret=$?
if [ $ret -ne 0 ]; then
    echo "gtk failed"
    exit 3
fi