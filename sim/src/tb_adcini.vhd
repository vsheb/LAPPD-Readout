library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.UtilityPkg.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

use work.LappdPkg.All;

entity tb_adcini is
end tb_adcini;

architecture Behavioral of tb_adcini is
   
   constant T_clk    : time := 8 ns;
   signal clk : std_logic := '0';
   signal rst : std_logic := '0';



   signal TxCmd         : std_logic := '0';
   signal adcResetCmd   : std_logic := '0';

   signal TxTrig        : std_logic := '0';

   signal adcSync       : std_logic := '0';
   signal adcConvClk    : std_logic := '0';
   signal adcConvClkR   : std_logic := '0';
   signal adcReset      : std_logic := '0';

   signal clkCnt            : slv(1 downto 0) := (others => '0');

begin

   process (clk)
   begin
      if rising_edge (clk) then
         clkCnt        <= clkCnt + 1;    
         adcConvClk    <= clkCnt(1);
         adcConvClkR   <= adcConvClk;
      end if;
   end process;

   AdcIniControl_U : entity work.AdcIniControl
      port map (
         sysClk => clk,
         syncRst => rst,

         adcConvClk => adcConvClk,

         txTrigCmd   => TxCmd, 
         adcResetCmd => adcResetCmd, 

         adcTxTrig   => TxTrig, 
         adcReset    => adcReset,
         adcSync     => adcSync
      );

   clk_proc1 : process                      
   begin                                     
      clk <= '0';                            
      wait for T_clk/2; --clock_period/2/2;                 
      clk <= '1';                            
      wait for T_clk/2; --clock_period/2/2;                 
   end process;                              

   stim : process
   begin
      wait for 100 ns;
      rst <= '1';
      wait for 100 ns;
      rst <= '0';
      
      wait for 1 us;

      wait until clk = '1';
      TxCmd <= '1';
      wait until clk = '1';
      wait until clk = '1';
      txCmd <= '0';


      wait for 10 us;

   end process;


end Behavioral;




