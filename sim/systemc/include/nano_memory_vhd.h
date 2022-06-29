#ifndef _SCGENMOD_nano_memory_
#define _SCGENMOD_nano_memory_

#include "systemc.h"

class nano_memory : public sc_foreign_module
{
public:
    sc_in_clk clk1_i;
    sc_in<sc_logic> clk2_i;
    sc_in<sc_logic> instr_oe;
    sc_in<sc_logic> instr_we;
    sc_in<sc_logic> data_oe;
    sc_in<sc_logic> data_we;
    sc_in<sc_uint<7> > pc_i;
    sc_in<sc_uint<4> > addr_i;
    sc_in<sc_lv<8> > instr_i;
    sc_in<sc_uint<7> > data_i;
    sc_out<sc_lv<4> > instr_o;
    sc_out<sc_uint<7> > data_o;
    sc_out<sc_uint<56> > func_o;


    nano_memory(sc_module_name nm, const char* hdl_name)
     : sc_foreign_module(nm),
       clk1_i("clk1_i"),
       clk2_i("clk2_i"),
       instr_oe("instr_oe"),
       instr_we("instr_we"),
       data_oe("data_oe"),
       data_we("data_we"),
       pc_i("pc_i"),
       addr_i("addr_i"),
       instr_i("instr_i"),
       data_i("data_i"),
       instr_o("instr_o"),
       data_o("data_o"),
       func_o("func_o")
    {
        elaborate_foreign_module(hdl_name);
    }
    ~nano_memory()
    {}

};

#endif

