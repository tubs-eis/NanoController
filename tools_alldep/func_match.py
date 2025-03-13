#!/bin/python3
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

def node_match(attr1,attr2):                                            # Auxiliary Function: Node match for isomorphism test of dependency subgraphs
  for attr in {'opcode','def','use'}:                                   # Opcode, Def, and Use fields must be identical in order for nodes to match
    if attr1[attr] != attr2[attr]:
      return False
  return True
