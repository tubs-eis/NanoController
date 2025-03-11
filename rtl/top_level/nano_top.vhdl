-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    TU Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;

library synopsys;
use synopsys.attributes.all;

library nano;
use nano.aux_pkg.all;
use nano.nano_pkg.all;

entity nano_top is
  generic(CTRL_CYCLE_DEPTH_G : natural := 21;                  -- Cycle LUT Depth
          STEP_GROUPS_G      : natural := 6;                   -- Max Number of Control Steps per Instruction
          CTRL_SCHG_W_G      : natural := 12;                  -- State Change LUT Output Width
          CTRL_CONF_ADR_W_G  : natural := maxi(NANO_I_W_C, 5)  -- LUT Configuration Address Port Width
         );
  port(
    nano_clk1       : in  std_logic;
    nano_clk2       : in  std_logic;
    nano_rst_n      : in  std_logic;
    nano_we_clut_i  : in  std_logic_vector((CTRL_CW_IDENT_W_C-1)/8 downto 0);
    nano_we_schg_i  : in  std_logic_vector((CTRL_SCHG_W_G-1)/8 downto 0);
    nano_lut_addr_i : in  std_logic_vector(CTRL_CONF_ADR_W_G-1 downto 0);
    nano_lut_din_i  : in  std_logic_vector(8-1 downto 0);
    nano_ext_wake   : in  std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
    nano_data_i     : in  std_logic_vector(NANO_D_W_C-1 downto 0);
    nano_instr      : in  std_logic_vector(NANO_I_W_C-1 downto 0);
    nano_func_i     : in  std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
    nano_addr       : out std_logic_vector(NANO_D_ADR_W_C-1 downto 0);
    nano_data_o     : out std_logic_vector(NANO_D_W_C-1 downto 0);
    nano_data_oe    : out std_logic;
    nano_data_we    : out std_logic;
    nano_instr_oe   : out std_logic;
    nano_sleep_o    : out std_logic;
    nano_clut_o     : out std_logic_vector(CTRL_CW_IDENT_W_C-1 downto 0);
    nano_schg_o     : out std_logic_vector(CTRL_SCHG_W_G-1 downto 0);
    nano_pc         : out std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
    nano_func_o     : out std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0)
    );
  attribute async_set_reset of nano_rst_n : signal is "true";
end entity nano_top;

architecture edge of nano_top is

  -----------------------------------------------------------------------------
  -- Nanocontroller
  -----------------------------------------------------------------------------
  signal nano_data_we_int       : std_logic;
  signal nano_data_we_lst       : std_logic;

begin  -- edge

  -----------------------------------------------------------------------------
  -- Nanocontroller
  -----------------------------------------------------------------------------
  seq : process(nano_clk1, nano_rst_n)
  begin
    if nano_rst_n = '0' then
      nano_func_o      <= (others => '0');
      nano_data_we_lst <= '0';
    elsif rising_edge(nano_clk1) then
      nano_data_we_lst <= nano_data_we_int;
      if nano_data_we_lst = '1' then
        nano_func_o               <= nano_func_i;
        --nano_func_o(2*NANO_D_W_C) <= nano_func_i(2*NANO_D_W_C) or nano_func_i(2*NANO_D_W_C+1);  -- This is for switchable Power-On Cycling for TTA
      end if;
    end if;
  end process seq;
  
  nano_logic_inst : entity nano.nano_logic(edge)
    generic map(CTRL_CYCLE_DEPTH_G => CTRL_CYCLE_DEPTH_G,  -- Cycle LUT Depth
                STEP_GROUPS_G      => STEP_GROUPS_G,       -- Max Number of Control Steps per Instruction
                CTRL_SCHG_W_G      => CTRL_SCHG_W_G,       -- State Change LUT Output Width
                CTRL_CONF_ADR_W_G  => CTRL_CONF_ADR_W_G    -- LUT Configuration Address Port Width
               )
    port map (
      clk1_i     => nano_clk1,
      clk2_i     => nano_clk2,
      rst_n_i    => nano_rst_n,
      we_clut_i  => nano_we_clut_i,
      we_schg_i  => nano_we_schg_i,
      lut_addr_i => nano_lut_addr_i,
      lut_din_i  => nano_lut_din_i,
      ext_wake_i => nano_ext_wake,
      instr_i    => nano_instr,
      data_i     => nano_data_i,
      func_i     => nano_func_i,
      sleep_o    => nano_sleep_o,
      instr_oe   => nano_instr_oe,
      data_oe    => nano_data_oe,
      data_we    => nano_data_we_int,
      clut_o     => nano_clut_o,
      schg_o     => nano_schg_o,
      pc_o       => nano_pc,
      addr_o     => nano_addr,
      data_o     => nano_data_o);
  
  nano_data_we <= nano_data_we_int;

end architecture edge;
