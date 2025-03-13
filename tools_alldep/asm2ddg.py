#!/bin/python3
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

import sys
import copy
import tempfile
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


argc = len(sys.argv)
if argc > 1:
  f = open(sys.argv[1])
else:
  f = tempfile.TemporaryFile('w+')
  f.write(sys.stdin.read())
  f.seek(0)


blocklist = []
injectBB = False
header = ''
headerDone = False
for line in f:                                                          # Pass 1: Read ASM source file line by line and build node list with dependencies
  tokens = line.split(';')[0].strip().split()                           # Tokenize input line, separated by whitespaces
  if len(tokens) == 0:
    continue                                                            # if tokens empty, continue with next line
  token = tokens[0]
  if token[-1] == ':':                                                  # Special case: If token ends with :, it is a label (new block)
    node = copy.deepcopy(cf.dataDepBB)
    node['imm'] = token[:-1]
    blocklist.append([node])
    injectBB = False
  elif token in cf.dataDep:                                             # else Trivial case: If token is found in data dependency node dictionary, add nodes to list
    headerDone = True
    for node in cf.dataDep[token]:
      node = copy.deepcopy(node)
      node['srcline'] = " ".join(tokens)                                # include original source line for listings and traceback
      if node['opcode'] == 'bb':                                        # if explicit basic block node, add and continue with next node
        blocklist.append([node])
        continue
      if injectBB:                                                      # if implicit basic block node needs to be injected after control flow node, do it here
        bbnode = copy.deepcopy(cf.dataDepBB)
        blocklist.append([bbnode])
      blocklist[-1].append(node)                                        # Trivial addition of new node to list
      injectBB = False
      if node['opcode'] == 'bcond' or node['opcode'] == 'sleep':        # mark injection of implicit basic block node after control flow node
        injectBB = True
      if '#' in node['use']:
        node['imm'] = " ".join(tokens[1:])                              # include original immediate definition when literal value is used in node
  if not headerDone:
    header += line                                                      # pass original file header for variable defines before first token (ORG)
f.close()


blockedges = []
nodenum = 0
for block in blocklist:                                                 # Pass 2: Analyze dependencies by tracking def-use, use-def and def-def, and build edge list
  defs = {}
  uses = {}
  for node in block:
    nodenum += 1                                                        # update current node number
    if node['opcode'] == 'bb':                                          # update current basic block, if necessary
      blockedges.append([])
    for regname in node['use']:                                         # append edges for def-use dependencies
      appendDepEdgesFrom(defs)
    for regname in node['def']:                                         # append edges for use-def and def-def dependencies
      appendDepEdgesFrom(uses)
      appendDepEdgesFrom(defs)
    addNodeStatesTo(uses,'use')                                         # update defs and uses with current node
    addNodeStatesTo(defs,'def')


print(repr((header,blocklist,blockedges)))
