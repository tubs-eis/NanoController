// Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
//                    Technische Universitaet Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#ifndef TB_HPP_
#define TB_HPP_

#include <cstdlib>
#include <systemc.h>
#include "../../../config/nanodefs.h"

#ifndef IMEM_IMAGE_H_
#define IMEM_IMAGE_H_
#include "imem_image.h"
#endif

SC_MODULE(tb) {
  sc_in_clk                      clk;
  sc_out<bool>                   rst_n;
  sc_out<sc_lv<NANO_EXT_IRQ_W> > irq;
  
  sc_in<sc_logic>                          imem_oe_ref, imem_oe_vhdl;
  sc_in<sc_uint<NANO_I_ADR_W> >            imem_addr_ref, imem_addr_vhdl;
  sc_in<sc_lv<NANO_I_W> >                  imem_out_ref, imem_out_vhdl;
  sc_in<sc_logic>                          dmem_oe_ref, dmem_oe_vhdl;
  sc_in<sc_logic>                          dmem_we_ref, dmem_we_vhdl;
  sc_in<sc_uint<NANO_D_ADR_W> >            dmem_addr_ref, dmem_addr_vhdl;
  sc_in<sc_uint<NANO_D_W> >                dmem_in_ref, dmem_in_vhdl;
  sc_in<sc_uint<NANO_D_W> >                dmem_out_ref, dmem_out_vhdl;
  sc_in<sc_uint<NANO_FUNC_OUTS*NANO_D_W> > dmem_func_ref, dmem_func_vhdl;
  sc_out<sc_logic>                         imem_init_en;
  sc_out<sc_uint<NANO_I_ADR_W> >           imem_addr_out;
  //sc_out<sc_lv<NANO_I_W> >                 imem_data_out;
  sc_out<sc_lv<2*NANO_I_W> >               imem_data_out;
  
  bool initflag;

  void imem_addr_mux();
  void testbench();

  SC_CTOR(tb) {
    srand(1);
    SC_THREAD(testbench);
    sensitive << clk.pos();
    SC_METHOD(imem_addr_mux);
    sensitive << imem_addr_vhdl;
  }
};

#endif /* TB_HPP_ */
