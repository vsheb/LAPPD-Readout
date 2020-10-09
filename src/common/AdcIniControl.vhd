library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
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
   signal iRstDivClk          : std_logic;

   signal iAdcTxTrig          : std_logic := '0';
   signal adcTxTrigR          : std_logic := '0';
   signal adcTxTrigRCopy      : std_logic := '0';
   signal iTxTrgEdge          : std_logic := '0';
   signal localTxTrg          : std_logic := '0';
   signal txTrgCnt            : std_logic_vector(2 downto 0)  := (others => '0');
   signal localAdcReset       : std_logic := '0';
   signal adcResetCnt         : std_logic_vector(3 downto 0)  := (others => '0');
   signal adcSyncCnt          : std_logic_vector(1 downto 0) := (others => '0');

   signal bufRCE_i            : std_logic := '1';
   signal bufRCLR_i           : std_logic := '0';
   signal waitCnt             : std_logic_vector(3 downto 0) := (others => '0');

   type   rstSeqStatesType   is (  IDLE_S, 
                                   OUT_DIS_S, 
                                   BUFR_CLR_S,
                                   OUT_ENA_S,
                                   DONE_S );
   signal rst_state    : rstSeqStatesType := IDLE_S;
   
   attribute IOB : string;                               
   attribute IOB of adcTxTrigR         : signal is "TRUE";

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
      end if;
   end process;

   -------------------------------------------------------------------------
   -------------------------------------------------------------------------
   EdgeDetTxTrg_U : entity work.EdgeDetector 
   port map (
      clk    => sysClk,
      rst    => '0',
      input  => txTrigCmd,
      output => iTxTrgEdge
   );
   process (sysClk)
   begin
      if rising_edge (sysClk) then
         if iTxTrgEdge = '1' then
            localTxTrg <= '1';
         end if;
         if localTxTrg = '1' and adcConvClkR = '1' then
            iAdcTxTrig <= '1';
         end if;
         if iAdcTxTrig = '1' and adcConvClkR = '1' then
            localTxTrg <= '0';
            iAdcTxTrig <= '0';
         end if;
      end if;
   end process;

   FDRE_TxTrig : FDRE
   generic map (   
      INIT => '0'
   )  
   port map (   
      Q  => adcTxTrigR,
      C  => sysClk,
      CE => '1',
      R  => '0',
      D  => iAdcTxTrig
   );
   adcTxTrig <= adcTxTrigR;

   process (sysClk)
   begin
      if rising_edge (sysClk) then
         adcTxTrigRCopy <= iAdcTxTrig;
         if adcTxTrigRCopy = '1' and adcConvClkR = '1' then
            adcSyncCnt <=  (others => '0');
         else
            adcSyncCnt <= adcSyncCnt + 1;
         end if;
         if adcSyncCnt = b"11" then
            adcSync <= '1';
         else
            adcSync <= '0';
         end if;
      end if;
   end process;



   -- generate RESET signal 
   process(sysClk) 
   begin
      if rising_edge(sysClk) then
         if adcResetCmd = '1' then
            localAdcReset <= '1';
            adcResetCnt <= (others => '1');
         end if;
         if localAdcReset = '1' then
            adcResetCnt <= adcResetCnt - '1';
         end if;
         if adcResetCnt = b"000" then
            localAdcReset <= '0';
         end if;
      end if;
      
   end process;
   
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


