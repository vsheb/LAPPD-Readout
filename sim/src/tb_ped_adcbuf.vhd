
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;
use work.LappdPkg.All;


entity tb_ped_adcbuf is
end tb_ped_adcbuf;

architecture behav of tb_ped_adcbuf is

   constant T_clk    : time := 8 ns;
   signal clk        : std_logic;
   signal rst        : std_logic := '0';
   

   signal sysclk : std_logic := '0';

   signal stopSample    : Word10Array(0 downto 0) := (others => (others => '0'));
   signal sampleValid   : std_logic := '0';

   signal wrEna           :   std_logic := '0';
   signal wrData          :   AdcDataArray(0 to 63) := (others => (others => '0'));

   signal adcBufEthEna      : sl := '0';
   signal adcBufEthAddr     : slv(9 downto 0)           := (others => '0');
   signal adcBufEthChan     : slv(5 downto 0)           := (others => '0');
   signal adcBufEthData     : slv(11 downto 0); --: AdcDataArray(0 downto 0) := (others => (others => '0'));

   signal adcBufRdChn  : std_logic_vector(5 downto 0) := (others => '0');
   signal adcBufRdAddr : std_logic_vector(9 downto 0) := (others => '0');
   signal adcBufReq    : std_logic := '0';
   signal adcBufAck    : std_logic := '0';
   signal adcBufRdData : std_logic_vector(11 downto 0) := (others => '0');

   
   signal smpNum       : slv(9 downto 0) := (others => '0');
   signal smpNumArr    : Word10Array(0 to 7);
   signal pedArr       : AdcDataArray(0 to 63) := (others => (others => '0'));
   signal stopSmpArr   : Word10Array(0 to 7)   := (others => (others => '0'));
   signal stopSmpValid : sl := '0';

   signal evtBusy    : sl := '0';

   signal regReq     : std_logic := '0';
   signal regChan    : slv(5 downto 0) := (others => '0');
   signal regAddr    : slv(9 downto 0) := (others => '0');
   signal regAck     : sl := '0';
   signal regWrEn    : sl := '0';
   signal regWrData  : slv(11 downto 0) := (others => '0');
   signal regRdData  : slv(11 downto 0) := (others => '0');

begin

   U_AdcBuffer : entity work.AdcBuffer
   generic map(
      ADC_CHANNELS_NUMBER => 32,
      ADC_CHIPS_NUMBER    => 2,
      ADC_DATA_WIDTH      => 12,
      ADC_DATA_DEPTH      => 10 
   )
   port map(
      sysClk           => clk,
      sysRst           => rst, 
                       
      pedSubOn         => '1',
                       
      WrEnable         => wrEna,
      dataValid        => (others => '1'),
      wrData           => wrData,

      pedArr           => pedArr,
      pedSmpNumArr     => smpNumArr,
      drsStopSampleArr => stopSmpArr,
      drsStopSmpValid  => stopSmpValid,

      rdEthEnable      => adcBufEthEna,
      rdEthAddr        => adcBufEthAddr,
      rdEthChan        => adcBufEthChan,
      rdEthData        => adcBufEthData,

      -- reg interface
      rdChan        => adcBufRdChn,
      rdAddr        => adcBufRdAddr,
      rdReq         => adcBufReq,
      rdAck         => adcBufAck,
      rdData        => adcBufRdData,
      -- debug      
                    
      curAddr       => open 

   );

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

      -- fill pedestal data
      for i in 0 to 100 loop
         wait until clk = '1';
         regReq    <= '1';
         regChan   <= slv(to_unsigned(0,6 ));
         regAddr   <= slv(to_unsigned(i,10));
         regWrEn   <= '1';
         regWrData <= slv(to_signed(i-50,12)); 
         wait until clk = '1';
         wait until regAck = '1' and clk = '1';
         regReq    <= '0';
         regWrEn   <= '0';
         wait until clk = '1';
      end loop;

      wait for 100 ns;

      stopSmpArr <= (others => slv(to_unsigned(1,10)));

      -- read peds out
      for i in 0 to 100 loop
         wait until clk = '1';
         regReq       <= '1';
         regChan      <= slv(to_unsigned(0,6));
         regWrEn      <= '0';
         regAddr      <= slv(to_unsigned(i,10));
         wait until clk = '1';
         wait until regAck = '1';
         regReq <= '0';
         wait until clk = '1';
      end loop;

      wait for 100 ns;
      evtBusy <= '1';
      wait for 100 ns;

      stopSmpValid <= '1';
      wait for 2*T_clk;
      -- fill adc data
      for i in -50 to 50 loop
         wait until clk = '1';
         wrData <= ( others => slv(to_signed(i*2,12)) );
         wrEna  <= '1';
         wait until clk = '1';
         wrEna  <= '0';
      end loop;

      wait for 100 ns;

      adcBufEthEna <= '1';

      for i in 0 to 100 loop
         wait until clk = '1';
         adcBufEthAddr <= slv(to_unsigned(i,10));
         adcBufEthCHan <= slv(to_unsigned(0,6));
         wait until clk = '1';
      end loop;

      adcBufEthEna <= '0';


   end process;


end behav;

