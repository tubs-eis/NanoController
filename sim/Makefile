## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
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
	@echo "Starting VHDL verification (Testcase 1: lockctrl_alt)..."
	#cd "../asm" && ./axasm -p nano -v -o ../sim/img/lockctrl_alt.mem ../sw/lockctrl_alt.asm
	source init_tools; export SIM_GENERICS=-gapp_prefix=\"img/lockctrl_alt\"; vsim -c -do "source scr/simulate.tcl; start -O:simulate; quit -f"
	@echo "Starting VHDL verification (Testcase 2: lockctrl)..."
	#cd "../asm" && ./axasm -p nano -v -o ../sim/img/lockctrl.mem ../sw/lockctrl.asm
	source init_tools; export SIM_GENERICS=-gapp_prefix=\"img/lockctrl\"; vsim -c -do "source scr/simulate.tcl; start -O:simulate; quit -f"
	@echo "Starting VHDL verification (Testcase 3: glsens)..."
	#cd "../asm" && ./axasm -p nano -v -o ../sim/img/glsens.mem ../sw/glsens.asm
	source init_tools; export SIM_GENERICS=-gapp_prefix=\"img/glsens\"; vsim -c -do "source scr/simulate.tcl; start -O:simulate; quit -f"
	@echo "Starting VHDL verification (Testcase 4: meas_lockctrl_alt)..."
	#cd "../asm" && ./axasm -p nano -v -o ../sim/img/meas_lockctrl_alt.mem ../sw/meas_lockctrl_alt.asm
	source init_tools; export SIM_GENERICS=-gapp_prefix=\"img/meas_lockctrl_alt\"; vsim -c -do "source scr/simulate.tcl; start -O:simulate; quit -f"
	@echo "Starting VHDL verification (Testcase 5: meas_lockctrl)..."
	#cd "../asm" && ./axasm -p nano -v -o ../sim/img/meas_lockctrl.mem ../sw/meas_lockctrl.asm
	source init_tools; export SIM_GENERICS=-gapp_prefix=\"img/meas_lockctrl\"; vsim -c -do "source scr/simulate.tcl; start -O:simulate; quit -f"
	@echo "Starting VHDL verification (Testcase 6: meas_glsens)..."
	#cd "../asm" && ./axasm -p nano -v -o ../sim/img/meas_glsens.mem ../sw/meas_glsens.asm
	source init_tools; export SIM_GENERICS=-gapp_prefix=\"img/meas_glsens\"; vsim -c -do "source scr/simulate.tcl; start -O:simulate; quit -f"
	
clean-sim:
	@source init_tools; vsim -c -do "source scr/simulate.tcl; start -O:clean; quit -f"
	rm -f transcript
	rm -f vsim.wlf
