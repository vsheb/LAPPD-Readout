LIBRARY ieee;                                                    
USE ieee.std_logic_1164.ALL;                                     
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
                                                                 
library work;
use work.LappdPkg.All;

library UNISIM;
use UNISIM.VComponents.all;

ENTITY tb_adc IS                                                
END tb_adc;                                                     

architecture beh of tb_adc is 

   constant clock_period : time := 20 ns;

   signal clk : std_logic := '0';
   signal rst : std_logic := '0';

   signal sysclk : std_logic := '0';

   signal adcClkP,  adcClkN  : std_logic;
   signal adcDoClkP, adcDoClkN : std_logic;
   signal adcFrClkP, adcFrClkN : std_logic;
   signal adcDoP,   adcDoN   : std_logic_vector(7 downto 0);
   signal adcDataOut         : AdcDataArray(7 downto 0);
   signal adcDataValid       : std_logic;
   signal adcDataClk         : std_logic;

   signal adcStart     : std_logic;
   signal adcBufRdChn  : std_logic_vector(3 downto 0);
   signal adcBufRdAddr : std_logic_vector(9 downto 0);
   signal adcBufReq    : std_logic;
   signal adcBufAck    : std_logic;
   signal adcBufRdData : std_logic_vector(11 downto 0);

   signal adcBufCurAddr : std_logic_vector(9 downto 0);

   signal TxCmd         : std_logic := '0';
   signal TxTrig        : std_logic := '0';

begin

   adc_u : entity work.AdcSimModel 
   generic map (
      N_CHANNELS => 8
   )
   port map (
     CLKP => adcClkP,
     CLKN => adcClkN,

     DCOP => adcDoClkP,
     DCON => adcDoClkN,

     FCOP => adcFrClkP,
     FCON => adcFrClkN,

     DOP  => adcDoP,
     DON  => adcDoN
   );

   adcClkP <= clk;
   adcClkN <= not clk;

   U_AdcInterface : entity work.AdcReadout
   generic map (
      N_DATA_LINES => 8
   )
   port map(
      sysClk        => sysclk,
      iDelayRefClk  => '0',
      adcConvClk    => clk,          -- Master clock to module (read clock for ADC)

      txTrigCmd     => TxCmd,      
      adcResetCmd   => '0',
      bitslip       => (others => '0'),

      syncRst       => rst,          -- Synchronous reset

      adcFrameDelay => (others => '0'),
      adcDataDelay  => (others => (others => '0')),
      adcClkDelay   => (others => '0'),

      adcDoClkP     => adcDoClkP,
      adcDoClkN     => adcDoClkN,
      adcFrClkP     => adcFrClkP,
      adcFrClkN     => adcFrClkN,
      adcDataInP    => adcDoP,
      adcDataInN    => adcDoN,
      
      -- Output ports
      adcTxTrig     => TxTrig,
      adcReset      => open,
      adcDelayDebug => open,
      bitslipCnt    => open,
      adcClkP       => adcClkP,
      adcClkN       => adcClkN,
      
      adcDataClk    => adcDataClk,
      adcFrameOut   => open,
      adcDataOut    => adcDataOut, 
      adcDataValid  => adcDataValid 
   );

   U_AdcBuffer : entity work.AdcBuffer
   generic map(
      ADC_CHANNELS_NUMBER => 8,
      ADC_DATA_WIDTH      => 12,
      ADC_DATA_DEPTH      => 10 
   )
   port map(
      sysClk        => sysclk,
      sysRst        => rst, 

      rdEthEnable      => '0',
      rdEthAddrInc     => '0',
      rdEthAddrRst     => '0',
      rdEthData        => open,

      WrEnable      => adcDataValid,
      wrData        => adcDataOut,
      
      -- reg interface
      rdChan        => adcBufRdChn,
      rdAddr        => adcBufRdAddr,
      rdReq         => adcBufReq,
      rdAck         => adcBufAck,
      rdData        => adcBufRdData,
      -- debug      
                    
      curAddr       => adcBufCurAddr

   );
   
   clk_proc : process                      
   begin                                     
      clk <= '0';                            
      wait for clock_period/2;                 
      clk <= '1';                            
      wait for clock_period/2;                 
   end process;                              

   clk_proc1 : process                      
   begin                                     
      sysclk <= '0';                            
      wait for clock_period/2/2;                 
      sysclk <= '1';                            
      wait for clock_period/2/2;                 
   end process;                              

   stim : process
   begin
      adcStart <= '0';
      adcBufRdChn <= X"0";
      adcBufRdAddr <= std_logic_vector(to_unsigned(0, 10));
      wait for 100 ns;
      rst <= '1';
      wait for 100 ns;
      rst <= '0';
      wait for 1 us;

      wait until sysclk = '1';
      TxCmd <= '1';
      wait for clock_period/2 + 1 ns;
      TxCMd <= '0';

      wait until clk = '1';
      adcStart <= '1';
      wait for clock_period;
      adcStart <= '0';

      wait for 10 us;

   end process;


end beh;


