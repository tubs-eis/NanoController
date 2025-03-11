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
  
  parameter string app_prefix = "";
  
  // To DUT (DUT inputs)
  logic nano_clk_sig = 1'b1;
  logic nano_rst_n_sig;
  logic nano_ext_wake_sig = 1'b0;
  logic dbg_spi_en_n_sig;
  logic dbg_spi_mosi_sig;
  logic dbg_spi_sclk_sig;
  
  // From DUT (DUT outputs)
  logic [35:0] nano_ctrl_sig;
  logic dbg_spi_miso_sig;
  
  // Clock Generators:
  always #(MAIN_CLK_DELAY) nano_clk_sig = ~nano_clk_sig;
  
  // Instantiate simulation wrapper of DUT
  sim_wrapper inst0
  (
    .i_nano_clk(nano_clk_sig),
    .i_nano_rst_n(nano_rst_n_sig),
    .i_nano_ext_wake(nano_ext_wake_sig),
    .i_dbg_spi_en_n(dbg_spi_en_n_sig),
    .i_dbg_spi_mosi(dbg_spi_mosi_sig),
    .i_dbg_spi_sclk(dbg_spi_sclk_sig),
    .o_nano_ctrl(nano_ctrl_sig),
    .o_dbg_spi_miso(dbg_spi_miso_sig)
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
    .o_dbg_spi_sclk(dbg_spi_sclk_sig)
  );

endmodule
