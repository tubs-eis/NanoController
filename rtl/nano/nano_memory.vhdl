-- Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;

use work.nano_pkg.all;

entity nano_memory is
  port(clk1_i   : in  std_logic;
       clk2_i   : in  std_logic;
       instr_oe : in  std_logic;
       instr_we : in  std_logic;
       data_oe  : in  std_logic;
       data_we  : in  std_logic;
       pc_i     : in  std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
       addr_i   : in  std_logic_vector(NANO_D_ADR_W_C-1 downto 0);
       -- !! changed for MEH ASIC flashloader with 8 bit load, load 2 4-bit instructions parallel !!
       instr_i  : in  std_logic_vector(2*NANO_I_W_C-1 downto 0);  --(NANO_I_W_C-1 downto 0);
       -- !! change end !!
       data_i   : in  std_logic_vector(NANO_D_W_C-1 downto 0);
       instr_o  : out std_logic_vector(NANO_I_W_C-1 downto 0);
       data_o   : out std_logic_vector(NANO_D_W_C-1 downto 0);
       func_o   : out std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0)
      );
end entity nano_memory;

architecture edge of nano_memory is
begin

  -- (Optional) Tcl Commands for ASIC Synthesis
  --            Uncomment lines for your tool if you prefer
  --            not to ungroup certain NanoController modules
  
  -- synopsys dc_tcl_script_begin
  -- ## Synopsys Design Compiler
  -- #set_ungroup nano_imem_inst false
  -- #set_ungroup nano_dmem_inst false
  -- ## Cadence GENUS: Legacy UI
  -- #set_attribute ungroup_ok false nano_imem_inst
  -- #set_attribute ungroup_ok false nano_dmem_inst
  -- ## Cadence GENUS: Stylus Common UI
  -- set_db [vfind /des*/* -hinst nano_imem_inst] .ungroup_ok false
  -- set_db [vfind /des*/* -hinst nano_dmem_inst] .ungroup_ok false
  -- synopsys dc_tcl_script_end

  -- Nano IMEM
  nano_imem_inst : entity work.nano_imem(edge_ram)
    generic map(DEPTH      => 2**NANO_I_ADR_W_C,
                DEPTH_LOG2 => NANO_I_ADR_W_C,
                WIDTH_BITS => NANO_I_W_C
               )
    port map(clk1_i  => clk1_i,
             clk2_i  => clk2_i,
             oe_i    => instr_oe,
             we_i    => instr_we,
             addr_i  => pc_i,
             instr_i => instr_i,
             instr_o => instr_o
            );
  
  -- Nano DMEM
  nano_dmem_inst : entity work.nano_dmem(edge)
    generic map(DEPTH_LOG2 => NANO_D_ADR_W_C,
                WIDTH_BITS => NANO_D_W_C,
                FUNC_OUTS  => NANO_FUNC_OUTS_C  -- Number of Functional Memory Outputs
               )
    port map(clk1_i => clk1_i,
             clk2_i => clk2_i,
             oe_i   => data_oe,
             we_i   => data_we,
             addr_i => addr_i,
             data_i => data_i,
             data_o => data_o,
             func_o => func_o                   -- Functional Memory Output
            );

end architecture edge;
