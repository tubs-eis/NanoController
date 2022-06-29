-- Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;

entity clkgate is
  port(clk : in  std_logic;
       en  : in  std_logic;
       gck : out std_logic);
end entity clkgate;

architecture asic of clkgate is
  signal en_lat : std_logic;
begin
  process(clk,en)
  begin
    if clk = '0' then
      en_lat <= en;
    end if;
  end process;
  gck <= clk and en_lat;
end architecture asic;
