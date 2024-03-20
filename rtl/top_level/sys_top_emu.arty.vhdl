-- Copyright (c) 2024 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
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

entity sys_top_emu is
  port(
    CLK100MHZ    : in    std_ulogic;
    btn          : in    std_ulogic_vector(3 downto 0);
    sw           : in    std_ulogic_vector(3 downto 0);
    led          : out   std_ulogic_vector(3 downto 0);
    ck_rst       : in    std_ulogic
    );
end entity sys_top_emu;

architecture rtl of sys_top_emu is
  
  component nano_top is
    port(
      nano_clk1     : in  std_logic;
      nano_clk2     : in  std_logic;
      nano_rst_n    : in  std_logic;
      nano_ext_wake : in  std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
      nano_instr    : in  std_logic_vector(NANO_I_W_C-1 downto 0);
      nano_instr_oe : out std_logic;
      nano_pc       : out std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
      nano_func_o   : out std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0)
      );
  end component nano_top;
  
  signal btn_w         : std_logic_vector(3 downto 0);
  signal sw_w          : std_logic_vector(3 downto 0);
  
  signal nano_clk1       : std_logic;
  signal nano_clk2       : std_logic;
  signal nano_func       : std_logic_vector(NANO_FUNC_OUTS_C*NANO_D_W_C-1 downto 0);
  signal nano_instr      : std_logic_vector(NANO_I_W_C-1 downto 0);
  -- !! changed for MEH ASIC flashloader with 8 bit load, load 2 4-bit instructions parallel !!
  signal nano_instr_init : std_logic_vector(2*NANO_I_W_C-1 downto 0);  --(NANO_I_W_C-1 downto 0);
  -- !! change end !!
  signal nano_instr_oe   : std_logic;
  signal nano_instr_we   : std_logic;
  signal nano_instr_addr : std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
  signal nano_pc         : std_logic_vector(NANO_I_ADR_W_C-1 downto 0);
  signal nano_rst_n_int  : std_logic;
  signal nano_ext_wake   : std_logic_vector(NANO_EXT_IRQ_W_C-1 downto 0);
  
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
  constant RESET_CNT_WIDTH : natural                              := 8;
  constant RESET_CNT_MAX   : unsigned(RESET_CNT_WIDTH-1 downto 0) := to_unsigned(2**RESET_CNT_WIDTH -1, RESET_CNT_WIDTH);
  constant NCLK_CNT_WIDTH  : natural                              := 8;
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
  dbg_wake       <= (others => '0');
  nano_ext_wake  <= btn(0) & dbg_wake(NANO_EXT_IRQ_W_C-2 downto 0);
  nano_rst_n_int <= nano_rst_n;
  
  nano_top_inst : nano_top
    port map(
      nano_clk1         => nano_clk1,
      nano_clk2         => '0',
      nano_rst_n        => nano_rst_n_int,
      nano_ext_wake     => nano_ext_wake,
      nano_instr        => nano_instr,
      nano_instr_oe     => nano_instr_oe,
      nano_pc           => nano_pc,
      nano_func_o       => nano_func);
  
  -----------------------------------------------------------------------------
  -- Nanocontroller IMEM
  -----------------------------------------------------------------------------
  nano_instr_we   <= '0';
  nano_instr_addr <= nano_pc;
  nano_instr_init <= (others => '0');
  
  nano_imem_inst : entity nano.nano_imem(edge_ram)
    generic map(DEPTH      => 2**NANO_I_ADR_W_C,
                DEPTH_LOG2 => NANO_I_ADR_W_C,
                WIDTH_BITS => NANO_I_W_C
               )
    port map(clk1_i  => nano_clk1,
             clk2_i  => '0',
             oe_i    => nano_instr_oe,
             we_i    => nano_instr_we,
             addr_i  => nano_instr_addr,
             instr_i => nano_instr_init,
             instr_o => nano_instr
            );
  
  
  
  nano_clk2       <= '0';
  led(1 downto 0) <= std_ulogic_vector(nano_func(1 downto 0));
  led(3 downto 2) <= std_ulogic_vector(nano_func(2*NANO_D_W_C+1 downto 2*NANO_D_W_C));
  btn_w           <= std_logic_vector(btn);
  sw_w            <= std_logic_vector(sw);
  
  
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
  -- clock generation for NanoController: divide-by-256 for enable of BUFGCE
  --

  pll_seq : process (pll_clk, pll_locked)
  begin
    if pll_locked = '0' then
      nano_clk1_cnt_ff <= (others => '0');
    elsif rising_edge(pll_clk) then
      nano_clk1_cnt_ff <= nano_clk1_cnt_nxt;
    end if;
  end process pll_seq;
  
  nano_clk_seq : process (nano_clk1, pll_locked)
  begin
    if pll_locked = '0' then
      nano_rst_n_ff  <= '0';
      reset_cnt_ff   <= (others => '0');
      reset_n_ff     <= '0';
    elsif rising_edge(nano_clk1) then
      nano_rst_n_ff  <= reset_n_nxt;
      reset_cnt_ff   <= reset_cnt_nxt;
      reset_n_ff     <= reset_n_nxt;
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
