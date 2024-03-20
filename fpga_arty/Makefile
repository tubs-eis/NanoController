## Copyright (c) 2024 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


SHELL := /bin/bash

.PHONY: all fpga_prj fpga fpga_pgm run_gui clean_syn clean clean_logs


all: clean fpga_prj fpga
        
fpga_prj: 
	cd "../asm" && ./axasm -p nano -v -o ../fpga_arty/imem_image.img ../sw/lockctrl.asm
	source init_tools; LC_NUMERIC=C vivado -mode batch -notrace -source ./scr/vivado_synthesis.tcl -tclargs C:project | GREP_COLOR='01;33' grep -iE --line-buffered --color=always '|warning' | GREP_COLOR='01;31' grep -iE --line-buffered --color=always '|error'
        
fpga:
	source init_tools; LC_NUMERIC=C vivado -mode batch -notrace -source ./scr/vivado_synthesis.tcl -tclargs C:compile | GREP_COLOR='01;33' grep -iE --line-buffered --color=always '|warning' | GREP_COLOR='01;31' grep -iE --line-buffered --color=always '|error'

fpga_pgm:
	source init_tools; LC_NUMERIC=C vivado -mode batch -notrace -source ./scr/vivado_synthesis.tcl -tclargs C:program | GREP_COLOR='01;33' grep -iE --line-buffered --color=always '|warning' | GREP_COLOR='01;31' grep -iE --line-buffered --color=always '|error'

run_gui:
	source init_tools; cd syn && LC_NUMERIC=C vivado sys.xpr

clean_syn:
	rm -rf ./syn || true
        
clean: clean_syn

clean_logs: 
	rm *.jou *.log || true

