#!/bin/python3
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

import sys
import tempfile
import ast
import config as cf


## Hamming distance between two strings in Python
## https://stackoverflow.com/questions/54172831/hamming-distance-between-two-strings-in-python
def dstHamming(str1, str2):
  return sum(c1 != c2 for c1, c2 in zip(str1, str2))


argc = len(sys.argv)
if argc > 1:
  f = open(sys.argv[1])
else:
  f = tempfile.TemporaryFile('w+')
  f.write(sys.stdin.read())
  f.seek(0)

iMemCycleList, cLutCycleList, xtraCycleList = ast.literal_eval(f.read())
f.close()


cList = []
for iMem, cLut in zip(iMemCycleList, cLutCycleList):                    # Build up sequence of Cycle LUT addresses in NanoController CU:
  cList.extend(list(range(cLut[0],cLut[0]+len(iMem)-1)))                # - in REGFETCH state
  cList.extend(cLut)                                                    # - in EXECUTE state
  cList.append(cLut[0])                                                 # - in FETCH state of next instruction

cListStr = [f'{i:0{cf.schgLUTBaseAddrBits}b}' for i in cList]           # Convert trace of Cycle LUT addresses to list of binary strings, ...
hamming = 0
for i in range(len(cList)-1):                                           # ... then accumulate Hamming distances within sequence
  hamming += dstHamming(cListStr[i], cListStr[i+1])

print(hamming)
