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

entity nano_ctrl_cw is
  port(concat_i   : in  std_logic;                                       -- Concatenation Flag
       imem_oe_i  : in  std_logic;
       wake_i     : in  std_logic_vector(NANO_IRQ_W_C-1      downto 0);
       flag_i     : in  std_logic_vector(FL_W_C-1            downto 0);  -- Datapath Flags
       pc_gsel_i  : in  std_logic_vector(PC_GROUPS_C-1       downto 0);
       cw_ident_i : in  std_logic_vector(CTRL_CW_IDENT_W_C-1 downto 0);  -- Control Word Identification Number
       cw_o       : out std_logic_vector(CW_W_C-1            downto 0)   -- Datapath Control Word
      );
end entity nano_ctrl_cw;

architecture rtl of nano_ctrl_cw is
  signal cw : std_logic_vector(CW_W_C-1 downto 0);
begin
  
  comb : process(concat_i, imem_oe_i, wake_i, flag_i, pc_gsel_i, cw_ident_i)
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
    case cw_ident_i is
      --
      -- ; IMEM Cycle
      when IDENT_IMEM_CYCLE =>
        cw(CW_IMEM_OE) <= '1';
      --
      -- ; DMEM Cycle
      when IDENT_DMEM_CYCLE =>
        cw(CW_DMEM_OE) <= '1';
      --
      -- OPB <- MEM[MEMPTR]
      when IDENT_OPB_FROM_MEM =>
        cw(CW_B_OP_SEL)                             <= '0';
        cw(CW_B_WREN+B_GROUPS_C-1 downto CW_B_WREN) <= (others => '1');
      --
      -- MEM[MEMPTR] <- ACCU; DMEM Cycle
      when IDENT_MEM_FROM_ACCU =>
        cw(CW_DMEM_WE) <= '1';
      --
      -- ACCU - OPB; Z
      when IDENT_CMP_ACCU_OPB =>
        cw(CW_CIN)       <= '1';
        cw(CW_CIN_SEL)   <= '0';
        cw(CW_B_INV)     <= '1';
        cw(CW_B_SEL)     <= '0';
        cw(CW_A_ZERO_N)  <= '1';
        cw(CW_A_SEL)     <= '0';
        cw(CW_ZERO_WREN) <= '1';
        if imem_oe_i = '1' then
          cw(CW_IMEM_OE) <= '1';
        end if;
      --
      -- ACCU <- ACCU + OPB; Z
      when IDENT_ACCU_PLUS_OPB =>
        cw(CW_CIN)       <= '0';
        cw(CW_CIN_SEL)   <= '0';
        cw(CW_B_INV)     <= '0';
        cw(CW_B_SEL)     <= '0';
        cw(CW_A_ZERO_N)  <= '1';
        cw(CW_A_SEL)     <= '0';
        cw(CW_ZERO_WREN) <= '1';
        cw(CW_ACCU_WREN) <= '1';
        cw(CW_C_WREN)    <= '1';
        if imem_oe_i = '1' then
          cw(CW_IMEM_OE) <= '1';
        end if;
      --
      -- ACCU <- ACCU - OPB; Z
      when IDENT_ACCU_MINUS_OPB =>
        cw(CW_CIN)       <= '1';
        cw(CW_CIN_SEL)   <= '0';
        cw(CW_B_INV)     <= '1';
        cw(CW_B_SEL)     <= '0';
        cw(CW_A_ZERO_N)  <= '1';
        cw(CW_A_SEL)     <= '0';
        cw(CW_ZERO_WREN) <= '1';
        cw(CW_ACCU_WREN) <= '1';
        cw(CW_C_WREN)    <= '1';
        if imem_oe_i = '1' then
          cw(CW_IMEM_OE) <= '1';
        end if;
      --
      -- ACCU <- OPB; Z
      when IDENT_ACCU_FROM_OPB =>
        cw(CW_CIN)       <= '0';
        cw(CW_CIN_SEL)   <= '0';
        cw(CW_B_INV)     <= '0';
        cw(CW_B_SEL)     <= '0';
        cw(CW_A_ZERO_N)  <= '0';
        cw(CW_ZERO_WREN) <= '1';
        cw(CW_ACCU_WREN) <= '1';
        cw(CW_C_WREN)    <= '1';
        if imem_oe_i = '1' then
          cw(CW_IMEM_OE) <= '1';
        end if;
      --
      -- ACCU <- 0; Z
      when IDENT_ACCU_ZERO =>
        cw(CW_CIN)       <= '0';
        cw(CW_CIN_SEL)   <= '0';
        cw(CW_B_INV)     <= '0';
        cw(CW_B_SEL)     <= '1';
        cw(CW_B_ONE)     <= '0';
        cw(CW_A_ZERO_N)  <= '0';
        cw(CW_ZERO_WREN) <= '1';
        cw(CW_ACCU_WREN) <= '1';
        cw(CW_C_WREN)    <= '1';
        if imem_oe_i = '1' then
          cw(CW_IMEM_OE) <= '1';
        end if;
      --
      -- ACCU <- ACCU + 1; Z
      when IDENT_ACCU_PLUS_ONE =>
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
        if imem_oe_i = '1' then
          cw(CW_IMEM_OE) <= '1';
        end if;
      --
      -- ACCU <- ACCU - 1; Z
      when IDENT_ACCU_MINUS_ONE =>
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
        if imem_oe_i = '1' then
          cw(CW_IMEM_OE) <= '1';
        end if;
      --
      -- if (not Z) PC <- PC + OPB
      when IDENT_BRANCH =>
        cw(CW_CIN)      <= '0';
        cw(CW_CIN_SEL)  <= '0';
        cw(CW_B_INV)    <= '0';
        cw(CW_B_SEL)    <= '0';
        cw(CW_A_ZERO_N) <= '0';
        cw(CW_A_SEL)    <= '1';
        if flag_i(FL_ZERO_REG) = '0' then
          cw(CW_A_ZERO_N) <= '1';
          if concat_i = '0' then
            if PC_GROUPS_C > 1 then
              cw(CW_PC_GSEL+PC_GROUPS_C-2 downto CW_PC_GSEL) <= pc_gsel_i(PC_GROUPS_C-2 downto 0);
              cw(CW_PC_WREN+PC_GROUPS_C-1)                   <= pc_gsel_i(PC_GROUPS_C-2);
              for i in PC_GROUPS_C-2 downto 1 loop
                cw(CW_PC_WREN+i)                             <= pc_gsel_i(i-1) and not pc_gsel_i(i);
              end loop; --i
              cw(CW_PC_WREN)                                 <= not pc_gsel_i(0);
            else
              cw(CW_PC_WREN)                                 <= '1';
            end if;
          end if;
        end if;
        if concat_i = '1' then
          cw(CW_IMEM_OE) <= '1';
        end if;
      --
      -- if (wake_i) ACK; PC <- IRQV
      when IDENT_WAKE =>
        cw(CW_PC_IRQ) <= '1';
        wake_ack_v    := (others => '0');
        for i in 0 to NANO_IRQ_W_C-1 loop
          if wake_i(i) = '1' then
            cw(CW_PC_WREN) <= '1';
            if concat_i = '1' then
              wake_ack_v     := (others => '0');
              wake_ack_v(i)  := '1';
              cw(CW_IMEM_OE) <= '1';
            end if;
          end if;
        end loop; --i
        cw(CW_WAKE_ACK+NANO_IRQ_W_C-1 downto CW_WAKE_ACK) <= wake_ack_v;
      --
      when others =>
    end case;
  end process comb;
  
  -- Control Outputs
  cw_o  <= cw;
  
end architecture rtl;
