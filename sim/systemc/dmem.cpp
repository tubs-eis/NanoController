// Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
//                    TU Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#include "include/dmem.hpp"

void dmem_ref::func() {
  while(true) {
    wait();
    unsigned int addr = dmem_addr.read().to_uint();
    if((dmem_oe.read() == '1') && (addr < (1 << NANO_D_ADR_W))) 
      dmem_out.write(dmem[addr]);
    if(dmem_we.read() == '1') {
      dmem[addr] = dmem_in.read();
      if(addr >= ((1 << NANO_D_ADR_W) - NANO_FUNC_OUTS)) {
        int i;
        sc_biguint<NANO_FUNC_OUTS*NANO_D_W> tmp;
        for(i = 0; i < NANO_FUNC_OUTS; i++)
          tmp.range((i+1)*NANO_D_W-1,i*NANO_D_W) = dmem[(1 << NANO_D_ADR_W) - NANO_FUNC_OUTS + i];
        func_out.write(tmp);
      }
    }
  }
}

SC_MODULE_EXPORT(dmem_ref);
