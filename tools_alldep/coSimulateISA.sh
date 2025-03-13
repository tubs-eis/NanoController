#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

shopt -s extglob

bcdefs='define max(a,b){if(a>b){return(a)}else{return(b)}}'
dirname="$1_coSimulateISA"
synconf='syn_configs.csv'
tabconf='table_configs.csv'

errdir=`basename $(pwd)`

if [ -d "$1" ]; then
  
  mkdir -p $dirname
  echo "SIZE_CLUT,SIZE_SCHG,SIZE_IMEM,STEP_GROUPS_DUT" > $dirname/$synconf
  echo "idx,SIZE_CLUT,SIZE_SCHG,SIZE_IMEM,STEP_GROUPS_DUT" > $dirname/$tabconf
  
  for fname in $1/*.*.+(0).clut
  do
    isaname=`basename $fname | cut -d. -f 1`
    dutname=`basename $fname | cut -d. -f 1-2`
  
    for lutname in $1/$dutname.*.clut
    do
    
      lutidx=.`basename $lutname | cut -d. -f 3`
      echo "-N- SOLUTION $dutname$lutidx" > $dirname/$dutname$lutidx.log
      
      clutref=`expr $(cat $1/goldenref.clut | wc -w) - 1`
      schgref=`expr $(cat $1/goldenref.schg | wc -w) - 1`
      imemref=`expr $(cat $1/goldenref.mem | wc -w) - 1`
      echo "-N- REF: $clutref $schgref $imemref" >> $dirname/$dutname$lutidx.log
      
      clutdut=`expr $(cat $1/$dutname$lutidx.clut | wc -w) - 1`
      schgdut=`expr $(cat $1/$dutname$lutidx.schg | wc -w) - 1`
      imemdut=`expr $(cat $1/$dutname.mem | wc -w) - 1`
      echo "-N- DUT: $clutdut $schgdut $imemdut" >> $dirname/$dutname$lutidx.log
      
      clut=`echo "$bcdefs; max($clutref,$clutdut)" | bc`
      schg=`echo "$bcdefs; max($schgref,$schgdut)" | bc`
      imem=`echo "$bcdefs; max($imemref,$imemdut)" | bc`
      echo "-N- MAX: $clut $schg $imem" >> $dirname/$dutname$lutidx.log
      
      stpgrp=`cat $1/$isaname.pat | tail -n 1`
      stpgrp=`echo "$bcdefs; max(6,$stpgrp)" | bc`
      echo "-N- DUT STEP_GROUPS: $stpgrp" >> $dirname/$dutname$lutidx.log
      
      make -C sim SIM_GENERICS="-ggoldenref=\"../$1/goldenref\" -gdutfiles=\"../$1/$dutname\" -glutidx=\"$lutidx\" -gSIZE_CLUT=$clut -gSIZE_SCHG=$schg -gSIZE_IMEM=$imem -gSTEP_GROUPS_GOLDEN=6 -gSTEP_GROUPS_DUT=$stpgrp" clean-sim sim-hdl >> $dirname/$dutname$lutidx.log
      #make -C sim SIM_GENERICS="-ggoldenref=\"../$1/goldenref\" -gdutfiles=\"../$1/$dutname\" -glutidx=\"$lutidx\" -gSIZE_CLUT=$clut -gSIZE_SCHG=$schg -gSIZE_IMEM=$imem -gSTEP_GROUPS_GOLDEN=6 -gSTEP_GROUPS_DUT=$stpgrp" clean-sim sim-hdl-gui
      
      st=`cat $dirname/$dutname$lutidx.log | grep 'Fatal:' | wc -l`
      if [ "$st" -ne 0 ]; then
        echo "[ERROR] $errdir: Co-Simulation $dutname$lutidx did not finish successfully. Exit with Error 1..." >&2
        exit 1
      fi
      
      echo "$dutname$lutidx,$clutdut,$schgdut,$imemdut,$stpgrp" >> $dirname/$tabconf
      sconf="$clutdut,$schgdut,$imemdut,$stpgrp"
      confgrep=`cat $dirname/$synconf | grep "$sconf" | wc -l`
      if [ "$confgrep" -eq 0 ]; then
        echo $sconf >> $dirname/$synconf
      fi
      
    done
  
  done
  
else
  
  echo "[ERROR] $errdir: Co-Simulation directory '$1' does not exist. Exit with Error 1..." >&2
  exit 1
  
fi
