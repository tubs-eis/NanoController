-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    TU Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.

library ieee;
use ieee.std_logic_1164.all;

package ctrl_pkg is
  
  -- SAR ADC
  constant CTRL_ADC_BW_C : natural := 10;  -- Bitwidth of SAR ADC
  
  -- Clock Divider
  constant CTRL_CLKDIV_CNT_W_C : natural := 3;  -- Cycle Counter Width for configurable Clock Divider
  
  -- Debug Commands (8 Bit)
  --
  -- | 7     4 | 3     0 |
  -- | Command | Address |
  --
  constant DBG_CMD_LEN_C  : natural := 4;
  constant DBG_CMD_LO_IDX : natural := 4;
  constant DBG_CMD_HI_IDX : natural := DBG_CMD_LO_IDX + DBG_CMD_LEN_C - 1;
  --
  constant DBG_CMD_W_RST_C  : std_logic_vector(3 downto 0) := "0000";  -- WRITE: Reset State
  constant DBG_CMD_W_CGEN_C : std_logic_vector(3 downto 0) := "0010";  -- WRITE: Clock Enable Generator
  constant DBG_CMD_W_INST_C : std_logic_vector(3 downto 0) := "0011";  -- WRITE: Instruction
  constant DBG_CMD_W_RATE_C : std_logic_vector(3 downto 0) := "0100";  -- WRITE: Baudrate
  constant DBG_CMD_W_WAKE_C : std_logic_vector(3 downto 0) := "0101";  -- WRITE: Wake-Up Events
  constant DBG_CMD_W_CLUT_C : std_logic_vector(3 downto 0) := "0110";  -- WRITE: Cycle LUT
  constant DBG_CMD_W_SCHG_C : std_logic_vector(3 downto 0) := "0111";  -- WRITE: State Change LUT
  --
  constant DBG_CMD_R_ADC_C  : std_logic_vector(3 downto 0) := "1000";  -- READ: ADC
  constant DBG_CMD_R_FUNC_C : std_logic_vector(3 downto 0) := "1001";  -- READ: Functional Memory
  constant DBG_CMD_R_IADR_C : std_logic_vector(3 downto 0) := "1010";  -- READ: Instruction Address
  constant DBG_CMD_R_INST_C : std_logic_vector(3 downto 0) := "1011";  -- READ: Instruction
  constant DBG_CMD_R_RATE_C : std_logic_vector(3 downto 0) := "1100";  -- READ: Baudrate
  constant DBG_CMD_R_CLUT_C : std_logic_vector(3 downto 0) := "1110";  -- READ: Cycle LUT
  constant DBG_CMD_R_SCHG_C : std_logic_vector(3 downto 0) := "1111";  -- READ: State Change LUT
  
  -- Debug UART
  -- UART status register (USR): bit constants
  constant RXC  : natural := 7;         -- RX interrupt
  constant TXC  : natural := 6;         -- TX interrupt
  constant UDRE : natural := 5;         -- data register (TX) empty
  constant FERR : natural := 4;         -- framing error
  constant OVR  : natural := 3;         -- overrun
  constant USR2 : natural := 2;         -- free
  constant USR1 : natural := 1;         -- free
  constant USR0 : natural := 0;         -- free
  
  -- Debug SPI
  constant DBG_SPI_SYNCHER_W_C : natural := 3;  -- Width of Valid Signal Synchronizer (including Edge Feedback)
  constant DBG_SPI_EDGEDLY_W_C : natural := 3;  -- Width of Edge Delay Shift Register for generating several Enable Signals
  
end package ctrl_pkg;
