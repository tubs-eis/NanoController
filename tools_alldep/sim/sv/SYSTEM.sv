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
  
  parameter NANO_FUNC_OUTS_C = 8;
  parameter NANO_IRQ_W_C = 4;
  parameter NANO_D_W_C = 9;
  parameter string goldenref = "";
  parameter string dutfiles = "";
  parameter string lutidx = "";
  parameter SIZE_CLUT = 21;
  parameter SIZE_SCHG = 16;
  parameter SIZE_IMEM = 128;
  parameter STEP_GROUPS_GOLDEN = 6;
  parameter STEP_GROUPS_DUT = 6;
  
  // Clock Generator
  logic nano_clk_sig = 1'b1;
  always #(MAIN_CLK_DELAY) nano_clk_sig = ~nano_clk_sig;
  
  // Signals to units (DUT inputs)
  logic nano_rst_n_sig;
  logic dbg_spi_en_n_sig;
  logic dbg_spi_mosi_golden_sig, dbg_spi_mosi_dut_sig;
  logic dbg_spi_sclk_sig;
  
  // Signals from units (DUT outputs)
  logic nano_sleep_golden_sig, nano_sleep_dut_sig;
  logic [NANO_FUNC_OUTS_C*NANO_D_W_C-1:0] nano_func_golden_sig, nano_func_dut_sig;
  
  // Instantiate Golden Reference (Standard ISA)
  dut_wrapper
  #(
    .CTRL_CYCLE_DEPTH_G(SIZE_CLUT),
    .STEP_GROUPS_G(STEP_GROUPS_GOLDEN)
  )
  golden_inst
  (
    .i_nano_clk(nano_clk_sig),
    .i_nano_rst_n(nano_rst_n_sig),
    .i_dbg_spi_en_n(dbg_spi_en_n_sig),
    .i_dbg_spi_mosi(dbg_spi_mosi_golden_sig),
    .i_dbg_spi_sclk(dbg_spi_sclk_sig),
    .o_dbg_spi_miso(),
    .o_nano_sleep(nano_sleep_golden_sig),
    .o_nano_func(nano_func_golden_sig)
  );
  
  // Instantiate DUT (ISA to validate)
  dut_wrapper
  #(
    .CTRL_CYCLE_DEPTH_G(SIZE_CLUT),
    .STEP_GROUPS_G(STEP_GROUPS_DUT)
  )
  dut_inst
  (
    .i_nano_clk(nano_clk_sig),
    .i_nano_rst_n(nano_rst_n_sig),
    .i_dbg_spi_en_n(dbg_spi_en_n_sig),
    .i_dbg_spi_mosi(dbg_spi_mosi_dut_sig),
    .i_dbg_spi_sclk(dbg_spi_sclk_sig),
    .o_dbg_spi_miso(),
    .o_nano_sleep(nano_sleep_dut_sig),
    .o_nano_func(nano_func_dut_sig)
  );
  
  // Testbench
  testbench 
  #(
    .NANO_FUNC_OUTS_C(NANO_FUNC_OUTS_C),
    .NANO_IRQ_W_C(NANO_IRQ_W_C),
    .NANO_D_W_C(NANO_D_W_C),
    .goldenref(goldenref),
    .dutfiles(dutfiles),
    .lutidx(lutidx),
    .SIZE_CLUT(SIZE_CLUT),
    .SIZE_SCHG(SIZE_SCHG),
    .SIZE_IMEM(SIZE_IMEM)
  )
  tb_inst
  (
    .i_nano_clk(nano_clk_sig),
    .i_nano_sleep_golden(nano_sleep_golden_sig),
    .i_nano_sleep_dut(nano_sleep_dut_sig),
    .i_nano_func_golden(nano_func_golden_sig),
    .i_nano_func_dut(nano_func_dut_sig),
    .o_nano_rst_n(nano_rst_n_sig),
    .o_dbg_spi_en_n(dbg_spi_en_n_sig),
    .o_dbg_spi_mosi_golden(dbg_spi_mosi_golden_sig),
    .o_dbg_spi_mosi_dut(dbg_spi_mosi_dut_sig),
    .o_dbg_spi_sclk(dbg_spi_sclk_sig)
  );

endmodule
