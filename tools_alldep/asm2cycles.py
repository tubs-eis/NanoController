#!/bin/python3
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

import re
import sys
import tempfile
import ast
import config as cf

# Standard ISA (can be overridden by INCDEF file below)
incdef = [ \
"#define LDI(...)                  DB(0); VAR_MACRO(__VA_ARGS__,ARG3,ARG2,ARG1)(__VA_ARGS__)", \
"#define CMPI(...)                 DB(1); VAR_MACRO(__VA_ARGS__,ARG3,ARG2,ARG1)(__VA_ARGS__)", \
"#define ADDI(...)                 DB(2); VAR_MACRO(__VA_ARGS__,ARG3,ARG2,ARG1)(__VA_ARGS__)", \
"#define SUBI(...)                 DB(3); VAR_MACRO(__VA_ARGS__,ARG3,ARG2,ARG1)(__VA_ARGS__)", \
"//#define LIS(...)                  DB(OP_LIS); VAR_MACRO(__VA_ARGS__,ARG2,ARG1)(__VA_ARGS__)", \
"#define LIS(a1)                   DB(4); DB(a1)", \
"#define LISL                      DB(5)", \
"//#define LDS(...)                  DB(OP_LDS); VAR_MACRO(__VA_ARGS__,ARG2,ARG1)(__VA_ARGS__)", \
"#define LDS(a1)                   DB(6); DB(a1)", \
"#define LDSL                      DB(7)", \
"#define DBNE(...)                 DB(8); VAR_MACRO(__VA_ARGS__,BRANCH3,BRANCH2,BRANCH1)(__VA_ARGS__)", \
"#define BNE(...)                  DB(9); VAR_MACRO(__VA_ARGS__,BRANCH3,BRANCH2,BRANCH1)(__VA_ARGS__)", \
"//#define CST(...)                  DB(OP_CST); VAR_MACRO(__VA_ARGS__,ARG2,ARG1)(__VA_ARGS__)", \
"#define CST(a1)                   DB(10); DB(a1)", \
"#define CSTL                      DB(11)", \
"//#define ST(...)                   DB(OP_ST); VAR_MACRO(__VA_ARGS__,ARG2,ARG1)(__VA_ARGS__)", \
"#define ST(a1)                    DB(12); DB(a1)", \
"#define STL                       DB(13)", \
"//#define LD(...)                 DB(OP_LD); VAR_MACRO(__VA_ARGS__,ARG2,ARG1)(__VA_ARGS__)", \
"#define LD(a1)                    DB(14); DB(a1)", \
"#define SLEEP                     DB(15)" ]

# Standard State Change LUT (can be overridden by file below)
schgLUT = [ \
"110001000000", \
"110000011000", \
"110000100000", \
"110000101000", \
"100000110101", \
"000000110101", \
"100001100101", \
"000001100101", \
"111010010001", \
"111010011000", \
"100000000010", \
"000000000010", \
"100000001001", \
"000000001001", \
"100000110010", \
"000110100000" ]

# Basic Block Trace will be loaded from file
bbTrace = []

##################################

argc = len(sys.argv)
if argc > 4:
  incdef = []
  with open(sys.argv[4]) as fIncDef:
    for line in fIncDef:
      incdef.append(line)
if argc > 3:
  schgLUT = []
  with open(sys.argv[3]) as fSchgLUT:
    for line in fSchgLUT:
      if line[0] != '@':
        schgLUT.append(line)
if argc > 2:
  with open(sys.argv[2]) as fBbTrace:
    bbTrace = ast.literal_eval(fBbTrace.read())

f = open(sys.argv[1])

g = tempfile.TemporaryFile('w+')
g.write(sys.stdin.read())
g.seek(0)


iMemCode = []
for line in g:                                                          # Pass 0: Read Verilog memory object input from axasm via stdin and arrange as integer list
  for i in line.split():
    if i[0] != '@':
      iMemCode.extend(i)
iMemCode = [int(i, 16) for i in iMemCode]

reToken = re.compile(r'\s*#define\s+(\w+)(\([\.\w]+\)\s+|\s+)DB\((\d+)\)')
tokenDict = {}
for line in incdef:                                                     # Pass 1: Read INCDEF file and obtain valid mnemonic tokens, correlate with state change LUT data
  matchToken = reToken.match(line)
  if matchToken:                                                        # yep, it's a valid mnemonic token, so:
    mnemo = matchToken.group(1)
    opEnc = int(matchToken.group(3))                                    # - get integer representation of opcode encoding, store it in token dictionary
    tokenDict[mnemo] = {}
    tokenDict[mnemo]['opcode'] = opEnc
    schgEntry = schgLUT[opEnc]                                          # - use opcode encoding to retrieve information from state change LUT
    for field in cf.schgLUTOrder:                                       # - decode base-2 fields in order from state change LUT entry, store to token dictionary
      idxR = 1
      if field in cf.schgLUTEncLength:
        idxR = cf.schgLUTEncLength[field]
      idxR = min(idxR,len(schgEntry))
      tokenDict[mnemo][field] = int(schgEntry[:idxR], 2)
      schgEntry = schgEntry[idxR:]

if cf.debugStdErr:
  print(tokenDict, file=sys.stderr)
  print(file=sys.stderr)

iMemPerBB = []
cLutPerBB = []
xtraPerBB = []
injectBB = False
iMemPtr = 0
for line in f:                                                          # Pass 2: Read ASM source file line by line
  tokens = line.split(';')[0].strip().split()                           # Tokenize input line, separated by whitespaces
  if len(tokens) == 0:
    continue                                                            # if tokens empty, continue with next line
  token = tokens[0]
  if token == 'END':                                                    # Abortion if END of source file found
    break
  if injectBB or token[-1] == ':' or token == 'ORG':                    # Special cases of new basic blocks: If BB injection marked, or token is 'ORG' or ends with ':' being a label
    iMemPerBB.append([])
    cLutPerBB.append([])
    xtraPerBB.append([])
    if cf.debugStdErr:
      print(f"=== New BB ===", file=sys.stderr)
    injectBB = False
  if token in tokenDict:                                                # if Trivial case: token found in token dictionary, add up cycles
    if tokenDict[token]['Branch'] == 1 \
    or tokenDict[token]['Wake'] == 1:                                   # - mark injection of new basic block after control flow instruction
      injectBB = True
    iMemPerBB[-1].append([token])                                       # FETCH + REGFETCH cycles
    iMemPerBB[-1][-1].extend(iMemCode[iMemPtr+1:iMemPtr+len(tokens)])
    iMemPtr += len(tokens)
    if len(tokens) > 1:
      xtraPerBB[-1].append(token)                                       # xtra FETCH cycle when REGFETCH follows
    cLutPerBB[-1].append(list(range(tokenDict[token]['BaseAddr'], \
    tokenDict[token]['BaseAddr']+tokenDict[token]['Cycode']+1)))        # EXECUTE cycles
    if tokenDict[token]['Branch'] == 1:
      xtraPerBB[-1].append(token)                                       # xtra EXECUTE cycle when a branch instruction
  else:
    continue
  print(f"{tokens} +++ {'2' if len(tokens) > 1 else '1'} FETCH {f'+++ {len(tokens)-1} REGFETCH' if len(tokens) > 1 else ''} +++ {tokenDict[token]['Cycode']+tokenDict[token]['Branch']+1} EXECUTE", file=sys.stderr)
f.close()

iMemCycleList = []
cLutCycleList = []
xtraCycleList = []
for i in bbTrace:                                                       # Pass 3: Accumulate cycle lists according to program basic block trace to obtain profiling for complete application
  iMemCycleList.extend(iMemPerBB[i])
  cLutCycleList.extend(cLutPerBB[i])
  xtraCycleList.extend(xtraPerBB[i])

if cf.debugStdErr:
  print(file=sys.stderr)
  print([sum([len(ii) for ii in i])+sum([len(jj) for jj in j])+len(k) for i,j,k in zip(iMemPerBB, cLutPerBB, xtraPerBB)], file=sys.stderr)

print(repr((iMemCycleList, cLutCycleList, xtraCycleList)))
