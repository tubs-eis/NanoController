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
cp sw/$1.asm $outdir

cp sw/$1.ast.bbtrace $outdir/$1.bbtrace

cp asm/axasm $outdir
cp asm/nano*.inc $outdir
cp asm/soloasm.* $outdir
cp asm/solo*.awk $outdir

cp tools_alldep/asm2cycles.py $outdir
cp tools_alldep/asm2ddg.py $outdir
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

### Generate code2images.sh
echo "#!/bin/bash" > $outdir/code2images.sh
echo "set -e" >> $outdir/code2images.sh
echo "" >> $outdir/code2images.sh
echo "rm -rf $1/" >> $outdir/code2images.sh
echo "cat $1.code | ./code2asm.py $1" >> $outdir/code2images.sh
echo "cat $1.code | ./code2streams.py $1" >> $outdir/code2images.sh
echo "" >> $outdir/code2images.sh
echo "for f in $1/*.incdef" >> $outdir/code2images.sh
echo "do" >> $outdir/code2images.sh
echo "  cover=\$(basename \$f .incdef)" >> $outdir/code2images.sh
echo "  cat nano.template.header.inc $1/\$cover.incdef nano.template.footer.inc > $1/\$cover.inc" >> $outdir/code2images.sh
echo "  cp $1/\$cover.inc ." >> $outdir/code2images.sh
echo "  " >> $outdir/code2images.sh
echo "  for g in $1/\$cover.*.asm" >> $outdir/code2images.sh
echo "  do" >> $outdir/code2images.sh
echo "    img=\$(basename \$g .asm)" >> $outdir/code2images.sh
echo "    ./axasm -p \$cover -v \$g > $1/\$img.mem" >> $outdir/code2images.sh
echo "  done" >> $outdir/code2images.sh
echo "  " >> $outdir/code2images.sh
echo "  rm \$cover.inc" >> $outdir/code2images.sh
echo "  " >> $outdir/code2images.sh
echo "done" >> $outdir/code2images.sh
echo "" >> $outdir/code2images.sh
echo "### Golden Reference" >> $outdir/code2images.sh
echo "cp ../sim/img/$1.mem $1/goldenref.mem" >> $outdir/code2images.sh
echo "cp ../sim/img/$1.clut $1/goldenref.clut" >> $outdir/code2images.sh
echo "cp ../sim/img/$1.schg $1/goldenref.schg" >> $outdir/code2images.sh

chmod ugo+x $outdir/code2images.sh
