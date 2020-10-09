library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use work.LappdPkg.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity tb_adcbuf is
end tb_adcbuf;

architecture Behavioral of tb_adcbuf is

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

   signal adcBufRdChn  : std_logic_vector(4 downto 0);
   signal adcBufRdAddr : std_logic_vector(9 downto 0);
   signal adcBufReq    : std_logic;
   signal adcBufAck    : std_logic;
   signal adcBufRdData : std_logic_vector(11 downto 0);

   
   signal smpNum     : slv(9 downto 0) := (others => '0');
   signal smpNumArr  : Word10Array(0 to 7);
   signal pedArr     : AdcDataArray(0 to 63) := (others => (others => '0'));
   signal stopSmpArr : Word10Array(0 to 7);
   signal stopSmpValid : sl := '0';

   signal hitsMask   : slv(63 downto 0) := (others => '0');
   signal zeroThreshArr        : AdcDataArray(0 to 63) := (others => (others => '0'));

   signal evtBusy    : sl := '0';

   signal regReq     : std_logic := '0';
   signal regChan    : slv(5 downto 0) := (others => '0');
   signal regAddr    : slv(9 downto 0) := (others => '0');
   signal regAck     : sl := '0';
   signal regWrEn    : sl := '0';
   signal regWrData  : slv(11 downto 0) := (others => '0');
   signal regRdData  : slv(11 downto 0) := (others => '0');

begin

   -------------------------------------------------
   -- ADC buffer
   -------------------------------------------------
   U_AdcBuffer : entity work.AdcBuffer
   generic map(
      ADC_CHANNELS_NUMBER => 32,
      ADC_CHIPS_NUMBER    => 2,
      ADC_DATA_WIDTH      => 12,
      ADC_DATA_DEPTH      => 10 
   )
   port map(
      sysClk           => clk, --adcDataClk,
      sysRst           => '0', 

      rstWrAddr        => '0',

      pedSubOn         => '0',
      zeroThreshArr    => zeroThreshArr,

      WrEnable         => wrEna,
      dataValid        => (others => '1'),
      wrData           => wrData,

      pedArr           => pedArr,
      pedSmpNumArr     => smpNumArr,
      drsStopSampleArr => (others => (others => '0')),
      drsStopSmpValid  => stopSmpValid,

      rdEthEnable      => adcBufEthEna,
      rdEthAddr        => adcBufEthAddr,
      rdEthChan        => adcBufEthChan,
      rdEthData        => adcBufEthData,

      -- reg interface
      rdChan        => (others => '0'),
      rdAddr        => regAddr,
      rdReq         => regReq,
      rdAck         => regAck,
      rdData        => regRdData,
      hitsThrMask   => hitsMask,

      -- debug      
      curAddr       => open,
      nWordsWrtn    => open

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
      wait for 100 ns;

      stopSmpValid <= '1';
      -- fill adc data
      for i in 0 to 100 loop
         wait until clk = '1';
         wrData <= ( others => slv(to_signed(i*2,12)) );
         pedArr <= ( others => slv(to_signed(i,12)) );
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

      wait for 100 ns;

      wait until clk = '1';
      regReq <= '1';
      regAddr <= slv(to_unsigned(1,10));
      wait until (regAck and clk) = '1' ;
      regReq <= '0';
      wait for 100 ns;

      for i in 0 to 100 loop
                   
         wait until clk = '1';
         regReq <= '1';
         regAddr <= slv(to_unsigned(0,10));
         wait until (regAck and clk) = '1' ;
         regReq <= '0';
         wait for 100 ns;

      end loop;
      

   end process;


end Behavioral;




