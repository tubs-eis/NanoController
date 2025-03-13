#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

set -e

for asmapp in lockctrl lockctrl_alt
do
  ./Z_templateGen.sh ${asmapp}
  rm -rf ZZ_${asmapp}
  cp -R Z_${asmapp}_TEMPLATE ZZ_${asmapp}
  rm -rf Z_${asmapp}_TEMPLATE
  
  ./ZZ_asm2code.sh ${asmapp}
  ./ZZ_code2images.sh ${asmapp}
  
  ## Longer runtime, therefore commented out for quick testing.
  ## Uncomment to enable (if desired).
  #./ZZ_coSimulateISA.sh ${asmapp}
  #./ZZ_images2cluttrace.sh ${asmapp}

  ## Requires VANAGA repository checkout (see README)!
  ## Longer runtime, therefore commented out for quick testing.
  ## Uncomment to enable (if desired).
  #./ZZ_images2openc.sh ${asmapp}
done

for ddgapp in lockctrl lockctrl_alt
do
  ./Z_templateGen_ddg.sh ${ddgapp}
  seq -w 0 5 | while read i
  do
    rm -rf ZZ_${ddgapp}${i}
    cp -R Z_${ddgapp}_TEMPLATE ZZ_${ddgapp}${i}
  done
  rm -rf Z_${ddgapp}_TEMPLATE
  
  seq -w 0 5 | while read i
  do
    ./ZZ_ddg2code.sh ${ddgapp}${i}
    ./ZZ_code2images.sh ${ddgapp}${i}
    
    ## Longer runtime, therefore commented out for quick testing.
    ## Uncomment to enable (if desired).
    #./ZZ_coSimulateISA.sh ${ddgapp}${i}
    #./ZZ_images2cluttrace.sh ${ddgapp}${i}
    
    ## Requires VANAGA repository checkout (see README)!
    ## Longer runtime, therefore commented out for quick testing.
    ## Uncomment to enable (if desired).
    #./ZZ_images2openc.sh ${ddgapp}${i}
  done
done
