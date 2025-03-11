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

use work.aux_pkg.all;
use work.nano_pkg.all;
use work.func_pkg.all;

entity nano_logic is
  generic(CTRL_CYCLE_DEPTH_G : natural := 21;                  -- Cycle LUT Depth
          STEP_GROUPS_G      : natural := 6;                   -- Max Number of Control Steps per Instruction
          CTRL_SCHG_W_G      : natural := 12;                  -- State Change LUT Output Width
          CTRL_CONF_ADR_W_G  : natural := maxi(NANO_I_W_C, 5)  -- LUT Configuration Address Port Width
         );
  port(clk1_i     : in  std_logic;
       clk2_i     : in  std_logic;
       rst_n_i    : in  std_logic;
       we_clut_i  : in  std_logic_vector((CTRL_CW_IDENT_W_C-1)/8 downto 0);
       we_schg_i  : in  std_logic_vector((CTRL_SCHG_W_G-1)/8 downto 0);
       lut_addr_i : in  std_logic_vector(CTRL_CONF_ADR_W_G-1 downto 0);
       lut_din_i  : in  std_logic_vector(8-1 downto 0);
       ext_wake_i : in  std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
       instr_i    : in  std_logic_vector(NANO_I_W_C-1 downto 0);
       data_i     : in  std_logic_vector(NANO_D_W_C-1 downto 0);
       func_i     : in  std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
       sleep_o    : out std_logic;
       instr_oe   : out std_logic;
       data_oe    : out std_logic;
       data_we    : out std_logic;
       clut_o     : out std_logic_vector(CTRL_CW_IDENT_W_C-1 downto 0);
       schg_o     : out std_logic_vector(CTRL_SCHG_W_G-1 downto 0);
       pc_o       : out std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
       addr_o     : out std_logic_vector(NANO_D_ADR_W_C-1 downto 0);
       data_o     : out std_logic_vector(NANO_D_W_C-1 downto 0)
      );
  attribute async_set_reset of rst_n_i : signal is "true";
end entity nano_logic;

architecture edge of nano_logic is
  -- Control Signals
  signal flag : std_logic_vector(FL_W_C-1         downto 0);
  signal cw   : std_logic_vector(CW_W_C-1         downto 0);
  signal pc   : std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
  signal wake : std_logic_vector(NANO_IRQ_W_C-1   downto 0);
  signal irqv : std_logic_vector(NANO_D_W_C-1     downto 0);
  
  -- Data Signals
  signal data : std_logic_vector(NANO_D_W_C-1 downto 0);
  signal alu  : std_logic_vector(NANO_D_W_C-1 downto 0);
  
  -- Registers
  signal ext_wake_sample : std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
  signal ext_wake_delay  : std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
  signal ext_wake        : std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
begin

  -- (Optional) Tcl Commands for ASIC Synthesis
  --            Uncomment lines for your tool if you prefer
  --            not to ungroup certain NanoController modules

  -- synopsys dc_tcl_script_begin
  -- ## Synopsys Design Compiler
  -- #set_ungroup nano_dp_inst false
  -- #set_ungroup nano_ctrl_inst false
  -- #set_ungroup func_rtc_inst false
  -- ## Cadence GENUS: Legacy UI
  -- #set_attribute ungroup_ok false nano_dp_inst
  -- #set_attribute ungroup_ok false nano_ctrl_inst
  -- #set_attribute ungroup_ok false func_rtc_inst
  -- ## Cadence GENUS: Stylus Common UI
  -- set_db [vfind /des*/* -hinst nano_dp_inst] .ungroup_ok false
  -- set_db [vfind /des*/* -hinst nano_ctrl_inst] .ungroup_ok false
  -- set_db [vfind /des*/* -hinst func_rtc_inst] .ungroup_ok false
  -- synopsys dc_tcl_script_end

  -- Nano Datapath
  nano_dp_inst : entity work.nano_dp(edge)
    port map(clk1_i  => clk1_i,
             clk2_i  => clk2_i,
             rst_n_i => rst_n_i,
             cw_i    => cw,    -- Datapath Control Word
             pc_i    => pc,    -- Program Counter
             data_i  => data,
             flag_o  => flag,  -- Datapath Flags
             data_o  => data_o,
             alu_o   => alu
            );
            
  -- Nano Control FSM
  nano_ctrl_inst : entity work.nano_ctrl(edge)
    generic map(CTRL_CYCLE_DEPTH_G => CTRL_CYCLE_DEPTH_G,  -- Cycle LUT Depth
                STEP_GROUPS_G      => STEP_GROUPS_G,       -- Max Number of Control Steps per Instruction
                CTRL_SCHG_W_G      => CTRL_SCHG_W_G,       -- State Change LUT Output Width
                CTRL_CONF_ADR_W_G  => CTRL_CONF_ADR_W_G    -- LUT Configuration Address Port Width
               )
    port map(clk1_i     => clk1_i,
             clk2_i     => clk2_i,
             rst_n_i    => rst_n_i,
             we_clut_i  => we_clut_i,   -- Cycle LUT Write Enable
             we_schg_i  => we_schg_i,   -- State Change LUT Write Enable
             lut_addr_i => lut_addr_i,  -- LUT Configuration Address Input
             lut_din_i  => lut_din_i,   -- LUT Configuration Data Input
             wake_i     => wake,
             flag_i     => flag,        -- Datapath Flags
             alu_i      => alu,
             irqv_i     => irqv,        -- IRQ Address Vector
             instr_i    => instr_i,
             clut_o     => clut_o,      -- Cycle LUT Read-Out
             schg_o     => schg_o,      -- State Change LUT Read-Out
             cw_o       => cw,          -- Datapath Control Word
             ptr_o      => addr_o,      -- MEMPTR
             pc_o       => pc           -- Program Counter
            );

  -- Functional Unit: RTC
  func_rtc_inst : entity work.func_rtc(edge)
    generic map(CNT_BITS => FUNC_RTC_CNT_W_C
               )
    port map(clk1_i  => clk1_i,
             clk2_i  => clk2_i,
             rst_n_i => rst_n_i,
             param_i => func_i((NANO_FUNC_OUTS_C-NANO_IRQ_W_C)*NANO_D_W_C-1 downto (NANO_FUNC_OUTS_C-NANO_IRQ_W_C-1)*NANO_D_W_C),
             ack_i   => cw(CW_WAKE_ACK+NANO_IRQ_W_C-1),
             wake_o  => wake(NANO_IRQ_W_C-1)
            );
  
  wake(NANO_IRQ_W_C-2 downto 0) <= ext_wake;
            
  -- Operand B Selection
  opb_sel : process(instr_i, data_i, cw(CW_B_OP_SEL))
  begin
    data <= (others => '-');
    if cw(CW_B_OP_SEL) = '0' then
      data <= data_i;
    else
      data(data'length-1 downto (B_GROUPS_C-1)*B_GROUP_W_C) <= instr_i(data'length-(B_GROUPS_C-1)*B_GROUP_W_C-1 downto 0);
      for i in 0 to B_GROUPS_C-2 loop
        data((i+1)*B_GROUP_W_C-1 downto i*B_GROUP_W_C) <= instr_i(B_GROUP_W_C-1 downto 0);
      end loop; --i
    end if;
  end process opb_sel;
  
  -- Wake-Up Start Vector Multiplexing
  wake_vec : process(func_i, wake)
  begin
    irqv <= func_i((NANO_FUNC_OUTS_C-NANO_IRQ_W_C+1)*NANO_D_W_C-1 downto (NANO_FUNC_OUTS_C-NANO_IRQ_W_C)*NANO_D_W_C);
    for i in 0 to NANO_IRQ_W_C-1 loop
      if wake(i) = '1' then
        irqv <= func_i((NANO_FUNC_OUTS_C-NANO_IRQ_W_C+i+1)*NANO_D_W_C-1 downto (NANO_FUNC_OUTS_C-NANO_IRQ_W_C+i)*NANO_D_W_C);
      end if;
    end loop; --i
  end process wake_vec;
  
  -- External Edge-Triggered Wake-Up Signal Handling
  wake_ext : process(clk1_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      ext_wake_sample <= (others => '0');
      ext_wake_delay  <= (others => '0');
      ext_wake        <= (others => '0');
    elsif rising_edge(clk1_i) then
      ext_wake_sample <= ext_wake_i;
      ext_wake_delay  <= ext_wake_sample;
      for i in 0 to NANO_EXT_IRQ_W_C-1 loop
        if cw(CW_WAKE_ACK+i) = '1' or (ext_wake_sample(i) = '1' and ext_wake_delay(i) = '0') then
          ext_wake(i) <= ext_wake_sample(i) and not cw(CW_WAKE_ACK+i);
        end if;
      end loop; --i
    end if;
  end process wake_ext;
  
  -- Output to Memories
  sleep_o  <= cw(CW_PC_IRQ);
  instr_oe <= cw(CW_IMEM_OE) or not rst_n_i;
  data_oe  <= cw(CW_DMEM_OE);
  data_we  <= cw(CW_DMEM_WE);
  pc_o     <= pc;
            
end architecture edge;
