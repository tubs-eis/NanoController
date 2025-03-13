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
import os
import ast
import networkx as nx
from networkx.drawing.nx_pydot import write_dot
from networkx.readwrite import json_graph
import config as cf


def genCycleLUTSchedule(s):                                             # Auxiliary Function: Generate all possible Cycle LUT schedules via recursion
  if len(s) == 0:
    yield ()
  else:
    for prefix in s:
      for string in genCycleLUTSchedule(s.difference({prefix})):
        yield (list(prefix) + list(string))

def encodeCycleLUTCodes(schedules):                                     # Auxiliary Function: Generate binary stream encoding for Cycle LUT schedule
  for s in schedules:
    output = []
    for i in s:
      output.extend(cf.cycleLUTCodes[i])
    if cf.cLUTRemoveInnerIMEMCycles:                                    # With config option: Remove all inner occurrences of IMEM_CYCLE in string list, only keep last position (if existing)
      while cf.cwID['IMEM_CYCLE'] in output:                            # -- IMEM_CYCLE is inferred by MEM_FROM_ACCU, but may be only required at the end of a multi-cycle instruction
        imemIdx = output.index(cf.cwID['IMEM_CYCLE'])                   # -- in order to resolve a memory resource conflict for next instruction fetch
        if imemIdx < len(output)-1:
          output.pop(imemIdx)
          continue
        break
    yield output

def encodeCycleLUTNames(schedules):                                     # Auxiliary Function: Generate binary stream encoding for Cycle LUT schedule
  for s in schedules:
    output = []
    for i in s:
      output.append(cf.cwID[i])
    yield output

def posInCycleLUT(sublist,inlist):                                      # Auxiliary Function: Identify position of a sublist within a merged/concatenated input list
  for i in range(len(inlist)-len(sublist)+1):
    if inlist[i:i+len(sublist)] == sublist:
      return i

def genStateChgEntries(stringlist,enclist):                             # Auxiliary Function: Generate State Change LUT modifiers from opcodes in LUT string list
  for i,string in enumerate(stringlist):
    output = cf.schgDefault.copy()
    for s in string:
      output.update(cf.schgModifiers[s])
    output[cf.schgCycodeField] = len(enclist[i])-1
    yield output

def updateStateChgForCycleLUT(statechg,poslist):                        # Auxiliary Function: For each Cycle LUT encoding, yield base address positions for State Change LUT
  for pos in poslist:
    output = []
    for instIdx,addr in enumerate(pos):
      output.append(statechg[instIdx].copy())                           # separate dictionary copy of common prepared State Change LUT dict for each instruction, ...
      output[-1][cf.schgBaseField] = addr                               # ... updated with base address of instruction for that particular cycle LUT
    yield output

def genVerilogMem(stringlist):                                          # Auxiliary Function: Generate binary memory image as a string (Verilog-style)
  output = '@0'
  for string in stringlist:
    output += '\n' + string
  return output

def convertStateChgToBinary(dictlist):                                  # Auxiliary Function: Convert state change LUT dictionaries into list of binary strings
  output = []
  for schgDict in dictlist:
    string = ''
    for field in cf.schgLUTOrder:                                       # Output order of bit fields is defined in config
      val = schgDict[field]
      if field in cf.schgLUTEncLength:                                  # Special case: If field name has bit length for encoding given, the integer must be converted to a binary string
        val = f'{val:0{cf.schgLUTEncLength[field]}b}'
      string += val
    output.append(string)
  return output


argc = len(sys.argv)
if argc > 2:
  f = open(sys.argv[1])
  outdir = sys.argv[2]
  os.makedirs(outdir, exist_ok=True)
else:
  f = tempfile.TemporaryFile('w+')
  f.write(sys.stdin.read())
  f.seek(0)
  if argc > 1:
    outdir = sys.argv[1]
    os.makedirs(outdir, exist_ok=True)
  else:
    tempdir = tempfile.TemporaryDirectory()
    outdir = tempdir.name

header, LUTStringLists, LUTAssemblies, codeGraphs, topoSchedules = ast.literal_eval(f.read())
codeGraphs = [json_graph.node_link_graph(g) for g in codeGraphs]
f.close()


for idx, codeG in enumerate(codeGraphs):
  encLUTString = list(encodeCycleLUTCodes(LUTStringLists[idx]))
  if any(len(sublist) == 0 for sublist in encLUTString):                # Exclusion Criterion: If an instruction within a cover only consists of immediate loading (no cycle LUT encoding), ...
    continue                                                            # ... exclude for now (not supported by current architecture)
  schedCycleLUTs = [list(genCycleLUTSchedule(s)) for s in LUTAssemblies[idx]]
  stateChgEntries = list(genStateChgEntries(LUTStringLists[idx],encLUTString))
  if cf.debugStdErr:
    print(f'Code {idx}:', file=sys.stderr)
    print(LUTStringLists[idx], file=sys.stderr)
    #print(encLUTString, file=sys.stderr)
    #print(stateChgEntries, file=sys.stderr)
  with open(f"{outdir}/{idx:0{len(str(len(codeGraphs)))}}.pat", "w") as outf:
    for t in LUTStringLists[idx]:                                       # Output patterns in human-readable form for debugging
      print(t, file=outf)
    print(f"\nSTEP_GROUPS:\n{max([len(s) for s in encLUTString])}", file=outf)
  for schedIdx, s in enumerate(schedCycleLUTs):
    bestBaseAddr = None
    cycleEnc = []
    posInCLUT = []
    for enc in encodeCycleLUTNames(s):                                  # Evaluate each cycle LUT encoding
      poslist = [posInCycleLUT(sublist,enc) for sublist in encLUTString]
      maxBaseAddr = max(poslist)
      if bestBaseAddr is not None:                                      # Only keep solutions with lowest maximum base address (save bits in State Change LUT) - if a new minimum is achieved, non-minimum solutions are cleared from further consideration
        if maxBaseAddr > bestBaseAddr:
          continue
        elif maxBaseAddr < bestBaseAddr:
          cycleEnc.clear()
          posInCLUT.clear()
      bestBaseAddr = maxBaseAddr
      cycleEnc.append(enc)
      posInCLUT.append(poslist)
    stateChgSolutions = list(updateStateChgForCycleLUT(stateChgEntries,posInCLUT))
    if cf.debugStdErr:
      #print(posInCLUT, file=sys.stderr)
      #print(stateChgSolutions,file=sys.stderr)
      print(f'Cycle LUT Depth is {min([len(c) for c in cycleEnc])}.', file=sys.stderr)
      print(f'Maximum encoded Base Address value is {bestBaseAddr}.', file=sys.stderr)
      print(f'Maximum encoded Cycode value is {max(map(lambda x:x[cf.schgCycodeField],stateChgEntries))}.', file=sys.stderr)
    for t in range(len(cycleEnc)):                                      # For each valid solution, generate Cycle LUT and State Change LUT memory images
      with open(f"{outdir}/{idx:0{len(str(len(codeGraphs)))}}.{schedIdx:0{len(str(len(schedCycleLUTs)))}}.{t:0{len(str(len(cycleEnc)))}}.clut", "w") as outf:
        print(genVerilogMem(cycleEnc[t]), file=outf)
      with open(f"{outdir}/{idx:0{len(str(len(codeGraphs)))}}.{schedIdx:0{len(str(len(schedCycleLUTs)))}}.{t:0{len(str(len(cycleEnc)))}}.schg", "w") as outf:
        print(genVerilogMem(convertStateChgToBinary(stateChgSolutions[t])), file=outf)
  if cf.debugStdErr:
    print(topoSchedules[idx], file=sys.stderr)
