#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

set -e

echo "== IMAGES2OPENC START == $(date) =="

for di in $(ls -d ZZ_$1*/)
do
  ### Generate images2openc.sh
  echo "#!/bin/bash" > ${di}images2openc.sh
  echo "set -e" >> ${di}images2openc.sh
  echo "shopt -s extglob" >> ${di}images2openc.sh
  echo "" >> ${di}images2openc.sh
  echo "for f in $1/*.inc" >> ${di}images2openc.sh
  echo "do" >> ${di}images2openc.sh
  echo "  cover=\$(basename \$f .inc)" >> ${di}images2openc.sh
  echo "  " >> ${di}images2openc.sh
  echo "  for g in $1/\$cover.*.mem" >> ${di}images2openc.sh
  echo "  do" >> ${di}images2openc.sh
  echo "    img=\$(basename \$g .mem)" >> ${di}images2openc.sh
  echo "    cat \$g | ./asm2cycles.py $1/\$img.asm $1.bbtrace $1/\$img.+(0).schg $1/\$cover.incdef | ./cycles2openc.py \$img" >> ${di}images2openc.sh
  echo "  done" >> ${di}images2openc.sh
  echo "  " >> ${di}images2openc.sh
  echo "done" >> ${di}images2openc.sh
  
  chmod ugo+x ${di}images2openc.sh
  
  echo "== $di == $(date) =="
  { cd $di; ./images2openc.sh; cd ..; }
done

echo "== IMAGES2OPENC END == $(date) =="
