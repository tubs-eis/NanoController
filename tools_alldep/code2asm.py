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
from networkx.readwrite import json_graph
import config as cf


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


for codeIdx, codeG in enumerate(codeGraphs):                             # fer each valid code cover
  for schedIdx, sched in enumerate(topoSchedules[codeIdx]):              # for each valid schedule of code cover, create ASM output file
    if cf.debugStdErr:
      print(f"Cover {codeIdx}, Schedule {schedIdx}: {sched}", file=sys.stderr)
    with open(f"{outdir}/{codeIdx:0{len(str(len(codeGraphs)))}}.{schedIdx:0{len(str(len(topoSchedules[codeIdx])))}}.asm", "w") as outf:
      print(f"{header}", file=outf)
      for node in sched:                                                 # print ASM output node after node
        nodeattr = codeG.nodes[node]
        if nodeattr['opcode'] == 'bb':                                   # for BB entry/label nodes
          if 'srcline' in nodeattr:                                      # if an ORG source line is attributed, output it
            print(f"{nodeattr['srcline']}\n", file=outf)
          elif len(nodeattr['imm']) > 0:
            print(f"\n{nodeattr['imm']}:\n", file=outf)                  # if it is label node, output label
        else:
          print(f"  {nodeattr['opcode']}  {nodeattr['imm']}", file=outf)
      print(f"\nEND", file=outf)                                         # END ASM output
  with open(f"{outdir}/{codeIdx:0{len(str(len(codeGraphs)))}}.incdef", "w") as outf:
    for patIdx, pat in enumerate(LUTStringLists[codeIdx]):               # create ISA definition include file for table assembler
      firstMod = ''
      secondMod = ''
      for cw in pat:                                                     # analyze control words in each instruction pattern
        if cw in cf.asmMods:                                             # and apply definition modifiers if configured
          firstMod = cf.asmMods[cw][0]
          secondMod = cf.asmMods[cw][1]
      print(f"#define PAT_{patIdx:0{len(str(len(LUTStringLists[codeIdx])))}}{firstMod}  DB({patIdx}){secondMod}", file=outf)
