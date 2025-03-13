#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

set -e
shopt -s extglob

for f in $1/*.inc
do
  cover=$(basename $f .inc)
  
  for g in $1/$cover.*.mem
  do
    img=$(basename $g .mem)
    cat $g | ./asm2cycles.py $1/$img.asm $1.bbtrace $1/$img.+(0).schg $1/$cover.incdef | ./cycles2openc.py $img
  done
  
done
