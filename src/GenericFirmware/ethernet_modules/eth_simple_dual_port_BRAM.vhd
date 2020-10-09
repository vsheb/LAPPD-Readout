-------------------------------------------------------------------------------
-- Title      : eth_simple_dual_port_BRAM
-- Project    :
-------------------------------------------------------------------------------
-- File       : eth_simple_dual_port_BRAM.vhd
-- Author     : Kevin Keefe  <kevinkeefe@Kevins-MacBook-Pro.local>
-- Company    :
-- Created    : 2019-07-18
-- Last update: 2019-07-18
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description:
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-18  1.0      kevinkeefe	Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.std_logic_unsigned.all;

-- single port BRAM entity
entity eth_simple_dual_port_BRAM is
  generic (
    addr_cnt : integer := 1024
    );
    port (
      clk    : in  std_logic;
      en     : in  std_logic;
      we     : in  std_logic;
      addr_i : in  std_logic_vector(9 downto 0);
      addr_o : in  std_logic_vector(9 downto 0);
      di     : in  std_logic_vector(15 downto 0);
      do     : out std_logic_vector(15 downto 0)
);
end entity eth_simple_dual_port_BRAM;

-- read first synchronous BRAM
architecture rtl of eth_simple_dual_port_BRAM is

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
          ram_mem1(conv_integer(addr_i)) <= di;
        end if;
          do <= ram_mem1(conv_integer(addr_o));
     end if;
    end if;
  end process;

-- do <= ram_mem1(conv_integer(addr_o));

end architecture rtl;
