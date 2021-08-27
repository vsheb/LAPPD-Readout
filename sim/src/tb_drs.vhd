----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/13/2019 01:53:50 AM
-- Design Name: 
-- Module Name: tb_drs - Behavioral
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
--use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity tb_drs is
end tb_drs;

architecture Behavioral of tb_drs is
   constant clock_period : time := 8 ns;

   signal clk : std_logic;

   signal configReg     : std_logic_vector(7 downto 0) := (others => '0');
   signal regMode       : std_logic := '0';
   signal regData       : std_logic_vector(7 downto 0) := (others => '0');
   signal regReq        : std_logic := '0';
   signal regAck        : std_logic := '0';

   signal readoutReq    : std_logic := '0';
   signal readoutAck    : std_logic := '0';

   signal nSamples      : std_logic_vector(11 downto 0) := (others => '0');

   signal transModeOn   : std_logic := '0';

   signal stopSample    : Word10Array(0 downto 0) := (others => (others => '0'));
   signal sampleValid   : std_logic := '0';

   signal adcSync       : std_logic := '0';
   signal adcConvClk    : std_logic := '0'; 
   signal adcConvClkR   : std_logic := '0';
   signal clkCnt        : std_logic_vector(2 downto 0) := (others => '0');

   signal drsRefClkP    : std_logic := '0';
   signal drsRefClkN    : std_logic := '0';
   signal drsAddr       : std_logic_vector(3 downto 0) := (others => '0');
   signal drsSrClk      : std_logic := '0';
   signal drsSrIn       : std_logic := '0';
   signal drsRsrLoad    : std_logic := '0';
   signal drsSrOut      : std_logic_vector(0 downto 0) := (others => '0');
   signal drsDWrite     : std_logic := '0';
   signal drsBusy       : std_logic;
   signal drsDEnable    : std_logic;
   signal drsStopValid  : std_logic := '0';

   signal TxCmd         : std_logic := '0';
   signal TxTrig        : std_logic := '0';

begin

   UUT : entity work.DrsControl 
      generic map(
          SR_CLOCK_HALF_PERIOD_G => 8
          )
      port map(
         -- System clock and reset
         sysClk        => clk, 
         sysRst        => '0', 

         adcSync       => adcSync,
         dEnable       => '1',
         phaseAdcSrClk => (others => '0'),
         refClkRatio   => x"0000_0004",
         -- User requests
         regMode       => b"00",
         regData       => regData,
         regReq        => regReq,
         regAck        => regAck,

         -- Perform the normal readout sequence
         readoutReq    => readoutReq, 
         readoutAck    => readoutAck, 
         nSamples      => nSamples,   
         stopSample    => stopSample,
         sampleValid   => sampleValid,
         validPhase    => std_logic_vector(to_unsigned(0,6)),
         waitAfterAddr => std_logic_vector(to_unsigned(16,16)),
         stopSmpValid  => drsStopValid,

         idleMode      => b"01",

         -- DRS4 address & serial interfacing
         drsRefClkN    => drsRefClkN,
         drsRefClkP    => drsRefClkP,
         drsAddr       => drsAddr,    
         drsSrClk      => drsSrClk,  
         drsSrIn       => drsSrIn,   
         drsRsrLoad    => drsRsrLoad,
         drsSrOut      => drsSrOut,  
         drsDWrite     => drsDWrite,
         drsDEnable    => drsDEnable,
         drsPllLck     => (others => '1'),
         drsBusy       => drsBusy
      );

   AdcIniControl_U : entity work.AdcIniControl
      port map (
         sysClk      => clk,
         syncRst     => '0',

         adcConvClk  => adcConvClk,

         txTrigCmd   => TxCmd, 
         adcResetCmd => '0', 

         adcTxTrig   => TxTrig, 
         adcReset    => open,
         adcSync     => adcSync
      );

   clk_proc : process                      
   begin                                     
      clk <= '0';                            
      wait for clock_period/2;                 
      clk <= '1';                            
      wait for clock_period/2;                 
   end process;                              

   clk_cnt : process (clk)
   begin
      if rising_edge (clk) then
         clkCnt <= clkCnt + 1;
         adcConvClkR   <= adcConvClk;
      end if;
   end process;
   adcConvClk <= clkCnt(1);


   stim : process
   begin
      nSamples <= '0' & std_logic_vector(to_unsigned(1024,11));
      transModeOn <= '0';
      
      wait for 0.5 us;
      wait until clk = '1';
      TxCmd <= '1';
      wait until clk = '1';
      wait until clk = '1';
      txCmd <= '0';
      wait for 0.5 us;

      wait until clk = '1';
      readoutReq <= '1';
      wait until readoutAck = '1';
      wait until clk = '1';
      readoutReq <= '0';
      wait until drsBusy = '0';


      wait for 10 us;

   end process;


end Behavioral;



