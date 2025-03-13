#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

set -e

outdir=Z_$1_TEMPLATE

mkdir -p $outdir
cat sw/$1.ast | ./tools_alldep/ast2ddgs.py $1
for f in ${1}*.ddg
do
  ddgname=$(basename $f .ddg)
  mv $f $outdir
  cp sw/$1.ast.bbtrace $outdir/$ddgname.bbtrace
done

cp asm/axasm $outdir
cp asm/nano*.inc $outdir
cp asm/soloasm.* $outdir
cp asm/solo*.awk $outdir

cp tools_alldep/asm2cycles.py $outdir
cp tools_alldep/code2asm.py $outdir
cp tools_alldep/code2streams.py $outdir
cp tools_alldep/config.py $outdir
cp tools_alldep/coSimulateISA.sh $outdir
cp tools_alldep/cover2code.py $outdir
cp tools_alldep/cycles2cluttrace.py $outdir
cp tools_alldep/cycles2openc.py $outdir
cp tools_alldep/ddg2sets.py $outdir
cp tools_alldep/func_match.py $outdir
cp tools_alldep/sets2slack2cover.py $outdir

mkdir -p $outdir/sim
cp -R tools_alldep/sim/scr $outdir/sim
cp -R tools_alldep/sim/sv $outdir/sim
cp -R tools_alldep/sim/vhdl $outdir/sim
cp tools_alldep/sim/init_tools $outdir/sim
cp tools_alldep/sim/Makefile $outdir/sim

### Golden Reference
cp sim/img/$1.mem $outdir/goldenref.mem
cp sim/img/$1.clut $outdir/goldenref.clut
cp sim/img/$1.schg $outdir/goldenref.schg
