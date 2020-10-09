---------------------------------------------------------------------------------- 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.all;
   use ieee.numeric_std.all;
   use ieee.std_logic_unsigned.all;
library UNISIM;                                                                                                        
   use UNISIM.vcomponents.all;                                                                                            

entity clk_div is
   --generic (
      --RATIO : integer := 40
   --);
   port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      ratio     : in  std_logic_vector(31 downto 0);
      strb      : in  std_logic;

      clkdiv    : out std_logic;
      hb        : out std_logic;
      sync_strb : out std_logic
   );
end clk_div;

architecture beh of clk_div is
   signal   max_cnt      : std_logic_vector(31 downto 0);
   signal   max_cnt_prd  : std_logic_vector(31 downto 0);
   constant zero_cnt     : std_logic_vector(31 downto 0) := (others => '0');
   signal   i_cnt        : std_logic_vector(31 downto 0) := (others => '0');
   signal   i_clkdiv        : std_logic := '0';

   signal   i_hb_cnt     : std_logic_vector(31 downto 0) := (others => '0');
   signal   i_hb         : std_logic;

   signal   i_strb_cnt : std_logic_vector(31 downto 0) := (others => '0');
   signal   i_strb     : std_logic := '0';
   signal   i_strb_e   : std_logic := '0';
begin                                                                                                                

   CLK_PROC : process(clk)
   begin
      if rising_edge(clk) then
         if rst = '1' then
            i_cnt <= (others => '0');
            i_clkdiv <= '0';
         else
            max_cnt <= ('0' & ratio(31 downto 1)) - 1;
            if i_cnt < max_cnt then
               i_cnt <= i_cnt + '1';
            else
               i_cnt <= (others => '0');
               i_clkdiv <= not i_clkdiv;
            end if;
         end if;
      end if;
   end process CLK_PROC;

   clkdiv <= i_clkdiv;

   HB_PROC : process(clk)
   begin
      if rising_edge(clk) then
         max_cnt_prd <= ratio;
         i_hb <= '0';
         i_hb_cnt <= i_hb_cnt + 1;
         if i_hb_cnt = max_cnt then
            i_hb <= '1';
         end if;
         if i_hb_cnt >= max_cnt_prd-1 then
            i_hb_cnt <= (others => '0');
         end if;
      end if;
   end process;

   hb <= i_hb;

   STRB_PROC : process(clk)
   begin
      if rising_edge(clk) then

         if strb = '1' then
            i_strb_e <= '1';
         end if;

         if i_strb_e = '1' and i_hb_cnt = max_cnt then
            i_strb <= '1';
            i_strb_e <= '0';
         else
            i_strb <= '0';
         end if;

      end if;
   end process STRB_PROC;

   sync_strb <= i_strb;

end beh;


