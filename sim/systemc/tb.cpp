// Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
//                    Technische Universitaet Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#include "include/tb.hpp"

void tb::imem_addr_mux() {
  if(!initflag) imem_addr_out.write(imem_addr_vhdl.read());
}

void tb::testbench() {
  
  int        i;
  int        prox_cnt = (rand()%4096) + 2048;
  int        rtc_cnt  = 0;
  bool       prox_on = false;
  sc_uint<3> nano_func_prev;
  sc_lv<3>   irq_int = "000";
  
  // Reset sequence
  rst_n.write(false);
  irq.write(irq_int);
  initflag = true;
  imem_init_en.write(sc_logic('0'));
  wait();
  wait();
  
  // Initialize VHDL IMEM
  //imem_init_en.write(sc_logic('1'));
  //for(i=0; i<(sizeof(imem_image)/sizeof(imem_image[0])); i++) {
  //  imem_addr_out.write(i);
  //  imem_data_out.write(imem_image[i]);
  //  wait();
  //}
  // Initialize VHDL IMEM (with inertial delay to account for delayed gated clock in IMEM)
  wait(100, SC_NS);
  imem_init_en.write(sc_logic('1'));
  for(i=0; i<(sizeof(imem_image)/sizeof(imem_image[0])); i+=2) {
    imem_addr_out.write(i);
    if((i+2)>(sizeof(imem_image)/sizeof(imem_image[0])))
      imem_data_out.write(imem_image[i] << 4);
    else
      imem_data_out.write((imem_image[i] << 4) + imem_image[i+1]);
    wait();
    wait(100, SC_NS);
  }
  initflag = false;
  imem_init_en.write(sc_logic('0'));
  imem_addr_out.write(0);
  
  // Remove Reset
  wait();
  wait();
  rst_n.write(true);
  i = 65536;
  
  while(i--) {
    
    // Generating random interrupt events
    if(!prox_cnt--) {
      if(prox_on) {
        prox_on = false;
        prox_cnt = (rand()%32768) + 44032;
        irq_int[2] = '0';
        irq.write(irq_int);
      } else {
        prox_on = true;
        prox_cnt = (rand()%8192) + 8192;
        irq_int[2] = '1';
        irq.write(irq_int);
        cout << "[TB]   " << sc_time_stamp() << ": PROX INT triggered." << endl;
      }
    }
    
    if(imem_oe_ref.read() != imem_oe_vhdl.read())     SC_REPORT_FATAL("compare", "[ERROR] VHDL != REF: IMEM_OE. Stopping.");
    if(imem_addr_ref.read() != imem_addr_vhdl.read()) SC_REPORT_FATAL("compare", "[ERROR] VHDL != REF: IMEM_ADDR. Stopping.");
    if(imem_oe_ref.read() == '1')
      if(imem_out_ref.read() != imem_out_vhdl.read()) SC_REPORT_FATAL("compare", "[ERROR] VHDL != REF: IMEM_OUT. Stopping.");
    if(dmem_oe_ref.read() != dmem_oe_vhdl.read())     SC_REPORT_FATAL("compare", "[ERROR] VHDL != REF: DMEM_OE. Stopping.");
    if(dmem_we_ref.read() != dmem_we_vhdl.read())     SC_REPORT_FATAL("compare", "[ERROR] VHDL != REF: DMEM_WE. Stopping.");
    if(dmem_addr_ref.read() != dmem_addr_vhdl.read()) SC_REPORT_FATAL("compare", "[ERROR] VHDL != REF: DMEM_ADDR. Stopping.");
    if(dmem_in_ref.read() != dmem_in_vhdl.read())     SC_REPORT_FATAL("compare", "[ERROR] VHDL != REF: DMEM_IN. Stopping.");
    if(dmem_func_ref.read() != dmem_func_vhdl.read()) SC_REPORT_FATAL("compare", "[ERROR] VHDL != REF: DMEM_FUNC. Stopping.");
    if(dmem_oe_ref.read() == '1')
      if(dmem_out_ref.read() != dmem_out_vhdl.read()) SC_REPORT_FATAL("compare", "[ERROR] VHDL != REF: DMEM_OUT. Stopping.");
    
    nano_func_prev[0] = dmem_func_vhdl.read()[0];
    nano_func_prev[1] = dmem_func_vhdl.read()[2*NANO_D_W];
    nano_func_prev[2] = dmem_func_vhdl.read()[2*NANO_D_W+1];
    
    wait();
    
    if(((dmem_func_vhdl.read()[0] == 1) && (nano_func_prev[0] == 0)) || ((dmem_func_vhdl.read()[0] == 0) && (nano_func_prev[0] == 1)))
      cout << "[NANO] " << sc_time_stamp() << ": RTC tick occurred. " << ++rtc_cnt << " simulated seconds elapsed." << endl;
    
    sc_uint<2> temp = dmem_func_vhdl.read().range(2*NANO_D_W+1,2*NANO_D_W);
    if(temp != nano_func_prev.range(2,1)) {
      if(temp == 0)
        cout << "[NANO] " << sc_time_stamp() << ": GPC Power-Down." << endl;
      else if(temp == 1)
        cout << "[NANO] " << sc_time_stamp() << ": GPC Power-On, GPC in Reset." << endl;
      else if(temp == 2)
        cout << "[NANO] " << sc_time_stamp() << ": GPC running." << endl;
      else
        cout << "[WARNING] " << sc_time_stamp() << ": GPC state set to something strange!" << endl;
    }
    
  }
  
  cout << "[STOP] Simulation Time: " << sc_time_stamp() << endl;
  sc_stop();

}

