## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


# Generate init file content procedure (Verilog init input)
proc genInitFile {out_ptr in_ptr} {
  set in_data [read $in_ptr]
  set in_data [split $in_data "\n"]
  puts $out_ptr "memory_initialization_radix=16;"
  puts $out_ptr "memory_initialization_vector="
  foreach in_line $in_data {
    set in_line [split [string trim $in_line]]
    foreach word $in_line {
      if {[string index $word 0] != "@"} {
        puts $out_ptr "$word"
      }
    }
  }
  puts $out_ptr ";"
}

# Create memory initialization files
foreach fileNameEntry [findFiles "$dest_dir/.." "*.img"] {
  set fileRoot [file rootname [file tail $fileNameEntry]]
  set out_ptr [open "$dest_dir/$fileRoot.coe" "w"]
  set in_ptr [open $fileNameEntry "r"]
  genInitFile $out_ptr $in_ptr
  close $in_ptr
  close $out_ptr
}

# Create Memory IP
create_ip -name dist_mem_gen -vendor xilinx.com -library ip -version 8.0 -module_name main
set_property -dict [list CONFIG.coefficient_file [file normalize "$dest_dir/imem_image.coe"] CONFIG.data_width {9} CONFIG.depth {256} CONFIG.input_clock_enable {true} CONFIG.input_options {registered}] [get_ips main]
generate_target {instantiation_template} [get_files [file normalize "$dest_dir/${proj_name}.srcs/sources_1/ip/main/main.xci"]]
generate_target all [get_files [file normalize "$dest_dir/${proj_name}.srcs/sources_1/ip/main/main.xci"]]
catch { config_ip_cache -export [get_ips -all main] }
export_ip_user_files -of_objects [get_files [file normalize "$dest_dir/${proj_name}.srcs/sources_1/ip/main/main.xci"]] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] [file normalize "$dest_dir/${proj_name}.srcs/sources_1/ip/main/main.xci"]]

# Create PLL IP
create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name arty_pll
set_property -dict [list CONFIG.PRIMITIVE {PLL} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {8}] [get_ips arty_pll]
generate_target {instantiation_template} [get_files [file normalize "$dest_dir/${proj_name}.srcs/sources_1/ip/arty_pll/arty_pll.xci"]]
generate_target all [get_files  [file normalize "$dest_dir/${proj_name}.srcs/sources_1/ip/arty_pll/arty_pll.xci"]]
catch { config_ip_cache -export [get_ips -all arty_pll] }
export_ip_user_files -of_objects [get_files [file normalize "$dest_dir/${proj_name}.srcs/sources_1/ip/arty_pll/arty_pll.xci"]] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] [file normalize "$dest_dir/${proj_name}.srcs/sources_1/ip/arty_pll/arty_pll.xci"]]
