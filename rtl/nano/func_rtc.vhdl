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

entity func_rtc is
  generic(CNT_BITS : natural
         );
  port(clk1_i   : in  std_logic;
       clk2_i   : in  std_logic;
       rst_n_i  : in  std_logic;
       param_i  : in  std_logic_vector(NANO_D_W_C-1 downto 0);
       ack_i    : in  std_logic;
       wake_o   : out std_logic
      );
  attribute async_set_reset of rst_n_i : signal is "true";
end entity func_rtc;

architecture edge of func_rtc is
  
  -- Cycle Counter
  constant zero_c : std_logic_vector(NANO_D_W_C-1 downto 0) := (others => '0');
  signal   cnt    : unsigned(CNT_BITS-1 downto 0);
  
  -- Limit Detector
  signal limit  : std_logic;
  signal unconf : std_logic;
  
begin
  
  -- Sequential Counter Update
  seq : process(clk1_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      cnt    <= (others => '0');
      cnt(0) <= '1';
      wake_o <= '0';
    elsif rising_edge(clk1_i) then
      cnt <= cnt + 1;
      if unconf = '1' or limit = '1' then
        cnt    <= (others => '0');
        cnt(0) <= '1';
      end if;
      if unconf = '1' or ack_i = '1' then
        wake_o <= '0';
      elsif limit = '1' then
        wake_o <= '1';
      end if;
    end if;
  end process seq;
  
  -- Limit Detector
  unconf <= '1' when param_i = zero_c else '0';
  limit  <= '1' when std_logic_vector(cnt(CNT_BITS-1 downto CNT_BITS-NANO_D_W_C)) = param_i else '0';
  
end architecture edge;
