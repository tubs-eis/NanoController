/**********************************************************************
axasm Copyright 2006, 2007, 2008, 2009 
by Al Williams (alw@al-williams.com).

NanoController Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
                                  TU Braunschweig, Germany
                                  www.tu-braunschweig.de/en/eis


This file is part of axasm.

axasm is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public Licenses as published
by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

axasm is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY: without even the implied warranty of 
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the 
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with axasm (see LICENSE.TXT). 
If not, see http://www.gnu.org/licenses/.

If a non-GPL license is desired, contact the author.

This is the NanoController definition file

***********************************************************************/
#ifndef _SOLO_ASM_INC
#define _SOLO_ASM_INC
#include <stdio.h>
#include <stdlib.h>
#include <soloasm.h>
#include "../config/nanodefs.h"

// We assume the first ORG is the lowest address
#define ORG(n) unsigned int genasm(int _solo_pass) { \
   unsigned _solo_add=n;\
   _solo_info.psize=8; \
   _solo_info.begin=n; \
   _solo_info.memsize=(1<<NANO_I_ADR_W)-1; \
   _solo_info.ary=malloc(sizeof(int)*_solo_info.memsize)


#define REORG(n) _solo_add=n;
#define END _solo_info.end=_solo_add-1; return _solo_add; }

#define DEFLABEL(lb) static unsigned lb
#define LABEL(lb) lb=_solo_add

#define DMASK ((1<<NANO_I_W)-1)
#define DB(n) _solo_info.ary[_solo_add++]=(n&DMASK)


#define VAR_MACRO(_1,_2,_3,NAME,...) NAME
#define ARG1(a1)                  DB(a1&(DMASK>>1))
//#define ARG2(a1,a2)               DB(((DMASK>>1)+1)|(a1&(DMASK>>1))); DB(a2&(DMASK>>1))
//#define ARG2(a1,a2)               DB(((DMASK>>1)+1)|(a1&(DMASK>>1))); DB(a2)
#define ARG2(a1,a2)               DB(((DMASK>>1)+1)|(a1&(DMASK>>1))); DB(a2&(DMASK>>1))
#define ARG3(a1,a2,a3)            DB(((DMASK>>1)+1)|(a1&(DMASK>>1))); DB(((DMASK>>1)+1)|(a2&(DMASK>>1))); DB(a3&(DMASK>>1))
#define BRANCH1(t1)               DB((t1-_solo_add-1)&(DMASK>>1))
#define BRANCH2(t1,t2)            DB(((DMASK>>1)+1)|((t1-_solo_add-2)&(DMASK>>1))); DB(((t2-_solo_add-1)>>(NANO_I_W-1))&(DMASK>>1))
#define BRANCH3(t1,t2,t3)         DB(((DMASK>>1)+1)|((t1-_solo_add-3)&(DMASK>>1))); DB(((DMASK>>1)+1)|(((t2-_solo_add-2)>>(NANO_I_W-1))&(DMASK>>1))); DB(((t3-_solo_add-1)>>(2*(NANO_I_W-1)))&(DMASK>>1))
//#define BRANCH2(t1,t2)            DB(((DMASK>>1)+1)|((t1-_solo_add-2)&(DMASK>>1))); DB(((t2-_solo_add-1)>>(NANO_I_W-1)))

