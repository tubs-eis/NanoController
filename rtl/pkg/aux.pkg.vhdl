-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    TU Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.std_logic_1164.all;

package aux_pkg is
  function log2(temp : natural) return natural;
  function mini(a, b : natural) return natural;
  function maxi(a, b : natural) return natural;
  function orreduce(input : std_logic_vector) return std_logic;
  function andexpand(input : std_logic_vector; mask : std_logic) return std_logic_vector;
  function muxtree(input, sel : std_logic_vector; len : natural) return std_logic_vector;
  function muxchain(input, sel : std_logic_vector; len : natural) return std_logic_vector;
  function dectree(input : std_logic; sel : std_logic_vector) return std_logic_vector;
  function bin2therm(input : std_logic_vector) return std_logic_vector;
  function therm2bin(input : std_logic_vector) return std_logic_vector;
end package aux_pkg;

package body aux_pkg is
	function log2(temp : natural) return natural is
	begin
		for i in 0 to integer'high loop
			if (2**i >= temp) then
				return i;
			end if;
		end loop;
		return 0;
	end function log2;
  
  function mini(a, b : natural) return natural is
  begin
    if (a < b) then
      return a;
    else
      return b;
    end if;
  end function mini;
  
  function maxi(a, b : natural) return natural is
  begin
    if (a > b) then
      return a;
    else
      return b;
    end if;
  end function maxi;
  
  function orreduce(input : std_logic_vector) return std_logic is
    variable output : std_logic;
  begin
    output := '0';
    for i in input'low to input'high loop
      output := output or input(i);
    end loop; --i
    return output;
  end function orreduce;
  
  function andexpand(input : std_logic_vector; mask : std_logic) return std_logic_vector is
    variable output : std_logic_vector(input'high downto input'low);
  begin
    for i in input'low to input'high loop
      output(i) := input(i) and mask;
    end loop; --i
    return output;
  end function andexpand;
  
  function muxtree(input, sel : std_logic_vector; len : natural) return std_logic_vector is
    variable output : std_logic_vector(len-1          downto 0);
    variable temp   : std_logic_vector(input'length-1 downto 0);
    variable idx    : natural;
  begin
    output := (others => '0');
    temp   := (others => '0');
    idx    := input'length;
    if len >= idx then
      output(idx-1 downto 0) := input;
      return output;
    else
      idx := 2**(sel'length-1)*len;
      if sel(sel'left) = '0' then
        temp(idx-1 downto 0) := input(idx-1 downto 0);
        return muxtree(temp(idx-1 downto 0), sel(sel'left-1 downto sel'right), len);
      else
        temp(input'length-idx-1 downto 0) := input(input'length-1 downto idx);
        return muxtree(temp(input'length-idx-1 downto 0), sel(sel'left-1 downto sel'right), len);
      end if;
    end if;
  end function muxtree;
  
  function muxchain(input, sel : std_logic_vector; len : natural) return std_logic_vector is
    variable output : std_logic_vector(len-1 downto 0);
    variable idx    : natural;
  begin
    output := (others => '0');
    idx    := input'length;
    if len >= idx then
      output(idx-1 downto 0) := input;
      return output;
    else
      idx := sel'length*len;
      if sel(sel'left) = '0' then
        return muxchain(input(idx-1 downto 0), sel(sel'left-1 downto sel'right), len);
      else
        output(input'length-idx-1 downto 0) := input(input'length-1 downto idx);
        return output;
      end if;
    end if;
  end function muxchain;
  
  function dectree(input : std_logic; sel : std_logic_vector) return std_logic_vector is
    variable output : std_logic_vector(2**sel'length-1   downto 0);
    variable temp   : std_logic_vector(output'length/2-1 downto 0);
    variable addr   : std_logic_vector(sel'length-2      downto 0);
  begin
    output := (others => '0');
    if sel'length = 0 then
      output(0) := input;
      return output;
    else
      addr := sel(sel'left downto sel'right+1);
      temp := dectree(input, addr);
      for i in 0 to temp'length-1 loop
        case sel(sel'right) is
          when '0' =>    output(2*i)   := temp(i);
          when '1' =>    output(2*i+1) := temp(i);
          when others =>
        end case;
      end loop; --i
      return output;
    end if;
  end function dectree;
  
  function bin2therm(input : std_logic_vector) return std_logic_vector is
    variable output : std_logic_vector(2**input'length-2 downto 0);
    variable temp   : std_logic_vector(output'length/2-1 downto 0);
    variable msbexp : std_logic_vector(temp'length-1     downto 0);
    variable msb    : std_logic;
  begin
    if input'length <= 1 then
      return input;
    else
      temp := bin2therm(input(input'left-1 downto input'right));
      msb  := input(input'left);
      for i in msbexp'left downto msbexp'right loop
        msbexp(i) := msb;
      end loop; --i
      output := (temp and msbexp) & msb & (temp or msbexp);
      return output;
    end if;
  end function bin2therm;
  
  function therm2bin(input : std_logic_vector) return std_logic_vector is
    variable inalign : std_logic_vector(2**log2(input'length+1)-2 downto 0);
    variable output  : std_logic_vector(log2(inalign'length)-1    downto 0);
    variable msb     : std_logic;
  begin
    if input'length <= 1 then
      return input;
    else
      inalign                          := (others => '0');
      inalign(input'length-1 downto 0) := input;
      msb                              := inalign(inalign'length/2);
      output                           := (others => '-');
      output(output'length-1)          := msb;
      case msb is
        when '0' =>    output(output'length-2 downto 0) := therm2bin(inalign(inalign'length/2-1 downto 0));
        when '1' =>    output(output'length-2 downto 0) := therm2bin(inalign(inalign'length-1   downto inalign'length/2+1));
        when others =>
      end case;
      return output;
    end if;
  end function therm2bin;
end package body aux_pkg;
