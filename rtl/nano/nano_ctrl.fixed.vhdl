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
  signal pc_gsel  : std_logic_vector(PC_GROUPS_C-2   downto 0);
  signal reg_gsel : std_logic_vector(SEQ_GROUPS_C-2  downto 0);
  
  -- Control Logic
  signal cw     : std_logic_vector(CW_W_C-1     downto 0);
  signal pc_mux : std_logic_vector(NANO_D_W_C-1 downto 0);
  
begin

  -- Sequential FSM: Control State
  seq : process(clk1_i, rst_n_i)
    constant no_wake_c  : std_logic_vector(NANO_IRQ_W_C-1 downto 0) := (others => '0');
    variable instr_mux  : std_logic_vector(NANO_I_W_C-1   downto 0);
    variable concat_mux : std_logic;
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
      instr_mux  := instr_i;
      concat_mux := instr_i(NANO_I_W_C-1);
      if PC_GROUPS_C > 1 then
        if pc_gsel(0) = '1' then
          instr_mux  := ir;
          concat_mux := concat;
        end if;
      end if;
      case state is
        --
        when FETCH =>
          case instr_mux is
            when OP_LDI | OP_CMPI | OP_ADDI | OP_SUBI | OP_LIS | OP_LDS | OP_DBNE | OP_BNE | OP_CST | OP_LD | OP_ST =>
              if concat = '0' then
                concat <= '1';
              else
                concat <= '0';
                state  <= REGFETCH;
              end if;
            when others =>
              state <= EXECUTE;
          end case;
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
          case ir is
            when OP_LDI | OP_CMPI | OP_ADDI | OP_SUBI | OP_DBNE | OP_BNE =>
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
            when others =>
              concat <= '0';
              state  <= EXECUTE;
          end case;
          -- !! change end !!
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
          case ir is
            --
            -- CST, CSTL, LD: 3 Execution Cycles
            when OP_CST | OP_CSTL | OP_LD =>
              if reg_gsel(1) = '1' then
                state    <= FETCH;
                reg_gsel <= (others => '0');
              end if;
            --
            -- LDI, CMPI, ADDI, SUBI: 1 Execution Cycle
            when OP_LDI | OP_CMPI | OP_ADDI | OP_SUBI =>
              state    <= FETCH;
              reg_gsel <= (others => '0');
            --
            -- ST, STL: 2 Execution Cycle
            when OP_ST | OP_STL =>
              if reg_gsel(0) = '1' then
                state    <= FETCH;
                reg_gsel <= (others => '0');
              end if;
            --
            -- LIS, LISL, LDS, LDSL: 6 Execution Cycles
            when OP_LIS | OP_LISL | OP_LDS | OP_LDSL =>
              if reg_gsel(4) = '1' then
                state    <= FETCH;
                reg_gsel <= (others => '0');
              end if;
            --
            -- DBNE: 3 Execution Cycles (2 + CONCAT-controlled IMEM cycle)
            when OP_DBNE =>
              if reg_gsel(0) = '1' then
                if concat = '0' then
                  concat   <= '1';
                  reg_gsel <= reg_gsel;
                else
                  state    <= FETCH;
                  reg_gsel <= (others => '0');
                end if;
                if PC_GROUPS_C > 1 then
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
            --
            -- BNE: 2 Execution Cycles (1 + CONCAT-controlled IMEM cycle)
            when OP_BNE =>
              if concat = '0' then
                concat   <= '1';
                reg_gsel <= reg_gsel;
              else
                state    <= FETCH;
                reg_gsel <= (others => '0');
              end if;
              if PC_GROUPS_C > 1 then
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
            --
            -- SLEEP: 2 Execution Cycles (1 + CONCAT-controlled IMEM cycle) when Wake Signal set
            when OP_SLEEP =>
              reg_gsel <= (others => '0');
              if wake_i /= no_wake_c then
                if concat = '0' then
                  concat <= '1';
                else
                  state <= FETCH;
                end if;
              end if;
            --
            when others =>
              state    <= FETCH;
              reg_gsel <= (others => '0');
            --
          end case;
        --
      end case;
    end if;
  end process seq;
  
  -- Combinational FSM: Control Signal Generation
  comb : process(state, ir, concat, pc_gsel, reg_gsel, flag_i, instr_i, wake_i)
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
        if PC_GROUPS_C > 1 then
          cw(CW_PC_GSEL+PC_GROUPS_C-2 downto CW_PC_GSEL) <= pc_gsel;
          cw(CW_PC_WREN+PC_GROUPS_C-1)                   <= pc_gsel(PC_GROUPS_C-2);
          for i in PC_GROUPS_C-2 downto 1 loop
            cw(CW_PC_WREN+i)                             <= pc_gsel(i-1) and not pc_gsel(i);
          end loop; --i
          cw(CW_PC_WREN)                                 <= not pc_gsel(0);
          cw(CW_IMEM_OE)                                 <= concat and not pc_gsel(0);
          cw(CW_IR_WREN)                                 <= not pc_gsel(0);
        else
          cw(CW_PC_WREN)                                 <= '1';
          cw(CW_IMEM_OE)                                 <= concat;
          cw(CW_IR_WREN)                                 <= '1';
        end if;
      --
      -- REGFETCH: Fetch MEMPTR for LIS, LDS, CST, LD, ST, and fetch OPB for LDI, CMPI, ADDI, SUBI, DBNE, BNE
      when REGFETCH =>
        cw(CW_CIN)      <= '1';
        cw(CW_CIN_SEL)  <= '0';
        cw(CW_B_INV)    <= '0';
        cw(CW_B_SEL)    <= '1';
        cw(CW_B_ONE)    <= '0';
        cw(CW_A_ZERO_N) <= '1';
        cw(CW_A_SEL)    <= '1';
        if PC_GROUPS_C > 1 then
          cw(CW_PC_GSEL+PC_GROUPS_C-2 downto CW_PC_GSEL) <= pc_gsel;
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
        case ir is
          --
          -- MEMPTR <- IMEM[PC]; CONCAT <- MSB; PC <- PC + 1
          when OP_LIS | OP_LDS | OP_CST | OP_LD | OP_ST =>
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
          when OP_LDI | OP_CMPI | OP_ADDI | OP_SUBI | OP_DBNE | OP_BNE =>
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
            -- !! change end !!
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
          --
          when others =>
        --
        end case;
      --
      when EXECUTE =>
        case ir is
          --
          -- LDI: ACCU <- OPB; Z
          when OP_LDI =>
            cw(CW_CIN)       <= '0';
            cw(CW_CIN_SEL)   <= '0';
            cw(CW_B_INV)     <= '0';
            cw(CW_B_SEL)     <= '0';
            cw(CW_A_ZERO_N)  <= '0';
            cw(CW_ZERO_WREN) <= '1';
            cw(CW_ACCU_WREN) <= '1';
            cw(CW_C_WREN)    <= '1';
            cw(CW_IMEM_OE)   <= '1';
          --
          -- CST / CSTL: ACCU        <- 0    ; Z
          --             MEM[MEMPTR] <- ACCU ; DMEM Cycle
          --                                 ; IMEM Cycle
          when OP_CST | OP_CSTL =>
            if reg_gsel(0) = '0' then
              cw(CW_CIN)       <= '0';
              cw(CW_CIN_SEL)   <= '0';
              cw(CW_B_INV)     <= '0';
              cw(CW_B_SEL)     <= '1';
              cw(CW_B_ONE)     <= '0';
              cw(CW_A_ZERO_N)  <= '0';
              cw(CW_ZERO_WREN) <= '1';
              cw(CW_ACCU_WREN) <= '1';
              cw(CW_C_WREN)    <= '1';
            elsif reg_gsel(1) = '0' then
              cw(CW_DMEM_WE)   <= '1';
            else
              cw(CW_IMEM_OE)   <= '1';
            end if;
          --
          -- ST / STL: MEM[MEMPTR] <- ACCU ; DMEM Cycle
          --                               ; IMEM Cycle
          when OP_ST | OP_STL =>
            if reg_gsel(0) = '0' then
              cw(CW_DMEM_WE) <= '1';
            else
              cw(CW_IMEM_OE) <= '1';
            end if;
          --
          -- CMPI: ACCU - OPB; Z
          when OP_CMPI =>
            cw(CW_CIN)       <= '1';
            cw(CW_CIN_SEL)   <= '0';
            cw(CW_B_INV)     <= '1';
            cw(CW_B_SEL)     <= '0';
            cw(CW_A_ZERO_N)  <= '1';
            cw(CW_A_SEL)     <= '0';
            cw(CW_ZERO_WREN) <= '1';
            cw(CW_IMEM_OE)   <= '1';
          --
          -- ADDI: ACCU <- ACCU + OPB; Z
          when OP_ADDI =>
            cw(CW_CIN)       <= '0';
            cw(CW_CIN_SEL)   <= '0';
            cw(CW_B_INV)     <= '0';
            cw(CW_B_SEL)     <= '0';
            cw(CW_A_ZERO_N)  <= '1';
            cw(CW_A_SEL)     <= '0';
            cw(CW_ZERO_WREN) <= '1';
            cw(CW_ACCU_WREN) <= '1';
            cw(CW_C_WREN)    <= '1';
            cw(CW_IMEM_OE)   <= '1';
          --
          -- SUBI: ACCU <- ACCU - OPB; Z
          when OP_SUBI =>
            cw(CW_CIN)       <= '1';
            cw(CW_CIN_SEL)   <= '0';
            cw(CW_B_INV)     <= '1';
            cw(CW_B_SEL)     <= '0';
            cw(CW_A_ZERO_N)  <= '1';
            cw(CW_A_SEL)     <= '0';
            cw(CW_ZERO_WREN) <= '1';
            cw(CW_ACCU_WREN) <= '1';
            cw(CW_C_WREN)    <= '1';
            cw(CW_IMEM_OE)   <= '1';
          --
          -- LD:                    ; DMEM Cycle
          --     OPB  <- MEM[MEMPTR]
          --     ACCU <- OPB        ; Z
          when OP_LD =>
            if reg_gsel(0) = '0' then
              cw(CW_DMEM_OE)                              <= '1';
            elsif reg_gsel(1) = '0' then
              cw(CW_B_OP_SEL)                             <= '0';
              cw(CW_B_WREN+B_GROUPS_C-1 downto CW_B_WREN) <= (others => '1');
            else
              cw(CW_CIN)       <= '0';
              cw(CW_CIN_SEL)   <= '0';
              cw(CW_B_INV)     <= '0';
              cw(CW_B_SEL)     <= '0';
              cw(CW_A_ZERO_N)  <= '0';
              cw(CW_ZERO_WREN) <= '1';
              cw(CW_ACCU_WREN) <= '1';
              cw(CW_C_WREN)    <= '1';
              cw(CW_IMEM_OE)   <= '1';
            end if;
          --
          -- LIS / LISL:                           ; DMEM Cycle
          --             OPB         <- MEM[MEMPTR]
          --             ACCU        <- OPB        ; Z
          --             ACCU        <- ACCU + 1   ; Z
          --             MEM[MEMPTR] <- ACCU       ; DMEM Cycle
          --                                       ; IMEM Cycle
          when OP_LIS | OP_LISL =>
            if reg_gsel(0) = '0' then
              cw(CW_DMEM_OE)                              <= '1';
            elsif reg_gsel(1) = '0' then
              cw(CW_B_OP_SEL)                             <= '0';
              cw(CW_B_WREN+B_GROUPS_C-1 downto CW_B_WREN) <= (others => '1');
            elsif reg_gsel(2) = '0' then
              cw(CW_CIN)       <= '0';
              cw(CW_CIN_SEL)   <= '0';
              cw(CW_B_INV)     <= '0';
              cw(CW_B_SEL)     <= '0';
              cw(CW_A_ZERO_N)  <= '0';
              cw(CW_ZERO_WREN) <= '1';
              cw(CW_ACCU_WREN) <= '1';
              cw(CW_C_WREN)    <= '1';
            elsif reg_gsel(3) = '0' then
              cw(CW_CIN)       <= '1';
              cw(CW_CIN_SEL)   <= '0';
              cw(CW_B_INV)     <= '0';
              cw(CW_B_SEL)     <= '1';
              cw(CW_B_ONE)     <= '0';
              cw(CW_A_ZERO_N)  <= '1';
              cw(CW_A_SEL)     <= '0';
              cw(CW_ZERO_WREN) <= '1';
              cw(CW_ACCU_WREN) <= '1';
              cw(CW_C_WREN)    <= '1';
            elsif reg_gsel(4) = '0' then
              cw(CW_DMEM_WE)   <= '1';
            else
              cw(CW_IMEM_OE)   <= '1';
            end if;
          --
          -- LDS / LDSL:                           ; DMEM Cycle
          --             OPB         <- MEM[MEMPTR]
          --             ACCU        <- OPB        ; Z
          --             ACCU        <- ACCU - 1   ; Z
          --             MEM[MEMPTR] <- ACCU       ; DMEM Cycle
          --                                       ; IMEM Cycle
          when OP_LDS | OP_LDSL =>
            if reg_gsel(0) = '0' then
              cw(CW_DMEM_OE)                              <= '1';
            elsif reg_gsel(1) = '0' then
              cw(CW_B_OP_SEL)                             <= '0';
              cw(CW_B_WREN+B_GROUPS_C-1 downto CW_B_WREN) <= (others => '1');
            elsif reg_gsel(2) = '0' then
              cw(CW_CIN)       <= '0';
              cw(CW_CIN_SEL)   <= '0';
              cw(CW_B_INV)     <= '0';
              cw(CW_B_SEL)     <= '0';
              cw(CW_A_ZERO_N)  <= '0';
              cw(CW_ZERO_WREN) <= '1';
              cw(CW_ACCU_WREN) <= '1';
              cw(CW_C_WREN)    <= '1';
            elsif reg_gsel(3) = '0' then
              cw(CW_CIN)       <= '0';
              cw(CW_CIN_SEL)   <= '0';
              cw(CW_B_INV)     <= '1';
              cw(CW_B_SEL)     <= '1';
              cw(CW_B_ONE)     <= '0';
              cw(CW_A_ZERO_N)  <= '1';
              cw(CW_A_SEL)     <= '0';
              cw(CW_ZERO_WREN) <= '1';
              cw(CW_ACCU_WREN) <= '1';
              cw(CW_C_WREN)    <= '1';
            elsif reg_gsel(4) = '0' then
              cw(CW_DMEM_WE)   <= '1';
            else
              cw(CW_IMEM_OE)   <= '1';
            end if;
          --
          -- DBNE:            ACCU <- ACCU - 1; Z
          --       if (not Z) PC   <- PC + OPB
          when OP_DBNE =>
            if reg_gsel(0) = '0' then
              cw(CW_CIN)       <= '0';
              cw(CW_CIN_SEL)   <= '0';
              cw(CW_B_INV)     <= '1';
              cw(CW_B_SEL)     <= '1';
              cw(CW_B_ONE)     <= '0';
              cw(CW_A_ZERO_N)  <= '1';
              cw(CW_A_SEL)     <= '0';
              cw(CW_ZERO_WREN) <= '1';
              cw(CW_ACCU_WREN) <= '1';
              cw(CW_C_WREN)    <= '1';
            else
              cw(CW_CIN)       <= '0';
              cw(CW_CIN_SEL)   <= '0';
              cw(CW_B_INV)     <= '0';
              cw(CW_B_SEL)     <= '0';
              cw(CW_A_ZERO_N)  <= '0';
              cw(CW_A_SEL)     <= '1';
              if flag_i(FL_ZERO_REG) = '0' then
                cw(CW_A_ZERO_N)  <= '1';
                if concat = '0' then
                  if PC_GROUPS_C > 1 then
                    cw(CW_PC_GSEL+PC_GROUPS_C-2 downto CW_PC_GSEL) <= pc_gsel;
                    cw(CW_PC_WREN+PC_GROUPS_C-1)                   <= pc_gsel(PC_GROUPS_C-2);
                    for i in PC_GROUPS_C-2 downto 1 loop
                      cw(CW_PC_WREN+i)                             <= pc_gsel(i-1) and not pc_gsel(i);
                    end loop; --i
                    cw(CW_PC_WREN)                                 <= not pc_gsel(0);
                  else
                    cw(CW_PC_WREN)                                 <= '1';
                  end if;
                end if;
              end if;
              if concat = '1' then
                cw(CW_IMEM_OE) <= '1';
              end if;
            end if;
          --
          -- BNE: if (not Z) PC <- PC + OPB
          when OP_BNE =>
            cw(CW_CIN)       <= '0';
            cw(CW_CIN_SEL)   <= '0';
            cw(CW_B_INV)     <= '0';
            cw(CW_B_SEL)     <= '0';
            cw(CW_A_ZERO_N)  <= '0';
            cw(CW_A_SEL)     <= '1';
            if flag_i(FL_ZERO_REG) = '0' then
              cw(CW_A_ZERO_N)  <= '1';
              if concat = '0' then
                if PC_GROUPS_C > 1 then
                  cw(CW_PC_GSEL+PC_GROUPS_C-2 downto CW_PC_GSEL) <= pc_gsel;
                  cw(CW_PC_WREN+PC_GROUPS_C-1)                   <= pc_gsel(PC_GROUPS_C-2);
                  for i in PC_GROUPS_C-2 downto 1 loop
                    cw(CW_PC_WREN+i)                             <= pc_gsel(i-1) and not pc_gsel(i);
                  end loop; --i
                  cw(CW_PC_WREN)                                 <= not pc_gsel(0);
                else
                  cw(CW_PC_WREN)                                 <= '1';
                end if;
              end if;
            end if;
            if concat = '1' then
              cw(CW_IMEM_OE) <= '1';
            end if;
          --
          -- SLEEP: if (wake_i) ACK; PC <- IRQV
          when OP_SLEEP =>
            cw(CW_PC_IRQ) <= '1';
            wake_ack_v    := (others => '0');
            for i in 0 to NANO_IRQ_W_C-1 loop
              if wake_i(i) = '1' then
                cw(CW_PC_WREN) <= '1';
                if concat = '1' then
                  wake_ack_v     := (others => '0');
                  wake_ack_v(i)  := '1';
                  cw(CW_IMEM_OE) <= '1';
                end if;
              end if;
            end loop; --i
            cw(CW_WAKE_ACK+NANO_IRQ_W_C-1 downto CW_WAKE_ACK) <= wake_ack_v;
          --
          when others =>
          --
        end case;
      --
    end case;
  end process comb;
  
  -- Concurrent Control Logic
  pc_mux <= alu_i when cw(CW_PC_IRQ) = '0' else irqv_i;

  -- Control Outputs
  clut_o <= (others => '-');
  schg_o <= (others => '-');
  cw_o   <= cw;
  pc_o   <= pc;
  ptr_o  <= memptr;
  
end architecture edge;
