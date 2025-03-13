#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

set -e

echo "== coSimulateISA START == $(date) =="

for di in $(ls -d ZZ_$1*/)
do
  echo "== $di == $(date) =="
  { cd $di; ./coSimulateISA.sh $1; cd ..; } &
done

wait

echo "== coSimulateISA END == $(date) =="
