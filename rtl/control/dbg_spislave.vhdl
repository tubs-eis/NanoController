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

library control;
use control.ctrl_pkg.all;

entity dbg_spislave is
  port(clk_i        : in  std_logic;
       rst_n_i      : in  std_logic;
       -- SPI Interface
       spi_en_n_i   : in  std_logic;
       spi_mosi_i   : in  std_logic;
       spi_sclk_i   : in  std_logic;
       spi_miso_o   : out std_logic;
       -- Status and Data
       data_i       : in  std_logic_vector(7 downto 0);
       data_o       : out std_logic_vector(7 downto 0);
       data_valid_o : out std_logic
      );
  attribute async_set_reset of rst_n_i : signal is "true";
end entity dbg_spislave;

architecture edge of dbg_spislave is
  -- SPI Signals
  signal data_in       : std_logic_vector(7 downto 0);
  signal data_in_valid : std_logic;
  signal data_out      : std_logic_vector(7 downto 0);
  signal spi_en        : std_logic;
  signal spi_sclk_180  : std_logic;
  attribute async_set_reset of spi_en : signal is "true";
  
  -- Controller Signals
  signal outbuffer      : std_logic_vector(7 downto 0);
  signal valid_edge     : std_logic;
  signal valid_edge_dly : std_logic_vector(DBG_SPI_EDGEDLY_W_C-1 downto 0);
  signal valid_syncher  : std_logic_vector(DBG_SPI_SYNCHER_W_C-1 downto 0);
begin
  
  -- SPI Signals
  spi_en       <= not spi_en_n_i;
  spi_sclk_180 <= not spi_sclk_i;
  spi_miso_o   <= data_out(data_out'left);
  
  -- SPI Input Side
  spi_in_seq : process(spi_sclk_i, spi_en)
  begin
    if spi_en = '0' then
      data_in_valid <= '1';
    elsif rising_edge(spi_sclk_i) then
      if data_in_valid = '1' then
        data_in       <= "0000001" & spi_mosi_i;
        data_in_valid <= '0';
      else
        data_in       <= data_in(data_in'left-1 downto 0) & spi_mosi_i;
        data_in_valid <= data_in(data_in'left);
      end if;
    end if;
  end process spi_in_seq;
  
  -- SPI Output Side
  spi_out_seq : process(spi_sclk_180, spi_en)
  begin
    if spi_en = '0' then
      data_out <= (others => '0');
    elsif rising_edge(spi_sclk_180) then
      if data_in_valid = '1' then
        data_out <= outbuffer;
      else
        data_out <= data_out(data_out'left-1 downto 0) & '0';
      end if;
    end if;
  end process spi_out_seq;
  
  -- Controller Signals
  valid_edge   <= valid_syncher(valid_syncher'left-1) and not valid_syncher(valid_syncher'left);
  data_valid_o <= valid_edge_dly(0);
  
  -- Controller Side
  controller_seq : process(clk_i, rst_n_i)
  begin
    if rst_n_i = '0' then
      valid_edge_dly <= (others => '0');
      valid_syncher  <= (others => '1');
    elsif rising_edge(clk_i) then
      valid_edge_dly <= valid_edge_dly(valid_edge_dly'left-1 downto 0) & valid_edge;
      valid_syncher  <= valid_syncher(valid_syncher'left-1 downto 0) & data_in_valid;
      if valid_edge_dly(valid_edge_dly'left) = '1' then
        outbuffer <= data_i;
      end if;
      if valid_edge = '1' then
        data_o <= data_in;
      end if;
    end if;
  end process controller_seq;

end architecture edge;
