// Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
//                    Technische Universitaet Braunschweig, Germany
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
  imem_oe.write(sc_logic('0'));
  imem_addr.write(pc);

  // function
  while(true) {

    // Fetch IR
    imem_oe.write(sc_logic('1'));
    wait();
    ir = imem_out.read();
    imem_oe.write(sc_logic('0'));
    branch_pc(1);
    
    // Fetch MEMPTR / OP B if necessary
    switch(ir.to_uint()) {
      
      // MEMPTR
      case OP_LIS:
      case OP_LDS:
      case OP_CST:
      case OP_ST:
        i = 0;
        do {
          imem_oe.write(sc_logic('1'));
          wait();
          concat = (imem_out.read().get_bit(NANO_I_W-1) == 1);
          if(i <= (NANO_D_ADR_W-1)/(NANO_I_W-1))
            memptr.range(min(NANO_D_ADR_W,(i+1)*(NANO_I_W-1))-1,i*(NANO_I_W-1)) = ((sc_uint<NANO_I_W>)imem_out.read()).range(min(NANO_D_ADR_W,(i+1)*(NANO_I_W-1))-i*(NANO_I_W-1)-1,0);
          imem_oe.write(sc_logic('0'));
          dmem_addr.write(memptr);
          branch_pc(1);
          i++;
        } while(concat);
        break;
      
      // OP B
      case OP_LDI:
      case OP_CMPI:
      case OP_DBNE:
      case OP_BNE:
        i = 0;
        do {
          imem_oe.write(sc_logic('1'));
          wait();
          concat = (imem_out.read().get_bit(NANO_I_W-1) == 1);
          if(i <= (NANO_D_W-1)/(NANO_I_W-1))
            opb.range(min(NANO_D_W,(i+1)*(NANO_I_W-1))-1,i*(NANO_I_W-1)) = ((sc_uint<NANO_I_W>)imem_out.read()).range(min(NANO_D_W,(i+1)*(NANO_I_W-1))-i*(NANO_I_W-1)-1,0);
          imem_oe.write(sc_logic('0'));
          branch_pc(1);
          i++;
        } while(concat);
        break;
        
      // No additional operands
      default: break;
    }
    
    // Execute Instructions
    switch(ir.to_uint()) {
      
      // LDI: 1 Execution Cycle
      case OP_LDI:
        wait();
        set_accu(opb);
        break;
      
      // CST, CSTL: 2 Execution Cycles
      // ST:        1 Execution Cycle
      case OP_CST:
      case OP_CSTL: 
        wait();
        set_accu(0);
      case OP_ST:
        dmem_we.write(sc_logic('1'));
        wait();
        dmem_we.write(sc_logic('0'));
        break;
      
      // CMPI: 1 Execution Cycle
      case OP_CMPI:
        wait();
        zero = ((accu - opb) == 0);
        break;
      
      // LIS, LISL: 4 Execution Cycles
      case OP_LIS:  
      case OP_LISL:
        dmem_oe.write(sc_logic('1'));
        wait();
        opb = dmem_out.read();
        dmem_oe.write(sc_logic('0'));
        wait();
        set_accu(opb);
        wait();
        set_accu((unsigned int)accu + 1);
        dmem_we.write(sc_logic('1'));
        wait();
        dmem_we.write(sc_logic('0'));
        break;
      
      // LDS, LDSL: 4 Execution Cycles
      case OP_LDS:  
      case OP_LDSL:
        dmem_oe.write(sc_logic('1'));
        wait();
        opb = dmem_out.read();
        dmem_oe.write(sc_logic('0'));
        wait();
        set_accu(opb);
        wait();
        set_accu((unsigned int)accu - 1);
        dmem_we.write(sc_logic('1'));
        wait();
        dmem_we.write(sc_logic('0'));
        break;
      
      // DBNE: 2 Execution Cycles
      // BNE:  1 Execution Cycle
      case OP_DBNE:
        wait();
        set_accu((unsigned int)accu - 1);
      case OP_BNE:  
        wait();
        if(zero) break;
        branch_pc(opb);
        break;
      
      // SLEEP: 1 Execution Cycle when Wake Signal set
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
        break;
      
      //
      default: 
        wait();
        break;
    }

  }
}

void nano_ref::func_rtc_comb() {
  rtc_param = func_in.read().range((NANO_FUNC_OUTS-NANO_IRQ_W)*NANO_D_W-1,(NANO_FUNC_OUTS-NANO_IRQ_W-1)*NANO_D_W);
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
