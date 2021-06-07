library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.std_logic_unsigned.all;
use work.UtilityPkg.all;
use work.LappdPkg.All;

library UNISIM;
use UNISIM.VComponents.all;

entity AdcIniControl is
   port (
      -- clocks
      sysClk        : in std_logic; -- system clock
      syncRst       : in std_logic; -- reset

      adcConvClk    : in std_logic; -- read clock for ADC

      txTrigCmd     : in std_logic; -- strobe to generate TX_TRIG signal
      adcResetCmd   : in std_logic; -- strobe to generate ADC RESET signal 

      bufRCE        : out std_logic;
      bufRCLR       : out std_logic;

      adcTxTrig     : out std_logic;
      adcReset      : out std_logic;
      adcSync       : out sl
   );
end AdcIniControl;

architecture Behavioral of AdcIniControl is
   signal iRst                : std_logic;
   signal adcConvClkR         : std_logic;
   signal adcConvClkRR        : std_logic;

   signal iAdcTxTrig          : std_logic := '0';
   signal localAdcReset       : std_logic := '0';
   signal adcSyncCnt          : std_logic_vector(2 downto 0) := (others => '0');
   signal stateCnt            : std_logic_vector(2 downto 0) := (others => '0');

   signal bufRCE_i            : std_logic := '1';
   signal bufRCLR_i           : std_logic := '0';
   signal waitCnt             : std_logic_vector(3 downto 0) := (others => '0');

   type   rstSeqStatesType   is (  IDLE_S, 
                                   OUT_DIS_S, 
                                   BUFR_CLR_S,
                                   OUT_ENA_S,
                                   DONE_S );
   signal rst_state    : rstSeqStatesType := IDLE_S;

   type adcSyncStatesType    is (  IDLE_S, 
                                   ADCCONV_SYNC_S,
                                   PHASE_TUNE_S,
                                   GEN_TXTRIG_S
                                );

   signal sync_state   : adcSyncStatesType := IDLE_S;
   
   attribute IOB : string;                               
   attribute IOB of adcTxTrig         : signal is "TRUE";
   attribute keep : string;
   attribute keep of iAdcTxTrig       : signal is "TRUE";

begin

   process (sysClk)
   begin
      if rising_edge (sysClk) then
         iRst <= syncRst;
      end if;
   end process;

   process (sysClk)
   begin
      if rising_edge (sysClk) then
         adcConvClkR <= adcConvClk;
         adcConvClkRR <= adcConvClkR;
      end if;
   end process;

   -------------------------------------------------------------------------
   -- ADC sync with TXTrig signal
   -------------------------------------------------------------------------
   process (sysClk)
   begin
      if rising_edge (sysClk) then
         adcSyncCnt <= adcSyncCnt + 1;
         stateCnt   <= stateCnt + 1;
         adcSync <= '0';
         case sync_state  is 
            when IDLE_S => 
               iAdcTxTrig <= '0';
               if txTrigCmd = '1' then
                  sync_state <= ADCCONV_SYNC_S;
               end if;
               if adcSyncCnt = b"000" then
                  adcSync <= '1';
               end if;
            when ADCCONV_SYNC_S => 
               stateCnt <=  (others => '0');
               if adcConvClkR = '1' and adcConvClk = '0' then
                  sync_state <= PHASE_TUNE_S;
                  stateCnt <= (others => '0');
               end if;
            when PHASE_TUNE_S => 
               if stateCnt = b"010" then
                  iAdcTxTrig <= '1';
                  stateCnt<= (others => '0');
                  sync_state <= GEN_TXTRIG_S;
               end if;

            when GEN_TXTRIG_S =>
               if stateCnt = b"011" then
                  iAdcTxTrig <= '0';
                  sync_state <= IDLE_S;
               end if;
            when others => 
               sync_state <= IDLE_S;
         end case;
         
         if iAdcTxTrig = '1' then 
            adcSyncCnt <= b"000";
         end if;


      end if;
   end process;

   FDRE_TxTrig : FDRE
   generic map (   
      INIT => '0'
   )  
   port map (   
      Q  => adcTxTrig,
      C  => sysClk,
      CE => '1',
      R  => '0',
      D  => iAdcTxTrig
   );
   -------------------------------------------------------------------------



   -------------------------------------------------------------------------
   pulseShaperReset_U : entity work.PulseShaper
      port map (
         clk => sysClk,
         rst => syncRst,
         len => x"002f",
         del => (others => '0'),
         din => adcResetCmd,
         dou => localAdcReset
      );

   adcReset <= localAdcReset;
   -------------------------------------------------------------------------


   -------------------------------------------------------------------------
   -- see UG472 pg.110
   -------------------------------------------------------------------------
   process (sysClk)
   begin
      if rising_edge (sysClk) then
         waitCnt <= waitCnt + 1;
         case rst_state is 
            when IDLE_S    => 
               bufRCLR_i  <= '0';
               bufRCE_i   <= '1';
               if waitCnt = x"f" then
                  rst_state   <= OUT_DIS_S;
                  waitCnt <= (others => '0');
               end if;
            when OUT_DIS_S =>
               bufRCLR_i  <= '0';
               bufRCE_i   <= '0';
               if waitCnt = x"f" then
                  rst_state   <= BUFR_CLR_S;
                  waitCnt <= (others => '0');
               end if;
            when BUFR_CLR_S =>
               bufRCLR_i  <= '1';
               bufRCE_i   <= '0';
               if waitCnt = x"f" then
                  rst_state   <= OUT_ENA_S;
                  waitCnt <= (others => '0');
               end if;
            when OUT_ENA_S  =>
               bufRCLR_i  <= '1';
               bufRCE_i   <= '1';
               if waitCnt = x"f" then
                  rst_state   <= DONE_S;
                  waitCnt <= (others => '0');
               end if;
            when DONE_S     =>
               bufRCLR_i  <= '0';
               bufRCE_i   <= '1';
            when others     =>
               rst_state  <= IDLE_S;
         end case;
      end if;
   end process;
   bufRCLR <= bufRCLR_i;
   bufRCE  <= bufRCE_i;
   -------------------------------------------------------------------------
   



end Behavioral;


