#ifndef _SCGENMOD_nano_logic_
#define _SCGENMOD_nano_logic_

#include "systemc.h"

class nano_logic : public sc_foreign_module
{
public:
    sc_in_clk clk1_i;
    sc_in<sc_logic> clk2_i;
    sc_in<bool> rst_n_i;
    sc_in<sc_lv<3> > ext_wake_i;
    sc_in<sc_lv<4> > instr_i;
    sc_in<sc_uint<7> > data_i;
    sc_in<sc_uint<56> > func_i;
    sc_out<sc_logic> instr_oe;
    sc_out<sc_logic> data_oe;
    sc_out<sc_logic> data_we;
    sc_out<sc_uint<7> > pc_o;
    sc_out<sc_uint<4> > addr_o;
    sc_out<sc_uint<7> > data_o;


    nano_logic(sc_module_name nm, const char* hdl_name)
     : sc_foreign_module(nm),
       clk1_i("clk1_i"),
       clk2_i("clk2_i"),
       rst_n_i("rst_n_i"),
       ext_wake_i("ext_wake_i"),
       instr_i("instr_i"),
       data_i("data_i"),
       func_i("func_i"),
       instr_oe("instr_oe"),
       data_oe("data_oe"),
       data_we("data_we"),
       pc_o("pc_o"),
       addr_o("addr_o"),
       data_o("data_o")
    {
        elaborate_foreign_module(hdl_name);
    }
    ~nano_logic()
    {}

};

#endif

