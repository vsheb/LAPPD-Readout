library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

use ieee.std_logic_arith.all; -- conv_std_logic_vector
use ieee.numeric_bit.all;

use std.textio.all;

entity AdcSimModel is
generic(
   N_CHANNELS  : integer := 1;
   filename    : string  := "";
   MODE        : integer := 32 -- 32 or 16 channel mode
);
port(
      CLKP : in std_logic;
      CLKN : in std_logic;
      
      DCOP : out std_logic;
      DCON : out std_logic;
      
      FCOP : out std_logic;
      FCON : out std_logic;
      
      DOP : out std_logic_vector(N_CHANNELS-1 downto 0);
      DON : out std_logic_vector(N_CHANNELS-1 downto 0)
   );
end AdcSimModel;

architecture behavioral of AdcSimModel is
	signal dco : std_logic := '0';
	signal fco : std_logic := '0';
	
   signal doa  : std_logic_vector(N_CHANNELS-1 downto 0) := (others => '0');

	signal dcop_s : std_logic := '0';
	signal dcon_s : std_logic := '1';

	signal fcop_s : std_logic := '0';
	signal fcon_s : std_logic := '1';

	signal dop_s : std_logic_vector(N_CHANNELS-1 downto 0) := (others => '0');
	signal don_s : std_logic_vector(N_CHANNELS-1 downto 0) := (others => '0');

	signal dbg   : std_logic_vector(11 downto 0) := (others=>'0');

   signal cnt   : std_logic_vector(11 downto 0) := (others => '0');
   constant adc_del_time : time := 0 ps; -- PAR

   signal adc_dat : std_logic_vector(11 downto 0) := (others => '0');
   signal fco32   : std_logic := '0';
	
begin

   clk_proc : process
      variable no_first_front_v : boolean := false;
      variable clk_period_v : time := 35000 ps;
      variable clk_front_time_v : time := 0 ps;
      variable tick_time_v : time := 0 ps;
   begin

      wait on CLKP until rising_edge(CLKP);

      fco32 <= not fco32;

      if no_first_front_v = false then
         no_first_front_v := true;
         clk_front_time_v := now;
         fco <= '0';
      else
         clk_period_v     := now - clk_front_time_v;
         tick_time_v      := clk_period_v / 24.01;
         clk_front_time_v := now;

         adc_dat <= adc_dat + '1';

         dco <= '0';

         for iBit in 0 to 11 loop 

            if MODE = 16 then
               if iBit < 5 then 
                  fco <= '1';
               else 
                  fco <= '0';
               end if;
            elsif MODE = 32 then
               if iBit = 0 then
                  fco <= not fco;
               end if;
            end if;

            doa <= (others => adc_dat(iBit));	
         
            --dco <= '0';
            wait for tick_time_v;
            dco <= not dco;
            wait for tick_time_v;
         end loop;

      end if; 

   end process;

	dcop_s <= transport     dco after adc_del_time;
	dcon_s <= transport not dco after adc_del_time;

	fcop_s <= transport     fco after adc_del_time;
	fcon_s <= transport not fco after adc_del_time;

	dop_s <= transport     doa after adc_del_time;
	don_s <= transport not doa after adc_del_time;

	DCOP <= dcop_s;
	DCON <= dcon_s;
	
	FCOP <= fcop_s;
	FCON <= fcon_s;

	DOP <= dop_s;
	DON <= don_s;


end;
