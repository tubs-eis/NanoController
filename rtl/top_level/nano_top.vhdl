-- Copyright (c) 2024 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
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
use nano.nano_pkg.all;

entity nano_top is
  port(
    nano_clk1     : in  std_logic;
    nano_clk2     : in  std_logic;
    nano_rst_n    : in  std_logic;
    nano_ext_wake : in  std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
    nano_instr    : in  std_logic_vector(NANO_I_W_C-1 downto 0);
    nano_instr_oe : out std_logic;
    nano_pc       : out std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
    nano_func_o   : out std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0)
    );
  attribute async_set_reset of nano_rst_n : signal is "true";
end entity nano_top;

architecture edge of nano_top is

  -----------------------------------------------------------------------------
  -- Nanocontroller
  -----------------------------------------------------------------------------
  signal nano_data_logic_to_mem : std_logic_vector(NANO_D_W_C-1 downto 0);
  signal nano_data_mem_to_logic : std_logic_vector(NANO_D_W_C-1 downto 0);
  signal nano_func              : std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
  signal nano_data_oe           : std_logic;
  signal nano_data_we           : std_logic;
  signal nano_data_we_lst       : std_logic;
  signal nano_addr              : std_logic_vector(NANO_D_ADR_W_C-1 downto 0);

begin  -- edge

  -- (Optional) Tcl Commands for ASIC Synthesis
  --            Uncomment lines for your tool if you prefer
  --            not to ungroup certain NanoController modules
  
  -- synopsys dc_tcl_script_begin
  -- ## Synopsys Design Compiler
  -- #set_ungroup nano_dmem_inst false
  -- ## Cadence GENUS: Legacy UI
  -- #set_attribute ungroup_ok false nano_dmem_inst
  -- ## Cadence GENUS: Stylus Common UI
  -- set_db [vfind /des*/* -hinst nano_dmem_inst] .ungroup_ok false
  -- synopsys dc_tcl_script_end

  -----------------------------------------------------------------------------
  -- Nanocontroller
  -----------------------------------------------------------------------------
  seq : process(nano_clk1, nano_rst_n)
  begin
    if nano_rst_n = '0' then
      nano_func_o      <= (others => '0');
      nano_data_we_lst <= '0';
    elsif rising_edge(nano_clk1) then
      nano_data_we_lst <= nano_data_we;
      if nano_data_we_lst = '1' then
        nano_func_o               <= nano_func;
        --nano_func_o(2*NANO_D_W_C) <= nano_func(2*NANO_D_W_C) or nano_func(2*NANO_D_W_C+1);  -- This is for switchable Power-On Cycling for TTA
      end if;
    end if;
  end process seq;
  
  nano_logic_inst : entity nano.nano_logic(edge)
    port map (
      clk1_i     => nano_clk1,
      clk2_i     => nano_clk2,
      rst_n_i    => nano_rst_n,
      ext_wake_i => nano_ext_wake,
      instr_i    => nano_instr,
      data_i     => nano_data_mem_to_logic,
      func_i     => nano_func,
      instr_oe   => nano_instr_oe,
      data_oe    => nano_data_oe,
      data_we    => nano_data_we,
      pc_o       => nano_pc,
      addr_o     => nano_addr,
      data_o     => nano_data_logic_to_mem);
  
  -- Nano DMEM
  nano_dmem_inst : entity nano.nano_dmem(edge)
    generic map(
      DEPTH_LOG2 => NANO_D_ADR_W_C,
      WIDTH_BITS => NANO_D_W_C,
      FUNC_OUTS  => NANO_FUNC_OUTS_C)   -- Number of Functional Memory Outputs
    port map(
      clk1_i => nano_clk1,
      clk2_i => nano_clk2,
      oe_i   => nano_data_oe,
      we_i   => nano_data_we,
      addr_i => nano_addr,
      data_i => nano_data_logic_to_mem,
      data_o => nano_data_mem_to_logic,
      func_o => nano_func);             -- Functional Memory Output

end architecture edge;
