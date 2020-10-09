----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/13/2019 01:53:50 AM
-- Design Name: 
-- Module Name: tb_drs_adc - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library work;
use work.LappdPkg.All;


entity tb_drs_adc is
end tb_drs_adc;

architecture Behavioral of tb_drs_adc is
   constant clock_period : time := 20 ns;
   
   constant sys_clk_period : time := 8 ns;

   signal clk : std_logic := '0';
   signal rst : std_logic := '0';

   signal sysclk : std_logic := '0';

   signal configReg     : std_logic_vector(7 downto 0) := (others => '0');
   signal regMode       : std_logic := '0';
   signal regData       : std_logic_vector(7 downto 0) := (others => '0');
   signal regReq        : std_logic := '0';
   signal regAck        : std_logic := '0';

   signal readoutReq    : std_logic := '0';
   signal readoutAck    : std_logic := '0';

   signal nSamples      : std_logic_vector(9 downto 0) := (others => '0');

   signal transModeOn   : std_logic := '0';

   signal stopSample    : Word10Array(0 downto 0) := (others => (others => '0'));
   signal sampleValid   : std_logic := '0';

   signal drsRefClkP    : std_logic := '0';
   signal drsRefClkN    : std_logic := '0';
   signal drsAddr       : std_logic_vector(3 downto 0) := (others => '0');
   signal drsSrClk      : std_logic := '0';
   signal drsSrIn       : std_logic := '0';
   signal drsRsrLoad    : std_logic := '0';
   signal drsSrOut      : std_logic_vector(0 downto 0) := (others => '0');
   signal drsDWrite     : std_logic := '0';

   signal adcClkP,  adcClkN  : std_logic;
   signal adcDoClkP, adcDoClkN : std_logic;
   signal adcFrClkP, adcFrClkN : std_logic;
   signal adcDoP,   adcDoN   : std_logic_vector(15 downto 0);
   signal adcDataOut         : AdcDataArray(31 downto 0);
   signal adcDataValid       : std_logic;
   signal adcDataClk         : std_logic;

   signal adcBufRdChn  : std_logic_vector(4 downto 0);
   signal adcBufRdAddr : std_logic_vector(9 downto 0);
   signal adcBufReq    : std_logic;
   signal adcBufAck    : std_logic;
   signal adcBufRdData : std_logic_vector(11 downto 0);

   signal adcBufCurAddr : std_logic_vector(9 downto 0);

   signal TxCmd         : std_logic := '0';
   signal TxTrig        : std_logic := '0';

begin

   drs_u : entity work.DrsControl
      port map(
         -- System clock and reset
         sysClk        => sysclk, 
         sysRst        => '0', 

         refClkRatio   => x"0000_0004",
         -- User requests
         regMode       => '0',
         regData       => regData,
         regReq        => regReq,
         regAck        => regAck,
         denable       => '1',
         -- Perform the normal readout sequence
         readoutReq    => readoutReq, 
         readoutAck    => readoutAck, 
         nSamples      => nSamples,   
         phaseAdcSrClk => X"3",
         stopSample    => stopSample,
         sampleValid   => sampleValid,

         transModeOn   => transModeOn,

         -- DRS4 address & serial interfacing
         drsRefClkN    => drsRefClkN,
         drsRefClkP    => drsRefClkP,
         drsAddr       => drsAddr,    
         drsSrClk      => drsSrClk,  
         drsSrIn       => drsSrIn,   
         drsRsrLoad    => drsRsrLoad,
         drsSrOut      => drsSrOut,  
         drsDWrite     => drsDWrite,
         drsPllLck     => (others => '1')
      );

   adc_u : entity work.AdcSimModel 
   generic map (
      N_CHANNELS => 16,
      MODE       => 32
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
      N_DATA_LINES => 16
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
      adcClkP       => adcClkP,
      adcClkN       => adcClkN,
      adcTxTrig     => TxTrig,
      adcReset      => open,

      adcDelayDebug => open,
      bitslipCnt    => open,
      
      adcDataClk    => adcDataClk,
      adcFrameOut   => open,
      adcDataOut    => adcDataOut, 
      adcDataValid  => adcDataValid 
   );

   U_AdcBuffer : entity work.AdcBuffer
   generic map(
      ADC_CHANNELS_NUMBER => 32,
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

   clk_proc : process(sysclk)
   begin                                     
      --clk <= '0';                            
      --wait for sys_clk_period*2/2;                 
      --clk <= '1';                            
      --wait for sys_clk_period*2/2;           
      if rising_edge(sysclk) then
         clk <= not clk;
      end if;
   end process;                              

   clk_proc1 : process                      
   begin                                     
      sysclk <= '0';                            
      wait for sys_clk_period/2; --clock_period/2/2;                 
      sysclk <= '1';                            
      wait for sys_clk_period/2; --clock_period/2/2;                 
   end process;                              

   stim : process
   begin
      nSamples <= std_logic_vector(to_unsigned(0,10));
      transModeOn <= '0';
      adcBufRdChn <= B"0_0000";
      adcBufRdAddr <= std_logic_vector(to_unsigned(0, 10));
      wait for 100 ns;
      rst <= '1';
      wait for 100 ns;
      rst <= '0';
      
      wait for 1 us;

      wait until clk = '1';
      readoutReq <= '1';
      wait until clk = '1';
      readoutReq <= '0';


      wait for 10 us;

   end process;


end Behavioral;




