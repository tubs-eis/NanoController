## Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


SHELL := /bin/bash

#################################################
# 01. VHDL-Design Verification
#################################################
sim-hdl:
	@echo "Starting VHDL verification ..."
	cd "../asm" && ./axasm -p nano -c -o ../sim/systemc/include/imem_image.h ../sw/lockctrl.asm
	@source init_tools; vsim -c -do "source scr/simulate.tcl; start -O:simulate; quit -f"
	
clean-sim:
	@source init_tools; vsim -c -do "source scr/simulate.tcl; start -O:clean; quit -f"
	rm -f transcript
	rm -f vsim.wlf
