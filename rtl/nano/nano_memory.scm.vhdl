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
  
  signal q : std_logic_vector(NANO_D_W_C-1 downto 0);
  
  -- Output Selection
  signal adc_ff : std_logic;
  
begin
  
  -- (Optional) Tcl Commands for ASIC Synthesis
  --            Uncomment lines for your tool if you prefer
  --            not to ungroup certain NanoController modules
  
  -- synopsys dc_tcl_script_begin
  -- ## Synopsys Design Compiler
  -- #set_ungroup nano_dmem_inst false
  -- #set_ungroup nano_imem_inst false
  -- ## Cadence GENUS: Legacy UI
  -- #set_attribute ungroup_ok false nano_dmem_inst
  -- #set_attribute ungroup_ok false nano_imem_inst
  -- ## Cadence GENUS: Stylus Common UI
  -- set_db [vfind /des*/* -hinst nano_dmem_inst] .ungroup_ok false
  -- set_db [vfind /des*/* -hinst nano_imem_inst] .ungroup_ok false
  -- synopsys dc_tcl_script_end
  
  
  -----------------------------------------------------------------------------
  -- Output Selection
  -----------------------------------------------------------------------------
  dmem_data_o  <= adc_i when adc_ff = '1' else q;
  process(clk1_i)
  begin
    if rising_edge(clk1_i) then
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
  
  
  nano_dmem_inst : entity work.nano_dmem(edge)
    generic map(
      DEPTH_LOG2 => NANO_D_ADR_W_C,
      WIDTH_BITS => NANO_D_W_C,
      FUNC_OUTS  => NANO_FUNC_OUTS_C)   -- Number of Functional Memory Outputs
    port map(
      clk1_i => clk1_i,
      clk2_i => clk2_i,
      oe_i   => dmem_oe_i,
      we_i   => dmem_we_i,
      addr_i => dmem_addr_i,
      data_i => dmem_data_i,
      data_o => q,
      func_o => dmem_func_o);           -- Functional Memory Output
  
  nano_imem_inst : entity work.nano_imem(edge_ram)
    generic map(DEPTH      => 2**NANO_I_ADR_W_C,
                DEPTH_LOG2 => NANO_I_ADR_W_C,
                WIDTH_BITS => NANO_I_W_C
               )
    port map(clk1_i  => clk1_i,
             clk2_i  => clk2_i,
             oe_i    => imem_oe_i,
             we_i    => imem_we_i,
             addr_i  => imem_addr_i,
             instr_i => imem_instr_i,
             instr_o => imem_instr_o
            );
  
end architecture edge;
