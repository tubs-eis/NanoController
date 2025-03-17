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

entity dbg_uart is
  port(clk_i        : in  std_logic;
       rst_n_i      : in  std_logic;
       -- UART RX and TX
       rx_i         : in  std_logic;
       tx_o         : out std_logic;
       -- Status & Data
       udr_read_i   : in  std_logic;
       data_i       : in  std_logic_vector(7 downto 0);
       ubrr_write_i : in  std_logic;
       udr_write_i  : in  std_logic;
       usr_reg_o    : out std_logic_vector(7 downto 0);
       ubrr_reg_o   : out std_logic_vector(7 downto 0);
       udr_rx_reg_o : out std_logic_vector(7 downto 0)
       );
end entity dbg_uart;

architecture edge of dbg_uart is

  -- receive state machine
  type rx_state is (IDLE,               -- wait for start bit
                    CHK_START,          -- check if start bit is valid
                    RECEIVE,            -- receive data bits
                    CHK_FRAMING         -- check for framing error
                    );

  -- device registers
  signal ubrr_reg, ubrr_nxt     : std_logic_vector(7 downto 0);  -- UART baud rate register
  signal usr_reg, usr_nxt       : std_logic_vector(7 downto 3);  -- UART status register
  signal udr_rx_reg, udr_rx_nxt : std_logic_vector(7 downto 0);  -- UART RX data register
  signal udr_tx_reg, udr_tx_nxt : std_logic_vector(7 downto 0);  -- UART TX data register

  -- internal registers
  signal tx_data_nxt, tx_data_reg             : std_logic_vector(9 downto 0);
  signal tx_cnt_nxt, tx_cnt_reg               : std_logic_vector(3 downto 0);
  signal tx_idle_nxt, tx_idle_reg             : std_logic;
  signal tx_div_nxt, tx_div_reg               : std_logic_vector(3 downto 0);
  --
  signal rx_filter_nxt, rx_filter_reg         : std_logic_vector(2 downto 0);
  signal rx_sample_tmr_nxt, rx_sample_tmr_reg : std_logic_vector(3 downto 0);
  signal rx_bit_cnt_nxt, rx_bit_cnt_reg       : std_logic_vector(3 downto 0);
  signal rx_data_nxt, rx_data_reg             : std_logic_vector(7 downto 0);
  signal rx_state_nxt, rx_state_reg           : rx_state;
  signal rx_filt_reg                          : std_logic;
  --
  signal baud_div_nxt, baud_div_reg           : std_logic_vector(7 downto 0);
  signal overrun_nxt, overrun_reg             : std_logic;
  signal x16_clk_reg                          : std_logic;

  -- internal signals
  signal rx_filt     : std_logic;      -- filtered RX input signal
  signal udre_set    : std_logic;      -- causes UDRE bit to be set
  signal udr_read    : std_logic;      -- signalizes UDR read access
  signal txc_set     : std_logic;      -- causes TXC bit to be set
  signal x16_clk     : std_logic;      -- 16x baud rate clock
  signal tx_clk      : std_logic;      -- 1x baud rate clock for transmitter
  signal rx_finished : std_logic;  -- signalizes end of character reception

begin
  
  -- connect outputs
  tx_o <= tx_data_reg(0);

-------------------------------------------------------------------------------
  -- read from registers
  usr_reg_o    <= usr_reg & b"000";
  ubrr_reg_o   <= ubrr_reg;
  udr_rx_reg_o <= udr_rx_reg;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  -- write into registers
  reg_write : process (ubrr_reg, usr_reg, udr_tx_reg, udr_rx_reg, overrun_reg,
                       txc_set, udre_set, udr_read_i, rx_finished, rx_data_reg,
                       rx_filt, data_i, ubrr_write_i, udr_write_i)
  begin
    ubrr_nxt    <= ubrr_reg;            -- baud rate reg    | 8 bit
    usr_nxt     <= usr_reg;             -- status register  | 8 bit [ RXC   | TXC   | UDRE  | FERR | OVR  | USR2 | USR1 | USR0 ] 
    udr_tx_nxt  <= udr_tx_reg;          -- TX data register | 8 bit
    udr_rx_nxt  <= udr_rx_reg;          -- RX data register | 8 bit
    overrun_nxt <= overrun_reg;         -- overrun register | 1 bit

    -- internal writes 
    if (txc_set = '1') then
      usr_nxt(TXC) <= '1';              -- set TXC
    end if;

    if (udre_set = '1') then
      usr_nxt(UDRE) <= '1';             -- set UDRE
    end if;

    if (udr_read_i = '1') then          -- read access to UDR?
      usr_nxt(OVR) <= overrun_reg;      -- update or flag
      usr_nxt(RXC) <= '0';              -- register read -> clear RXC flag
    end if;

    if (rx_finished = '1') then         -- character reception finished?
      usr_nxt(RXC) <= '1';              -- set RXC flag, reception finished

      if (usr_reg(RXC) = '0' or udr_read_i = '1') then  -- has UDR read register been read?
        udr_rx_nxt    <= rx_data_reg(7 downto 0);
        usr_nxt(FERR) <= not rx_filt;   -- FE = framing error?
        overrun_nxt   <= '0';
      else                              -- overrun detected
        overrun_nxt <= '1';
      end if;
    end if;


    -- writes from bus (higher priority)
    if (ubrr_write_i = '1') then
      ubrr_nxt <= data_i;
    end if;
    if (udr_write_i = '1') then
      udr_tx_nxt    <= data_i;
      usr_nxt(UDRE) <= '0';       -- clear UDRE
    end if;

  end process reg_write;

-------------------------------------------------------------------------------

--???????----------------------------------------------------------------------
  -- transmit logic
  tx_proc : process (tx_clk, tx_cnt_reg, tx_data_reg, tx_idle_reg, udr_tx_reg, usr_reg)
  begin
    tx_data_nxt <= tx_data_reg;  -- datenregister transmit
    tx_cnt_nxt  <= tx_cnt_reg;   -- counter fuer transmitted Datenwoerter
    udre_set    <= '0';          -- flag Sende-Datenregister (full | empty)
    txc_set     <= '0';          -- Sendevorgang beendet
    tx_idle_nxt <= tx_idle_reg;  -- zeigt an, ob Sendevorgang noch läuft (0 -> transmission | 1 -> nothing happens)

    if (tx_clk = '1') then
      if (unsigned(tx_cnt_reg) = 0) then   --character finished?
        if (usr_reg(UDRE) = '0') then   -- wenn Sendedatenregister gefuellt 
          tx_data_nxt(0)          <= '0';  -- start bit
          tx_data_nxt(8 downto 1) <= udr_tx_reg;  -- tx data byte
          tx_data_nxt(9)          <= '1';  -- stop bit for 8 bit mode
          tx_cnt_nxt              <= b"1001";  -- set counter for transmitted bits
          udre_set                <= '1';  -- Sendedatenriegister wurde übernommen
          tx_idle_nxt             <= '0';  -- Transmission in progress
        else  -- transmission finished | wenn Sendedatenregster geleert
          txc_set     <= not tx_idle_reg;  -- ??? 
          tx_idle_nxt <= '1';
        end if;
      else                              -- send next bit
        tx_data_nxt <= '1' & tx_data_reg(9 downto 1);
        tx_cnt_nxt  <= std_logic_vector(unsigned(tx_cnt_reg) - 1);
      end if;
    end if;
  end process tx_proc;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  -- receiver logic - filter
  filter_proc : process (rx_i, rx_filter_reg, x16_clk)
  begin
    rx_filter_nxt(2 downto 0) <= rx_filter_reg(2 downto 0);

    if (x16_clk = '1') then
      rx_filter_nxt(2 downto 0) <= rx_i & rx_filter_reg(2 downto 1);
    end if;

    -- majority selection
    rx_filt <= (rx_filter_reg(2) and rx_filter_reg(1)) or
               (rx_filter_reg(1) and rx_filter_reg(0)) or
               (rx_filter_reg(2) and rx_filter_reg(0));
    
  end process filter_proc;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  -- receiver logic - receive FSM
  rx_proc : process (rx_bit_cnt_reg, rx_data_reg, rx_filt, rx_filt_reg, rx_sample_tmr_reg, rx_state_reg, x16_clk_reg)
  begin
    rx_sample_tmr_nxt <= rx_sample_tmr_reg;  -- jedes Datenwort muss 16 x x16_clk_reg anliegen | rx_sample_tmr ist der counter dafuer
    rx_bit_cnt_nxt    <= rx_bit_cnt_reg;     -- counter fuer received Datenwoerter
    rx_data_nxt       <= rx_data_reg;        -- datenregister receive
    rx_state_nxt      <= rx_state_reg;       -- statemachine
    rx_finished       <= '0';

    if (x16_clk_reg = '1') then
      rx_sample_tmr_nxt <= std_logic_vector(unsigned(rx_sample_tmr_reg) - 1);

      case rx_state_reg is
        when IDLE =>                     -- wait for start bit
          rx_sample_tmr_nxt <= b"0111";  -- adjust sampling position
          rx_bit_cnt_nxt    <= (others => '0');

          if (((not rx_filt) and rx_filt_reg) = '1') then  -- falling edge detection = start bit
            rx_state_nxt <= CHK_START;
          end if;

        when CHK_START =>               -- check if start bit is valid
          if (unsigned(rx_sample_tmr_reg) = 0) then  -- sampling time?
            if (rx_filt = '0') then
              rx_state_nxt <= RECEIVE;  -- start bit valid
            else
              rx_state_nxt <= IDLE;     -- invalid -> ignore
            end if;
          end if;

        when RECEIVE =>                 -- receive data bits
          if (unsigned(rx_sample_tmr_reg) = 0) then
          
            rx_data_nxt    <= rx_filt & rx_data_reg(7 downto 1);
            rx_bit_cnt_nxt <= std_logic_vector(unsigned(rx_bit_cnt_reg) + 1);

            if (unsigned(rx_bit_cnt_reg) = 7) then  -- eighth bit received?
              rx_state_nxt <= CHK_FRAMING;
            end if;
          end if;

        when CHK_FRAMING =>             -- check for framing error
          if (unsigned(rx_sample_tmr_reg) = 0) then
            rx_finished  <= '1';
            rx_state_nxt <= IDLE;
          end if;
          
      end case;

    end if;

  end process rx_proc;
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
  -- baud rate generator
  x16_proc : process (baud_div_reg, ubrr_reg)
  begin
    if (unsigned(baud_div_reg) = 0) then  -- zero reached?
      baud_div_nxt <= ubrr_reg;
      x16_clk      <= '1';
    else
      baud_div_nxt <= std_logic_vector(unsigned(baud_div_reg) - 1);
      x16_clk      <= '0';
    end if;
  end process x16_proc;


  tx_clk_proc : process (tx_div_reg, x16_clk)
  begin
    tx_div_nxt <= tx_div_reg;
    tx_clk     <= '0';

    if (x16_clk = '1') then
      tx_div_nxt <= std_logic_vector(unsigned(tx_div_reg) + 1);
      if (unsigned(tx_div_reg) = 0) then
        tx_clk <= '1';
      end if;
    end if;
  end process tx_clk_proc;
-------------------------------------------------------------------------------  

-------------------------------------------------------------------------------
  -- clock process
  clock : process (clk_i, rst_n_i)
  begin
    if (rst_n_i = '0') then
      --ubrr_reg          <= x"41";           -- 9600 baud @ 10 MHz clock
      --ubrr_reg          <= x"04";           -- simulation speed
      --ubrr_reg <= (others => '0');
      ubrr_reg          <= x"33";           -- 1200 baud @ 1 MHz clock: ( CLOCK / (16 * (UBRR+1)) = BAUDRATE )

      --usr_reg           <= b"00_1_00";     -- UDRE - TX data register empty
      usr_reg           <= (others => '0');
      usr_reg(UDRE)     <= '1';
      udr_rx_reg        <= (others => '0');
      udr_tx_reg        <= (others => '0');
      --
      tx_data_reg       <= (others => '1');
      tx_cnt_reg        <= (others => '0');
      tx_idle_reg       <= '1';
      tx_div_reg        <= (others => '0');
      --
      rx_sample_tmr_reg <= (others => '0');
      rx_bit_cnt_reg    <= (others => '0');
      rx_data_reg       <= (others => '0');
      rx_state_reg      <= IDLE;
      rx_filt_reg       <= '1';
      rx_filter_reg     <= (others => '1');
      --
      overrun_reg       <= '0';
      x16_clk_reg       <= '0';
      baud_div_reg      <= (others => '0');
    elsif rising_edge(clk_i) then
      ubrr_reg          <= ubrr_nxt;
      usr_reg           <= usr_nxt;
      udr_rx_reg        <= udr_rx_nxt;
      udr_tx_reg        <= udr_tx_nxt;
      --
      tx_data_reg       <= tx_data_nxt;
      tx_cnt_reg        <= tx_cnt_nxt;
      tx_idle_reg       <= tx_idle_nxt;
      tx_div_reg        <= tx_div_nxt;
      --
      rx_sample_tmr_reg <= rx_sample_tmr_nxt;
      rx_bit_cnt_reg    <= rx_bit_cnt_nxt;
      rx_data_reg       <= rx_data_nxt;
      rx_state_reg      <= rx_state_nxt;
      rx_filt_reg       <= rx_filt;
      rx_filter_reg     <= rx_filter_nxt;
      --
      overrun_reg       <= overrun_nxt;
      x16_clk_reg       <= x16_clk;
      baud_div_reg      <= baud_div_nxt;
    end if;
  end process clock;

-------------------------------------------------------------------------------

end architecture edge;
