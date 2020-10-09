-- Title      : ethBRAMcomponent
-- Project    : ntcScrod
-------------------------------------------------------------------------------
-- File       : ethBRAMcomponent.vhd
-- Author     : Kevin Keefe  <kevinkeefe@Kevins-MBP.home>
-- Company    : UH Manoa
-- Created    : 2019-07-08
-- Last update: 2019-07-09
-- Platform   : Spartan 6
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: component entity description. XST uses this module to infer the
-- BRAM which is used in the userBufferEthBRAM module. the code here is taken
-- nearly directly from https://www.xilinx.com/support/documentation/sw_manuals/xilinx12_2/xst.pdf
-- the above url is a link to the xilinx user guide defining how to explain to
-- write HDL such that XST will infer a single port synchronous BRAM.
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-08  1.0      kevinkeefe  Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

-- single port BRAM entity
entity BRAM_eth is
  generic (
    addr_cnt    : integer := 1024
    );
    port (
      clk  : in  std_logic;
      en   : in  std_logic;
      we   : in  std_logic;
      addr : in  std_logic_vector(9 downto 0);
      di   : in  std_logic_vector(15 downto 0);
      do   : out std_logic_vector(15 downto 0)
);
end entity BRAM_eth;

-- read first synchronous BRAM
architecture read_first of BRAM_eth is

  type ram_space is array (0 to addr_cnt - 1) of std_logic_vector(15 downto 0);
  constant empty_ram : ram_space := (others => (others => '0'));
  signal ram_mem1 : ram_space := empty_ram;

begin  -- architecture syn_single

  process (clk) is
  begin
    -- make this stuff synchronous
    if rising_edge(clk) then
      -- clk enable check
      if (en = '1') then
        -- are we writing to the BRAM this clk cycle?
        if (we = '1') then
          ram_mem1(conv_integer(addr)) <= di;
        end if;
         do <= ram_mem1(conv_integer(addr));
     end if;
    end if;
  end process;

-- do <= ram_mem1(conv_integer(addr));

end architecture read_first;

