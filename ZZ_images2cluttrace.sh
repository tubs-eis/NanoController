#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

set -e

echo "== IMAGES2CLUTTRACE START == $(date) =="

for di in $(ls -d ZZ_$1*/)
do  
  ### Generate images2cluttrace.sh
  echo "#!/bin/bash" > ${di}images2cluttrace.sh
  echo "set -e" >> ${di}images2cluttrace.sh
  echo "" >> ${di}images2cluttrace.sh
  echo "for f in $1/*.inc" >> ${di}images2cluttrace.sh
  echo "do" >> ${di}images2cluttrace.sh
  echo "  cover=\$(basename \$f .inc)" >> ${di}images2cluttrace.sh
  echo "  " >> ${di}images2cluttrace.sh
  echo "  for g in $1/\$cover.*.mem" >> ${di}images2cluttrace.sh
  echo "  do" >> ${di}images2cluttrace.sh
  echo "    img=\$(basename \$g .mem)" >> ${di}images2cluttrace.sh
  echo "    " >> ${di}images2cluttrace.sh
  echo "    for h in $1/\$img.*.schg" >> ${di}images2cluttrace.sh
  echo "    do" >> ${di}images2cluttrace.sh
  echo "      cl=\$(basename \$h .schg)" >> ${di}images2cluttrace.sh
  echo "      cat \$g | ./asm2cycles.py $1/\$img.asm $1.bbtrace \$h $1/\$cover.incdef | ./cycles2cluttrace.py > $1/\$cl.cluttrace" >> ${di}images2cluttrace.sh
  echo "    done" >> ${di}images2cluttrace.sh
  echo "    " >> ${di}images2cluttrace.sh
  echo "  done" >> ${di}images2cluttrace.sh
  echo "  " >> ${di}images2cluttrace.sh
  echo "done" >> ${di}images2cluttrace.sh
  
  chmod ugo+x ${di}images2cluttrace.sh
  
  echo "== $di == $(date) =="
  { cd $di; ./images2cluttrace.sh; cd ..; }
done

echo "== IMAGES2CLUTTRACE END == $(date) =="
