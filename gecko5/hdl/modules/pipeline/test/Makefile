DUT=pipeline
SOURCE=../verilog/$(DUT).v
INCLUDES=\
../../binarize/verilog/*.v\
../../cca/verilog/*.v\
../../doubleBuffer/verilog/*.v\
../../edgeDetect/verilog/*.v\
../../featureTransferSpi/verilog/*.v\
../../ov7670Fake/verilog/*.v\
../../spi_master/Verilog/source/SPI_Master.v\
../../support/verilog/synchroFlop.v\
../../waitForTransfer/verilog/*.v\
../../triggerReset/verilog/*.v\

.PHONY:sim
sim: waveform.vcd

.PHONY:verilate
verilate: .stamp.verilate

.PHONY:build
build: obj_dir/Valu

.PHONY:waves
waves: waveform.vcd
	@echo
	@echo "### WAVES ###"
	gtkwave waveform.vcd

waveform.vcd: ./obj_dir/V$(DUT)
	@echo
	@echo "### SIMULATING ###"
	@./obj_dir/V$(DUT)

./obj_dir/V$(DUT): .stamp.verilate
	@echo
	@echo "### BUILDING SIM ###"
	make -C obj_dir -f V$(DUT).mk V$(DUT)

.stamp.verilate: $(SOURCE) tb_$(DUT).cpp
	@echo
	@echo "### VERILATING ###"
	verilator -Wall --trace -cc $(SOURCE) --exe tb_$(DUT).cpp -I $(INCLUDES)
	@touch .stamp.verilate

.PHONY:lint
lint: $(SOURCE)
	verilator --lint-only $(SOURCE) -I $(INCLUDES) --relative-includes 
	verilator --lint-only tb_$(DUT).v -I $(SOURCE) $(INCLUDES) --top-module tb_$(DUT) --timing --relative-includes 

.PHONY:vvp
vvp: $(SOURCE)
	iverilog -o $(DUT).vvp $(SOURCE) $(INCLUDES) tb_$(DUT).v -g2005-sv -Wall
	vvp $(DUT).vvp

.PHONY: clean
clean:
	rm -rf .stamp.*;
	rm -rf ./obj_dir
	rm -rf waveform.vcd
