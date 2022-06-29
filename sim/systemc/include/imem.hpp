// Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
//                    Technische Universitaet Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#ifndef IMEM_HPP_
#define IMEM_HPP_

#include <systemc.h>
#include <iostream>
#include "../../../config/nanodefs.h"

#ifndef IMEM_IMAGE_H_
#define IMEM_IMAGE_H_
#include "imem_image.h"
#endif

SC_MODULE(imem_ref) {
  sc_in_clk                     clk;
  sc_out<sc_lv<NANO_I_W> >      imem_out;
  sc_in<sc_logic>               imem_oe;
  sc_in<sc_uint<NANO_I_ADR_W> > imem_addr;

  int min(int a, int b);
  void func();
  void addrchk();

  SC_CTOR(imem_ref) {
    SC_METHOD(func);
    sensitive << imem_addr;
    SC_CTHREAD(addrchk, clk.pos());
  }
};

#endif /* IMEM_HPP_ */
