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

entity nano_lut is
  generic(DEPTH      : natural;
          DEPTH_LOG2 : natural;
          WIDTH_BITS : natural;
          W_GRP_SIZE : natural
         );
  port(clk1_i  : in  std_logic;
       clk2_i  : in  std_logic;
       we_i    : in  std_logic_vector((WIDTH_BITS-1)/W_GRP_SIZE downto 0);
       addr_i  : in  std_logic_vector(DEPTH_LOG2-1 downto 0);
       data_i  : in  std_logic_vector(W_GRP_SIZE-1 downto 0);
       data_o  : out std_logic_vector(WIDTH_BITS-1 downto 0)
      );
end entity nano_lut;

architecture edge of nano_lut is
  
  signal cluta        : unsigned(4 downto 0);
  signal clutd, clutq : std_logic_vector(3 downto 0);
  type clut_t is array (0 to 31) of std_logic_vector(3 downto 0);
  signal clut : clut_t := (
    0  => "1000", 1  => "0011", 2  => "0000", 3  => "0100",
    4  => "0101", 5  => "0110", 6  => "0001", 7  => "0010",
    8  => "0111", 9  => "1001", 10 => "0011", 11 => "0000",
    12 => "0001", 13 => "0010", 14 => "0111", 15 => "1010",
    16 => "0011", 17 => "0000", 18 => "1010", 19 => "1011",
    20 => "1100", others => "0000"
  );
  
  signal schga : unsigned(3 downto 0);
  signal schgd_lo, schgq_lo : std_logic_vector(7 downto 0);
  signal schgd_hi, schgq_hi : std_logic_vector(3 downto 0);
  type schg_lo_t is array (0 to 15) of std_logic_vector(7 downto 0);
  type schg_hi_t is array (0 to 15) of std_logic_vector(3 downto 0);
  signal schg_lo : schg_lo_t := (
    0  => "01000000", 1  => "00011000",
    2  => "00100000", 3  => "00101000",
    4  => "00110101", 5  => "00110101",
    6  => "01100101", 7  => "01100101",
    8  => "10010001", 9  => "10011000",
    10 => "00000010", 11 => "00000010",
    12 => "00001001", 13 => "00001001",
    14 => "00110010", 15 => "10100000",
    others => "00000000"
  );
  signal schg_hi : schg_hi_t := (
    0  => "1100", 1  => "1100",
    2  => "1100", 3  => "1100",
    4  => "1000", 5  => "0000",
    6  => "1000", 7  => "0000",
    8  => "1110", 9  => "1110",
    10 => "1000", 11 => "0000",
    12 => "1000", 13 => "0000",
    14 => "1000", 15 => "0001",
    others => "0000"
  );
  
  attribute ram_style : string;
  attribute ram_style of clut    : signal is "distributed";
  attribute ram_style of schg_lo : signal is "distributed";
  attribute ram_style of schg_hi : signal is "distributed";
  
begin
  
  process(addr_i)
  begin
    cluta <= (others => '0');
    schga <= (others => '0');
    --
    for i in addr_i'length-1 downto 0 loop
      if i < cluta'length then
        cluta(i) <= addr_i(i);
      end if;
      if i < schga'length then
        schga(i) <= addr_i(i);
      end if;
    end loop; --i
  end process;
  
  process(data_i)
  begin
    clutd    <= (others => '0');
    schgd_lo <= (others => '0');
    schgd_hi <= (others => '0');
    --
    for i in data_i'length-1 downto 0 loop
      if i < clutd'length-1 then
        clutd(i) <= data_i(i);
      end if;
      if i < schgd_lo'length-1 then
        schgd_lo(i) <= data_i(i);
      end if;
      if i < schgd_hi'length-1 then
        schgd_hi(i) <= data_i(i);
      end if;
    end loop; --i
  end process;
  
  process(clutq, schgq_lo, schgq_hi)
  begin
    data_o <= (others => '0');
    --
    if data_o'length = clutq'length then
      data_o <= clutq;
    else
      data_o(                schgq_lo'length-1 downto               0) <= schgq_lo;
      data_o(schgq_hi'length+schgq_lo'length-1 downto schgq_lo'length) <= schgq_hi;
    end if;
  end process;
  
  process(clk1_i)
  begin
    if rising_edge(clk1_i) then
      for i in 0 to we_i'length-1 loop
       if i = 0 then
        if we_i(i) = '1' then
          clut(to_integer(cluta)) <= clutd;
          schg_lo(to_integer(schga)) <= schgd_lo;
        end if;
       else
        if we_i(i) = '1' then
          schg_hi(to_integer(schga)) <= schgd_hi;
        end if;
       end if;
      end loop; --i
    end if;
  end process;
  
  clutq    <= clut(to_integer(cluta));
  schgq_lo <= schg_lo(to_integer(schga));
  schgq_hi <= schg_hi(to_integer(schga));
  
end architecture edge;
