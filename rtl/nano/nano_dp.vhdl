-- Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
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

use work.nano_pkg.all;
use work.aux_pkg.all;

entity nano_dp is
  port(clk1_i  : in  std_logic;
       clk2_i  : in  std_logic;
       rst_n_i : in  std_logic;
       cw_i    : in  std_logic_vector(CW_W_C-1         downto 0);  -- Datapath Control Word
       pc_i    : in  std_logic_vector(NANO_I_ADR_W_C-1 downto 0);  -- Program Counter
       data_i  : in  std_logic_vector(NANO_D_W_C-1     downto 0);
       flag_o  : out std_logic_vector(FL_W_C-1         downto 0);  -- Datapath Flags
       data_o  : out std_logic_vector(NANO_D_W_C-1     downto 0);
       alu_o   : out std_logic_vector(NANO_D_W_C-1     downto 0)
      );
  attribute async_set_reset of rst_n_i : signal is "true";
end entity nano_dp;

architecture edge of nano_dp is
  
  -- Datapath Registers
  signal accu : unsigned(NANO_D_W_C   downto 0); -- Accu including Carry
  signal opb  : unsigned(NANO_D_W_C-1 downto 0); -- Operand B
  signal z    : std_logic;                       -- Zero Flag
  
  -- Adder Logic
  signal result, a   : unsigned(NANO_D_W_C   downto 0);
  signal b           : unsigned(NANO_D_W_C-1 downto 0);
  signal c           : unsigned(0            downto 0);
  signal result_zero : std_logic;
  
  -- Operand Logic
  signal a_pre  : std_logic_vector(NANO_D_W_C    downto 0);
  signal b_pre  : std_logic_vector(NANO_D_W_C-1  downto 0);
  signal b_one  : std_logic_vector(NANO_D_W_C-1  downto 0);
  signal pc_g   : std_logic_vector(NANO_D_W_C-1  downto 0);
  
begin

  -- Sequential Register Update
  seq : process(clk1_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      accu <= (others => '0');
      opb  <= (others => '0');
      z    <= '0';
    elsif rising_edge(clk1_i) then
      --
      if cw_i(CW_ACCU_WREN) = '1' then
        accu(NANO_D_W_C-1 downto 0) <= result(NANO_D_W_C-1 downto 0);
      end if;
      --
      if cw_i(CW_C_WREN) = '1' then
        accu(NANO_D_W_C) <= result(NANO_D_W_C);
      end if;
      --
      if cw_i(CW_ZERO_WREN) = '1' then
        z <= result_zero;
      end if;
      --
      for i in 0 to B_GROUPS_C-2 loop
        if cw_i(CW_B_WREN+i) = '1' then
          opb((i+1)*B_GROUP_W_C-1 downto i*B_GROUP_W_C) <= unsigned(data_i((i+1)*B_GROUP_W_C-1 downto i*B_GROUP_W_C));
        end if;
      end loop; --i
      if cw_i(CW_B_WREN+B_GROUPS_C-1) = '1' then
        opb(NANO_D_W_C-1 downto (B_GROUPS_C-1)*B_GROUP_W_C) <= unsigned(data_i(NANO_D_W_C-1 downto (B_GROUPS_C-1)*B_GROUP_W_C));
      end if;
      --
    end if;
  end process seq;
  
  -- Adder
  a           <= unsigned(a_pre and (NANO_D_W_C   downto 0 => cw_i(CW_A_ZERO_N)));
  b           <= unsigned(b_pre xor (NANO_D_W_C-1 downto 0 => cw_i(CW_B_INV)));
  c           <= accu(NANO_D_W_C downto NANO_D_W_C) when cw_i(CW_CIN_SEL) = '1' else (others => cw_i(CW_CIN));
  result      <= a + b + c;
  result_zero <= '1' when result(NANO_D_W_C-1 downto 0) = 0 else '0';
  
  -- Operand Inputs
  a_pre(NANO_D_W_C)            <= '0';
  a_pre(NANO_D_W_C-1 downto 0) <= std_logic_vector(accu(NANO_D_W_C-1 downto 0)) when cw_i(CW_A_SEL) = '0' else pc_g;
  pc_g                         <= muxchain(pc_i, cw_i(PC_GROUPS_C+CW_PC_GSEL-2 downto CW_PC_GSEL), NANO_D_W_C);
  b_pre                        <= std_logic_vector(opb) when cw_i(CW_B_SEL) = '0' else b_one;
  b_one                        <= (0 => cw_i(CW_B_ONE), others => '0');
  
  -- Datapath Outputs
  data_o               <= std_logic_vector(accu(NANO_D_W_C-1 downto 0));
  alu_o                <= std_logic_vector(result(NANO_D_W_C-1 downto 0));
  flag_o(FL_CARRY_REG) <= std_logic(accu(NANO_D_W_C));
  flag_o(FL_ZERO_REG)  <= z;
  flag_o(FL_CARRY)     <= std_logic(result(NANO_D_W_C));
  flag_o(FL_ZERO)      <= result_zero;

end architecture edge;
