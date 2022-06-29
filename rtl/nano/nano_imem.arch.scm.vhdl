-- Copyright (c) 2022 Chair for Chip Design for Embedded Computing,
--                    Technische Universitaet Braunschweig, Germany
--                    www.tu-braunschweig.de/en/eis
--
-- Use of this source code is governed by an MIT-style
-- license that can be found in the LICENSE file or at
-- https://opensource.org/licenses/MIT.


library top_level;

architecture edge_ram of nano_imem is
  
  -- MEM Array
  type imem_t is array (0 to DEPTH-1) of std_logic_vector(WIDTH_BITS-1 downto 0);
  
  -- RAM
  signal imem : imem_t;
  -- !! changed for MEH ASIC flashloader with 8 bit load, load 2 4-bit instructions parallel !!
  signal wen  : std_logic_vector((2**DEPTH_LOG2)/2-1 downto 0);  --((2**DEPTH_LOG2)-1 downto 0);
  
  -- Input / Address Latch Signals
  signal instr : std_logic_vector(2*WIDTH_BITS-1 downto 0);  --(WIDTH_BITS-1 downto 0);
  -- !! change end !!
  signal addr  : std_logic_vector(DEPTH_LOG2-1 downto 0);
  
  -- Clock Gating Signals
  signal clk1_we_gated : std_logic;
  signal clk1_oe_gated : std_logic;
  -- !! changed for MEH ASIC flashloader with 8 bit load, load 2 4-bit instructions parallel !!
  signal clk_row_gated : std_logic_vector(DEPTH/2-1 downto 0);  --(DEPTH-1 downto 0);
  -- !! change end !!
  
begin

  -- Clock Gating (global write enable)
  clk1_we_gate : entity top_level.clkgate(asic)
    port map(clk => clk1_i,
             en  => we_i,
             gck => clk1_we_gated);
  
  -- Clock Gating (global output enable)
  clk1_oe_gate : entity top_level.clkgate(asic)
    port map(clk => clk1_i,
             en  => oe_i,
             gck => clk1_oe_gated);
  
  -- Memory Rows (with local write clock gating)
  -- !! changed for MEH ASIC flashloader with 8 bit load, load 2 4-bit instructions parallel !!
  wen <= dectree(we_i, addr_i(addr_i'left downto 1));  --addr_i);
  mem_row_gen : for i in 0 to DEPTH/2-1 generate  --DEPTH-1 generate
    clk_row_gate : entity top_level.clkgate(asic)
      port map(clk => clk1_we_gated,
               en  => wen(i),
               gck => clk_row_gated(i));
    
    mem_write : process(clk_row_gated(i))
    begin
      if rising_edge(clk_row_gated(i)) then
        --imem(i) <= instr;
        imem(2*i)   <= instr(2*WIDTH_BITS-1 downto WIDTH_BITS);
        imem(2*i+1) <= instr(WIDTH_BITS-1   downto 0);
  -- !! change end !!
      end if;
    end process mem_write;
  end generate mem_row_gen;
  
  -- Input Data Latch
  in_lat : process(we_i, instr_i)
  begin
    if we_i = '1' then
      instr <= instr_i;
    end if;
  end process in_lat;
  
  -- Address Latch
  addr_lat : process(we_i, oe_i, addr_i)
  begin
    if we_i = '1' or oe_i = '1' then
      addr <= addr_i;
    end if;
  end process addr_lat;
  
  -- Output Mux
  out_mux : process(clk1_oe_gated)
    variable dvec : std_logic_vector((2**DEPTH_LOG2)*WIDTH_BITS-1 downto 0);
    variable dout : std_logic_vector(WIDTH_BITS-1                 downto 0);
  begin
    if rising_edge(clk1_oe_gated) then
      dvec := (others => '-');
      for i in 0 to DEPTH-1 loop
        dvec((i+1)*WIDTH_BITS-1 downto i*WIDTH_BITS) := imem(i);
      end loop; --i
      dout := muxtree(dvec, addr, WIDTH_BITS);
      instr_o <= dout;
    end if;
  end process out_mux;
  
end architecture edge_ram;
