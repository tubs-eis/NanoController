-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    TU Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library top_level;

library control;
use control.ctrl_pkg.all;

entity clkdiv_rst_gen is
  port(clk_i      : in  std_logic;
       rst_n_i    : in  std_logic;
       param_i    : in  std_logic_vector(CTRL_CLKDIV_CNT_W_C-1 downto 0);
       we_param_i : in  std_logic;
       clk_o      : out std_logic;
       rst_n_o    : out std_logic
      );
end entity clkdiv_rst_gen;

architecture edge of clkdiv_rst_gen is
  
  -- Reset Generator
  signal rst_n_ff  : std_logic;
  signal rst_n_int : std_logic;
  
  -- Clock Enable Generator
  signal cnt_ff   : unsigned(CTRL_CLKDIV_CNT_W_C-1 downto 0);
  signal param_ff : std_logic_vector(CTRL_CLKDIV_CNT_W_C-1 downto 0);
  signal en_ff    : std_logic;
  
begin
  
  -- Reset Generation
  resgen : process(clk_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      rst_n_ff  <= '0';
      rst_n_int <= '0';
    elsif rising_edge(clk_i) then
      rst_n_ff  <= rst_n_i;
      rst_n_int <= rst_n_ff;
    end if;
  end process resgen;
  
  -- Clock Enable Generator
  clkengen : process(clk_i, rst_n_int)
  begin
    if rst_n_int = '0' then
      cnt_ff   <= (others => '0');
      param_ff <= (others => '0');
      en_ff    <= '0';
    elsif rising_edge(clk_i) then
      cnt_ff <= cnt_ff - 1;
      en_ff  <= '0';
      if we_param_i = '1' then
        param_ff <= param_i;
      end if;
      if cnt_ff = 0 then
        cnt_ff <= unsigned(param_ff);
        en_ff  <= '1';
      end if;
    end if;
  end process clkengen;
  
  -- Clock Division via Clock Gating
  clkdiv_gate : entity top_level.clkgate(asic)
    port map(clk => clk_i,
             en  => en_ff,
             gck => clk_o);
  
  -- Outputs
  rst_n_o <= rst_n_int;
  
end architecture edge;
