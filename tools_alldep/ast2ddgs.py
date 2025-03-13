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


def appendDepEdgesFrom(fromdict):                                       # Auxiliary Function: Append dependency edges for 'regname' in 'fromdict' to current node nodenum
  if regname in fromdict:
    for prevnode in fromdict[regname]:
      blockedges[-1].append((prevnode,nodenum))

def addNodeStatesTo(todict,state):                                      # Auxiliary Function: Update 'todict' with registers from 'state' of current 'node'
  for regname in node[state]:
    if regname not in todict:
      todict[regname] = set()
    todict[regname].add(nodenum)

def recBlockPerm(fencedBB,bbList):                                      # Auxiliary Function: Recursively permute a basic block with node fences in AST input
  if len(fencedBB) == 0:
    yield bbList
  elif type(fencedBB[0]) is dict:                                       # Fixed nodes have dictionary type, just pass to next recursion (no permutation)
    for i in recBlockPerm(fencedBB[1:],bbList+[fencedBB[0]]):
      yield i
  else:                                                                 # If a list is found instead (node fence), start a separate recursion for each permutation
    if type(fencedBB[0][0]) is dict:                                    # Last level of hierarchy of the node fence, forward fixed nodes and recur
      for i in recBlockPerm(fencedBB[0]+fencedBB[1:],bbList):
        yield i
    else:                                                               # Permutation block found! For each element, forward it and recur on remaining elements
      for j in fencedBB[0]:                                             # to get all possible permutations
        rest = fencedBB[0].copy()
        rest.remove(j)
        if len(rest) > 0:
          newFencedBB = [j]+[rest]+fencedBB[1:]
        else:
          newFencedBB = [j]+fencedBB[1:]                                # do not include empty rest of a completely handled permutation block
        for i in recBlockPerm(newFencedBB,bbList):
          yield i

def recBlockLists(bbPerms,solution):                                    # Auxiliary Function: Recursively get all block lists of DDG permutations
  if len(bbPerms) == 0:
    yield solution
  else:
    for j in bbPerms[0]:
      for i in recBlockLists(bbPerms[1:],solution+[j]):
        yield i


argc = len(sys.argv)
if argc > 2:
  f = open(sys.argv[1])
  outname = sys.argv[2]
elif argc > 1:
  f = tempfile.TemporaryFile('w+')
  f.write(sys.stdin.read())
  f.seek(0)
  outname = sys.argv[1]


## Remove specific characters from a string in Python
## https://stackoverflow.com/questions/3939361/remove-specific-characters-from-a-string-in-python
header, fencedBlocklist = ast.literal_eval(f.read().translate(str.maketrans('','','\n')))
f.close()


bbPerms = []
for bb in fencedBlocklist:                                              # Pass 1: Generate all basic block permutations by considering node fences in AST input
  bbPerms.append([i for i in recBlockPerm(bb,[])])

if cf.debugStdErr:
  print([len(i) for i in bbPerms], file=sys.stderr)


ddgcnt = 0
blocklistOut = []
blockedgesOut = []
for blocklist in recBlockLists(bbPerms,[]):                             # Pass 2: Generate output for each DDG block list
  blockedges = []
  nodenum = 0
  for block in blocklist:                                               # Analyze dependencies by tracking def-use, use-def and def-def, and build edge list
    defs = {}
    uses = {}
    for node in block:
      nodenum += 1                                                      # update current node number
      if node['opcode'] == 'bb':                                        # update current basic block, if necessary
        blockedges.append([])
      else:
        node['srcline'] = ''                                            # for backward compatibility with older tools
      for regname in node['use']:                                       # append edges for def-use dependencies
        appendDepEdgesFrom(defs)
      for regname in node['def']:                                       # append edges for use-def and def-def dependencies
        appendDepEdgesFrom(uses)
        appendDepEdgesFrom(defs)
      addNodeStatesTo(uses,'use')                                       # update defs and uses with current node
      addNodeStatesTo(defs,'def')
  blocklistOut.append(blocklist)                                        # collect output of each DDG block list
  blockedgesOut.append(blockedges)
  ddgcnt += 1

for t in range(ddgcnt):                                                 # Pass 3: Generate output files for each DDG
  with open(f"{outname}{t:0{len(str(ddgcnt))}}.ddg", "w") as outf:
    print(repr((header,blocklistOut[t],blockedgesOut[t])), file=outf)

if cf.debugStdErr:
  print(f'{ddgcnt} DDG permutations generated.', file=sys.stderr)
