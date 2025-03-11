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

library control;
use control.ctrl_pkg.all;

library nano;
use nano.aux_pkg.all;
use nano.nano_pkg.all;

entity dbg_ctrl is
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
end entity dbg_ctrl;

architecture edge of dbg_ctrl is

  -- FSM State
  type fsm_state_t is (IDLE, CMD, TRANSMIT, RECEIVE, UPDATE_MEM);
  signal state : fsm_state_t;
  
  -- Generated Control Signals
  signal rx_ack    : std_logic;
  signal ctrl_tx   : std_logic;
  signal ctrl_rate : std_logic;
  signal imem_oe   : std_logic;
  signal imem_we   : std_logic;
  signal we_cgen   : std_logic;
  signal we_clut   : std_logic;
  signal we_schg   : std_logic;
  
  -- Registers
  signal command     : std_logic_vector(7 downto 0);
  signal tx_data     : std_logic_vector(7 downto 0);
  signal dbg_addr    : unsigned(DBG_CONF_ADR_W_G-1 downto 0);
  signal dbg_addr_ff : unsigned(DBG_CONF_ADR_W_G-1 downto 0);
  signal dbg_wake    : std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
  signal rst, rst_ff : std_logic;
  signal rst_n_ff    : std_logic;

begin
  
  -- Output signals
  rst_n_o     <= rst_n_ff;
  rx_ack_o    <= rx_ack;
  command_o   <= command;
  tx_data_o   <= tx_data;
  ctrl_tx_o   <= ctrl_tx;
  ctrl_rate_o <= ctrl_rate;
  imem_oe_o   <= imem_oe;
  imem_we_o   <= imem_we;
  we_cgen_o   <= we_cgen;
  we_clut_o   <= we_clut;
  we_schg_o   <= we_schg;
  dbg_addr_o  <= std_logic_vector(dbg_addr);
  dbg_wake_o  <= dbg_wake;
  
  -- Sequential FSM process
  fsm_seq : process(clk_i, rst_n_i)
    variable dbg_addr_inc : unsigned(DBG_CONF_ADR_W_G-1 downto 0);
  begin
    if rst_n_i = '0' then
      state     <= IDLE;
      rx_ack    <= '0';
      ctrl_tx   <= '0';
      ctrl_rate <= '0';
      imem_oe   <= '0';
      imem_we   <= '0';
      we_cgen   <= '0';
      we_clut   <= '0';
      we_schg   <= '0';
      dbg_wake  <= (others => '0');
      rst       <= '0';
      rst_ff    <= '0';
      rst_n_ff  <= '0';
    elsif rising_edge(clk_i) then
      rst_ff    <= rst;
      rst_n_ff  <= not rst_ff;
      rx_ack    <= '0';
      ctrl_tx   <= '0';
      ctrl_rate <= '0';
      imem_oe   <= '0';
      imem_we   <= '0';
      we_cgen   <= '0';
      we_clut   <= '0';
      we_schg   <= '0';
      dbg_addr_inc := dbg_addr + 1;
      case state is
        --
        -- IDLE: Wait for command over debug interface
        when IDLE =>
          if rx_flag_i = '1' and rx_ack = '0' then
            state   <= CMD;
            rx_ack  <= '1';
            command <= rx_data_i;
          end if;
        --
        -- CMD: Evaluate received debug command
        when CMD =>
          if command(DBG_CMD_HI_IDX) = '1' then -- read
            state   <= TRANSMIT;
            tx_data <= dbg_data_i;
            case command(DBG_CMD_HI_IDX downto DBG_CMD_LO_IDX) is
              when DBG_CMD_R_INST_C | DBG_CMD_R_CLUT_C | DBG_CMD_R_SCHG_C =>
                dbg_addr_ff <= dbg_addr_inc;
              when others =>
            end case;
          else -- write
            state   <= RECEIVE;
          end if;
        --
        -- TRANSMIT: Send out debug data if transmitter not busy
        when TRANSMIT =>
          if tx_empty_i = '1' then
            state   <= UPDATE_MEM;
            ctrl_tx <= '1';
          end if;
        --
        -- RECEIVE: Wait for another byte to write
        when RECEIVE =>
          if rx_flag_i = '1' then
            state   <= UPDATE_MEM;
            rx_ack  <= '1';
            case command(DBG_CMD_HI_IDX downto DBG_CMD_LO_IDX) is
              when DBG_CMD_W_RST_C  =>
                tx_data     <= rx_data_i;
                rst         <= rx_data_i(0);
                dbg_addr_ff <= (others => '0');
              when DBG_CMD_W_CGEN_C =>
                tx_data     <= rx_data_i;
                we_cgen     <= '1';
              when DBG_CMD_W_INST_C =>
                tx_data     <= rx_data_i;
                imem_we     <= '1';
                -- !! changed for 8 bit load, load 2 4-bit instructions parallel !!
                dbg_addr_ff <= dbg_addr + 2;  --dbg_addr_inc;
                -- !! change end !!
              when DBG_CMD_W_RATE_C =>
                tx_data     <= rx_data_i;
                ctrl_rate   <= '1';
              when DBG_CMD_W_WAKE_C =>
                dbg_wake    <= rx_data_i(NANO_EXT_IRQ_W_C-1 downto 0);
              when DBG_CMD_W_CLUT_C =>
                tx_data     <= rx_data_i;
                we_clut     <= '1';
                dbg_addr_ff <= dbg_addr_inc;
              when DBG_CMD_W_SCHG_C =>
                tx_data     <= rx_data_i;
                we_schg     <= '1';
                dbg_addr_ff <= dbg_addr_inc;
              when others =>
            end case;
          end if;
        --
        -- UPDATE_MEM: Update memory addresses and outputs for next debug query
        when UPDATE_MEM =>
          state    <= IDLE;
          dbg_addr <= dbg_addr_ff;
          imem_oe  <= '1';
        --
      end case;
    end if;
  end process fsm_seq;

end architecture edge;
