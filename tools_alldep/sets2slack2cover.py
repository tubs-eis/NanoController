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
import copy
import time
import signal
import networkx as nx
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
## Algorithm X in 30 lines!
## https://www.cs.mcgill.ca/~aassaf9/python/algorithm_x.html

## Algorithm X is an algorithm for solving the exact cover problem.
## The exact cover problem is represented in Algorithm X by a matrix A 
## consisting of 0s and 1s. The goal is to select a subset of the rows 
## such that the digit 1 appears in each column exactly once.

def solve(X,Y,solution=[]):                                             # Algorithm X works as follows:
  if not X:                                                             # If the matrix A has no columns, the current partial solution is a valid solution;
    yield list(solution)                                                # terminate successfully.
  else:
    if len(bestSolution[-1]) > 0:                                       # Conditional Recursion: If the cover length in this recursion branch will be worse than a previous solution (with parameterizable slack), ...
      slackBBLength = bestLength
      if bestLength in cf.slackBBDict:
        slackBBLength += cf.slackBBDict[bestLength]
      if len(solution) >= slackBBLength:                                # ... we are not interested in computing it to save runtime - return to abort recursion of this branch.
        return
    c = min(X, key=lambda c: len(X[c]))                                 # 1. Otherwise choose a column c (deterministically, minimum number of '1' entries).
    for r in list(X[c]):                                                # 2. Choose a row r such that A(r,c) = 1 (nondeterministically, selection order in A(r,c) = list(X[c]) does not matter).
      solution.append(r)                                                # 3. Include row r in the partial solution.
      cols = select(X,Y,r)                                              # 4.
      for s in solve(X,Y,solution):                                     # 5. Repeat this algorithm recursively on the reduced matrix A.
        yield s
      deselect(X,Y,r,cols)                                              # For next recursion of (2), state of X and solution is restored
      solution.pop()

def select(X,Y,r):                                                      # Auxiliary Function: Step (4) of Algorithm X
  cols = []
  for j in Y[r]:                                                        # 4. For each column j such that A(r,j) = 1, i.e., j in Y[r], ...
    for i in X[j]:                                                      #    ... for each row i such that A(i,j) = 1, i.e., i in X[j], ...
      for k in Y[i]:
        if k != j:
          X[k].remove(i)                                                #        ... delete row i from matrix A.
    cols.append(X.pop(j))                                               #    ... delete column j from matrix A.
  return cols

def deselect(X,Y,r,cols):                                               # Auxiliary Function: Revert step (4) for next recursion
  for j in reversed(Y[r]):
    X[j] = cols.pop()
    for i in X[j]:
      for k in Y[i]:
        if k != j:
          X[k].add(i)
## ---


def isLonger(graphList,curShortest):                                    # Auxiliary Function: Return if a graph list is longer than current shortest unique solution (with parameterizable slack)
  if curShortest is not None:
    if len(graphList) > (curShortest + cf.slackUniqueInsts):
      return True
  return False

def recUniquify(uniqueInsts,prevGraphList):                             # Auxiliary Function: Recursively find and uniquify identical instructions via pattern isomorphism
  global run
  if run:                                                               # Check global semaphor if we should still recur
    if len(uniqueInsts) == 0:
      yield [], prevGraphList                                           # Abort recursion when no basic blocks left to permute, return previously uniquified graph list
    else:
      curShortest = None
      for count in range(len(uniqueInsts[0])):                          # For all possible permutations of basic block with shortest instruction length:
        curGraphList = prevGraphList.copy()
        for newG in uniqueInsts[0][count]:                              # Check isomorphism of new graphs of recursion against existing old unique graph list
          for oldG in prevGraphList:
            if nx.is_isomorphic(oldG,newG,node_match=funcMatch.node_match):
              break
          else:
            curGraphList.append(newG)                                   # Only if not isomorphic to any existing graph in old list, append new graph
        if isLonger(curGraphList,curShortest):                          # Skip recursion if new unique graph list already longer than old unique list (no improvement possible)
          continue
        for perm, graphs in recUniquify(uniqueInsts[1:],curGraphList):  # Recursion
          if isLonger(graphs,curShortest):                              # Only return recursive result if not longer than existing results, update shortest unique solution if necessary
            continue
          yield [count] + perm, graphs
          if curShortest is None:
            curShortest = len(graphs)
          curShortest = min(curShortest, len(graphs))


argc = len(sys.argv)
if argc > 1:
  f = open(sys.argv[1])
else:
  f = tempfile.TemporaryFile('w+')
  f.write(sys.stdin.read())
  f.seek(0)

header, depG, isaList = ast.literal_eval(f.read())
depG = json_graph.node_link_graph(depG)
f.close()


origISAList = [bbList.copy() for bbList in isaList]
for bb, isa in enumerate(origISAList):                                  # Pass 0: Pre-condition possible ISA instructions (multi-cycle constraint, immediate nodes needing successor, ldMem needing successor due to CW logic bug)
  for nodeset in isa:
    if len(nodeset) > cf.constraintCyclesPerInst:                       # Abort criterion: Pattern length exceeding multi-cycle constraint?
      isaList[bb].remove(nodeset)
      continue
    sg = nx.subgraph(depG,nodeset)
    for node in nodeset:
      useAttr = sg.nodes[node]['use']                                   # Abort criterion: Patterns with immediate node not having a successor are discarded
      opAttr = sg.nodes[node]['opcode']                                 # Abort criterion: Patterns with ldMem node not having a successor are discarded (CW logic bug in NanoController v2)
      if useAttr == {'#'} or opAttr == 'ldMem':
        if len([i for i in sg.successors(node)]) == 0:
          isaList[bb].remove(nodeset)
          break
      if cf.constraintSleepSeparate:
        if opAttr == 'sleep' and len(nodeset) > 1:                      # Abort criterion: Allow sleep only to be an exclusive instruction (improves ISA quality for reference applications)
          isaList[bb].remove(nodeset)
          break


X = []
Y = []
bestSolution = []
for bb, isa in enumerate(isaList):                                      # Pass 1: Find shortest instruction covers for each basic block ISA
  X.append(set())
  for cand in isa:                                                      # Universe X is all nodes in BB that can be covered by ISA
    X[-1].update(cand)
  Y.append({i : list(j) for i,j in enumerate(isa)})                     # Y is basic block ISA dictionary
  X[-1] = {j : set() for j in X[-1]}                                    # Reshape the input X according to:
  for i in Y[-1]:                                                       # https://www.cs.mcgill.ca/~aassaf9/python/algorithm_x.html
    for j in Y[-1][i]:
      X[-1][j].add(i)
  bestSolution.append([])
  bestLength = 0
  for cover in solve(X[-1],Y[-1]):                                      # Iteratively solve Algorithm X to find shortest instruction covers
    if len(bestSolution[-1]) == 0:
      bestLength = len(cover)
    bestLength = min(bestLength, len(cover))
    bestSolution[-1].append(cover)
  origBestSolution = bestSolution[-1].copy()
  slackBBLength = bestLength
  if bestLength in cf.slackBBDict:
    slackBBLength += cf.slackBBDict[bestLength]
  for cover in origBestSolution:                                        # Prune solutions to shortest instruction cover (with parameterizable slack)
    if len(cover) > slackBBLength:
      bestSolution[-1].remove(cover)
  if cf.debugStdErr:
    print(X[-1], file=sys.stderr)
    print(Y[-1], file=sys.stderr)
    print(bestSolution[-1], file=sys.stderr)
    print(f'BB {bb}: There are {len(bestSolution[-1])} Shortest Instruction Covers (min. {bestLength}, max. {slackBBLength} instructions) with max. {cf.constraintCyclesPerInst} cycles per instruction.', file=sys.stderr)


uniqueInsts = []
for bb, block in enumerate(bestSolution):                               # Pass 2: Find number of unique instructions for each shortest basic block instruction cover
  uniqueInsts.append([])
  for cover in block:                                                   # Analyze for each cover permutation with shortest instruction length
    uniqueInsts[-1].append([])
    subGraphList = []
    for subg in cover:                                                  # Collect dependency subgraphs of instructions in match to identify identical patterns via isomorphism
      subGraphList.append(depG.subgraph(Y[bb][subg]))                   # Generate flattened list of all dependency subgraphs of instructions
    while len(subGraphList) > 0:                                        # As long as there are still instructions to be matched:
      tmpGraph = subGraphList.pop(0)                                    # - Get one instruction
      tmpGraphList = subGraphList.copy()
      for subg in tmpGraphList:                                         # - Match with each other still existing instruction
        if nx.is_isomorphic(tmpGraph,subg,node_match=funcMatch.node_match):
          subGraphList.remove(subg)                                     # - If matching, remove match from subgraph list
      uniqueInsts[-1][-1].append(tmpGraph)                              # - When all duplicates are removed, append instruction to unique list


signal.signal(signal.SIGUSR1, handlerSolutionsNow)                      # Register signal handlers for global semaphor
signal.signal(signal.SIGUSR2, handlerSolutionsNow)
bestCovers = []
bestGraphs = []
bestUnique = 0
iterCnt = 0
for perm, graphs in recUniquify(uniqueInsts,[]):                        # Pass 3: Iteratively generate total program covers with lowest number of unique instructions (with parameterizable slack)
  if len(bestGraphs) == 0:
    bestUnique = len(graphs)
  if len(graphs) < bestUnique:                                          # If a new lowest number of unique instructions is achieved, prune bestCovers / bestGraphs with parameterizable slack
    bestUnique = len(graphs)
    prunePtr = 0
    while prunePtr < len(bestCovers):
      if len(bestGraphs[prunePtr]) > (bestUnique + cf.slackUniqueInsts):
        bestCovers.pop(prunePtr)
        bestGraphs.pop(prunePtr)
      else:
        prunePtr += 1
  bestCovers.append([])                                                 # Append recent found solution to lists for downstream passing, remove original source line & immediate values
  bestGraphs.append([copy.deepcopy(i) for i in graphs])
  for g in bestGraphs[-1]:
    for node in g.nodes:
      g.nodes[node].pop('srcline')
      g.nodes[node].pop('imm')
  for bb, permidx in enumerate(perm):
    bestCovers[-1].extend([sorted(Y[bb][i],key=lambda x: str(x).rjust(len(str(len(depG.nodes))))) for i in bestSolution[bb][permidx]])
  if cf.debugStdErr:
    print(f'{time.strftime("%Y-%m-%d %H:%M:%S")} - {iterCnt}: {bestCovers[-1]}: {len(bestCovers[-1])} Total Instructions, {len(bestGraphs[-1])} Unique Instructions.', file=sys.stderr)
    iterCnt += 1


if cf.debugStdErr:
  if run:
    print(f'{len(bestCovers)} Best Covers (with slack) passed to downstream processing.', file=sys.stderr)
  else:
    print(f'{len(bestCovers)} Covers passed to downstream processing AFTER ABORTING RECURSION.', file=sys.stderr)

print(repr((header,json_graph.node_link_data(depG),bestCovers,[[json_graph.node_link_data(j) for j in i] for i in bestGraphs])))
