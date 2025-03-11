library ieee;
use ieee.std_logic_1164.all;

library nano;
use nano.aux_pkg.all;
use nano.nano_pkg.all;

library control;
use control.ctrl_pkg.all;

library top_level;

entity sim_wrapper is
  port(
    -- Inputs
    i_nano_clk         : in  std_logic;
    i_nano_rst_n       : in  std_logic;
    i_nano_ext_wake    : in  std_logic;
    i_dbg_spi_en_n     : in  std_logic;
    i_dbg_spi_mosi     : in  std_logic;
    i_dbg_spi_sclk     : in  std_logic;
    -- Outputs
    o_nano_ctrl        : out std_logic_vector(35 downto 0);
    o_dbg_spi_miso     : out std_logic
    );
end entity sim_wrapper;

architecture str of sim_wrapper is

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
  signal nano_clk                 : std_logic;
  signal nano_rst_n               : std_logic;
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
  
begin
  
  -----------------------------------------------------------------------------
  -- Common Nanocontroller logic (independent of implementation platform)
  -----------------------------------------------------------------------------
  nano_ext_wake <= i_nano_ext_wake & dbg_wake(NANO_EXT_IRQ_W_C-2 downto 0);
  
  nano_top_inst : nano_top
    generic map(CTRL_CYCLE_DEPTH_G => CTRL_CYCLE_DEPTH_C,  -- Cycle LUT Depth
                STEP_GROUPS_G      => STEP_GROUPS_C,       -- Encoded Execution Cycle Number Width
                CTRL_SCHG_W_G      => CTRL_SCHG_W_C,       -- State Change LUT Output Width
                CTRL_CONF_ADR_W_G  => CTRL_CONF_ADR_W_C    -- LUT Configuration Address Port Width
               )
    port map(
      nano_clk1         => nano_clk,
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
  nano_memory_inst : entity nano.nano_memory(edge)
    port map(clk1_i       => nano_clk,
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
  
  nano_rst_n_int  <= nano_rst_n_dbg;
  nano_instr_we   <= '0';
  nano_instr_addr <= nano_pc;
  nano_instr_init <= (others => '-');
  
  -----------------------------------------------------------------------------
  -- Debug Interface / SPI-Slave
  -----------------------------------------------------------------------------
  dbg_iface_inst : entity control.dbg_iface(edge)
    generic map(CTRL_SCHG_W_G     => CTRL_SCHG_W_C,      -- State Change LUT Output Width
                CTRL_CONF_ADR_W_G => CTRL_CONF_ADR_W_C,  -- LUT Configuration Address Port Width
                DBG_CONF_ADR_W_G  => DBG_CONF_ADR_W_C)   -- Memory Debug Address Port Width
    port map(clk_i        => nano_clk,
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
             spi_en_n_i   => i_dbg_spi_en_n,
             spi_mosi_i   => i_dbg_spi_mosi,
             spi_sclk_i   => i_dbg_spi_sclk,
             rst_n_o      => nano_rst_n_dbg,
             spi_miso_o   => o_dbg_spi_miso,
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
  
  -----------------------------------------------------------------------------
  -- Clock Divider, Reset Generator, ADC Clock Gate
  -----------------------------------------------------------------------------
  clkdiv_rst_gen_inst : entity control.clkdiv_rst_gen(edge)
    port map(clk_i      => i_nano_clk,
             rst_n_i    => i_nano_rst_n,
             param_i    => nano_cgen_param_from_dbg,
             we_param_i => nano_we_cgen_from_dbg,
             clk_o      => nano_clk,
             rst_n_o    => nano_rst_n
            );
  
  -----------------------------------------------------------------------------
  -- Connection to pins
  -----------------------------------------------------------------------------
  o_nano_ctrl <= nano_func(o_nano_ctrl'length-1 downto 0);
  
end architecture str;
