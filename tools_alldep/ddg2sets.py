#!/bin/python3
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

## Introduction to Exact Cover Problem and Algorithm X
## https://www.geeksforgeeks.org/introduction-to-exact-cover-problem-and-algorithm-x/

## Python for Education: The Exact Cover Problem
## https://core.ac.uk/download/pdf/230920551.pdf

## Algorithm X in 30 lines!
## https://www.cs.mcgill.ca/~aassaf9/python/algorithm_x.html

import sys
import tempfile
import ast
import networkx as nx
from networkx.readwrite import json_graph
import config as cf


def recInstrSearch(prevSched,prevSchedList,isa):                        # Auxiliary Function: Recursively search valid instructions from topologically sorted schedules
  schedDict = {}
  for sched in prevSchedList:                                           # for each still-possible schedule tail
    if len(sched) > 0:                                                  # Abortion criterion: no schedule tail
      curSched = frozenset(prevSched.union({sched[0]}))                 # update instruction pattern from schedule tail, concatenate all resource uses
      if '#' in depG.nodes[sched[0]]['use'] and len(prevSched) > 0:     # Skip criterion: if immediate not first node in instruction, this is currently not allowed - skip current pattern candidate
        continue
      if curSched not in schedDict:                                     # schedDict will contain as keys all possible instruction patterns on this branch, as value a list of further schedule branching
        schedDict[curSched] = []
      schedDict[curSched].append(sched[1:])
  for key in schedDict:                                                 # for each valid instruction pattern, add it to current ISA candidates and recurse further
    isa.add(key)
    recInstrSearch(key,schedDict[key],isa)


argc = len(sys.argv)
if argc > 1:
  f = open(sys.argv[1])
else:
  f = tempfile.TemporaryFile('w+')
  f.write(sys.stdin.read())
  f.seek(0)

header, blocklist, blockedges = ast.literal_eval(f.read())
f.close()


depG = nx.DiGraph()
bblist = []
nodenum = 1
for block in blocklist:                                                 # Pass 1: Build dependency graph from node and edge lists
  bblist.append(nodenum)
  depG.add_nodes_from([(i,elem) for i,elem in enumerate(block,start=nodenum)])
  nodenum += len(block)
for block in blockedges:
  depG.add_edges_from(block)


isaList = []
schedules = [list(nx.all_topological_sorts(depG.subgraph({i}.union(nx.descendants(depG,i))))) for i in bblist]
for block in schedules:                                                 # Pass 2: Find sets of instructions from all valid topological dependency graph sorts
  isaList.append(set())
  schedList = []
  for sched in block:                                                   # Prepare initial list of still-possible schedule tails (starting from each node in schedule)
    schedList.extend([sched[i:] for i in range(1,len(sched))])
  recInstrSearch(frozenset(),schedList,isaList[-1])


print(repr((header,json_graph.node_link_data(depG),[[set(i) for i in isa] for isa in isaList])))

if cf.debugStdErr:
  print([len(i) for i in schedules], file=sys.stderr)
  print([len(isa) for isa in isaList], file=sys.stderr)
