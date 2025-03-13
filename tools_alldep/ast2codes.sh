#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

set -e

app=$(basename $1 .ast)

cat $1 | ./ast2ddgs.py $app

for f in ${app}*.ddg
do
  ddg=$(basename $f .ddg)
  { echo "== START == $(date) ==" > $ddg.log; { cat $f | ./ddg2sets.py | ./sets2slack2cover.py | ./cover2code.py; } 1> $ddg.code 2>> $ddg.log; echo "== END == $(date) ==" >> $ddg.log; } &
done

wait
