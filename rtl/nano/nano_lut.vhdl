-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    TU Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.

library ieee;
use ieee.std_logic_1164.all;

library top_level;

use work.aux_pkg.all;

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
  
  constant W_GRP_NUM : natural := ((WIDTH_BITS-1)/W_GRP_SIZE)+1;
  
  -- LUT Array
  type lut_grp_t is array (0 to DEPTH-1) of std_logic_vector(W_GRP_SIZE-1 downto 0);
  type lut_t is array (0 to W_GRP_NUM-1) of lut_grp_t;
  signal lut : lut_t;
  signal wen : std_logic_vector((2**DEPTH_LOG2)-1 downto 0);
  
  -- Input Latch Signals
  signal data : std_logic_vector(W_GRP_SIZE-1 downto 0);
  
  -- Clock Gating Signals
  signal we_reduced    : std_logic;
  signal clk1_we_gated : std_logic;

begin
  
  -- Clock Gating (global write enable)
  we_reduced <= orreduce(we_i);
  clk1_we_gate : entity top_level.clkgate(asic)
    port map(clk => clk1_i,
             en  => we_reduced,
             gck => clk1_we_gated);
  
  -- LUT Rows (with local write clock gating)
  wen <= dectree(we_reduced, addr_i);
  lut_grp_gen : for j in 0 to W_GRP_NUM-1 generate
    signal wen_grp : std_logic_vector((2**DEPTH_LOG2)-1 downto 0);
  begin
    wen_grp <= andexpand(wen, we_i(j));
    lut_row_gen : for i in 0 to DEPTH-1 generate
      signal clk_row_gated : std_logic_vector(DEPTH-1 downto 0);
    begin
      clk_row_gate : entity top_level.clkgate(asic)
        port map(clk => clk1_we_gated,
                 en  => wen_grp(i),
                 gck => clk_row_gated(i));
      
      lut_write : process(clk_row_gated(i))
      begin
        if rising_edge(clk_row_gated(i)) then
          lut(j)(i) <= data;
        end if;
      end process lut_write;
    end generate lut_row_gen;
  end generate lut_grp_gen;
  
  -- Input Data Latch
  in_lat : process(we_reduced, data_i)
  begin
    if we_reduced = '1' then
      data <= data_i;
    end if;
  end process in_lat;
  
  -- Output Mux
  out_mux : process(lut, addr_i)
    variable dvec : std_logic_vector((2**DEPTH_LOG2)*W_GRP_NUM*W_GRP_SIZE-1 downto 0);
    variable dout : std_logic_vector(W_GRP_NUM*W_GRP_SIZE-1                 downto 0);
  begin
      dvec := (others => '-');
      for i in 0 to DEPTH-1 loop
        for j in 0 to W_GRP_NUM-1 loop
          dvec(i*W_GRP_NUM*W_GRP_SIZE+(j+1)*W_GRP_SIZE-1 downto i*W_GRP_NUM*W_GRP_SIZE+j*W_GRP_SIZE) := lut(j)(i);
        end loop; --j
      end loop; --i
      dout := muxtree(dvec, addr_i, W_GRP_NUM*W_GRP_SIZE);
      data_o <= dout(WIDTH_BITS-1 downto 0);
  end process out_mux;
  
end architecture edge;
