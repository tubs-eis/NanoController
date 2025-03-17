-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    TU Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.

library ieee;
use ieee.std_logic_1164.all;

use work.nano_pkg.all;

entity nano_memory is
  port(clk1_i       : in  std_logic;
       clk2_i       : in  std_logic;
       adc_i        : in  std_logic_vector(NANO_D_W_C-1 downto 0);
       dmem_oe_i    : in  std_logic;
       dmem_we_i    : in  std_logic;
       dmem_addr_i  : in  std_logic_vector(NANO_D_ADR_W_C-1 downto 0);
       dmem_data_i  : in  std_logic_vector(NANO_D_W_C-1 downto 0);
       imem_oe_i    : in  std_logic;
       imem_we_i    : in  std_logic;
       imem_addr_i  : in  std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
       -- !! changed for MEH ASIC flashloader with 8 bit load, load 2 4-bit instructions parallel !!
       imem_instr_i : in  std_logic_vector(2*NANO_I_W_C-1 downto 0);  --(NANO_I_W_C-1 downto 0);
       -- !! change end !!
       dmem_data_o  : out std_logic_vector(NANO_D_W_C-1 downto 0);
       dmem_func_o  : out std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
       imem_instr_o : out std_logic_vector(NANO_I_W_C-1 downto 0)
      );
end entity nano_memory;

architecture edge of nano_memory is
  
  COMPONENT main
    PORT (
      clk : IN STD_LOGIC;
      i_ce : IN STD_LOGIC;
      we : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      a : IN STD_LOGIC_VECTOR(imem_addr_i'length-2 DOWNTO 0);
      d : IN STD_LOGIC_VECTOR(8 DOWNTO 0);
      spo : OUT STD_LOGIC_VECTOR(8 DOWNTO 0)
    );
  END COMPONENT;
  
  -- Distributed RAM Macro Interface
  signal ce : std_logic;
  signal we : std_logic_vector(0 downto 0);
  signal q  : std_logic_vector(NANO_D_W_C-1 downto 0);
  
  -- DMEM / IMEM Muxing
  signal d : std_logic_vector(8 downto 0);
  signal a : std_logic_vector(imem_addr_i'length-2 downto 0);
  
  -- Output Selection
  signal a0_ff  : std_logic;
  signal adc_ff : std_logic;
  
begin
  
  -----------------------------------------------------------------------------
  -- Interface Signals
  -----------------------------------------------------------------------------
  ce    <= dmem_oe_i or dmem_we_i or imem_oe_i or imem_we_i;
  we(0) <= imem_we_i or dmem_we_i;
  
  -----------------------------------------------------------------------------
  -- DMEM / IMEM Muxing
  -----------------------------------------------------------------------------
  d <= '0' & imem_instr_i when imem_we_i = '1' else dmem_data_i;
  a <= "1111" & dmem_addr_i when (dmem_oe_i = '1' or dmem_we_i = '1') else imem_addr_i(8 downto 1);
  
  -----------------------------------------------------------------------------
  -- Output Selection
  -----------------------------------------------------------------------------
  dmem_data_o  <= adc_i when adc_ff = '1' else q;
  imem_instr_o <= q(3 downto 0) when a0_ff = '1' else q(7 downto 4);
  process(clk1_i)
  begin
    if rising_edge(clk1_i) then
      if imem_oe_i = '1' then
        a0_ff <= imem_addr_i(0);
      end if;
      if dmem_oe_i = '1' then
        adc_ff <= '1';
        for i in 0 to NANO_D_ADR_W_C-1 loop
          if dmem_addr_i(i) = '0' then
            adc_ff <= '0';
          end if;
        end loop; --i
      end if;
    end if;
  end process;
  
  -----------------------------------------------------------------------------
  -- Functional Memory
  -----------------------------------------------------------------------------
  funcmem_inst : entity work.nano_dmem(edge)
    generic map(
      DEPTH_LOG2 => NANO_D_ADR_W_C,
      WIDTH_BITS => NANO_D_W_C,
      FUNC_OUTS  => NANO_FUNC_OUTS_C)   -- Number of Functional Memory Outputs
    port map(
      clk1_i => clk1_i,
      clk2_i => clk2_i,
      oe_i   => '0',
      we_i   => dmem_we_i,
      addr_i => dmem_addr_i,
      data_i => dmem_data_i,
      data_o => open,
      func_o => dmem_func_o);           -- Functional Memory Output
  
  -----------------------------------------------------------------------------
  -- Distributed RAM Macro Instance
  -----------------------------------------------------------------------------
  main_inst : main
    PORT MAP (
      clk => clk1_i,
      i_ce => ce,
      we => we,
      a => a,
      d => d,
      spo => q
    );
  
end architecture edge;
