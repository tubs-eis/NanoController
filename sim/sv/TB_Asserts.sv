// Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
//                    TU Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

module TB_Asserts(
  i_nano_clk,
  i_tb_boot_done,
  i_tb_instr_addr, i_ref_instr_addr,
  i_tb_instr_oe, i_ref_instr_oe,
  i_tb_dmem_out, i_ref_dmem_out,
  i_tb_dmem_oe, i_ref_dmem_oe,
  i_tb_dmem_we, i_ref_dmem_we,
  i_tb_dmem_addr, i_ref_dmem_addr,
  i_tb_dmem_in, i_ref_dmem_in,
  i_tb_func, i_ref_func
);

  parameter NANO_I_ADR_W_C;
  parameter NANO_D_W_C;
  parameter NANO_D_ADR_W_C;
  parameter NANO_FUNC_OUTS_C;
  
  input logic i_nano_clk;
  input logic i_tb_boot_done;
  input bit   [NANO_I_ADR_W_C-1:0] i_tb_instr_addr, i_ref_instr_addr;
  input logic i_tb_instr_oe, i_ref_instr_oe;
  input bit   [NANO_D_W_C-1:0] i_tb_dmem_out, i_ref_dmem_out;
  input logic i_tb_dmem_oe, i_ref_dmem_oe;
  input logic i_tb_dmem_we, i_ref_dmem_we;
  input bit   [NANO_D_ADR_W_C-1:0] i_tb_dmem_addr, i_ref_dmem_addr;
  input bit   [NANO_D_W_C-1:0] i_tb_dmem_in, i_ref_dmem_in;
  input bit   [NANO_FUNC_OUTS_C*NANO_D_W_C-1:0] i_tb_func, i_ref_func;
  
  bit [NANO_FUNC_OUTS_C*NANO_D_W_C-1:0] func_prev = 0;
  
  //
  initial begin;
    
    while(1) begin
      func_prev = i_tb_func;
      
      @(posedge i_nano_clk);
      
      if(i_tb_boot_done) begin
        assert(i_tb_instr_addr === i_ref_instr_addr) else $fatal(1, "[FATAL] VHDL != REF: IMEM_ADDR. Stopping.");
        assert(i_tb_instr_oe === i_ref_instr_oe) else $fatal(1, "[FATAL] VHDL != REF: IMEM_OE. Stopping.");
        assert(i_tb_dmem_out === i_ref_dmem_out) else $fatal(1, "[FATAL] VHDL != REF: DMEM_OUT. Stopping.");
        assert(i_tb_dmem_oe === i_ref_dmem_oe) else $fatal(1, "[FATAL] VHDL != REF: DMEM_OE. Stopping.");
        assert(i_tb_dmem_we === i_ref_dmem_we) else $fatal(1, "[FATAL] VHDL != REF: DMEM_WE. Stopping.");
        assert(i_tb_dmem_addr === i_ref_dmem_addr) else $fatal(1, "[FATAL] VHDL != REF: DMEM_ADDR. Stopping.");
        assert(i_tb_dmem_in === i_ref_dmem_in) else $fatal(1, "[FATAL] VHDL != REF: DMEM_IN. Stopping.");
        assert(i_tb_func === i_ref_func) else $fatal(1, "[FATAL] VHDL != REF: DMEM_FUNC. Stopping");
      end
      
      if(i_tb_func !== func_prev) begin
        $write("[FUNC] %0t: ", $realtime);
        for (int j=NANO_FUNC_OUTS_C-1; j>=0; j--) begin
          $write("%3d ", i_tb_func[j*NANO_D_W_C +: NANO_D_W_C]);
        end
        $display();
      end
    end
  
  end // initial

endmodule
