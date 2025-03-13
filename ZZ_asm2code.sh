#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

set -e

echo "== ASM2CODE START == $(date) =="

for di in $(ls -d ZZ_$1*/)
do
  echo $di
  { echo "== START == $(date) ==" > $di$1.log; { cd $di; ./asm2ddg.py $1.asm | ./ddg2sets.py | ./sets2slack2cover.py | ./cover2code.py; cd ..; } 1> $di$1.code 2>> $di$1.log; echo "== END == $(date) ==" >> $di$1.log; } &
done

wait

echo "== ASM2CODE END == $(date) =="
