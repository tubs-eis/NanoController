// Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
//                    Technische Universitaet Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#ifndef NANO_HPP_
#define NANO_HPP_

#include <systemc.h>
#include "../../../config/nanodefs.h"

SC_MODULE(nano_ref) {
  sc_in_clk                                clk;
  sc_in<bool>                              rst_n;
  sc_in<sc_uint<NANO_D_W> >                dmem_out;
  sc_in<sc_lv<NANO_I_W> >                  imem_out;
  sc_in<sc_uint<NANO_FUNC_OUTS*NANO_D_W> > func_in;
  sc_in<sc_lv<NANO_EXT_IRQ_W> >            wake_in;
  sc_out<sc_logic>                         dmem_oe, dmem_we;
  sc_out<sc_uint<NANO_D_W> >               dmem_in;
  sc_out<sc_uint<NANO_D_ADR_W> >           dmem_addr;
  sc_out<sc_logic>                         imem_oe;
  sc_out<sc_uint<NANO_I_ADR_W> >           imem_addr;

  sc_uint<NANO_I_ADR_W> pc;
  sc_uint<NANO_D_W>     accu, opb;
  sc_uint<1>            carry;
  bool                  zero, concat;
  sc_uint<NANO_D_ADR_W> memptr;
  sc_lv<NANO_I_W>       ir;
  
  sc_uint<FUNC_RTC_CNT_W> rtc_cnt;
  sc_uint<NANO_D_W>       rtc_param;
  bool                    rtc_wake, rtc_unconf;
  
  bool ext_wake;

  int  min(int a, int b);
  void branch_pc(int offset);
  void set_accu(unsigned int result);
  void func();
  void func_rtc_seq();
  void func_rtc_comb();
  void func_ext_seq();

  SC_CTOR(nano_ref) {
    SC_CTHREAD(func, clk.pos());
    async_reset_signal_is(rst_n,false);
    SC_METHOD(func_rtc_comb);
    sensitive << func_in;
    SC_CTHREAD(func_rtc_seq, clk.pos());
    SC_CTHREAD(func_ext_seq, clk.pos());
  }
};

#endif /* NANO_HPP_ */
