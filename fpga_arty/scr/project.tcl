## Copyright (c) 2024 Chair for Chip Design for Embedded Computing,
##                    Technische Universitaet Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.


# findFiles
# basedir - the directory to start looking in
# pattern - A pattern, as defined by the glob command, that the files must match
proc findFiles { basedir pattern } {

  # Fix the directory name, this ensures the directory name is in the
  # native format for the platform and contains a final directory seperator
  set basedir [string trimright [file join [file normalize $basedir] { }]]
  set fileList {}

  # Look in the current directory for matching files, -type {f r}
  # means ony readable normal files are looked at, -nocomplain stops
  # an error being thrown if the returned list is empty
  foreach fileName [glob -nocomplain -type {f r} -path $basedir $pattern] {
    lappend fileList $fileName
  }

  # Now look for any sub direcories in the current directory
  foreach dirName [glob -nocomplain -type {d  r} -path $basedir *] {
    # Recusively call the routine on the sub directory and append any
    # new files to the results
    set subDirList [findFiles $dirName $pattern]
    if { [llength $subDirList] > 0 } {
      foreach subDirFile $subDirList {
        lappend fileList $subDirFile
      }
    }
  }
  return $fileList
}


########################################################################

global project libraries
set idx 0

### define project config
set project(name)       "sys"
set project(xil_pins)   "../scr/Arty-Master.xdc"
set project(xil_opts)   "../scr/vivado_opt.tcl"
set project(xil_ip_gen) "../scr/vivado_ip_gen.tcl"
set project(xil_ip_syn) "../scr/vivado_ip_syn.tcl"
set project(syn_top)    "sys_top_emu"


### library nano
set libraries(${idx},name) "nano"
set libraries(${idx},id) ${idx}
set libraries(${idx},sim) 0
lappend libraries(${idx},files) "../../rtl/pkg/aux.pkg.vhdl"
lappend libraries(${idx},files) "../../rtl/pkg/func.pkg.vhdl"
lappend libraries(${idx},files) "../../rtl/pkg/nano.pkg.vhdl"
lappend libraries(${idx},files) "../../rtl/pkg/nano_rom_image.vhdl"
lappend libraries(${idx},files) "../../rtl/nano/func_rtc.vhdl"
lappend libraries(${idx},files) "../../rtl/nano/nano_ctrl.vhdl"
lappend libraries(${idx},files) "../../rtl/nano/nano_dmem.arty.vhdl"
lappend libraries(${idx},files) "../../rtl/nano/nano_dp.vhdl"
lappend libraries(${idx},files) "../../rtl/nano/nano_imem.vhdl"
lappend libraries(${idx},files) "../../rtl/nano/nano_imem.arch.arty.vhdl"
lappend libraries(${idx},files) "../../rtl/nano/nano_logic.vhdl"
#foreach fileNameEntry [findFiles "../../rtl/nano" "*.vhd*"] {
#  lappend libraries(${idx},files) $fileNameEntry
#}


### library module top_level
incr idx
set libraries(${idx},name) "top_level"
set libraries(${idx},id)  ${idx}
set libraries(${idx},sim) 0
lappend libraries(${idx},files) "../../rtl/top_level/nano_top.vhdl"
lappend libraries(${idx},files) "../../rtl/top_level/sys_top_emu.arty.vhdl"

