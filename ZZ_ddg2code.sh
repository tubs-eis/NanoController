#!/bin/bash
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

set -e

echo "== DDG2CODE START == $(date) =="

for di in $(ls -d ZZ_$1*/)
do

  echo $di
  { echo "== START == $(date) ==" > $di$1.log; { cd $di; cat $1.ddg | ./ddg2sets.py | ./sets2slack2cover.py | ./cover2code.py; cd ..; } 1> $di$1.code 2>> $di$1.log; echo "== END == $(date) ==" >> $di$1.log; } &
  
  ### Generate code2images.sh
  echo "#!/bin/bash" > ${di}code2images.sh
  echo "set -e" >> ${di}code2images.sh
  echo "" >> ${di}code2images.sh
  echo "rm -rf $1/" >> ${di}code2images.sh
  echo "cat $1.code | ./code2asm.py $1" >> ${di}code2images.sh
  echo "cat $1.code | ./code2streams.py $1" >> ${di}code2images.sh
  echo "" >> ${di}code2images.sh
  echo "for f in $1/*.incdef" >> ${di}code2images.sh
  echo "do" >> ${di}code2images.sh
  echo "  cover=\$(basename \$f .incdef)" >> ${di}code2images.sh
  echo "  cat nano.template.header.inc $1/\$cover.incdef nano.template.footer.inc > $1/\$cover.inc" >> ${di}code2images.sh
  echo "  cp $1/\$cover.inc ." >> ${di}code2images.sh
  echo "  " >> ${di}code2images.sh
  echo "  for g in $1/\$cover.*.asm" >> ${di}code2images.sh
  echo "  do" >> ${di}code2images.sh
  echo "    img=\$(basename \$g .asm)" >> ${di}code2images.sh
  echo "    ./axasm -p \$cover -v \$g > $1/\$img.mem" >> ${di}code2images.sh
  echo "  done" >> ${di}code2images.sh
  echo "  " >> ${di}code2images.sh
  echo "  rm \$cover.inc" >> ${di}code2images.sh
  echo "  " >> ${di}code2images.sh
  echo "done" >> ${di}code2images.sh
  echo "" >> ${di}code2images.sh
  echo "### Golden Reference" >> ${di}code2images.sh
  echo "cp goldenref.mem $1/goldenref.mem" >> ${di}code2images.sh
  echo "cp goldenref.clut $1/goldenref.clut" >> ${di}code2images.sh
  echo "cp goldenref.schg $1/goldenref.schg" >> ${di}code2images.sh

  chmod ugo+x ${di}code2images.sh

done

wait

echo "== DDG2CODE END == $(date) =="
