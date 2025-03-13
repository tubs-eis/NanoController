-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    TU Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.

library ieee;
use ieee.std_logic_1164.all;

library nano;
use nano.aux_pkg.all;
use nano.nano_pkg.all;

library control;
use control.ctrl_pkg.all;

library top_level;

entity dut_wrapper is
  generic(
    CTRL_CYCLE_DEPTH_G : natural := 21;  -- Cycle LUT Depth
    STEP_GROUPS_G      : natural := 6    -- Max Number of Control Steps per Instruction
  );
  port(
    i_nano_clk         : in  std_logic;
    i_nano_rst_n       : in  std_logic;
    i_dbg_spi_en_n     : in  std_logic;
    i_dbg_spi_mosi     : in  std_logic;
    i_dbg_spi_sclk     : in  std_logic;
    o_dbg_spi_miso     : out std_logic;
    o_nano_sleep       : out std_logic;
    o_nano_func        : out std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0)
  );
end entity dut_wrapper;

architecture str of dut_wrapper is
  
  constant CTRL_CYCODE_W_C   : natural := log2(STEP_GROUPS_G);                         -- Encoded Execution Cycle Number Width
  constant CTRL_SCHG_W_C     : natural := log2(CTRL_CYCLE_DEPTH_G)+CTRL_CYCODE_W_C+4;  -- State Change LUT Output Width
  constant CTRL_CONF_ADR_W_C : natural := maxi(NANO_I_W_C, log2(CTRL_CYCLE_DEPTH_G));  -- LUT Configuration Address Port Width
  constant DBG_CONF_ADR_W_C  : natural := maxi(CTRL_CONF_ADR_W_C,NANO_I_ADR_W_C);      -- Memory Debug Address Port Width

  signal nano_func                : std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
  signal nano_instr               : std_logic_vector(NANO_I_W_C-1 downto 0);
  -- !! changed for MEH ASIC flashloader with 8 bit load, load 2 4-bit instructions parallel !!
  signal nano_instr_init_from_dbg : std_logic_vector(2*NANO_I_W_C-1 downto 0);  --(NANO_I_W_C-1 downto 0);
  -- !! change end !!
  signal nano_sleep               : std_logic;
  signal nano_instr_oe            : std_logic;
  signal nano_instr_oe_from_dbg   : std_logic;
  signal nano_instr_we_from_dbg   : std_logic;
  signal nano_instr_addr          : std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
  signal nano_instr_addr_from_dbg : std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
  signal nano_clk                 : std_logic;
  signal nano_rst_n               : std_logic;
  signal nano_rst_n_dbg           : std_logic;
  signal nano_clut                : std_logic_vector(CTRL_CW_IDENT_W_C-1 downto 0);
  signal nano_schg                : std_logic_vector(CTRL_SCHG_W_C-1 downto 0);
  signal nano_lut_addr_from_dbg   : std_logic_vector(CTRL_CONF_ADR_W_C-1 downto 0);
  signal nano_we_clut_from_dbg    : std_logic_vector((CTRL_CW_IDENT_W_C-1)/8 downto 0);
  signal nano_we_schg_from_dbg    : std_logic_vector((CTRL_SCHG_W_C-1)/8 downto 0);
  signal nano_lut_din_from_dbg    : std_logic_vector(8-1 downto 0);
  signal nano_we_cgen_from_dbg    : std_logic;
  signal nano_cgen_param_from_dbg : std_logic_vector(CTRL_CLKDIV_CNT_W_C-1 downto 0);
  
  signal nano_data_from_mem : std_logic_vector(NANO_D_W_C-1 downto 0);
  signal nano_func_from_mem : std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
  signal nano_data_addr     : std_logic_vector(NANO_D_ADR_W_C-1 downto 0);
  signal nano_data_to_mem   : std_logic_vector(NANO_D_W_C-1 downto 0);
  signal nano_data_oe       : std_logic;
  signal nano_data_we       : std_logic;
  
  signal dbg_wake : std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);

begin

  o_nano_sleep <= nano_sleep;
  o_nano_func  <= nano_func;

  nano_top_inst : entity top_level.nano_top(edge)
    generic map(
      CTRL_CYCLE_DEPTH_G => CTRL_CYCLE_DEPTH_G,  -- Cycle LUT Depth
      STEP_GROUPS_G      => STEP_GROUPS_G,       -- Max Number of Control Steps per Instruction
      CTRL_SCHG_W_G      => CTRL_SCHG_W_C,       -- State Change LUT Output Width
      CTRL_CONF_ADR_W_G  => CTRL_CONF_ADR_W_C    -- LUT Configuration Address Port Width
    )
    port map(
      nano_clk1         => nano_clk,
      nano_clk2         => '0',
      nano_rst_n        => nano_rst_n_dbg,
      nano_we_clut_i    => nano_we_clut_from_dbg,
      nano_we_schg_i    => nano_we_schg_from_dbg,
      nano_lut_addr_i   => nano_lut_addr_from_dbg,
      nano_lut_din_i    => nano_lut_din_from_dbg,
      nano_ext_wake     => dbg_wake,
      nano_data_i       => nano_data_from_mem,
      nano_instr        => nano_instr,
      nano_func_i       => nano_func_from_mem,
      nano_addr         => nano_data_addr,
      nano_data_o       => nano_data_to_mem,
      nano_data_oe      => nano_data_oe,
      nano_data_we      => nano_data_we,
      nano_instr_oe     => nano_instr_oe,
      nano_sleep_o      => nano_sleep,
      nano_clut_o       => nano_clut,
      nano_schg_o       => nano_schg,
      nano_pc           => nano_instr_addr,
      nano_func_o       => nano_func
    );
  
  nano_memory_inst : entity nano.nano_memory(edge)
    port map(
      clk1_i       => nano_clk,
      clk2_i       => '0',
      adc_i        => (others => '0'),
      dmem_oe_i    => nano_data_oe,
      dmem_we_i    => nano_data_we,
      dmem_addr_i  => nano_data_addr,
      dmem_data_i  => nano_data_to_mem,
      imem_oe_i    => nano_instr_oe_from_dbg,
      imem_we_i    => nano_instr_we_from_dbg,
      imem_addr_i  => nano_instr_addr_from_dbg,
      imem_instr_i => nano_instr_init_from_dbg,
      dmem_data_o  => nano_data_from_mem,
      dmem_func_o  => nano_func_from_mem,
      imem_instr_o => nano_instr
    );
  
  clkdiv_rst_gen_inst : entity control.clkdiv_rst_gen(edge)
    port map(
      clk_i      => i_nano_clk,
      rst_n_i    => i_nano_rst_n,
      param_i    => nano_cgen_param_from_dbg,
      we_param_i => nano_we_cgen_from_dbg,
      clk_o      => nano_clk,
      rst_n_o    => nano_rst_n
    );
  
  dbg_iface_inst : entity control.dbg_iface(edge)
    generic map(
      CTRL_SCHG_W_G     => CTRL_SCHG_W_C,      -- State Change LUT Output Width
      CTRL_CONF_ADR_W_G => CTRL_CONF_ADR_W_C,  -- LUT Configuration Address Port Width
      DBG_CONF_ADR_W_G  => DBG_CONF_ADR_W_C    -- Memory Debug Address Port Width
    )
    port map(
      clk_i        => nano_clk,
      rst_n_i      => nano_rst_n,
      dbg_adc_i    => (others => '0'),
      dbg_func_i   => nano_func,
      dbg_iadr_i   => nano_instr_addr,
      dbg_inst_i   => nano_instr,
      dbg_ctlgen_i => (others => '0'),
      dbg_clut_i   => nano_clut,
      dbg_schg_i   => nano_schg,
      imem_oe_i    => nano_instr_oe,
      imem_we_i    => '0',
      imem_addr_i  => nano_instr_addr,
      imem_instr_i => (others => '0'),
      spi_en_n_i   => i_dbg_spi_en_n,
      spi_mosi_i   => i_dbg_spi_mosi,
      spi_sclk_i   => i_dbg_spi_sclk,
      --uart_rx_i    => i_uart_rx,
      rst_n_o      => nano_rst_n_dbg,
      spi_miso_o   => o_dbg_spi_miso,
      --uart_tx_o    => o_uart_tx,
      dbg_wake_o   => dbg_wake,
      imem_oe_o    => nano_instr_oe_from_dbg,
      imem_we_o    => nano_instr_we_from_dbg,
      imem_addr_o  => nano_instr_addr_from_dbg,
      imem_instr_o => nano_instr_init_from_dbg,
      we_cgen_o    => nano_we_cgen_from_dbg,
      cgen_param_o => nano_cgen_param_from_dbg,
      we_clut_o    => nano_we_clut_from_dbg,
      we_schg_o    => nano_we_schg_from_dbg,
      lut_addr_o   => nano_lut_addr_from_dbg,
      lut_din_o    => nano_lut_din_from_dbg
    );

end architecture str;
