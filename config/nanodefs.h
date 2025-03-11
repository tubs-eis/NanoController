// Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
//                    TU Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#ifndef NANODEFS_H_
#define NANODEFS_H_

// Interrupt Ports
#define NANO_IRQ_W     4
#define NANO_EXT_IRQ_W (NANO_IRQ_W-1)


// Datapath & Data Memory
//#define NANO_D_W     7
#define NANO_D_W     9
#define NANO_D_ADR_W 4


// Functional Memory
#define NANO_FUNC_OUTS (NANO_IRQ_W+4)

#define FUNC_RTC_CNT_W 19


// Encoding & Instruction Memory
#define NANO_I_W     4
#define NANO_I_ADR_W 9

#define OP_LDI   0
#define OP_CMPI  1
#define OP_ADDI  2
#define OP_SUBI  3
#define OP_LIS   4
#define OP_LISL  5
#define OP_LDS   6
#define OP_LDSL  7
#define OP_DBNE  8
#define OP_BNE   9
#define OP_CST   10
#define OP_CSTL  11
#define OP_ST    12
#define OP_STL   13
#define OP_LD    14
#define OP_SLEEP 15


#endif /* NANODEFS_H_ */
