#!/bin/python3
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

## Efficient Algorithm for String Concatenation with Overlap
## https://saturncloud.io/blog/efficient-algorithm-for-string-concatenation-with-overlap/

## Z algorithm (Linear time pattern searching Algorithm)
## https://www.geeksforgeeks.org/z-algorithm-linear-time-pattern-searching-algorithm/

## How to merge strings with overlapping characters in python?
## https://stackoverflow.com/questions/52528744/how-to-merge-strings-with-overlapping-characters-in-python

import sys
import tempfile
import ast
import time
import signal
import networkx as nx
from networkx.drawing.nx_pydot import write_dot
from networkx.readwrite import json_graph
import config as cf
import func_match as funcMatch


run = True                                                              # Global semaphor: Should we still run?

def handlerSolutionsNow(signum,frame):                                  # Signal Handler: Deliver current solutions now and abort recursion
  global run
  run = False                                                           # Indicate by global semaphor
  if cf.debugStdErr:
    print(f'[SIGNAL] Received signal to deliver current solutions now, abort recursion...', file=sys.stderr)

## ---

## How to test if a list contains another list as a contiguous subsequence?
## https://stackoverflow.com/questions/3847386/how-to-test-if-a-list-contains-another-list-as-a-contiguous-subsequence

def contains(sublist,inlist):
  return any(inlist[i:i+len(sublist)] == sublist for i in range(len(inlist)-len(sublist)+1))

## How to merge strings with overlapping characters in python?
## https://stackoverflow.com/questions/52528744/how-to-merge-strings-with-overlapping-characters-in-python

def assemble(prev_str_list):                                            # Recursively assemble (overlap and merge) opcode string sequences for Cycle LUT
  if len(prev_str_list) < 2:                                            # Termination Criterion: If only 1 sequence left, return it as tuple in a frozen set
    return {frozenset(tuple(string) for string in prev_str_list)}       # for immutable collection of output results
  str_list = prev_str_list.copy()
  output = set()
  string = str_list.pop()                                               # Pop an opcode string to compare to from current sequence and follow trivial recursion (no overlapping, no merging)
  output.update({frozenset({tuple(string)}.union(set(fz))) for fz in assemble(str_list)})
  for i,candidate in enumerate(str_list):                               # Nontrivial recursion: Look if there are candidate matches for overlapping and merging...
    matches = set()
    if contains(candidate,string):                                      # ...due to candidate entirely in compared string (candidate merged into string)
      matches.add(tuple(string))
    elif contains(string,candidate):                                    # ...due to compared string entirely in candidate (string merged into candidate)
      matches.add(tuple(candidate))
    else:
      for n in reversed(range(1,min(len(string),len(candidate)))):      # ...due to partial overlaps (reversed range, longer overlaps are preferred for shorter LUT sequence)
        hasMatch = False
        if candidate[:n] == string[-n:]:                                # - end of compared string matches beginning of candidate
          matches.add(tuple(string + candidate[n:]))
          hasMatch = True
        if candidate[-n:] == string[:n]:                                # - end of candidate matches beginning of compared string
          matches.add(tuple(candidate[:-n] + string))
          hasMatch = True
        if hasMatch:                                                    # If long partial overlap successful, do not look for shorter overlaps (solution will be worse)
          break
    for match in matches:                                               # Follow nontrivial recursion of overlapping and merged sequence matches
      output.update(assemble(str_list[:i] + str_list[i+1:] + [list(match)]))
  return output
## ---


def encodeStrList(strList):                                             # Auxiliary Function: Encode string list of instruction operations to intermediate cycle LUT mnemonics
  output = []
  for instr in strList:
    iStr = []
    for op in instr:
      iStr.extend(cf.cycleLUTNames[op])
    if cf.cLUTRemoveInnerIMEMCycles:                                    # With config option: Remove all inner occurrences of IMEM_CYCLE in string list, only keep last position (if existing)
      while 'IMEM_CYCLE' in iStr:                                       # -- IMEM_CYCLE is inferred by MEM_FROM_ACCU, but may be only required at the end of a multi-cycle instruction
        imemIdx = iStr.index('IMEM_CYCLE')                              # -- in order to resolve a memory resource conflict for next instruction fetch
        if imemIdx < len(iStr)-1:
          iStr.pop(imemIdx)
          continue
        break
    output.append(iStr)
  return output

def findAllTopologicalSchedules(bblist,prevList):                       # Auxiliary Function: Find all valid topological schedules of a sequence of basic blocks by recursion
  if len(bblist) == 0:
    yield prevList
  else:
    for srt in nx.all_topological_sorts(codeG.subgraph({bblist[0]}.union(nx.descendants(codeG,bblist[0])))):
      for i in findAllTopologicalSchedules(bblist[1:],prevList+srt):
        yield i

def validCycleOrders(pat):                                              # Auxiliary Function: Yield all valid cycle orders within a single pattern node
  for order in nx.all_topological_sorts(pat):                           # Iterate through all topological orders of single node pattern graph
    for node in order[1:]:
      if '#' in pat.nodes[node]['use']:                                 # Skip criterion: if immediate not first node in instruction, this is currently not allowed - skip current pattern candidate
        break
    else:
      yield order

def validISACombinations(gList):                                        # Auxiliary Function: Yield all valid combinations of cycle orders for a complete ISA by recursion
  if len(gList) == 0:
    yield []
  else:
    for i in validISACombinations(gList[1:]):
      for j in validCycleOrders(gList[0]):
        yield [j] + i


argc = len(sys.argv)
if argc > 1:
  f = open(sys.argv[1])
else:
  f = tempfile.TemporaryFile('w+')
  f.write(sys.stdin.read())
  f.seek(0)

header, depG, coverList, graphList = ast.literal_eval(f.read())
depG = json_graph.node_link_graph(depG)
graphList = [[json_graph.node_link_graph(j) for j in i] for i in graphList]
f.close()


validISAList = [list(validISACombinations(i)) for i in graphList]       # Pass 1: Collect lists of all valid ISA combinations for each cover in graph list
validISAStrings = [[[[graphList[i][j].nodes[node]['opcode'] for node in pat] for j,pat in enumerate(comb)] for comb in isa] for i,isa in enumerate(validISAList)]
bblist = []
for node in sorted(depG.nodes,key=lambda x: str(x).rjust(len(str(len(depG.nodes))))):
  if len(nx.ancestors(depG,node)) == 0:
    bblist.append(node)                                                 # Collect all basic block start nodes in dependency graph (no ancestors!)


signal.signal(signal.SIGUSR1, handlerSolutionsNow)                      # Register signal handlers for global semaphor
signal.signal(signal.SIGUSR2, handlerSolutionsNow)
bestLUTCovers = []
bestLUTStringLists = []
bestLUTAssemblies = []
bestLUTLength = None
for coveridx, coverISAStringCombs in enumerate(validISAStrings):        # Pass 2: Evaluate which covers have shortest Cycle LUT length
  if not run:                                                           # Check global semaphor if we should still iterate
    break
  for strList in coverISAStringCombs:                                   # For each valid cycle order of each instruction in ISA:
    if not run:                                                         # Check global semaphor if we should still iterate
      break
    encStrList = encodeStrList(strList)                                 # Encode cycle LUT entries to intermediate mnemonics
    assembledStrings = [{j for j in i} for i in assemble(encStrList)]   # Assemble, i.e., overlap and merge, the cycle LUT entries (mnemonics!) of each instruction (microcode-style)
    minLUTLength = min([sum([len(t) for t in s]) for s in assembledStrings])
    if bestLUTLength is not None:                                       # Only keep the best/shortest solutions (with parameterizable slack) - if a new minimum is achieved, non-minimum solutions are cleared from further consideration
      if minLUTLength > (bestLUTLength + cf.slackCycleLUTLen):
        continue
      elif minLUTLength > cf.constraintCycleLUTLen:
        continue
      elif minLUTLength < bestLUTLength:                                # If a new lowest Cycle LUT length is achieved, prune solutions with parameterizable slack
        prunePtr = 0
        while prunePtr < len(bestLUTCovers):
          if min([sum([len(t) for t in s]) for s in bestLUTAssemblies[prunePtr]]) > (minLUTLength + cf.slackCycleLUTLen):
            bestLUTCovers.pop(prunePtr)
            bestLUTStringLists.pop(prunePtr)
            bestLUTAssemblies.pop(prunePtr)
          else:
            prunePtr += 1
        bestLUTLength = minLUTLength
    else:
      bestLUTLength = minLUTLength
    bestLUTCovers.append(coveridx)                                      # In the end, bestLUTCovers contains the cover index of shortest Cycle LUT solutions
    for s in assembledStrings.copy():
      if sum([len(t) for t in s]) > minLUTLength:
        assembledStrings.remove(s)
    bestLUTStringLists.append(strList)
    bestLUTAssemblies.append(assembledStrings)                          # bestLUTAssemblies is updated with possible shortest Cycle LUT microcode assemblies
    if cf.debugStdErr:
      print(strList, file=sys.stderr)
      print(encStrList, file=sys.stderr)
      print(assembledStrings, file=sys.stderr)
      print(f'{time.strftime("%Y-%m-%d %H:%M:%S")} - Cover {coveridx}: Minimum CW LUT length is {minLUTLength}.', file=sys.stderr)


bestCodeGraphs = []
topoSchedules = []
for idx in bestLUTCovers:                                               # Pass 3: Generate code graph for each shortest instruction cover with fewest unique instructions and shortest Cycle LUT entries
  cover = coverList[idx]
  codeG = depG.copy()                                                   # Derive pattern-matched code graph from dependency graph
  for cut in cover:                                                     # For each node cut in instruction cover:
    for newOp, subg in enumerate(graphList[idx]):                       # Match cut to graph number in list of unique instructions
      if nx.is_isomorphic(depG.subgraph(cut),subg,node_match=funcMatch.node_match):
        break                                                           # When matched, for-loop breaks and number is contained in newOp
    edgesToAdd = []
    nodesToDelete = []
    tgtNode = cut[-1]                                                   # To maintain topological ordering, the resulting pattern node must have highest node number of cut (last in cut list)
    tgtImm = codeG.nodes[tgtNode]['imm']
    for node in cut[0:-1]:                                              # To collapse all other nodes into resulting pattern node, analyze dependencies and derive nodesToDelete and edgesToAdd
      nodesToDelete.append(node)
      for pred in codeG.predecessors(node):
        if pred not in cut:
          edgesToAdd.append((pred,tgtNode))
      for succ in codeG.successors(node):
        if succ not in cut:
          edgesToAdd.append((tgtNode,succ))
      imm = codeG.nodes[node]['imm']
      if len(imm) > 0:                                                  # also derive target immediate (if applicable) - only one immediate value currently allowed
        tgtImm = imm
    codeG.remove_nodes_from(nodesToDelete)                              # Finally, remove nodes and add edges to collapse cut into single pattern node
    codeG.add_edges_from(edgesToAdd)
    codeG.nodes[tgtNode].clear()                                        # Update attribute dict with pattern opcode and original node information
    codeG.nodes[tgtNode]['opcode'] = f'PAT_{newOp:0{len(str(len(graphList[idx])))}}'
    codeG.nodes[tgtNode]['orignodes'] = cut
    codeG.nodes[tgtNode]['imm'] = tgtImm                                # Update with immediate value if applicable
  bestCodeGraphs.append(codeG)
  topoSchedules.append(list(findAllTopologicalSchedules(bblist,[])))
  #if cf.debugStdErr:
  #  print(cover, file=sys.stderr)
  #  print(validISAList[idx], file=sys.stderr)
  #  print(validISAStrings[idx], file=sys.stderr)
  #  for pat in graphList[idx]:
  #    write_dot(pat, sys.stderr)
  #  for sched in topoSchedules[-1]:
  #    print(sched, file=sys.stderr)
  #  write_dot(bestCodeGraphs[-1], sys.stderr)

if cf.debugStdErr:
  if run:
    print(f'{len(bestLUTCovers)} Best LUT Covers (with slack {cf.slackCycleLUTLen}) passed to downstream processing.', file=sys.stderr)
  else:
    print(f'{len(bestLUTCovers)} LUT Covers passed to downstream processing AFTER ABORTING ITERATION.', file=sys.stderr)

print(repr((header,bestLUTStringLists,bestLUTAssemblies,[json_graph.node_link_data(g) for g in bestCodeGraphs],topoSchedules)))
