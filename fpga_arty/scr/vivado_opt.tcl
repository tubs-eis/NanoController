## Copyright (c) 2024 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part $part -flow {Vivado Synthesis 2021} -strategy "Vivado Synthesis Defaults" -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2021" [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property "part" $part $obj
set_property "steps.synth_design.args.flatten_hierarchy" "none" $obj
set_property "steps.synth_design.args.directive" "RuntimeOptimized" $obj
set_property "steps.synth_design.args.fsm_extraction" "off" $obj

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part $part -flow {Vivado Implementation 2021} -strategy "Vivado Implementation Defaults" -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2021" [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property "part" $part $obj
set_property "steps.opt_design.args.directive" "RuntimeOptimized" $obj
set_property "steps.place_design.args.directive" "RuntimeOptimized" $obj
set_property "steps.route_design.args.directive" "RuntimeOptimized" $obj

# set the current impl run
current_run -implementation [get_runs impl_1]
