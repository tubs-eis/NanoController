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

library synopsys;
use synopsys.attributes.all;

use work.aux_pkg.all;
use work.nano_pkg.all;

entity nano_ctrl is
  generic(CTRL_CYCLE_DEPTH_G : natural := 21;                  -- Cycle LUT Depth
          STEP_GROUPS_G      : natural := 6;                   -- Max Number of Control Steps per Instruction
          CTRL_SCHG_W_G      : natural := 12;                  -- State Change LUT Output Width
          CTRL_CONF_ADR_W_G  : natural := maxi(NANO_I_W_C, 5)  -- LUT Configuration Address Port Width
         );
  port(clk1_i     : in  std_logic;
       clk2_i     : in  std_logic;
       rst_n_i    : in  std_logic;
       we_clut_i  : in  std_logic_vector((CTRL_CW_IDENT_W_C-1)/8 downto 0);  -- Cycle LUT Write Enable
       we_schg_i  : in  std_logic_vector((CTRL_SCHG_W_G-1)/8     downto 0);  -- State Change LUT Write Enable
       lut_addr_i : in  std_logic_vector(CTRL_CONF_ADR_W_G-1     downto 0);  -- LUT Configuration Address Input
       lut_din_i  : in  std_logic_vector(8-1                     downto 0);  -- LUT Configuration Data Input
       wake_i     : in  std_logic_vector(NANO_IRQ_W_C-1          downto 0);
       flag_i     : in  std_logic_vector(FL_W_C-1                downto 0);  -- Datapath Flags
       alu_i      : in  std_logic_vector(NANO_D_W_C-1            downto 0);
       irqv_i     : in  std_logic_vector(NANO_D_W_C-1            downto 0);  -- IRQ Address Vector
       instr_i    : in  std_logic_vector(NANO_I_W_C-1            downto 0);
       clut_o     : out std_logic_vector(CTRL_CW_IDENT_W_C-1     downto 0);  -- Cycle LUT Read-Out
       schg_o     : out std_logic_vector(CTRL_SCHG_W_G-1         downto 0);  -- State Change LUT Read-Out
       cw_o       : out std_logic_vector(CW_W_C-1                downto 0);  -- Datapath Control Word
       ptr_o      : out std_logic_vector(NANO_D_ADR_W_C-1        downto 0);  -- MEMPTR
       pc_o       : out std_logic_vector(NANO_I_ADR_W_C-1        downto 0)   -- Program Counter
      );
  attribute async_set_reset of rst_n_i : signal is "true";
end entity nano_ctrl;

architecture edge of nano_ctrl is

  -- Control Registers
  signal pc     : std_logic_vector(NANO_I_ADR_W_C-1 downto 0); -- Program Counter
  signal memptr : std_logic_vector(NANO_D_ADR_W_C-1 downto 0); -- MEMPTR
  signal ir     : std_logic_vector(NANO_I_W_C-1     downto 0); -- Instruction Register
  signal concat : std_logic;                                   -- Concatenation Flag
  
  -- Control State
  constant SEQ_GROUPS_C : natural := maxi(CTRL_GROUPS_C, STEP_GROUPS_G);  -- Number of Sequential Steps Register Bits
  type ctrl_state_t is (FETCH, REGFETCH, EXECUTE);
  signal state    : ctrl_state_t;
  signal pc_gsel  : std_logic_vector(PC_GROUPS_C-1   downto 0);
  signal reg_gsel : std_logic_vector(SEQ_GROUPS_C-2  downto 0);
  
  -- Control Logic
  signal cw     : std_logic_vector(CW_W_C-1     downto 0);
  signal pc_mux : std_logic_vector(NANO_D_W_C-1 downto 0);
  
  -- State Change LUT
  constant CTRL_CYCLE_ADR_W_C : natural := log2(CTRL_CYCLE_DEPTH_G);  -- Cycle LUT Address Width
  constant CTRL_CYCODE_W_C    : natural := log2(STEP_GROUPS_G);       -- Encoded Execution Cycle Number Width
  signal reg_fetch    : std_logic;
  signal opb_fetch    : std_logic;
  signal branch       : std_logic;
  signal wake         : std_logic;
  signal last_cycle   : std_logic;
  signal baseaddr     : std_logic_vector(CTRL_CYCLE_ADR_W_C-1 downto 0);
  signal cycode       : std_logic_vector(CTRL_CYCODE_W_C-1    downto 0);
  signal cycode_therm : std_logic_vector(2**CTRL_CYCODE_W_C-2 downto 0);
  signal instr_mux    : std_logic_vector(NANO_I_W_C-1         downto 0);
  signal statechg_lut : std_logic_vector(CTRL_SCHG_W_G-1      downto 0);
  signal statechg_adr : std_logic_vector(NANO_I_W_C-1         downto 0);
  
  -- Cycle LUT
  signal cw_addr  : std_logic_vector(CTRL_CYCLE_ADR_W_C-1 downto 0);
  signal cw_cycle : std_logic_vector(CTRL_CYCODE_W_C-1    downto 0);
  signal cw_ident : std_logic_vector(CTRL_CW_IDENT_W_C-1  downto 0);
  signal cw_lut   : std_logic_vector(CW_W_C-1             downto 0);
  
begin

  -- synopsys dc_tcl_script_begin
  -- ## Cadence GENUS: Stylus Common UI
  -- set_db [vfind /des*/* -hinst nano_ctrl_lut_statechg_inst] .lp_clock_gating_exclude true
  -- set_db [vfind /des*/* -hinst nano_ctrl_lut_cycle_inst] .lp_clock_gating_exclude true
  -- synopsys dc_tcl_script_end

  -- State Change LUT
  cycode_therm <= bin2therm(cycode);
  last_cycle   <= '1' when reg_gsel(STEP_GROUPS_G-2 downto 0) = cycode_therm(STEP_GROUPS_G-2 downto 0) else '0';
  statechg_adr <= lut_addr_i(NANO_I_W_C-1 downto 0) when rst_n_i = '0' else instr_mux;
  reg_fetch    <= statechg_lut(CTRL_CYCLE_ADR_W_C+CTRL_CYCODE_W_C+3);
  opb_fetch    <= statechg_lut(CTRL_CYCLE_ADR_W_C+CTRL_CYCODE_W_C+2);
  branch       <= statechg_lut(CTRL_CYCLE_ADR_W_C+CTRL_CYCODE_W_C+1);
  wake         <= statechg_lut(CTRL_CYCLE_ADR_W_C+CTRL_CYCODE_W_C);
  baseaddr     <= statechg_lut(CTRL_CYCLE_ADR_W_C+CTRL_CYCODE_W_C-1 downto CTRL_CYCODE_W_C);
  cycode       <= statechg_lut(CTRL_CYCODE_W_C-1 downto 0);
  nano_ctrl_lut_statechg_inst : entity work.nano_lut(edge)
    generic map(DEPTH      => 2**NANO_I_W_C,
                DEPTH_LOG2 => NANO_I_W_C,
                WIDTH_BITS => CTRL_SCHG_W_G,
                W_GRP_SIZE => 8)
    port map(clk1_i => clk1_i,
             clk2_i => clk2_i,
             we_i   => we_schg_i,
             addr_i => statechg_adr,
             data_i => lut_din_i(8-1 downto 0),
             data_o => statechg_lut);
  
  -- Sequential FSM: Control State
  seq : process(clk1_i, rst_n_i)
    constant no_wake_c    : std_logic_vector(NANO_IRQ_W_C-1 downto 0) := (others => '0');
    variable concat_mux   : std_logic;
  begin
    if rst_n_i = '0' then
      pc     <= (others => '0');
      memptr <= (others => '0');
      ir     <= (others => '0');
      concat <= '0';
      state  <= FETCH;
      if PC_GROUPS_C > 1 then
        pc_gsel <= (others => '0');
      end if;
      if B_GROUPS_C > 1 or PTR_GROUPS_C > 1 then
        reg_gsel <= (others => '0');
      end if;
    elsif rising_edge(clk1_i) then
      --
      if cw(CW_PC_WREN+PC_GROUPS_C-1) = '1' then
        pc(pc'length-1 downto (PC_GROUPS_C-1)*PC_GROUP_W_C) <= pc_mux(pc'length-(PC_GROUPS_C-1)*PC_GROUP_W_C-1 downto 0);
      end if;
      for i in 0 to PC_GROUPS_C-2 loop
        if cw(CW_PC_WREN+i) = '1' then
          pc((i+1)*PC_GROUP_W_C-1 downto i*PC_GROUP_W_C) <= pc_mux;
        end if;
      end loop; --i
      --
      if cw(CW_PTR_WREN+PTR_GROUPS_C-1) = '1' then
        memptr(memptr'length-1 downto (PTR_GROUPS_C-1)*PTR_GROUP_W_C) <= instr_i(memptr'length-(PTR_GROUPS_C-1)*PTR_GROUP_W_C-1 downto 0);
      end if;
      for i in 0 to PTR_GROUPS_C-2 loop
        if cw(CW_PTR_WREN+i) = '1' then
          memptr((i+1)*PTR_GROUP_W_C-1 downto i*PTR_GROUP_W_C) <= instr_i(PTR_GROUP_W_C-1 downto 0);
        end if;
      end loop; --i
      --
      if cw(CW_IR_WREN) = '1' then
        ir <= instr_i;
      end if;
      if cw(CW_CONCAT_WREN) = '1' then
        concat <= instr_i(NANO_I_W_C-1);
      end if;
      --
      concat_mux := instr_i(NANO_I_W_C-1);
      if PC_GROUPS_C > 1 then
        if pc_gsel(0) = '1' then
          concat_mux := concat;
        end if;
      end if;
      case state is
        --
        when FETCH =>
          if reg_fetch = '1' then
            if concat = '0' then
              concat <= '1';
            else
              concat <= '0';
              state  <= REGFETCH;
            end if;
          else
            state <= EXECUTE;
          end if;
          if PC_GROUPS_C > 1 then
            if flag_i(FL_CARRY) = '1' then
              concat                          <= concat;
              state                           <= state;
              pc_gsel                         <= (others => '1');
              pc_gsel(PC_GROUPS_C-2 downto 1) <= pc_gsel(PC_GROUPS_C-3 downto 0);
            else
              pc_gsel                         <= (others => '0');
            end if;
          end if;
        --
        when REGFETCH =>
          -- !! changed for fixed MEMPTR concat and normal OPB concat for NexGen datapath !!
          if opb_fetch = '1' then
            if concat_mux = '0' then  --concat_mux = '0' or concat = '1' then  --concat_mux = '0' then
              concat <= '0';
              state  <= EXECUTE;
              if B_GROUPS_C > 1 or PTR_GROUPS_C > 1 then
                reg_gsel <= (others => '0');
              end if;
            elsif B_GROUPS_C > 1 or PTR_GROUPS_C > 1 then
              reg_gsel                           <= (others => '1');
              reg_gsel(SEQ_GROUPS_C-2 downto 1)  <= reg_gsel(SEQ_GROUPS_C-3 downto 0);
            end if;
          else
            concat <= '0';
            state  <= EXECUTE;
          end if;
          if PC_GROUPS_C > 1 then
            if flag_i(FL_CARRY) = '1' then
              state                           <= state;
              if B_GROUPS_C > 1 or PTR_GROUPS_C > 1 then
                reg_gsel                      <= reg_gsel;
              end if;
              pc_gsel                         <= (others => '1');
              pc_gsel(PC_GROUPS_C-2 downto 1) <= pc_gsel(PC_GROUPS_C-3 downto 0);
            else
              pc_gsel                         <= (others => '0');
            end if;
          end if;
        --
        when EXECUTE =>
          concat                             <= '0';
          reg_gsel                           <= (others => '1');
          reg_gsel(SEQ_GROUPS_C-2 downto 1)  <= reg_gsel(SEQ_GROUPS_C-3 downto 0);
          --
          if last_cycle = '1' then
            if wake = '0' and branch = '0' then
              state    <= FETCH;
              reg_gsel <= (others => '0');
            else
              reg_gsel <= reg_gsel;
              if (wake = '1' and wake_i /= no_wake_c) or branch = '1' then
                if concat = '0' then
                  concat <= '1';
                else
                  state    <= FETCH;
                  reg_gsel <= (others => '0');
                end if;
                if PC_GROUPS_C > 1 and branch = '1' then
                  if flag_i(FL_CARRY) = '1' then
                    concat                          <= concat;
                    state                           <= state;
                    reg_gsel                        <= reg_gsel;
                    pc_gsel                         <= (others => '1');
                    pc_gsel(PC_GROUPS_C-2 downto 1) <= pc_gsel(PC_GROUPS_C-3 downto 0);
                  else
                    pc_gsel                         <= (others => '0');
                  end if;
                end if;
              end if;
            end if;
          end if;
        --
      end case;
    end if;
  end process seq;
  
  -- Cycle LUT
  cw_cycle <= therm2bin(reg_gsel(STEP_GROUPS_G-2 downto 0));
  cw_addr  <= lut_addr_i(CTRL_CYCLE_ADR_W_C-1 downto 0) when rst_n_i = '0' else std_logic_vector(unsigned(baseaddr) + unsigned(cw_cycle));
  nano_ctrl_lut_cycle_inst : entity work.nano_lut(edge)
    generic map(DEPTH      => CTRL_CYCLE_DEPTH_G,
                DEPTH_LOG2 => CTRL_CYCLE_ADR_W_C,
                WIDTH_BITS => CTRL_CW_IDENT_W_C,
                W_GRP_SIZE => CTRL_CW_IDENT_W_C)
    port map(clk1_i => clk1_i,
             clk2_i => clk2_i,
             we_i   => we_clut_i,
             addr_i => cw_addr,
             data_i => lut_din_i(CTRL_CW_IDENT_W_C-1 downto 0),
             data_o => cw_ident);
  
  -- Control Word Identification Logic
  nano_ctrl_cw : entity work.nano_ctrl_cw(rtl)
    port map(concat_i   => concat,
             imem_oe_i  => last_cycle,
             wake_i     => wake_i,
             flag_i     => flag_i,
             pc_gsel_i  => pc_gsel,
             cw_ident_i => cw_ident,
             cw_o       => cw_lut);
  
  -- Combinational FSM: Control Signal Generation
  comb : process(state, ir, concat, pc_gsel, reg_gsel, instr_i, opb_fetch, cw_lut)
    variable wake_ack_v : std_logic_vector(NANO_IRQ_W_C-1 downto 0);
  begin
    cw(CW_ZERO_WREN)                                  <= '0';
    cw(CW_CIN)                                        <= '-';
    cw(CW_ACCU_WREN)                                  <= '0';
    cw(CW_CIN_SEL)                                    <= '-';
    cw(CW_B_INV)                                      <= '-';
    cw(CW_B_SEL)                                      <= '-';
    cw(CW_B_ONE)                                      <= '-';
    cw(CW_A_ZERO_N)                                   <= '-';
    cw(CW_A_SEL)                                      <= '-';
    cw(CW_C_WREN)                                     <= '0';
    if PC_GROUPS_C > 1 then
      cw(CW_PC_GSEL+PC_GROUPS_C-2 downto CW_PC_GSEL)  <= (others => '-');
    end if;
    cw(CW_PC_WREN+PC_GROUPS_C-1   downto CW_PC_WREN)  <= (others => '0');
    cw(CW_B_WREN+B_GROUPS_C-1     downto CW_B_WREN)   <= (others => '0');
    cw(CW_B_OP_SEL)                                   <= '-';
    cw(CW_DMEM_OE)                                    <= '0';
    cw(CW_DMEM_WE)                                    <= '0';
    cw(CW_PTR_WREN+PTR_GROUPS_C-1 downto CW_PTR_WREN) <= (others => '0');
    cw(CW_IMEM_OE)                                    <= '0';
    cw(CW_IR_WREN)                                    <= '0';
    cw(CW_CONCAT_WREN)                                <= '0';
    cw(CW_PC_IRQ)                                     <= '0';
    cw(CW_WAKE_ACK+NANO_IRQ_W_C-1 downto CW_WAKE_ACK) <= (others => '0');
    instr_mux                                         <= ir;
    case state is
      --
      -- FETCH: IR <- IMEM[PC]; PC <- PC + 1
      when FETCH =>
        cw(CW_CIN)      <= '1';
        cw(CW_CIN_SEL)  <= '0';
        cw(CW_B_INV)    <= '0';
        cw(CW_B_SEL)    <= '1';
        cw(CW_B_ONE)    <= '0';
        cw(CW_A_ZERO_N) <= '1';
        cw(CW_A_SEL)    <= '1';
        instr_mux       <= instr_i;
        if PC_GROUPS_C > 1 then
          cw(CW_PC_GSEL+PC_GROUPS_C-2 downto CW_PC_GSEL) <= pc_gsel(PC_GROUPS_C-2 downto 0);
          cw(CW_PC_WREN+PC_GROUPS_C-1)                   <= pc_gsel(PC_GROUPS_C-2);
          for i in PC_GROUPS_C-2 downto 1 loop
            cw(CW_PC_WREN+i)                             <= pc_gsel(i-1) and not pc_gsel(i);
          end loop; --i
          cw(CW_PC_WREN)                                 <= not pc_gsel(0);
          cw(CW_IMEM_OE)                                 <= concat and not pc_gsel(0);
          cw(CW_IR_WREN)                                 <= not pc_gsel(0);
          if pc_gsel(0) = '1' then
            instr_mux <= ir;
          end if;
        else
          cw(CW_PC_WREN)                                 <= '1';
          cw(CW_IMEM_OE)                                 <= concat;
          cw(CW_IR_WREN)                                 <= '1';
        end if;
      --
      -- REGFETCH: Fetch MEMPTR or OPB according to look-up
      when REGFETCH =>
        cw(CW_CIN)      <= '1';
        cw(CW_CIN_SEL)  <= '0';
        cw(CW_B_INV)    <= '0';
        cw(CW_B_SEL)    <= '1';
        cw(CW_B_ONE)    <= '0';
        cw(CW_A_ZERO_N) <= '1';
        cw(CW_A_SEL)    <= '1';
        if PC_GROUPS_C > 1 then
          cw(CW_PC_GSEL+PC_GROUPS_C-2 downto CW_PC_GSEL) <= pc_gsel(PC_GROUPS_C-2 downto 0);
          cw(CW_PC_WREN+PC_GROUPS_C-1)                   <= pc_gsel(PC_GROUPS_C-2);
          for i in PC_GROUPS_C-2 downto 1 loop
            cw(CW_PC_WREN+i)                             <= pc_gsel(i-1) and not pc_gsel(i);
          end loop; --i
          cw(CW_PC_WREN)                                 <= not pc_gsel(0);
          cw(CW_IMEM_OE)                                 <= not pc_gsel(0);
          cw(CW_CONCAT_WREN)                             <= not pc_gsel(0);
        else
          cw(CW_PC_WREN)                                 <= '1';
          cw(CW_IMEM_OE)                                 <= '1';
          cw(CW_CONCAT_WREN)                             <= '1';
        end if;
        --
        -- MEMPTR <- IMEM[PC]; CONCAT <- MSB; PC <- PC + 1
        if opb_fetch = '0' then
          -- !! changed for fixed concat for MEH ASIC with 7 bit datapath !!
          if PC_GROUPS_C > 1 then
            cw(CW_PC_WREN+PC_GROUPS_C-1)                   <= '0';
            for i in PC_GROUPS_C-2 downto 1 loop
              cw(CW_PC_WREN+i)                             <= '0';
            end loop; --i
            cw(CW_PC_WREN)                                 <= '0';
            cw(CW_IMEM_OE)                                 <= '0';
            cw(CW_CONCAT_WREN)                             <= '0';
          else
            cw(CW_PC_WREN)                                 <= '0';
            cw(CW_IMEM_OE)                                 <= '0';
            cw(CW_CONCAT_WREN)                             <= '0';
          end if;
          -- !! change end !!
          if PTR_GROUPS_C > 1 then
            if PC_GROUPS_C > 1 then
              cw(CW_PTR_WREN+PTR_GROUPS_C-1) <= reg_gsel(PTR_GROUPS_C-2) and not pc_gsel(0);
              for i in PTR_GROUPS_C-2 downto 1 loop
                cw(CW_PTR_WREN+i)            <= reg_gsel(i-1) and not (reg_gsel(i) or pc_gsel(0));
              end loop; --i
              cw(CW_PTR_WREN)                <= not (reg_gsel(0) or pc_gsel(0));
            else
              cw(CW_PTR_WREN+PTR_GROUPS_C-1) <= reg_gsel(PTR_GROUPS_C-2);
              for i in PTR_GROUPS_C-2 downto 1 loop
                cw(CW_PTR_WREN+i)            <= reg_gsel(i-1) and not reg_gsel(i);
              end loop; --i
              cw(CW_PTR_WREN)                <= not reg_gsel(0);
            end if;
          else
            if PC_GROUPS_C > 1 then
              cw(CW_PTR_WREN)                <= not pc_gsel(0);
            else
              cw(CW_PTR_WREN)                <= '1';
            end if;
          end if;
        --
        -- OPB <- IMEM[PC]; CONCAT <- MSB; PC <- PC + 1
        else
          -- !! changed for normal OPB concat for NexGen datapath !!
          if instr_i(NANO_I_W_C-1) = '0' then  --instr_i(NANO_I_W_C-1) = '0' or concat = '1' then  --instr_i(NANO_I_W_C-1) = '0' then
            if PC_GROUPS_C > 1 then
              cw(CW_PC_WREN+PC_GROUPS_C-1)                   <= '0';
              for i in PC_GROUPS_C-2 downto 1 loop
                cw(CW_PC_WREN+i)                             <= '0';
              end loop; --i
              cw(CW_PC_WREN)                                 <= '0';
              cw(CW_IMEM_OE)                                 <= '0';
              cw(CW_CONCAT_WREN)                             <= '0';
            else
              cw(CW_PC_WREN)                                 <= '0';
              cw(CW_IMEM_OE)                                 <= '0';
              cw(CW_CONCAT_WREN)                             <= '0';
            end if;
          end if;
          cw(CW_B_OP_SEL) <= '1';
          if B_GROUPS_C > 1 then
            if PC_GROUPS_C > 1 then
              cw(CW_B_WREN+B_GROUPS_C-1) <= reg_gsel(B_GROUPS_C-2) and not pc_gsel(0);
              for i in B_GROUPS_C-2 downto 1 loop
                cw(CW_B_WREN+i)          <= reg_gsel(i-1) and not (reg_gsel(i) or pc_gsel(0));
              end loop; --i
              cw(CW_B_WREN)              <= not (reg_gsel(0) or pc_gsel(0));
            else
              cw(CW_B_WREN+B_GROUPS_C-1) <= reg_gsel(B_GROUPS_C-2);
              for i in B_GROUPS_C-2 downto 1 loop
                cw(CW_B_WREN+i)          <= reg_gsel(i-1) and not reg_gsel(i);
              end loop; --i
              cw(CW_B_WREN)              <= not reg_gsel(0);
            end if;
          else
            if PC_GROUPS_C > 1 then
              cw(CW_B_WREN)              <= not pc_gsel(0);
            else
              cw(CW_PTR_WREN)            <= '1';
            end if;
          end if;
        end if;
      --
      when EXECUTE =>
        cw <= cw_lut;
      --
    end case;
  end process comb;
  
  -- Concurrent Control Logic
  pc_mux <= alu_i when cw(CW_PC_IRQ) = '0' else irqv_i;

  -- Control Outputs
  clut_o <= cw_ident;
  schg_o <= statechg_lut;
  cw_o   <= cw;
  pc_o   <= pc;
  ptr_o  <= memptr;
  
end architecture edge;
