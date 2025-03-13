// Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
//                    TU Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#ifndef DMEM_HPP_
#define DMEM_HPP_

#include <systemc.h>
#include "../../../config/nanodefs.h"

SC_MODULE(dmem_ref) {
  sc_in_clk                                    clk;
  sc_out<sc_uint<NANO_D_W> >                   dmem_out;
  sc_in<sc_logic>                              dmem_oe, dmem_we;
  sc_in<sc_uint<NANO_D_ADR_W> >                dmem_addr;
  sc_in<sc_uint<NANO_D_W> >                    dmem_in;
  sc_out<sc_biguint<NANO_FUNC_OUTS*NANO_D_W> > func_out;
  
  sc_uint<NANO_D_W>                         dmem[1 << NANO_D_ADR_W];

  void func();

	SC_CTOR(dmem_ref) {
    SC_CTHREAD(func, clk.pos());
	}
};

#endif /* DMEM_HPP_ */
