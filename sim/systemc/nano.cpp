// Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
//                    TU Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.


#include "include/nano.hpp"

int nano_ref::min(int a, int b) {
  return (a < b) ? a : b;
}

void nano_ref::branch_pc(int offset) {
  
  // indices and counter variables
  int i;
  
  // temporaries for simpler computation
  sc_uint<NANO_I_ADR_W> tmp_pc;
  sc_uint<1>            tmp_carry;
  
  tmp_pc = (unsigned int)((int)(unsigned int)pc + offset);
  for(i = 0; i <= ((NANO_I_ADR_W-1)/NANO_D_W); i++) {
    pc.range(min(NANO_I_ADR_W,(i+1)*NANO_D_W)-1,i*NANO_D_W) = tmp_pc.range(min(NANO_I_ADR_W,(i+1)*NANO_D_W)-1,i*NANO_D_W);
    tmp_carry = (NANO_I_ADR_W > (i+1)*NANO_D_W) && (tmp_pc.range(min(NANO_I_ADR_W,(i+2)*NANO_D_W)-1,min(NANO_I_ADR_W,(i+1)*NANO_D_W)) != pc.range(min(NANO_I_ADR_W,(i+2)*NANO_D_W)-1,min(NANO_I_ADR_W,(i+1)*NANO_D_W)));
    imem_addr.write(pc);
    if(tmp_carry) wait();
  }
}

void nano_ref::set_accu(unsigned int result) {
  accu  = result & ((1 << NANO_D_W) - 1);
  carry = (result & (1 << NANO_D_W)) >> NANO_D_W;
  zero  = (accu == 0);
  dmem_in.write(accu);
}

void nano_ref::func() {

  // indices and counter variables
  int i;

  // reset
  pc = 0;
  accu = 0;
  opb = 0;
  carry = 0;
  zero = false;
  concat = false;
  memptr = 0;
  ir = 0;

  dmem_oe.write(sc_logic('0'));
  dmem_we.write(sc_logic('0'));
  dmem_in.write(accu);
  dmem_addr.write(memptr);
  imem_oe_int.write(sc_logic('0'));
  imem_addr.write(pc);
  concat_en_int.write(sc_logic('0'));
  rtc_firstconf.write(false);

  // function
  while(true) {

    // Fetch IR
    imem_oe_int.write(sc_logic('0'));
    wait();
    ir = imem_out.read();
    branch_pc(1);
    
    // Fetch MEMPTR / OP B if necessary
    switch(ir.to_uint()) {
      
      // MEMPTR
      case OP_LIS:
      case OP_LDS:
      case OP_CST:
      case OP_LD:
      case OP_ST:
        imem_oe_int.write(sc_logic('1'));
        wait();
        branch_pc(1);
        // !! changed for fixed MEMPTR concat for NexGen datapath !!
        //concat_en_int.write(sc_logic('1'));
        concat_en_int.write(sc_logic('0'));
        //imem_oe_int.write(sc_logic('1'));
        imem_oe_int.write(sc_logic('0'));
        // !! change end !!
        i = 0;
        do {
          wait();
          concat = (imem_oe_shadow.read() == '1');
          // !! changed for fixed MEMPTR concat for NexGen datapath !!
          //if(i <= (NANO_D_ADR_W-1)/(NANO_I_W-1))
          //  memptr.range(min(NANO_D_ADR_W,(i+1)*(NANO_I_W-1))-1,i*(NANO_I_W-1)) = ((sc_uint<NANO_I_W>)imem_out.read()).range(min(NANO_D_ADR_W,(i+1)*(NANO_I_W-1))-i*(NANO_I_W-1)-1,0);
          if(i <= (NANO_D_ADR_W)/(NANO_I_W))
            memptr.range(min(NANO_D_ADR_W,(i+1)*(NANO_I_W))-1,i*(NANO_I_W)) = ((sc_uint<NANO_I_W>)imem_out.read()).range(min(NANO_D_ADR_W,(i+1)*(NANO_I_W))-i*(NANO_I_W)-1,0);
          if(concat)
            branch_pc(1);
          // !! change end !!
          dmem_addr.write(memptr);
          i++;
        } while(concat);
        break;
      
      // OP B
      case OP_LDI:
      case OP_CMPI:
      case OP_ADDI:
      case OP_SUBI:
      case OP_DBNE:
      case OP_BNE:
        imem_oe_int.write(sc_logic('1'));
        wait();
        branch_pc(1);
        concat_en_int.write(sc_logic('1'));
        imem_oe_int.write(sc_logic('1'));
        i = 0;
        do {
          wait();
          concat = (imem_oe_shadow.read() == '1');
          if(i <= (NANO_D_W-1)/(NANO_I_W-1))
            opb.range(min(NANO_D_W,(i+1)*(NANO_I_W-1))-1,i*(NANO_I_W-1)) = ((sc_uint<NANO_I_W>)imem_out.read()).range(min(NANO_D_W,(i+1)*(NANO_I_W-1))-i*(NANO_I_W-1)-1,0);
          if(concat)
            branch_pc(1);
          i++;
        } while(concat);
        break;
        
      // No additional operands
      default: break;
    }
    
    concat_en_int.write(sc_logic('0'));
    imem_oe_int.write(sc_logic('0'));
    
    // Execute Instructions
    switch(ir.to_uint()) {
      
      // LDI: 1 Execution Cycle
      case OP_LDI:
        imem_oe_int.write(sc_logic('1'));
        wait();
        set_accu(opb);
        break;
      
      // CST, CSTL: 3 Execution Cycles
      // ST, STL:   2 Execution Cycles
      case OP_CST:
      case OP_CSTL: 
        wait();
        set_accu(0);
      case OP_ST:
      case OP_STL:
        dmem_we.write(sc_logic('1'));
        wait();
        if(memptr == (1 << NANO_D_ADR_W)-NANO_IRQ_W-1)
          rtc_firstconf.write(true);
        dmem_we.write(sc_logic('0'));
        imem_oe_int.write(sc_logic('1'));
        wait();
        break;
      
      // CMPI: 1 Execution Cycle
      case OP_CMPI:
        imem_oe_int.write(sc_logic('1'));
        wait();
        zero = ((accu - opb) == 0);
        break;
      
      // ADDI: 1 Execution Cycle
      case OP_ADDI:
        imem_oe_int.write(sc_logic('1'));
        wait();
        set_accu((unsigned int)accu + (unsigned int)opb);
        break;
      
      // SUBI: 1 Execution Cycle
      case OP_SUBI:
        imem_oe_int.write(sc_logic('1'));
        wait();
        set_accu((unsigned int)accu - (unsigned int)opb);
        break;
      
      // LD: 3 Execution Cycles
      case OP_LD:
        dmem_oe.write(sc_logic('1'));
        wait();
        dmem_oe.write(sc_logic('0'));
        wait();
        opb = dmem_out.read();
        imem_oe_int.write(sc_logic('1'));
        wait();
        set_accu(opb);
        break;
      
      // LIS, LISL: 6 Execution Cycles
      case OP_LIS:  
      case OP_LISL:
        dmem_oe.write(sc_logic('1'));
        wait();
        dmem_oe.write(sc_logic('0'));
        wait();
        opb = dmem_out.read();
        wait();
        set_accu(opb);
        wait();
        set_accu((unsigned int)accu + 1);
        dmem_we.write(sc_logic('1'));
        wait();
        if(memptr == (1 << NANO_D_ADR_W)-NANO_IRQ_W-1)
          rtc_firstconf.write(true);
        dmem_we.write(sc_logic('0'));
        imem_oe_int.write(sc_logic('1'));
        wait();
        break;
      
      // LDS, LDSL: 6 Execution Cycles
      case OP_LDS:  
      case OP_LDSL:
        dmem_oe.write(sc_logic('1'));
        wait();
        dmem_oe.write(sc_logic('0'));
        wait();
        opb = dmem_out.read();
        wait();
        set_accu(opb);
        wait();
        set_accu((unsigned int)accu - 1);
        dmem_we.write(sc_logic('1'));
        wait();
        if(memptr == (1 << NANO_D_ADR_W)-NANO_IRQ_W-1)
          rtc_firstconf.write(true);
        dmem_we.write(sc_logic('0'));
        imem_oe_int.write(sc_logic('1'));
        wait();
        break;
      
      // DBNE: 3 Execution Cycles
      // BNE:  2 Execution Cycles
      case OP_DBNE:
        wait();
        set_accu((unsigned int)accu - 1);
      case OP_BNE:  
        wait();
        if(!zero)
          branch_pc(opb);
        imem_oe_int.write(sc_logic('1'));
        wait();
        break;
      
      // SLEEP: 2 Execution Cycles when Wake Signal set
      case OP_SLEEP:
        while(true) {
          if(rtc_wake || ext_wake) break;
          wait();
        }
        wait();
        if(rtc_wake) {
          pc.range(min(NANO_I_ADR_W,NANO_D_W)-1,0) = func_in.read().range(min(NANO_I_ADR_W,NANO_D_W)+(NANO_FUNC_OUTS-1)*NANO_D_W-1,(NANO_FUNC_OUTS-1)*NANO_D_W);
          rtc_wake = false;
        } else if(ext_wake) {
          pc.range(min(NANO_I_ADR_W,NANO_D_W)-1,0) = func_in.read().range(min(NANO_I_ADR_W,NANO_D_W)+(NANO_FUNC_OUTS-2)*NANO_D_W-1,(NANO_FUNC_OUTS-2)*NANO_D_W);
          ext_wake = false;
        }
        imem_addr.write(pc);
        imem_oe_int.write(sc_logic('1'));
        wait();
        break;
      
      //
      default: 
        imem_oe_int.write(sc_logic('1'));
        wait();
        break;
    }

  }
}

void nano_ref::oe_concat() {
  sc_logic oe_tmp;
  oe_tmp = (concat_en_int.read() == '1') ? imem_out.read()[NANO_I_W-1] : (rst_n.read() ? imem_oe_int.read() : sc_logic('1'));
  imem_oe.write(oe_tmp);
  imem_oe_shadow.write(oe_tmp);
}

void nano_ref::func_rtc_comb() {
  rtc_param = func_in.read().range((NANO_FUNC_OUTS-NANO_IRQ_W)*NANO_D_W-1,(NANO_FUNC_OUTS-NANO_IRQ_W-1)*NANO_D_W);
  if(!rst_n.read())
    rtc_unconf = false;
  else if(rtc_firstconf.read())
    rtc_unconf = (rtc_param == 0);
}

void nano_ref::func_rtc_seq() {
  
  // temporaries
  bool limit;
  
  // reset
  rtc_cnt = 1;
  rtc_wake = false;
  
  // function
  while(true) {
    wait();
    limit = false;
    if(rtc_firstconf)
      limit = (rtc_cnt.range(FUNC_RTC_CNT_W-1,FUNC_RTC_CNT_W-NANO_D_W) == rtc_param);
    if(limit || rtc_unconf)
      rtc_cnt = 1;
    else
      rtc_cnt++;
    if(limit && (!rtc_unconf)) rtc_wake = true;
  }
  
}

void nano_ref::func_ext_seq() {
  
  // temporaries
  bool sample, sample_prev;
  
  // reset
  ext_wake = false;
  sample   = false;
  
  // function
  while(true) {
    sample_prev = sample;
    sample = (wake_in.read().get_bit(NANO_EXT_IRQ_W-1) == 1);
    wait();
    if(sample && (!sample_prev)) ext_wake = true;
  }
  
}

SC_MODULE_EXPORT(nano_ref);
