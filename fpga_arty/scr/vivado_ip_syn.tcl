## Copyright (c) 2024 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


reset_run main_synth_1
reset_run arty_pll_synth_1

launch_runs -jobs 4 main_synth_1
export_simulation -of_objects [get_files [file normalize "$dest_dir/${proj_name}.srcs/sources_1/ip/main/main.xci"]] -directory [file normalize "$dest_dir/${proj_name}.ip_user_files/sim_scripts"] -ip_user_files_dir [file normalize "$dest_dir/${proj_name}.ip_user_files"] -ipstatic_source_dir [file normalize "$dest_dir/${proj_name}.ip_user_files/ipstatic"] -lib_map_path [list modelsim=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/modelsim"] questa=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/questa"] ies=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/ies"] xcelium=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/xcelium"] vcs=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/vcs"] riviera=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/riviera"]] -use_ip_compiled_libs -force -quiet

launch_runs -jobs 4 arty_pll_synth_1
export_simulation -of_objects [get_files [file normalize "$dest_dir/${proj_name}.srcs/sources_1/ip/arty_pll/arty_pll.xci"]] -directory [file normalize "$dest_dir/${proj_name}.ip_user_files/sim_scripts"] -ip_user_files_dir [file normalize "$dest_dir/${proj_name}.ip_user_files"] -ipstatic_source_dir [file normalize "$dest_dir/${proj_name}.ip_user_files/ipstatic"] -lib_map_path [list modelsim=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/modelsim"] questa=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/questa"] ies=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/ies"] xcelium=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/xcelium"] vcs=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/vcs"] riviera=[file normalize "$dest_dir/${proj_name}.cache/compile_simlib/riviera"]] -use_ip_compiled_libs -force -quiet

wait_on_run main_synth_1
wait_on_run arty_pll_synth_1
