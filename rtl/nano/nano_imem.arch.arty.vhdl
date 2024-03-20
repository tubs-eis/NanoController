-- Copyright (c) 2024 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library top_level;

architecture edge_ram of nano_imem is

  COMPONENT main
    PORT (
      clk : IN STD_LOGIC;
      i_ce : IN STD_LOGIC;
      we : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      a : IN STD_LOGIC_VECTOR(addr_i'length-2 DOWNTO 0);
      d : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
      spo : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
  END COMPONENT;
  
  -- BRAM Macro Interface
  signal ce : std_logic;
  signal we : std_logic_vector(0 downto 0);
  signal q  : std_logic_vector(7 downto 0);
  
  -- Output Selection
  signal a0_ff : std_logic;
  
begin
  
  -----------------------------------------------------------------------------
  -- Interface Signals
  -----------------------------------------------------------------------------
  ce <= oe_i or we_i;
  we <= (others => we_i);
  
  -----------------------------------------------------------------------------
  -- Output Selection
  -----------------------------------------------------------------------------
  instr_o <= q(3 downto 0) when a0_ff = '1' else q(7 downto 4);
  process(clk1_i)
  begin
    if rising_edge(clk1_i) then
      if oe_i = '1' then
        a0_ff <= addr_i(0);
      end if;
    end if;
  end process;
  
  -----------------------------------------------------------------------------
  -- Memory blocks (Block RAM)
  -----------------------------------------------------------------------------
  main_inst : main
    PORT MAP (
      clk => clk1_i,
      i_ce => ce,
      we => we,
      a => addr_i(addr_i'length-1 downto 1),
      d => instr_i,
      spo => q
    );

end architecture edge_ram;
