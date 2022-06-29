## Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
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

proc start {args} {
  variable operation

  set operation "compile"
  echo $args

  # parse arguments for test number
  foreach arg $args {
    if { [string compare -length 1 $arg "-"] == 0 } {
      if { [string match "-O:*" $arg] == 1 } {
        set operation $arg
        set operation [string range $operation 3 [string length $operation]]
      }
    }
  }

  ## start selected operation
  if { [string match "compile" $operation] } {
    sim_compile
  } elseif { [string match "simulate" $operation] } {
    sim_start_sim
  } elseif { [string match "clean" $operation] } {
    sim_clean
  }
}

### Compile sources
proc sim_compile {} {
  
  # create & map libraries
  puts "-N- create library nano"
  vlib nano
  vmap nano
  puts "-N- create library top_level"
  vlib top_level
  vmap top_level
  puts "-N- create library testbench"
  vlib testbench
  vmap testbench
  
  eval vcom -quiet -work top_level -check_synthesis ../rtl/top_level/clkgate.behav.vhdl
  
  # compile source files for library nano
  puts "-N- compile library nano"
  eval vcom -quiet -work nano -check_synthesis ../rtl/pkg/aux.pkg.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/pkg/func.pkg.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/pkg/nano.pkg.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/pkg/nano_rom_image.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/nano/func_rtc.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/nano/nano_ctrl.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/nano/nano_dmem.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/nano/nano_dp.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/nano/nano_imem.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/nano/nano_imem.arch.scm.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/nano/nano_logic.vhdl
  eval vcom -quiet -work nano -check_synthesis ../rtl/nano/nano_memory.vhdl
  
  # compile source files for library testbench
  puts "-N- compile library testbench"
  foreach fileNameEntry [findFiles "./systemc" "*.c*"] {
    eval sccom -work testbench $fileNameEntry
  }
  eval sccom -link -work testbench
  
}

### start simulation
proc sim_start_sim {} {
  
  # run modelsim compile
  sim_compile

  # start simulation
  eval vsim -t ps -L top_level -L nano -voptargs=+acc +notimingchecks -do {"set StdArithNoWarnings 1; set NumericStdNoWarnings 1"} testbench.SYSTEM

  # run the simulation
  run -all
  quit -sim
  
}

### clean Modelsim project
proc sim_clean {} {
  
  puts "-N- remove library directory nano"
  file delete -force nano
  puts "-N- remove library directory top_level"
  file delete -force top_level
  puts "-N- remove library directory testbench"
  file delete -force testbench
  
}
