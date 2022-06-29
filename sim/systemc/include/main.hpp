// Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
//                    Technische Universitaet Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#ifndef MAIN_HPP_
#define MAIN_HPP_

#include "nano.hpp"
#include "imem.hpp"
#include "dmem.hpp"
#include "tb.hpp"
#include "nano_logic_vhd.h"
#include "nano_memory_vhd.h"

SC_MODULE(SYSTEM) {
  nano_ref    *nano0;
  nano_logic  *nano1;
  imem_ref    *imem0;
  dmem_ref    *dmem0;
  nano_memory *mem1;
  tb          *tb0;
  
  sc_signal<bool>                              rst_n_sig;
  sc_signal<sc_logic>                          dmem_oe_sig, dmem_oe_vhdl_sig;
  sc_signal<sc_logic>                          dmem_we_sig, dmem_we_vhdl_sig;
  sc_signal<sc_logic>                          imem_oe_sig, imem_oe_vhdl_sig, imem_we_vhdl_sig;
  sc_signal<sc_uint<NANO_D_W> >                dmem_out_sig, dmem_out_vhdl_sig;
  sc_signal<sc_uint<NANO_D_W> >                dmem_in_sig, dmem_in_vhdl_sig;
  sc_signal<sc_lv<NANO_I_W> >                  imem_out_sig, imem_out_vhdl_sig; //, imem_in_vhdl_sig;
  sc_signal<sc_lv<2*NANO_I_W> >                imem_in_vhdl_sig;
  sc_signal<sc_uint<NANO_D_ADR_W> >            dmem_addr_sig, dmem_addr_vhdl_sig;
  sc_signal<sc_uint<NANO_I_ADR_W> >            imem_addr_sig, imem_addr_vhdl_sig, imem_nano_addr_vhdl_sig;
  sc_signal<sc_uint<NANO_FUNC_OUTS*NANO_D_W> > dmem_func_sig, dmem_func_vhdl_sig;
  sc_clock                                     clk_sig;
  sc_signal<sc_logic>                          clk2_sig;
  sc_signal<sc_lv<NANO_EXT_IRQ_W> >            ext_wake_sig;

  SC_CTOR(SYSTEM): clk_sig("clk_sig", 1000000000/32768, SC_NS) {
    
    nano0 = new nano_ref("nano_ref");
    nano0->clk(clk_sig);
    nano0->rst_n(rst_n_sig);
    nano0->dmem_out(dmem_out_sig);
    nano0->imem_out(imem_out_sig);
    nano0->dmem_oe(dmem_oe_sig);
    nano0->dmem_we(dmem_we_sig);
    nano0->dmem_in(dmem_in_sig);
    nano0->dmem_addr(dmem_addr_sig);
    nano0->imem_oe(imem_oe_sig);
    nano0->imem_addr(imem_addr_sig);
    nano0->func_in(dmem_func_sig);
    nano0->wake_in(ext_wake_sig);
    
    clk2_sig.write(sc_logic('0'));
    
    nano1 = new nano_logic("nano_logic_vhdl", "nano_logic");
    nano1->clk1_i(clk_sig);
    nano1->clk2_i(clk2_sig);
    nano1->rst_n_i(rst_n_sig);
    nano1->ext_wake_i(ext_wake_sig);
    nano1->instr_i(imem_out_vhdl_sig);
    nano1->data_i(dmem_out_vhdl_sig);
    nano1->func_i(dmem_func_vhdl_sig);
    nano1->instr_oe(imem_oe_vhdl_sig);
    nano1->data_oe(dmem_oe_vhdl_sig);
    nano1->data_we(dmem_we_vhdl_sig);
    nano1->pc_o(imem_nano_addr_vhdl_sig);
    nano1->addr_o(dmem_addr_vhdl_sig);
    nano1->data_o(dmem_in_vhdl_sig);
    
    imem0 = new imem_ref("imem_ref");
    imem0->clk(clk_sig);
    imem0->imem_out(imem_out_sig);
    imem0->imem_oe(imem_oe_sig);
    imem0->imem_addr(imem_addr_sig);
    
    dmem0 = new dmem_ref("dmem_ref");
    dmem0->clk(clk_sig);
    dmem0->dmem_out(dmem_out_sig);
    dmem0->dmem_oe(dmem_oe_sig);
    dmem0->dmem_we(dmem_we_sig);
    dmem0->dmem_addr(dmem_addr_sig);
    dmem0->dmem_in(dmem_in_sig);
    dmem0->func_out(dmem_func_sig);
    
    mem1 = new nano_memory("nano_memory_vhdl", "nano_memory");
    mem1->clk1_i(clk_sig);
    mem1->clk2_i(clk2_sig);
    mem1->instr_oe(imem_oe_vhdl_sig);
    mem1->instr_we(imem_we_vhdl_sig);
    mem1->data_oe(dmem_oe_vhdl_sig);
    mem1->data_we(dmem_we_vhdl_sig);
    mem1->pc_i(imem_addr_vhdl_sig);
    mem1->addr_i(dmem_addr_vhdl_sig);
    mem1->instr_i(imem_in_vhdl_sig);
    mem1->data_i(dmem_in_vhdl_sig);
    mem1->instr_o(imem_out_vhdl_sig);
    mem1->data_o(dmem_out_vhdl_sig);
    mem1->func_o(dmem_func_vhdl_sig);

    tb0 = new tb("testbench");
    tb0->clk(clk_sig);
    tb0->rst_n(rst_n_sig);
    tb0->irq(ext_wake_sig);
    tb0->imem_oe_ref(imem_oe_sig);
    tb0->imem_oe_vhdl(imem_oe_vhdl_sig);
    tb0->imem_addr_ref(imem_addr_sig);
    tb0->imem_addr_vhdl(imem_nano_addr_vhdl_sig);
    tb0->imem_out_ref(imem_out_sig);
    tb0->imem_out_vhdl(imem_out_vhdl_sig);
    tb0->dmem_oe_ref(dmem_oe_sig);
    tb0->dmem_oe_vhdl(dmem_oe_vhdl_sig);
    tb0->dmem_we_ref(dmem_we_sig);
    tb0->dmem_we_vhdl(dmem_we_vhdl_sig);
    tb0->dmem_addr_ref(dmem_addr_sig);
    tb0->dmem_addr_vhdl(dmem_addr_vhdl_sig);
    tb0->dmem_in_ref(dmem_in_sig);
    tb0->dmem_in_vhdl(dmem_in_vhdl_sig);
    tb0->dmem_out_ref(dmem_out_sig);
    tb0->dmem_out_vhdl(dmem_out_vhdl_sig);
    tb0->dmem_func_ref(dmem_func_sig);
    tb0->dmem_func_vhdl(dmem_func_vhdl_sig);
    tb0->imem_init_en(imem_we_vhdl_sig);
    tb0->imem_addr_out(imem_addr_vhdl_sig);
    tb0->imem_data_out(imem_in_vhdl_sig);
    
  }

  ~SYSTEM() {
    delete nano0;
    delete nano1;
    delete imem0;
    delete dmem0;
    delete mem1;
    delete tb0;
  }

};

#endif /* MAIN_HPP_ */
