-- Copyright (c) 2024 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
  signal wen  : std_logic_vector(DEPTH-1 downto 0);
  
  attribute ram_style : string;
  attribute ram_style of dmem : signal is "distributed";
  
  -- Functional Memory
  type func_t is array (DEPTH-FUNC_OUTS to DEPTH-1) of std_logic_vector(WIDTH_BITS-1 downto 0);
  signal func : func_t;
  
begin
  
  data_o <= dmem(to_integer(unsigned(addr_i)));
  mem_write : process(clk1_i)
  begin
    if rising_edge(clk1_i) then
      if we_i = '1' then
        dmem(to_integer(unsigned(addr_i))) <= data_i;
      end if;
    end if;
  end process mem_write;
  
  -- Functional Memory
  wen <= dectree(we_i, addr_i);
  funcmem_write : process(clk1_i)
  begin
    if rising_edge(clk1_i) then
      for i in DEPTH-FUNC_OUTS to DEPTH-1 loop
        if wen(i) = '1' then
          func(i) <= data_i;
        end if;
      end loop; --i
    end if;
  end process funcmem_write;
  
  -- Functional Output Mux
  out_mux : process(func)
    variable dvec : std_logic_vector(DEPTH*WIDTH_BITS-1 downto (DEPTH-FUNC_OUTS)*WIDTH_BITS);
  begin
    for i in DEPTH-FUNC_OUTS to DEPTH-1 loop
      dvec((i+1)*WIDTH_BITS-1 downto i*WIDTH_BITS) := func(i);
    end loop; --i
    func_o <= dvec(DEPTH*WIDTH_BITS-1 downto (DEPTH-FUNC_OUTS)*WIDTH_BITS);
  end process out_mux;
  
end architecture edge;
