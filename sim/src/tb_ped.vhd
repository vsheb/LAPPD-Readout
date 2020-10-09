library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use work.LappdPkg.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity tb_ped is
end tb_ped;



architecture behav of tb_ped is
   constant T_clk    : time := 20 ns;
   signal clk        : std_logic;
   signal rst        : std_logic := '0';

   signal smpNum     : slv(9 downto 0) := (others => '0');
   signal smpNumArr  : Word10Array(0 to 63);
   signal pedArr     : AdcDataArray(0 to 63) := (others => (others => '0'));

   signal evtBusy    : sl := '0';

   signal regReq     : std_logic := '0';
   signal regChan    : slv(5 downto 0) := (others => '0');
   signal regAddr    : slv(9 downto 0) := (others => '0');
   signal regAck     : sl := '0';
   signal regWrEn    : sl := '0';
   signal regWrData  : slv(11 downto 0) := (others => '0');
   signal regRdData  : slv(11 downto 0) := (others => '0');
   
begin

   LappdPedMemory_U : entity work.LappdPedMemory
      port map (
         clk          => clk,
         rst          => rst,

         smpNumArr    => smpNumArr,
         pedArr       => pedArr,

         evtBusy      => evtBusy,

         regReq       => regReq,
         regChan      => regChan,   
         regAddr      => regAddr,   
         regAck       => regAck,    
         regWrEn      => regWrEn,   
         regWrData    => regWrData, 
         regRdData    => regRdData 
      );

   ------------------------------------------
   -- clock process 
   ------------------------------------------
   clk_proc : process                      
   begin                                     
      clk <= '0';                            
      wait for T_clk/2;                 
      clk <= '1';                            
      wait for T_clk/2;                 
   end process;                              
   ------------------------------------------
   
   stim : process 
   begin
      evtBusy <= '0';
      wait for 100 ns;

      for i in 0 to 100 loop
         wait until clk = '1';
         regReq    <= '1';
         regChan   <= slv(to_unsigned(0,6 ));
         regAddr   <= slv(to_unsigned(i,10));
         regWrEn   <= '1';
         regWrData <= slv(to_unsigned(i,12)); 
         wait until clk = '1';
         wait until regAck = '1' and clk = '1';
         regReq    <= '0';
         regWrEn   <= '0';
         wait until clk = '1';
      end loop;

      wait for 100 ns;
      evtBusy <= '1';
      wait for 100 ns;

      for i in 0 to 100 loop
         wait until clk = '1';
         smpNumArr    <= (others => slv(to_unsigned(i,10)));
         wait until clk = '1';
      end loop;



   end process;

end behav;
