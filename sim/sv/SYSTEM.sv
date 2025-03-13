// Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
//                    TU Braunschweig, Germany
//                    www.tu-braunschweig.de/en/eis
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file or at
// https://opensource.org/licenses/MIT.

`timescale 1ns / 1ps

module SYSTEM();
  
  parameter MAIN_CLK_DELAY = 125;  // 4 MHz
  
  // NanoController parameters:
  // align these to rtl/pkg/nano.pkg.vhdl and config/nanodefs.h !
  parameter NANO_EXT_IRQ_W_C = 3;
  parameter NANO_I_W_C = 4;
  parameter NANO_I_ADR_W_C = 9;
  parameter NANO_D_W_C = 9;
  parameter NANO_D_ADR_W_C = 4;
  parameter NANO_FUNC_OUTS_C = 8;
  
  parameter string app_prefix = "";
  
  // To DUT (DUT inputs)
  logic nano_clk_sig = 1'b1;
  logic nano_rst_n_sig;
  logic nano_ext_wake_sig = 1'b0;
  logic dbg_spi_en_n_sig;
  logic dbg_spi_mosi_sig;
  logic dbg_spi_sclk_sig;
  
  // From DUT (DUT outputs)
  bit [NANO_FUNC_OUTS_C*NANO_D_W_C-1:0] nano_func_sig;
  logic dbg_spi_miso_sig;
  
  // Signals for Testbench / Reference Model
  logic ref_nano_clk_sig;
  logic tb_nano_rst_n_int_sig;
  logic tb_boot_done_sig;
  logic [NANO_EXT_IRQ_W_C-1:0] tb_ext_wake_sig;
  bit   [NANO_I_W_C-1:0] tb_instr_sig;
  bit   [NANO_I_ADR_W_C-1:0] tb_instr_addr_sig, ref_instr_addr_sig;
  logic tb_instr_oe_sig, ref_instr_oe_sig;
  bit   [NANO_D_W_C-1:0] tb_dmem_out_sig, ref_dmem_out_sig;
  logic tb_dmem_oe_sig, ref_dmem_oe_sig;
  logic tb_dmem_we_sig, ref_dmem_we_sig;
  bit   [NANO_D_ADR_W_C-1:0] tb_dmem_addr_sig, ref_dmem_addr_sig;
  bit   [NANO_D_W_C-1:0] tb_dmem_in_sig, ref_dmem_in_sig;
  bit   [NANO_FUNC_OUTS_C*NANO_D_W_C-1:0] ref_func_sig;
  
  // Clock Generators:
  always #(MAIN_CLK_DELAY) nano_clk_sig = ~nano_clk_sig;
  
  // SystemC Reference Model: NanoController
  nano_ref nano0
  (
    .clk(ref_nano_clk_sig),
    .rst_n(tb_nano_rst_n_int_sig),
    .dmem_out(ref_dmem_out_sig),
    .imem_out(tb_instr_sig),
    .func_in(ref_func_sig),
    .wake_in(tb_ext_wake_sig),
    .dmem_oe(ref_dmem_oe_sig),
    .dmem_we(ref_dmem_we_sig),
    .dmem_in(ref_dmem_in_sig),
    .dmem_addr(ref_dmem_addr_sig),
    .imem_oe(ref_instr_oe_sig),
    .imem_addr(ref_instr_addr_sig)
  );
  
  // SystemC Reference Model: DMEM & Functional Memory
  dmem_ref dmem0
  (
    .clk(ref_nano_clk_sig),
    .dmem_out(ref_dmem_out_sig),
    .dmem_oe(ref_dmem_oe_sig),
    .dmem_we(ref_dmem_we_sig),
    .dmem_addr(ref_dmem_addr_sig),
    .dmem_in(ref_dmem_in_sig),
    .func_out(ref_func_sig)
  );
  
  // Instantiate simulation wrapper of DUT
  sim_wrapper inst0
  (
    .i_nano_clk(nano_clk_sig),
    .i_nano_rst_n(nano_rst_n_sig),
    .i_nano_ext_wake(nano_ext_wake_sig),
    .i_dbg_spi_en_n(dbg_spi_en_n_sig),
    .i_dbg_spi_mosi(dbg_spi_mosi_sig),
    .i_dbg_spi_sclk(dbg_spi_sclk_sig),
    .o_nano_func(nano_func_sig),
    .o_dbg_spi_miso(dbg_spi_miso_sig),
    // Outputs for Testbench / Model
    .o_nano_clk(ref_nano_clk_sig),
    .o_nano_rst_n_int(tb_nano_rst_n_int_sig),
    .o_nano_ext_wake(tb_ext_wake_sig),
    .o_nano_instr(tb_instr_sig),
    .o_nano_instr_addr(tb_instr_addr_sig),
    .o_nano_instr_oe(tb_instr_oe_sig),
    .o_nano_data_from_mem(tb_dmem_out_sig),
    .o_nano_data_addr(tb_dmem_addr_sig),
    .o_nano_data_to_mem(tb_dmem_in_sig),
    .o_nano_data_oe(tb_dmem_oe_sig),
    .o_nano_data_we(tb_dmem_we_sig)
  );
  
  // VHDL/SystemC Co-Simulation Testbench Asserts
  TB_Asserts
  #(
    .NANO_I_ADR_W_C(NANO_I_ADR_W_C),
    .NANO_D_W_C(NANO_D_W_C),
    .NANO_D_ADR_W_C(NANO_D_ADR_W_C),
    .NANO_FUNC_OUTS_C(NANO_FUNC_OUTS_C)
  )
  asserts
  (
    .i_nano_clk(ref_nano_clk_sig),
    .i_tb_boot_done(tb_boot_done_sig),
    .i_tb_instr_addr(tb_instr_addr_sig),
    .i_tb_instr_oe(tb_instr_oe_sig),
    .i_tb_dmem_out(tb_dmem_out_sig),
    .i_tb_dmem_oe(tb_dmem_oe_sig),
    .i_tb_dmem_we(tb_dmem_we_sig),
    .i_tb_dmem_addr(tb_dmem_addr_sig),
    .i_tb_dmem_in(tb_dmem_in_sig),
    .i_tb_func(nano_func_sig),
    .i_ref_instr_addr(ref_instr_addr_sig),
    .i_ref_instr_oe(ref_instr_oe_sig),
    .i_ref_dmem_out(ref_dmem_out_sig),
    .i_ref_dmem_oe(ref_dmem_oe_sig),
    .i_ref_dmem_we(ref_dmem_we_sig),
    .i_ref_dmem_addr(ref_dmem_addr_sig),
    .i_ref_dmem_in(ref_dmem_in_sig),
    .i_ref_func(ref_func_sig)
  );
  
  // SPI Debug Master
  SPI_Debug_Master
  #(
    .app_prefix(app_prefix)
  )
  testbench
  (
    .i_nano_clk(nano_clk_sig),
    .i_dbg_spi_miso(dbg_spi_miso_sig),
    .o_nano_rst_n(nano_rst_n_sig),
    .o_dbg_spi_en_n(dbg_spi_en_n_sig),
    .o_dbg_spi_mosi(dbg_spi_mosi_sig),
    .o_dbg_spi_sclk(dbg_spi_sclk_sig),
    .o_tb_boot_done(tb_boot_done_sig)
  );

endmodule
