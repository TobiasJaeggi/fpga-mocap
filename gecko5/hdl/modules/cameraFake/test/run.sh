#!/bin/bash
# This script is used to run the test for the ov7670Fake module.
# Usage: run.sh [-g]
#   -g: Enable graphical output

while getopts "gh" opt; do
    case $opt in
        g)
            GTKWAVE=1
            ;;
        h)
            echo "Usage: run.sh [-g]"
            echo "  -g: Show simulation output in gtkwave"
            echo "  -h: Show this help message"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            ;;
    esac
done

FILENAME="ov7670Fake"
INCLUDES=""
# run verilator
verilator -Wall --trace -cc ../verilog/$FILENAME.v --exe tb_$FILENAME.cpp -I $INCLUDES
ret=$?
if [ $ret -ne 0 ]; then
    echo "verilator failed"
    exit 1
fi

# build test bench
make -C obj_dir -f V$FILENAME.mk V$FILENAME
ret=$?
if [ $ret -ne 0 ]; then
    echo "make failed"
    exit 2
fi

# run test bench
./obj_dir/V$FILENAME
ret=$?
if [ $ret -ne 0 ]; then
    echo "Test bench failed with code $ret"
else
    echo "Test bench passed with code $ret"
fi

# show waveform
if [ $GTKWAVE ]; then
    gtkwave waveform.vcd >/dev/null 2>&1 & 
    ret=$?
    if [ $ret -ne 0 ]; then
        echo "gtk failed"
        exit 3
    fi
fi
