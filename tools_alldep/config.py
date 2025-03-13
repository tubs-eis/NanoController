#!/bin/python3
## Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
##                    TU Braunschweig, Germany
##                    www.tu-braunschweig.de/en/eis
##
## Use of this source code is governed by an MIT-style
## license that can be found in the LICENSE file or at
## https://opensource.org/licenses/MIT.

## Toggles for debugging output to stderr
debugStdErr  = True

## Encoding properties for NanoController
cLUTRemoveInnerIMEMCycles = True
schgLUTBaseAddrBits = 5
schgLUTCycodeBits = 3

## NanoController constraints
constraintSleepSeparate = True
constraintCyclesPerInst = 6
constraintISALen = 16
constraintStepGroups = 6
constraintCycleLUTLen = 21
constraintImemNibbles = 480

# VANAGA config (imported as sub-package in some tools, for opcode encoding optimization)
bitlength = 4
population_size = 150
maximum_generation = 5000
mutation_rate = 0.85
tracked_fitness = 'min_metric'  # min_metric or max_metric
best_individuals_number = 2  # Choose percentage of elitism population
fitness_remove_immediates = False  # Should immediate values in IMEM stream be considered?

## DSE slack
slackBBDict = {}
#slackBBDict = {1: 1, 2: 2, 3: 1}
slackUniqueInsts = 0
slackCycleLUTLen = 0

## Definition of data dependency nodes for manual NanoController instructions
dataDepBB =           {'opcode' : 'bb',    'imm' : '', 'def' : {'OPB','ACCU','Z','MEMPTR','MEM'}, 'use' : {}}
dataDep = {'ORG'   : [dataDepBB],
           'LDI'   : [{'opcode' : 'ldImm', 'imm' : '', 'def' : {'OPB'},                           'use' : {'#'}},
                      {'opcode' : 'mvAcc', 'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'OPB'}}],
           'CMPI'  : [{'opcode' : 'ldImm', 'imm' : '', 'def' : {'OPB'},                           'use' : {'#'}},
                      {'opcode' : 'cmp',   'imm' : '', 'def' : {'Z'},                             'use' : {'ACCU','OPB'}}],
           'ADDI'  : [{'opcode' : 'ldImm', 'imm' : '', 'def' : {'OPB'},                           'use' : {'#'}},
                      {'opcode' : 'add',   'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'ACCU','OPB'}}],
           'SUBI'  : [{'opcode' : 'ldImm', 'imm' : '', 'def' : {'OPB'},                           'use' : {'#'}},
                      {'opcode' : 'sub',   'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'ACCU','OPB'}}],
           'LIS'   : [{'opcode' : 'ldPtr', 'imm' : '', 'def' : {'MEMPTR'},                        'use' : {'#'}},
                      {'opcode' : 'ldMem', 'imm' : '', 'def' : {'OPB'},                           'use' : {'MEMPTR','MEM'}},
                      {'opcode' : 'mvAcc', 'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'OPB'}},
                      {'opcode' : 'inc',   'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'ACCU','1'}},
                      {'opcode' : 'stMem', 'imm' : '', 'def' : {'MEM'},                           'use' : {'MEMPTR','ACCU'}}],
           'LISL'  : [{'opcode' : 'ldMem', 'imm' : '', 'def' : {'OPB'},                           'use' : {'MEMPTR','MEM'}},
                      {'opcode' : 'mvAcc', 'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'OPB'}},
                      {'opcode' : 'inc',   'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'ACCU','1'}},
                      {'opcode' : 'stMem', 'imm' : '', 'def' : {'MEM'},                           'use' : {'MEMPTR','ACCU'}}],
           'LDS'   : [{'opcode' : 'ldPtr', 'imm' : '', 'def' : {'MEMPTR'},                        'use' : {'#'}},
                      {'opcode' : 'ldMem', 'imm' : '', 'def' : {'OPB'},                           'use' : {'MEMPTR','MEM'}},
                      {'opcode' : 'mvAcc', 'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'OPB'}},
                      {'opcode' : 'dec',   'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'ACCU','1'}},
                      {'opcode' : 'stMem', 'imm' : '', 'def' : {'MEM'},                           'use' : {'MEMPTR','ACCU'}}],
           'LDSL'  : [{'opcode' : 'ldMem', 'imm' : '', 'def' : {'OPB'},                           'use' : {'MEMPTR','MEM'}},
                      {'opcode' : 'mvAcc', 'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'OPB'}},
                      {'opcode' : 'dec',   'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'ACCU','1'}},
                      {'opcode' : 'stMem', 'imm' : '', 'def' : {'MEM'},                           'use' : {'MEMPTR','ACCU'}}],
           'DBNE'  : [{'opcode' : 'ldLbl', 'imm' : '', 'def' : {'OPB'},                           'use' : {'#'}},
                      {'opcode' : 'dec',   'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'ACCU','1'}},
                      {'opcode' : 'bcond', 'imm' : '', 'def' : {'OPB','ACCU','Z','MEMPTR','MEM'}, 'use' : {'Z','OPB'}}],
           'BNE'   : [{'opcode' : 'ldLbl', 'imm' : '', 'def' : {'OPB'},                           'use' : {'#'}},
                      {'opcode' : 'bcond', 'imm' : '', 'def' : {'OPB','ACCU','Z','MEMPTR','MEM'}, 'use' : {'Z','OPB'}}],
           'CST'   : [{'opcode' : 'ldPtr', 'imm' : '', 'def' : {'MEMPTR'},                        'use' : {'#'}},
                      {'opcode' : 'clAcc', 'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'0'}},
                      {'opcode' : 'stMem', 'imm' : '', 'def' : {'MEM'},                           'use' : {'MEMPTR','ACCU'}}],
           'CSTL'  : [{'opcode' : 'clAcc', 'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'0'}},
                      {'opcode' : 'stMem', 'imm' : '', 'def' : {'MEM'},                           'use' : {'MEMPTR','ACCU'}}],
           'ST'    : [{'opcode' : 'ldPtr', 'imm' : '', 'def' : {'MEMPTR'},                        'use' : {'#'}},
                      {'opcode' : 'stMem', 'imm' : '', 'def' : {'MEM'},                           'use' : {'MEMPTR','ACCU'}}],
           'STL'   : [{'opcode' : 'stMem', 'imm' : '', 'def' : {'MEM'},                           'use' : {'MEMPTR','ACCU'}}],
           'LD'    : [{'opcode' : 'ldPtr', 'imm' : '', 'def' : {'MEMPTR'},                        'use' : {'#'}},
                      {'opcode' : 'ldMem', 'imm' : '', 'def' : {'OPB'},                           'use' : {'MEMPTR','MEM'}},
                      {'opcode' : 'mvAcc', 'imm' : '', 'def' : {'ACCU','Z'},                      'use' : {'OPB'}}],
           'SLEEP' : [{'opcode' : 'sleep', 'imm' : '', 'def' : {'OPB','ACCU','Z','MEMPTR','MEM'}, 'use' : {}}]}

## CW Identifiers, Cycle LUT Correspondence for Node Opcodes
cwID = {'IMEM_CYCLE'     : '0000',
        'DMEM_CYCLE'     : '0001',
        'OPB_FROM_MEM'   : '0010',
        'MEM_FROM_ACCU'  : '0011',
        'CMP_ACCU_OPB'   : '0100',
        'ACCU_PLUS_OPB'  : '0101',
        'ACCU_MINUS_OPB' : '0110',
        'ACCU_FROM_OPB'  : '0111',
        'ACCU_ZERO'      : '1000',
        'ACCU_PLUS_ONE'  : '1001',
        'ACCU_MINUS_ONE' : '1010',
        'BRANCH'         : '1011',
        'WAKE'           : '1100'}
cycleLUTNames = {'ldImm' : [],
                 'ldPtr' : [],
                 'ldLbl' : [],
                 'ldMem' : ['DMEM_CYCLE', 'OPB_FROM_MEM'],
                 'stMem' : ['MEM_FROM_ACCU', 'IMEM_CYCLE'],
                 'clAcc' : ['ACCU_ZERO'],
                 'mvAcc' : ['ACCU_FROM_OPB'],
                 'cmp'   : ['CMP_ACCU_OPB'],
                 'add'   : ['ACCU_PLUS_OPB'],
                 'sub'   : ['ACCU_MINUS_OPB'],
                 'inc'   : ['ACCU_PLUS_ONE'],
                 'dec'   : ['ACCU_MINUS_ONE'],
                 'bcond' : ['BRANCH'],
                 'sleep' : ['WAKE']}
cycleLUTCodes = {'ldImm' : [],
                 'ldPtr' : [],
                 'ldLbl' : [],
                 'ldMem' : [cwID['DMEM_CYCLE'], cwID['OPB_FROM_MEM']],
                 'stMem' : [cwID['MEM_FROM_ACCU'], cwID['IMEM_CYCLE']],
                 'clAcc' : [cwID['ACCU_ZERO']],
                 'mvAcc' : [cwID['ACCU_FROM_OPB']],
                 'cmp'   : [cwID['CMP_ACCU_OPB']],
                 'add'   : [cwID['ACCU_PLUS_OPB']],
                 'sub'   : [cwID['ACCU_MINUS_OPB']],
                 'inc'   : [cwID['ACCU_PLUS_ONE']],
                 'dec'   : [cwID['ACCU_MINUS_ONE']],
                 'bcond' : [cwID['BRANCH']],
                 'sleep' : [cwID['WAKE']]}

## State Change LUT Generation
schgBaseField = 'BaseAddr'
schgCycodeField = 'Cycode'
schgLUTOrder = ['RegFetch', 'OpbFetch', 'Branch', 'Wake', schgBaseField, schgCycodeField]
schgLUTEncLength = {schgBaseField : schgLUTBaseAddrBits, schgCycodeField : schgLUTCycodeBits}
schgDefault = {'RegFetch' : '0', 'OpbFetch' : '0', 'Branch' : '0', 'Wake' : '0'}
schgModifiers = {'ldImm' : {'RegFetch' : '1', 'OpbFetch' : '1'},
                 'ldPtr' : {'RegFetch' : '1', 'OpbFetch' : '0'},
                 'ldLbl' : {'RegFetch' : '1', 'OpbFetch' : '1'},
                 'ldMem' : {},
                 'stMem' : {},
                 'clAcc' : {},
                 'mvAcc' : {},
                 'cmp'   : {},
                 'add'   : {},
                 'sub'   : {},
                 'inc'   : {},
                 'dec'   : {},
                 'bcond' : {'Branch' : '1'},
                 'sleep' : {'Wake' : '1'}}

## Table Assembler Definition Include File Modifiers
asmMods = {'ldImm' : ['(...)', '; VAR_MACRO(__VA_ARGS__,ARG3,ARG2,ARG1)(__VA_ARGS__)'],
           'ldPtr' : ['(a1)', '; DB(a1)'],
           'ldLbl' : ['(...)', '; VAR_MACRO(__VA_ARGS__,BRANCH3,BRANCH2,BRANCH1)(__VA_ARGS__)']}
