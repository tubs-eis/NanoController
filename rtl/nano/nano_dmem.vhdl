-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    TU Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;

library top_level;

use work.aux_pkg.all;

entity nano_dmem is
  generic(DEPTH_LOG2 : natural;
          WIDTH_BITS : natural;
          FUNC_OUTS  : natural   -- Number of Functional Memory Outputs
         );
  port(clk1_i : in  std_logic;
       clk2_i : in  std_logic;
       oe_i   : in  std_logic;
       we_i   : in  std_logic;
       addr_i : in  std_logic_vector(DEPTH_LOG2-1           downto 0);
       data_i : in  std_logic_vector(WIDTH_BITS-1           downto 0);
       data_o : out std_logic_vector(WIDTH_BITS-1           downto 0);
       func_o : out std_logic_vector(FUNC_OUTS*WIDTH_BITS-1 downto 0)   -- Functional Memory Output
      );
end entity nano_dmem;

architecture edge of nano_dmem is
  
  -- MEM Array
  constant DEPTH : natural := 2**DEPTH_LOG2;
  type dmem_t is array (0 to DEPTH-1) of std_logic_vector(WIDTH_BITS-1 downto 0);
  signal dmem : dmem_t;
  signal dvec : std_logic_vector(DEPTH*WIDTH_BITS-1 downto 0);
  signal wen  : std_logic_vector(DEPTH-1 downto 0);
  
  -- Input Latch Signals
  signal data : std_logic_vector(WIDTH_BITS-1 downto 0);
  
  -- Clock Gating Signals
  signal clk1_we_gated : std_logic;
  signal clk1_oe_gated : std_logic;
  signal clk_row_gated : std_logic_vector(DEPTH-1 downto 0);
  
begin
  
  -- Clock Gating (global write enable)
  clk1_we_gate : entity top_level.clkgate(asic)
    port map(clk => clk1_i,
             en  => we_i,
             gck => clk1_we_gated);
  
  -- Clock Gating (global output enable)
  clk1_oe_gate : entity top_level.clkgate(asic)
    port map(clk => clk1_i,
             en  => oe_i,
             gck => clk1_oe_gated);
  
  -- Input Data Latch
  in_lat : process(we_i, data_i)
  begin
    if we_i = '1' then
      data <= data_i;
    end if;
  end process in_lat;

  -- Memory Rows (with local write clock gating)
  wen <= dectree(we_i, addr_i);
  mem_row_gen : for i in 0 to DEPTH-1 generate
    clk_row_gate : entity top_level.clkgate(asic)
      port map(clk => clk1_we_gated,
               en  => wen(i),
               gck => clk_row_gated(i));
    
    mem_write : process(clk_row_gated(i))
    begin
      if rising_edge(clk_row_gated(i)) then
        dmem(i) <= data;
      end if;
    end process mem_write;
  end generate mem_row_gen;
  
  -- Output Functional Memory
  func_o <= dvec(DEPTH*WIDTH_BITS-1 downto (DEPTH-FUNC_OUTS)*WIDTH_BITS);
  out_func : process(dmem)
  begin
    dvec <= (others => '-');
    for i in 0 to DEPTH-1 loop
      dvec((i+1)*WIDTH_BITS-1 downto i*WIDTH_BITS) <= dmem(i);
    end loop; --i
  end process out_func;
  
  -- Output Mux
  out_mux : process(clk1_oe_gated)
    variable dout : std_logic_vector(WIDTH_BITS-1 downto 0);
  begin
    if rising_edge(clk1_oe_gated) then
      dout := muxtree(dvec, addr_i, WIDTH_BITS);
      data_o <= dout;
    end if;
  end process out_mux;
  
end architecture edge;
