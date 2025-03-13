#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

set -e

rm -rf $1/
cat $1.code | ./code2asm.py $1
cat $1.code | ./code2streams.py $1

for f in $1/*.incdef
do
  cover=$(basename $f .incdef)
  cat ../asm/nano.template.header.inc $1/$cover.incdef ../asm/nano.template.footer.inc > $1/$cover.inc
  cp $1/$cover.inc ../asm
  
  for g in $1/$cover.*.asm
  do
    img=$(basename $g .asm)
    ../asm/axasm -p $cover -v $g > $1/$img.mem
  done
  
  rm ../asm/$cover.inc
  
done

### Golden Reference
../asm/axasm -p nano -v ../sw/$1.asm > $1/goldenref.mem
cp ../sim/img/nano_clut.mem $1/goldenref.clut
cp ../sim/img/nano_schg.mem $1/goldenref.schg
