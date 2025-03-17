-- Copyright (c) 2025 Chair for Chip Design for Embedded Computing,
--                    TU Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

library unisim;
use unisim.vcomponents.all;

library nano;
use nano.aux_pkg.all;
use nano.nano_pkg.all;

library control;
use control.ctrl_pkg.all;

entity sys_top_emu is
  port(
    CLK100MHZ    : in    std_ulogic;
    btn          : in    std_ulogic_vector(3 downto 0);
    sw           : in    std_ulogic_vector(3 downto 0);
    led          : out   std_ulogic_vector(3 downto 0);
    ck_rst       : in    std_ulogic;
    uart_txd_in  : in    std_ulogic;
    uart_rxd_out : out   std_ulogic
    );
end entity sys_top_emu;

architecture rtl of sys_top_emu is
  
  component nano_top is
    generic(CTRL_CYCLE_DEPTH_G : natural := 21;                  -- Cycle LUT Depth
            STEP_GROUPS_G      : natural := 6;                   -- Max Number of Control Steps per Instruction
            CTRL_SCHG_W_G      : natural := 12;                  -- State Change LUT Output Width
            CTRL_CONF_ADR_W_G  : natural := maxi(NANO_I_W_C, 5)  -- LUT Configuration Address Port Width
           );
    port(
      nano_clk1       : in  std_logic;
      nano_clk2       : in  std_logic;
      nano_rst_n      : in  std_logic;
      nano_we_clut_i  : in  std_logic_vector((CTRL_CW_IDENT_W_C-1)/8 downto 0);
      nano_we_schg_i  : in  std_logic_vector((CTRL_SCHG_W_G-1)/8 downto 0);
      nano_lut_addr_i : in  std_logic_vector(CTRL_CONF_ADR_W_G-1 downto 0);
      nano_lut_din_i  : in  std_logic_vector(8-1 downto 0);
      nano_ext_wake   : in  std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
      nano_data_i     : in  std_logic_vector(NANO_D_W_C-1 downto 0);
      nano_instr      : in  std_logic_vector(NANO_I_W_C-1 downto 0);
      nano_func_i     : in  std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
      nano_addr       : out std_logic_vector(NANO_D_ADR_W_C-1 downto 0);
      nano_data_o     : out std_logic_vector(NANO_D_W_C-1 downto 0);
      nano_data_oe    : out std_logic;
      nano_data_we    : out std_logic;
      nano_instr_oe   : out std_logic;
      nano_sleep_o    : out std_logic;
      nano_clut_o     : out std_logic_vector(CTRL_CW_IDENT_W_C-1 downto 0);
      nano_schg_o     : out std_logic_vector(CTRL_SCHG_W_G-1 downto 0);
      nano_pc         : out std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
      nano_func_o     : out std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0)
      );
  end component nano_top;
  
  constant CTRL_CYCODE_W_C   : natural := log2(STEP_GROUPS_C);                         -- Encoded Execution Cycle Number Width
  constant CTRL_SCHG_W_C     : natural := log2(CTRL_CYCLE_DEPTH_C)+CTRL_CYCODE_W_C+4;  -- State Change LUT Output Width
  constant CTRL_CONF_ADR_W_C : natural := maxi(NANO_I_W_C, log2(CTRL_CYCLE_DEPTH_C));  -- LUT Configuration Address Port Width
  constant DBG_CONF_ADR_W_C  : natural := maxi(CTRL_CONF_ADR_W_C,NANO_I_ADR_W_C);      -- Memory Debug Address Port Width
  
  signal leds_w        : std_logic_vector(3 downto 0);
  signal btn_w         : std_logic_vector(3 downto 0);
  signal sw_w          : std_logic_vector(3 downto 0);
  signal rx_w          : std_logic;
  signal tx_w          : std_logic;
  
  signal nano_clk1                : std_logic;
  signal nano_clk2                : std_logic;
  signal nano_func                : std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
  signal nano_instr               : std_logic_vector(NANO_I_W_C-1 downto 0);
  -- !! changed for MEH ASIC flashloader with 8 bit load, load 2 4-bit instructions parallel !!
  signal nano_instr_init          : std_logic_vector(2*NANO_I_W_C-1 downto 0);  --(NANO_I_W_C-1 downto 0);
  signal nano_instr_init_from_dbg : std_logic_vector(2*NANO_I_W_C-1 downto 0);  --(NANO_I_W_C-1 downto 0);
  -- !! change end !!
  signal nano_sleep               : std_logic;
  signal nano_instr_oe            : std_logic;
  signal nano_instr_oe_from_dbg   : std_logic;
  signal nano_instr_we            : std_logic;
  signal nano_instr_we_from_dbg   : std_logic;
  signal nano_instr_addr          : std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
  signal nano_instr_addr_from_dbg : std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
  signal nano_pc                  : std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
  signal nano_rst_n_int           : std_logic;
  signal nano_rst_n_dbg           : std_logic;
  signal nano_ext_wake            : std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
  signal nano_clut                : std_logic_vector(CTRL_CW_IDENT_W_C-1 downto 0);
  signal nano_schg                : std_logic_vector(CTRL_SCHG_W_C-1 downto 0);
  signal nano_lut_addr_from_dbg   : std_logic_vector(CTRL_CONF_ADR_W_C-1 downto 0);
  signal nano_we_clut_from_dbg    : std_logic_vector((CTRL_CW_IDENT_W_C-1)/8 downto 0);
  signal nano_we_schg_from_dbg    : std_logic_vector((CTRL_SCHG_W_C-1)/8 downto 0);
  signal nano_lut_din_from_dbg    : std_logic_vector(8-1 downto 0);
  signal nano_we_cgen_from_dbg    : std_logic;
  signal nano_cgen_param_from_dbg : std_logic_vector(CTRL_CLKDIV_CNT_W_C-1 downto 0);
  
  signal nano_data_from_mem : std_logic_vector(NANO_D_W_C-1 downto 0);
  signal nano_func_from_mem : std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
  signal nano_data_addr     : std_logic_vector(NANO_D_ADR_W_C-1 downto 0);
  signal nano_data_to_mem   : std_logic_vector(NANO_D_W_C-1 downto 0);
  signal nano_data_oe       : std_logic;
  signal nano_data_we       : std_logic;
  
  signal dbg_wake : std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
  
  component arty_pll
  port
   (-- Clock in ports
    -- Clock out ports
    clk_out1          : out    std_logic;
    -- Status and control signals
    reset             : in     std_logic;
    locked            : out    std_logic;
    clk_in1           : in     std_logic
   );
  end component;

  -- constants
  constant RESET_CNT_WIDTH : natural                              := 16;
  constant RESET_CNT_MAX   : unsigned(RESET_CNT_WIDTH-1 downto 0) := to_unsigned(2**RESET_CNT_WIDTH -1, RESET_CNT_WIDTH);
  constant NCLK_CNT_WIDTH  : natural                              := 3;
  constant NCLK_CNT_MAX    : unsigned(NCLK_CNT_WIDTH-1  downto 0) := to_unsigned(2**NCLK_CNT_WIDTH -1, NCLK_CNT_WIDTH);

  -- signals
  signal uc_rst     : std_ulogic;
  signal sys_clk    : std_ulogic;
  signal sys_rst_n  : std_ulogic;
  signal nano_rst_n : std_ulogic;
  signal pll_clk    : std_ulogic;
  signal pll_locked : std_ulogic;

  -- register
  signal reset_cnt_ff       : unsigned(RESET_CNT_WIDTH-1 downto 0) := (others => '0');
  signal reset_cnt_nxt      : unsigned(RESET_CNT_WIDTH-1 downto 0) := (others => '0');
  signal nano_clk1_cnt_ff   : unsigned(NCLK_CNT_WIDTH-1  downto 0) := (others => '0');
  signal nano_clk1_cnt_nxt  : unsigned(NCLK_CNT_WIDTH-1  downto 0) := (others => '0');
  signal nano_clk1_en       : std_ulogic                           := '0';
  signal reset_n_ff         : std_ulogic                           := '0';
  signal reset_n_nxt        : std_ulogic                           := '0';
  signal nano_rst_n_ff      : std_ulogic                           := '0';
  
begin

  -- invert reset
  uc_rst <= not ck_rst;
  
  -----------------------------------------------------------------------------
  -- Common Nanocontroller logic (independent of implementation platform)
  -----------------------------------------------------------------------------
  nano_ext_wake  <= btn(0) & dbg_wake(NANO_EXT_IRQ_W_C-2 downto 0);
  
  nano_top_inst : nano_top
    generic map(CTRL_CYCLE_DEPTH_G => CTRL_CYCLE_DEPTH_C,  -- Cycle LUT Depth
                STEP_GROUPS_G      => STEP_GROUPS_C,       -- Encoded Execution Cycle Number Width
                CTRL_SCHG_W_G      => CTRL_SCHG_W_C,       -- State Change LUT Output Width
                CTRL_CONF_ADR_W_G  => CTRL_CONF_ADR_W_C    -- LUT Configuration Address Port Width
               )
    port map(
      nano_clk1         => nano_clk1,
      nano_clk2         => '0',
      nano_rst_n        => nano_rst_n_int,
      nano_we_clut_i    => nano_we_clut_from_dbg,
      nano_we_schg_i    => nano_we_schg_from_dbg,
      nano_lut_addr_i   => nano_lut_addr_from_dbg,
      nano_lut_din_i    => nano_lut_din_from_dbg,
      nano_ext_wake     => nano_ext_wake,
      nano_data_i       => nano_data_from_mem,
      nano_instr        => nano_instr,
      nano_func_i       => nano_func_from_mem,
      nano_addr         => nano_data_addr,
      nano_data_o       => nano_data_to_mem,
      nano_data_oe      => nano_data_oe,
      nano_data_we      => nano_data_we,
      nano_instr_oe     => nano_instr_oe,
      nano_sleep_o      => nano_sleep,
      nano_clut_o       => nano_clut,
      nano_schg_o       => nano_schg,
      nano_pc           => nano_pc,
      nano_func_o       => nano_func);
  
  -----------------------------------------------------------------------------
  -- Nanocontroller DMEM, IMEM
  -----------------------------------------------------------------------------
  nano_rst_n_int  <= nano_rst_n_dbg;
  nano_instr_we   <= '0';
  nano_instr_addr <= nano_pc;
  nano_instr_init <= (others => '0');
  
  nano_memory_inst : entity nano.nano_memory(edge)
    port map(clk1_i       => nano_clk1,
             clk2_i       => '0',
             adc_i        => (others => '0'),
             dmem_oe_i    => nano_data_oe,
             dmem_we_i    => nano_data_we,
             dmem_addr_i  => nano_data_addr,
             dmem_data_i  => nano_data_to_mem,
             imem_oe_i    => nano_instr_oe_from_dbg,
             imem_we_i    => nano_instr_we_from_dbg,
             imem_addr_i  => nano_instr_addr_from_dbg,
             imem_instr_i => nano_instr_init_from_dbg,
             dmem_data_o  => nano_data_from_mem,
             dmem_func_o  => nano_func_from_mem,
             imem_instr_o => nano_instr
            );
  
  -----------------------------------------------------------------------------
  -- Debug Interface / UART
  -----------------------------------------------------------------------------
  dbg_iface_inst : entity control.dbg_iface(edge)
    generic map(CTRL_SCHG_W_G     => CTRL_SCHG_W_C,      -- State Change LUT Output Width
                CTRL_CONF_ADR_W_G => CTRL_CONF_ADR_W_C,  -- LUT Configuration Address Port Width
                DBG_CONF_ADR_W_G  => DBG_CONF_ADR_W_C)   -- Memory Debug Address Port Width
    port map(clk_i        => nano_clk1,
             rst_n_i      => nano_rst_n,
             dbg_adc_i    => (others => '0'),
             dbg_func_i   => nano_func,
             dbg_iadr_i   => nano_instr_addr,
             dbg_inst_i   => nano_instr,
             dbg_ctlgen_i => (others => '0'),
             dbg_clut_i   => nano_clut,
             dbg_schg_i   => nano_schg,
             imem_oe_i    => nano_instr_oe,
             imem_we_i    => nano_instr_we,
             imem_addr_i  => nano_instr_addr,
             imem_instr_i => nano_instr_init,
             uart_rx_i    => rx_w,
             rst_n_o      => nano_rst_n_dbg,
             uart_tx_o    => tx_w,
             dbg_wake_o   => dbg_wake,
             imem_oe_o    => nano_instr_oe_from_dbg,
             imem_we_o    => nano_instr_we_from_dbg,
             imem_addr_o  => nano_instr_addr_from_dbg,
             imem_instr_o => nano_instr_init_from_dbg,
             we_cgen_o    => nano_we_cgen_from_dbg,
             cgen_param_o => nano_cgen_param_from_dbg,
             we_clut_o    => nano_we_clut_from_dbg,
             we_schg_o    => nano_we_schg_from_dbg,
             lut_addr_o   => nano_lut_addr_from_dbg,
             lut_din_o    => nano_lut_din_from_dbg
            );

  
  
  nano_clk2                             <= '0';
  led(1 downto 0)                       <= std_ulogic_vector(nano_func(1 downto 0));
  led(3 downto 2)                       <= std_ulogic_vector(nano_func(2*NANO_D_W_C+1 downto 2*NANO_D_W_C));
  btn_w                                 <= std_logic_vector(btn);
  sw_w                                  <= std_logic_vector(sw);
  rx_w                                  <= std_logic(uart_txd_in);
  uart_rxd_out                          <= std_ulogic(tx_w);
  
  
  pll_inst : arty_pll
   port map ( 
  -- Clock out ports  
   clk_out1 => pll_clk,
  -- Status and control signals                
   reset => uc_rst,
   locked => pll_locked,
   -- Clock in ports
   clk_in1 => CLK100MHZ
 );
 
  nano_clk1_buf_inst : BUFGCE
    generic map(SIM_DEVICE => "7SERIES")
    port map(I  => pll_clk,
             O  => nano_clk1,
             CE => nano_clk1_en
            );

  --
  -- reset generation using delay counter to avoid reset toggeling
  -- clock generation for NanoController: divide-by-8 for enable of BUFGCE
  --

  pll_seq : process (pll_clk, pll_locked)
  begin
    if pll_locked = '0' then
      reset_cnt_ff     <= (others => '0');
      nano_clk1_cnt_ff <= (others => '0');
      reset_n_ff       <= '0';
    elsif rising_edge(pll_clk) then
      reset_cnt_ff     <= reset_cnt_nxt;
      nano_clk1_cnt_ff <= nano_clk1_cnt_nxt;
      reset_n_ff       <= reset_n_nxt;
    end if;
  end process pll_seq;
  
  nano_clk_seq : process (nano_clk1, pll_locked)
  begin
    if pll_locked = '0' then
      nano_rst_n_ff  <= '0';
    elsif rising_edge(nano_clk1) then
      nano_rst_n_ff  <= reset_n_nxt;
    end if;
  end process nano_clk_seq;

  reset_cnt : process(reset_cnt_ff)
  begin
    reset_cnt_nxt <= reset_cnt_ff;
    reset_n_nxt   <= '1';
    if reset_cnt_ff < RESET_CNT_MAX then
      reset_cnt_nxt <= reset_cnt_ff + 1;
      reset_n_nxt   <= '0';
    end if;
  end process reset_cnt;
  
  nano_clk1_cnt : process(nano_clk1_cnt_ff)
  begin
    nano_clk1_cnt_nxt <= nano_clk1_cnt_ff + 1;
    nano_clk1_en      <= '1';
    if nano_clk1_cnt_ff < NCLK_CNT_MAX then
      nano_clk1_en <= '0';
    end if;
  end process nano_clk1_cnt;

  -- sys clock and sys reset
  sys_clk    <= pll_clk;
  sys_rst_n  <= reset_n_ff;
  nano_rst_n <= nano_rst_n_ff;
  
  
end architecture rtl;
