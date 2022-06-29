-- Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;

use work.aux_pkg.all;

package nano_pkg is

  -- Architectural Parameters
  constant NANO_IRQ_W_C     : natural := 4;               -- Total Number of Wake-Up Interrupts
  constant NANO_EXT_IRQ_W_C : natural := NANO_IRQ_W_C-1;  -- Number of External Wake-Up Interrupts (lower priority than internal events)
  -- !! changed for MEH ASIC with 7 bit datapath !!
  constant NANO_D_W_C       : natural := 7;  --6;             -- Datapath Width
  constant NANO_D_ADR_W_C   : natural := 4;  --3;             -- Data Memory Address Width
  constant NANO_I_W_C       : natural := 4;               -- Instruction Width
  constant NANO_I_ADR_W_C   : natural := 7;  --6;             -- Instruction Memory Address Width
  -- !! change end !!
  constant NANO_FUNC_OUTS_C : natural := NANO_IRQ_W_C+4;  -- Number of Functional Memory Outputs
  
  -- Derived Constants
  constant PC_GROUP_W_C  : natural := mini(NANO_D_W_C, NANO_I_ADR_W_C);      -- PC Bitgroup Width
  constant PC_GROUPS_C   : natural := ((NANO_I_ADR_W_C-1)/PC_GROUP_W_C)+1;   -- Number of PC Bitgroups
  constant B_GROUP_W_C   : natural := mini(NANO_D_W_C, NANO_I_W_C-1);        -- Operand B Bitgroup Width
  -- !! changed for fixed concat for MEH ASIC with 7 bit datapath !!
  constant B_GROUPS_C    : natural := ((NANO_D_W_C-2)/B_GROUP_W_C)+1;  --((NANO_D_W_C-1)/B_GROUP_W_C)+1;        -- Number of Operand B Bitgroups
  constant PTR_GROUP_W_C : natural := mini(NANO_D_ADR_W_C, NANO_I_W_C);  --NANO_I_W_C-1);    -- MEMPTR Bitgroup Width
  -- !! change end !!
  constant PTR_GROUPS_C  : natural := ((NANO_D_ADR_W_C-1)/PTR_GROUP_W_C)+1;  -- Number of MEMPTR Bitgroups
  constant CTRL_GROUPS_C : natural := maxi(B_GROUPS_C, PTR_GROUPS_C);        -- Number of Register Bitgroups for CU State
  constant STEP_GROUPS_C : natural := 4;                                     -- Max Number of Control Steps per Instruction
  constant SEQ_GROUPS_C  : natural := maxi(CTRL_GROUPS_C, STEP_GROUPS_C);    -- Number of Sequential Steps Register Bits
  
  -- Opcode Definitions
  constant OP_LDI   : std_logic_vector(NANO_I_W_C-1 downto 0) := "0000";
  constant OP_CMPI  : std_logic_vector(NANO_I_W_C-1 downto 0) := "0001";
  constant OP_ADDI  : std_logic_vector(NANO_I_W_C-1 downto 0) := "0010";
  constant OP_SUBI  : std_logic_vector(NANO_I_W_C-1 downto 0) := "0011";
  constant OP_LIS   : std_logic_vector(NANO_I_W_C-1 downto 0) := "0100";
  constant OP_LISL  : std_logic_vector(NANO_I_W_C-1 downto 0) := "0101";
  constant OP_LDS   : std_logic_vector(NANO_I_W_C-1 downto 0) := "0110";
  constant OP_LDSL  : std_logic_vector(NANO_I_W_C-1 downto 0) := "0111";
  constant OP_DBNE  : std_logic_vector(NANO_I_W_C-1 downto 0) := "1000";
  constant OP_BNE   : std_logic_vector(NANO_I_W_C-1 downto 0) := "1001";
  constant OP_CST   : std_logic_vector(NANO_I_W_C-1 downto 0) := "1010";
  constant OP_CSTL  : std_logic_vector(NANO_I_W_C-1 downto 0) := "1011";
  constant OP_ST    : std_logic_vector(NANO_I_W_C-1 downto 0) := "1100";
  constant OP_STL   : std_logic_vector(NANO_I_W_C-1 downto 0) := "1101";
  constant OP_LD    : std_logic_vector(NANO_I_W_C-1 downto 0) := "1110";
  constant OP_SLEEP : std_logic_vector(NANO_I_W_C-1 downto 0) := "1111";
  
  -- Datapath Control Word Bits
  constant CW_ZERO_WREN   : natural :=                  0;
  constant CW_CIN         : natural := CW_ZERO_WREN   + 1;
  constant CW_ACCU_WREN   : natural := CW_CIN         + 1;
  constant CW_CIN_SEL     : natural := CW_ACCU_WREN   + 1;
  constant CW_B_INV       : natural := CW_CIN_SEL     + 1;
  constant CW_B_SEL       : natural := CW_B_INV       + 1;
  constant CW_B_ONE       : natural := CW_B_SEL       + 1;
  constant CW_A_ZERO_N    : natural := CW_B_ONE       + 1;
  constant CW_A_SEL       : natural := CW_A_ZERO_N    + 1;
  constant CW_C_WREN      : natural := CW_A_SEL       + 1;
  constant CW_PC_GSEL     : natural := CW_C_WREN      + 1;
  constant CW_PC_WREN     : natural := CW_PC_GSEL     + PC_GROUPS_C-1;
  constant CW_B_WREN      : natural := CW_PC_WREN     + PC_GROUPS_C;
  constant CW_B_OP_SEL    : natural := CW_B_WREN      + B_GROUPS_C;
  constant CW_DMEM_OE     : natural := CW_B_OP_SEL    + 1;
  constant CW_DMEM_WE     : natural := CW_DMEM_OE     + 1;
  constant CW_PTR_WREN    : natural := CW_DMEM_WE     + 1;
  constant CW_IMEM_OE     : natural := CW_PTR_WREN    + PTR_GROUPS_C;
  constant CW_IR_WREN     : natural := CW_IMEM_OE     + 1;
  constant CW_CONCAT_WREN : natural := CW_IR_WREN     + 1;
  constant CW_PC_IRQ      : natural := CW_CONCAT_WREN + 1;
  constant CW_WAKE_ACK    : natural := CW_PC_IRQ      + 1;
  
  -- Datapath Flag Bits
  constant FL_CARRY_REG : natural := 0;
  constant FL_ZERO_REG  : natural := FL_CARRY_REG + 1;
  constant FL_CARRY     : natural := FL_ZERO_REG  + 1;
  constant FL_ZERO      : natural := FL_CARRY     + 1;
  
  -- More Derived Constants
  constant CW_W_C : natural := CW_WAKE_ACK + NANO_IRQ_W_C;  -- Datapath Control Word Width
  constant FL_W_C : natural := FL_ZERO     + 1;             -- Datapath Flag Width
  
end package nano_pkg;
