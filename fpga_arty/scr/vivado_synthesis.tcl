## Copyright (c) 2024 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


# Run this script to create the Vivado project files in ../syn from this script
# If ::create_path global variable is set, the project is created under that path instead of the working dir

# Project specific settings. These must be updated for each project.
set part "xc7a35ticsg324-1L"
set brd_part "digilentinc.com:arty-a7-35:part0:1.1"

# default command - create project only (project | compile)
set syn_cmd "project"

# command line parsing
for {set i 0} {$i < $argc} {incr i} {
  if { [string match "C:*" [lindex $argv $i]] == 1 } {
    set syn_cmd [lindex $argv $i]
    set syn_cmd [string range ${syn_cmd} 2 [string length ${syn_cmd}]]
  }
}

if {[info exists ::create_path]} {
        set dest_dir $::create_path
} else {
  set dest_dir [file dirname [info script]]
  append dest_dir "/../syn"
        set dest_dir [file normalize $dest_dir]
}

if {![file isdirectory $dest_dir]} {
    puts "-N- Creating $dest_dir"
    file mkdir $dest_dir
}
cd $dest_dir

# get sources & project settings from project.tcl
source ../scr/project.tcl
set proj_name $project(name)

if { [string compare $syn_cmd "project"] == 0} {
  # Create project
  puts "-N- Creating new project in $dest_dir"
  create_project $proj_name $dest_dir

  # Set the directory path for the new project
  set proj_dir [get_property directory [current_project]]

  # Set project properties
  set obj [get_projects $proj_name]
  set_property "default_lib" "xil_defaultlib" $obj
  set_property "part" $part $obj
  set_property "board_part" $brd_part $obj
  set_property "simulator_language" "Mixed" $obj
  set_property "target_language" "VHDL" $obj

  # Create 'sources_1' fileset (if not found)
  if {[string equal [get_filesets -quiet sources_1] ""]} {
    create_fileset -srcset sources_1
  }

  # Create 'constrs_1' fileset (if not found)
  if {[string equal [get_filesets -quiet constrs_1] ""]} {
    create_fileset -constrset constrs_1
  }

  # add source files
  puts ""
  foreach idname [array names libraries "*,id"] {
    # get library id
    set lib_id   $libraries($idname)
    if {$libraries($lib_id,sim)} {
      continue
    }
    foreach fname $libraries($lib_id,files) {
      #set src_file [file normalize $fname]
      set src_file $fname
      # add source file to project
      add_files -quiet $src_file
      set obj [get_files $src_file]
      set_property "library" "$libraries($lib_id,name)" $obj
    }
  }

  # get top level hdl file
  puts ""
  foreach idname [array names libraries "*,id"] {
    set lib_id   $libraries($idname)
    foreach fname $libraries($lib_id,files) {
      if {[string match "*/$project(syn_top).*" $fname]} {
        puts "-N- found toplevel hdl file: $fname"
        set top_file $fname
      }
    }
  }

  # copy and add constraint file if file exists
  puts ""
  if { [file exists ${project(xil_pins)}] } {
    # copy xdc file
    set xdc_file "${project(name)}.xdc"
    puts "-N- copy constraint file $project(xil_pins) to ${xdc_file}"
    file copy -force ${project(xil_pins)} ${xdc_file}
    puts "-N- add constraint file: $xdc_file"
    add_files -fileset constrs_1 -quiet $xdc_file
  } else {
    puts "-E- constraint file missing: $project(xil_pins)"
  }

  # set synthesis options if file exists
  puts ""
  if { [file exists $project(xil_opts)] } {
    puts "-N- set synthesis options from $project(xil_opts)"
    source $project(xil_opts)
  } else {
    puts "-E- synthesis option file missing: $project(xil_opts)"
  }

  # set top level entity
  set obj [get_filesets sources_1]
  set_property "top" "$project(syn_top)" $obj

  # generate IP if file exists
  puts ""
  if { [file exists $project(xil_ip_gen)] } {
    puts "-N- generate IP from $project(xil_ip_gen)"
    source $project(xil_ip_gen)
  } else {
    puts "-E- generate IP file missing: $project(xil_ip_gen)"
  }

  puts "-N- Project created: $proj_name"
}

if { [string compare $syn_cmd "compile"] == 0} {
  open_project ${proj_name}.xpr
  reset_run synth_1
  reset_run impl_1
  update_compile_order -fileset sources_1
  
  # run synthesis
  if { [file exists $project(xil_ip_syn)] } {
    source $project(xil_ip_syn)
  }
  launch_runs synth_1 -jobs 8
  wait_on_run synth_1

  # run implementation
  launch_runs impl_1 -jobs 8
  wait_on_run impl_1

  # run bitfile generator 
  launch_runs impl_1 -to_step write_bitstream -jobs 8
  wait_on_run impl_1
  open_run impl_1
  report_utilization -hierarchical  -file [file normalize "$dest_dir/utilization_hier.rpt"] 
}

if { [string compare $syn_cmd "program"] == 0} {
  open_project ${proj_name}.xpr
  
  open_hw
  connect_hw_server
  open_hw_target
  current_hw_device [get_hw_devices xc7a35t_0]
  refresh_hw_device -update_hw_probes false [lindex [get_hw_devices xc7a35t_0] 0]
  set_property PROBES.FILE {} [get_hw_devices xc7a35t_0]
  set_property FULL_PROBES.FILE {} [get_hw_devices xc7a35t_0]
  set_property PROGRAM.FILE [file normalize "$dest_dir/${proj_name}.runs/impl_1/${project(syn_top)}.bit"] [get_hw_devices xc7a35t_0]
  program_hw_devices [get_hw_devices xc7a35t_0]
  refresh_hw_device [lindex [get_hw_devices xc7a35t_0] 0]
  disconnect_hw_server
}

# Close project
close_project
