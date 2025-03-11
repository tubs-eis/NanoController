-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    TU Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.

library ieee;
use ieee.std_logic_1164.all;

library control;
use control.ctrl_pkg.all;

library nano;
use nano.aux_pkg.all;
use nano.nano_pkg.all;

entity dbg_iface is
  generic(CTRL_SCHG_W_G     : natural := 12;                                        -- State Change LUT Output Width
          CTRL_CONF_ADR_W_G : natural := maxi(NANO_I_W_C, 5);                       -- LUT Configuration Address Port Width
          DBG_CONF_ADR_W_G  : natural := maxi(maxi(NANO_I_W_C,5),NANO_I_ADR_W_C));  -- Memory Debug Address Port Width
  port(clk_i        : in  std_logic;
       rst_n_i      : in  std_logic;
       dbg_adc_i    : in  std_logic_vector(CTRL_ADC_BW_C-1 downto 0);
       dbg_func_i   : in  std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
       dbg_iadr_i   : in  std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
       dbg_inst_i   : in  std_logic_vector(NANO_I_W_C-1 downto 0);
       dbg_ctlgen_i : in  std_logic_vector(7-1 downto 0);
       dbg_clut_i   : in  std_logic_vector(CTRL_CW_IDENT_W_C-1 downto 0);
       dbg_schg_i   : in  std_logic_vector(CTRL_SCHG_W_G-1 downto 0);
       imem_oe_i    : in  std_logic;
       imem_we_i    : in  std_logic;
       imem_addr_i  : in  std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
       -- !! changed for MEH ASIC flashloader with 8 bit load, load 2 4-bit instructions parallel !!
       imem_instr_i : in  std_logic_vector(2*NANO_I_W_C-1 downto 0);  --(NANO_I_W_C-1 downto 0);
       -- !! change end !!
       spi_en_n_i   : in  std_logic;
       spi_mosi_i   : in  std_logic;
       spi_sclk_i   : in  std_logic;
       rst_n_o      : out std_logic;
       spi_miso_o   : out std_logic;
       dbg_wake_o   : out std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
       imem_oe_o    : out std_logic;
       imem_we_o    : out std_logic;
       imem_addr_o  : out std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
       -- !! changed for MEH ASIC flashloader with 8 bit load, load 2 4-bit instructions parallel !!
       imem_instr_o : out std_logic_vector(2*NANO_I_W_C-1 downto 0);  --(NANO_I_W_C-1 downto 0);
       -- !! change end !!
       we_cgen_o    : out std_logic;
       cgen_param_o : out std_logic_vector(CTRL_CLKDIV_CNT_W_C-1 downto 0);
       we_clut_o    : out std_logic_vector((CTRL_CW_IDENT_W_C-1)/8 downto 0);
       we_schg_o    : out std_logic_vector((CTRL_SCHG_W_G-1)/8 downto 0);
       lut_addr_o   : out std_logic_vector(CTRL_CONF_ADR_W_G-1 downto 0);
       lut_din_o    : out std_logic_vector(8-1 downto 0));
end entity dbg_iface;

architecture edge of dbg_iface is
  
  -- Debug communication unit: SPI Slave
  component dbg_spislave is
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
  end component dbg_spislave;
  
  -- Debug Control State Machine
  component dbg_ctrl is
    generic(DBG_CONF_ADR_W_G : natural := maxi(maxi(NANO_I_W_C,5),NANO_I_ADR_W_C));  -- Memory Debug Address Port Width
    port(clk_i       : in  std_logic;
         rst_n_i     : in  std_logic;
         rx_flag_i   : in  std_logic;
         rx_data_i   : in  std_logic_vector(7 downto 0);
         tx_empty_i  : in  std_logic;
         dbg_data_i  : in  std_logic_vector(7 downto 0);
         rst_n_o     : out std_logic;
         rx_ack_o    : out std_logic;
         command_o   : out std_logic_vector(7 downto 0);
         ctrl_tx_o   : out std_logic;
         ctrl_rate_o : out std_logic;
         tx_data_o   : out std_logic_vector(7 downto 0);
         imem_oe_o   : out std_logic;
         imem_we_o   : out std_logic;
         we_cgen_o   : out std_logic;
         we_clut_o   : out std_logic;
         we_schg_o   : out std_logic;
         dbg_addr_o  : out std_logic_vector(DBG_CONF_ADR_W_G-1 downto 0);
         dbg_wake_o  : out std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0));
  end component dbg_ctrl;
  
  -- Interfacing Signals
  signal ubrr      : std_logic_vector(7 downto 0);
  signal rx_ack    : std_logic;
  signal command   : std_logic_vector(7 downto 0);
  signal tx_data   : std_logic_vector(7 downto 0);
  
  -- Interfacing Signals: SPI
  signal spi_data_rx    : std_logic_vector(7 downto 0);
  signal spi_data_valid : std_logic;
  
  -- Interface Switching
  signal rx_data      : std_logic_vector(7 downto 0);
  signal rx_flag      : std_logic;
  signal tx_empty     : std_logic;
  signal dbg_addr     : std_logic_vector(DBG_CONF_ADR_W_G-1 downto 0);
  signal dbg_imem_oe  : std_logic;
  signal dbg_imem_we  : std_logic;
  signal dbg_we_clut  : std_logic;
  signal dbg_we_schg  : std_logic;
  signal we_clut_vec  : std_logic_vector((2**(log2((CTRL_CW_IDENT_W_C-1)/8+1)))-1 downto 0);
  signal we_schg_vec  : std_logic_vector((2**(log2((CTRL_SCHG_W_G-1)/8+1)))-1 downto 0);
  
  -- Mux: Read Debug Data
  signal dbg_data_vec : std_logic_vector(((2**DBG_CMD_LEN_C)*8)-1 downto 0);
  signal dbg_data_sel : std_logic_vector(DBG_CMD_LEN_C-1 downto 0);
  signal dbg_data     : std_logic_vector(7 downto 0);
  
  -- Mux: Functional Memory
  signal mux_func_sel : std_logic_vector(log2(NANO_FUNC_OUTS_C)-1 downto 0);
  signal mux_func     : std_logic_vector(NANO_D_W_C-1 downto 0);
  
  -- Mux: ADC
  signal mux_adc_vec  : std_logic_vector(15 downto 0);
  signal mux_adc_sel  : std_logic_vector(0 downto 0);
  signal mux_adc      : std_logic_vector(7 downto 0);
  
  -- Mux: Instruction Address
  signal mux_iadr_vec : std_logic_vector((2**(log2((NANO_I_ADR_W_C-1)/8+1)))*8-1 downto 0);
  signal mux_iadr_sel : std_logic_vector(log2((NANO_I_ADR_W_C-1)/8+1)-1 downto 0);
  signal mux_iadr     : std_logic_vector(7 downto 0);
  
  -- Mux: State Change LUT
  signal mux_schg_vec : std_logic_vector((2**(log2((CTRL_SCHG_W_G-1)/8+1)))*8-1 downto 0);
  signal mux_schg_sel : std_logic_vector(log2((CTRL_SCHG_W_G-1)/8+1)-1 downto 0);
  signal mux_schg     : std_logic_vector(7 downto 0);
  
  signal rst_n     : std_logic;

begin

  ubrr <= (others => '0');
  
  dbg_spislave_inst : dbg_spislave
    port map(clk_i        => clk_i,
             rst_n_i      => rst_n_i,
             spi_en_n_i   => spi_en_n_i,
             spi_mosi_i   => spi_mosi_i,
             spi_sclk_i   => spi_sclk_i,
             spi_miso_o   => spi_miso_o,
             data_i       => tx_data,
             data_o       => spi_data_rx,
             data_valid_o => spi_data_valid);
  
  dbg_ctrl_inst : dbg_ctrl
    port map(clk_i       => clk_i,
             rst_n_i     => rst_n_i,
             rx_flag_i   => rx_flag,
             rx_data_i   => rx_data,
             tx_empty_i  => tx_empty,
             dbg_data_i  => dbg_data,
             rst_n_o     => rst_n,
             rx_ack_o    => rx_ack,
             command_o   => command,
             ctrl_tx_o   => open,
             ctrl_rate_o => open,
             tx_data_o   => tx_data,
             imem_oe_o   => dbg_imem_oe,
             imem_we_o   => dbg_imem_we,
             we_cgen_o   => we_cgen_o,
             we_clut_o   => dbg_we_clut,
             we_schg_o   => dbg_we_schg,
             dbg_addr_o  => dbg_addr,
             dbg_wake_o  => dbg_wake_o);
  
  -- LUT Write Enable Decoding
  we_clut_vec <= dectree(dbg_we_clut, command(log2(we_clut_vec'length)-1 downto 0));
  we_schg_vec <= dectree(dbg_we_schg, command(log2(we_schg_vec'length)-1 downto 0));
  
  -- Interface Switching: Allow memory debugging during reset
  rst_n_o      <= rst_n;
  imem_oe_o    <= imem_oe_i when rst_n = '1' else dbg_imem_oe;
  imem_we_o    <= imem_we_i when rst_n = '1' else dbg_imem_we;
  imem_addr_o  <= imem_addr_i when rst_n = '1' else dbg_addr(imem_addr_o'length-1 downto 0);
  imem_instr_o <= imem_instr_i when rst_n = '1' else tx_data(imem_instr_o'length-1 downto 0);
  cgen_param_o <= tx_data(cgen_param_o'length-1 downto 0);
  lut_addr_o   <= dbg_addr(lut_addr_o'length-1 downto 0);
  lut_din_o    <= tx_data;
  we_clut_o    <= we_clut_vec(we_clut_o'length-1 downto 0);
  we_schg_o    <= we_schg_vec(we_schg_o'length-1 downto 0);
  
  -- Interface Switching: Last used interface for command receiving is enabled for transmission
  rx_flag      <= spi_data_valid;
  rx_data      <= spi_data_rx;
  tx_empty     <= '1';
  
  -- Mux Debug Data
  dbg_data_vec <= mux_schg & x"0" & dbg_clut_i & '0' & dbg_ctlgen_i & ubrr & x"0" & dbg_inst_i & mux_iadr & mux_func(7 downto 0) & mux_adc & x"0000000000000000";
  dbg_data_sel <= command(DBG_CMD_HI_IDX downto DBG_CMD_LO_IDX);
  dbg_data <= muxtree(dbg_data_vec, dbg_data_sel, dbg_data'length);
  
  -- Mux Functional Memory
  mux_func_sel <= command(log2(NANO_FUNC_OUTS_C)-1 downto 0);
  mux_func     <= muxtree(dbg_func_i, mux_func_sel, NANO_D_W_C);
  
  -- Mux ADC
  mux_adc_vec  <= "000000" & dbg_adc_i;
  mux_adc_sel  <= command(0 downto 0);
  mux_adc      <= muxtree(mux_adc_vec, mux_adc_sel, mux_adc'length);
  
  -- Mux Instruction Address
  mux_iadr_vec(mux_iadr_vec'length-1 downto NANO_I_ADR_W_C) <= (others => '0');
  mux_iadr_vec(NANO_I_ADR_W_C-1 downto 0)                   <= dbg_iadr_i;
  mux_iadr_sel                                              <= command(mux_iadr_sel'length-1 downto 0);
  mux_iadr                                                  <= muxtree(mux_iadr_vec, mux_iadr_sel, mux_iadr'length);
  
  -- Mux State Change LUT
  mux_schg_vec(mux_schg_vec'length-1 downto CTRL_SCHG_W_G) <= (others => '0');
  mux_schg_vec(CTRL_SCHG_W_G-1 downto 0)                   <= dbg_schg_i;
  mux_schg_sel                                             <= command(mux_schg_sel'length-1 downto 0);
  mux_schg                                                 <= muxtree(mux_schg_vec, mux_schg_sel, mux_schg'length);

end architecture edge;
