## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


SIM_GENERICS ?= -ggoldenref="../rtc/goldenref" -gdutfiles="../rtc/goldenref" -gSIZE_CLUT=21 -gSIZE_SCHG=16 -gSIZE_IMEM=128

SHELL := /bin/bash

export SIM_GENERICS := $(SIM_GENERICS)

#################################################
# 01. VHDL-Design Verification
#################################################
sim-hdl:
	@echo "Starting VHDL verification ..."
	@source init_tools; vsim -c -do "source scr/simulate.tcl; start -O:simulate; quit -f"

sim-hdl-gui:
	@echo "Starting VHDL verification ..."
	@source init_tools; vsim -do "source scr/simulate.tcl; start -O:simulate"
	
clean-sim:
	@source init_tools; vsim -c -do "source scr/simulate.tcl; start -O:clean; quit -f"
	rm -f transcript
	rm -f vsim.wlf
