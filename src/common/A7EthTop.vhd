library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
--use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use work.Eth1000BaseXPkg.all;
use work.GigabitEthPkg.all;

library UNISIM;
use UNISIM.VComponents.all;

entity A7EthTop is
   generic (
      GATE_DELAY_G    : time    := 1 ns
   );
   port ( 
      -- Direct GT connections
      gtTxP           : out sl;
      gtTxN           : out sl;
      gtRxP           :  in sl;
      gtRxN           :  in sl;
      gtClkP          :  in sl;
      gtClkN          :  in sl;
      -- SFP transceiver disable pin
      txDisable       : out sl;
      -- Clocks out from Ethernet core
      ethUsrClk62     : out sl;
      ethUsrClk125    : out sl;
      -- Status and diagnostics out
      ethSync         : out  sl;
      ethReady        : out  sl;
      led             : out  slv(15 downto 0);
      -- User data paths in and out, including clocks and reset
      userClk         : in  sl;
      userRstIn       : in  sl;
      userRstOut      : out sl;
      -- TX data is sent out on userClk domain
      userTxData      : in  slv(7 downto 0);
      userTxDataValid : in  sl;
      userTxDataLast  : in  sl;
      userTxDataReady : out sl;
      -- RX data comes in on clk125 domain
      userRxData      : out slv(7 downto 0);
      userRxDataValid : out sl;
      userRxDataLast  : out sl;
      userRxDataReady : in  sl
   );
end A7EthTop;

architecture Behavioral of A7EthTop is

   signal firstClk     : sl;
   signal firstClkRst  : sl;

   signal gtClk        : sl;
   signal ethClk62     : sl;
   signal ethClk62Rst  : sl;
   signal ethClk125    : sl;
   signal ethClk125Rst : sl;

   signal dcmClkValid    : sl;
   signal dcmSpLocked    : sl;
   signal usrClkValid    : sl;
   signal usrClkLocked   : sl;
   signal pllLock0       : sl;
   signal gtpResetDone0  : sl;
   signal rxResetDone    : sl;
   signal txResetDone    : sl;
   signal rxFsmResetDone : sl;
   signal txFsmResetDone : sl;
   
   signal gtpReset0     : sl;
   signal gtpReset1     : sl;
   signal txReset0      : sl;
   signal txReset1      : sl;
   signal rxReset0      : sl;
   signal rxReset1      : sl;
   signal rxBufReset0   : sl;
   signal rxBufReset1   : sl;

   signal rxBufStatus0  : slv(2 downto 0);
   signal rxBufStatus1  : slv(2 downto 0);
   signal txBufStatus0  : slv(1 downto 0);
   signal txBufStatus1  : slv(1 downto 0);
   signal rxBufError0   : sl;
   signal rxBufError1   : sl;

   signal rxByteAligned0   : sl;
   signal rxByteAligned1   : sl;
   signal rxEnMCommaAlign0 : sl;
   signal rxEnMCommaAlign1 : sl;
   signal rxEnPCommaAlign0 : sl;
   signal rxEnPCommaAlign1 : sl;

   signal ethRxLinkSync  : sl;
   signal ethAutoNegDone : sl;

   signal phyRxLaneIn    : EthRxPhyLaneInType;
   signal phyTxLaneOut   : EthTxPhyLaneOutType;
   
   signal tpData      : slv(31 downto 0);
   signal tpDataValid : sl;
   signal tpDataLast  : sl;
   signal tpDataReady : sl;

   signal userRst     : sl;
   
   signal gte2Clk     : sl;
   signal gte2ClkRst  : sl;

   signal macTxData   : EthMacDataType;
   signal macRxData   : EthMacDataType;

   signal macBadCrcCount : slv(15 downto 0);

   attribute dont_touch : string;
   attribute dont_touch of rxFsmResetDone : signal is "true";
   attribute dont_touch of txFsmResetDone : signal is "true";  
   attribute dont_touch of rxResetDone : signal is "true";
   attribute dont_touch of txResetDone : signal is "true";
   attribute dont_touch of macBadCrcCount : signal is "true";
   
begin

   txDisable         <= '0';
   ethSync           <= ethRxLinkSync;
   ethReady          <= ethAutoNegDone;
   
   -- KC 9/17/18
   -- I guess this means tie my particular signals into these ports declared in "entity"
   -- port declared in entity <= signal declared in Architecture/Behaviorial 
   
   ethUsrClk62       <= ethClk62;
   ethUsrClk125      <= ethClk125;
   userRstOut        <= userRst;
   
   led(0)            <= dcmSpLocked;
   led(1)            <= dcmClkValid;
   led(2)            <= not(gtpReset0);
   led(3)            <= gtpResetDone0;
   led(4)            <= pllLock0;
   led(5)            <= usrClkLocked;
   led(6)            <= usrClkValid;
   led(7)            <= ethRxLinkSync;
   led(8)            <= ethAutoNegDone;
   led(9)            <= not(ethClk62Rst);
   led(10)           <= not(ethClk125Rst);
   led(15 downto 11) <= (others => '1');

    -- KC 9/17/18
    -- Now it seems like we have some nested entities...
   U_GtpA7Wrapper : entity work.GtpA7Wrapper
      port map (
         -- Direct GT connections
         gtTxP             => gtTxP,
         gtTxN             => gtTxN,
         gtRxP             => gtRxP,
         gtRxN             => gtRxN,
         gtClkP            => gtClkP,
         gtClkN            => gtClkN,
         -- Clocks out
         txUserClkOut      => ethClk62,  --: out sl;
         ethClk125         => ethClk125, --: out sl;
         clkGteDiv2Out     => gte2Clk,   --: out sl;
         -- Resets in
         resetIn           => ethClk62Rst,   --:  in sl;
         linkSynced        => ethRxLinkSync, --:  in sl;
         -- Resets are done
         txFsmResetDoneOut => txFsmResetDone, --: out sl;
         rxFsmResetDoneOut => rxFsmResetDone, --: out sl;
         rxResetDoneOut    => rxResetDone,    --: out sl;
         txResetDoneOut    => txResetDone,    --: out sl;
         -- PLL is locked
         gtPllLock         => pllLock0, --: out sl;
         -- RX data interfaces
         rxDataOut         => phyRxLaneIn.data,  --: out slv(15 downto 0);
         rxCharIsK         => phyRxLaneIn.dataK, --: out slv(1 downto 0);
         -- RX error detection
         rxDispErr         => phyRxLaneIn.dispErr, --: out slv(1 downto 0);
         rxNotInTable      => phyRxLaneIn.decErr,  --: out slv(1 downto 0);
         rxByteAligned     => rxByteAligned0,      --: out sl;
         -- TX data interfaces
         txDataIn          => phyTxLaneOut.data, --: in  slv(15 downto 0);
         txCharIsK         => phyTxLaneOut.dataK --: in  slv(1 downto 0)
   );

   --------------------------------------------------------------------------
   -- Gigabit Ethernet 1000-BaseX Link (Synchronization + Autonegotiation) --
   --------------------------------------------------------------------------
   U_Eth1000BaseXCore : entity work.Eth1000BaseXCore
      generic map (
         EN_AUTONEG_G    => true,
         GATE_DELAY_G    => GATE_DELAY_G
      )
      port map ( 
         -- 125 MHz clock and reset
         eth125Clk          => ethClk125,
         eth125Rst          => ethClk125Rst,
         -- 62 MHz clock and reset
         eth62Clk           => ethClk62,
         eth62Rst           => ethClk62Rst,
         -- Data to/from GT
         phyRxData          => phyRxLaneIn,
         phyTxData          => phyTxLaneOut,
         -- Status signals
         statusSync         => ethRxLinkSync,
         statusAutoNeg      => ethAutoNegDone,
         -- MAC TX/RX data (125 MHz clock domain)
         macTxData          => macTxData,
         macRxData          => macRxData
      );

   ------------------------
   -- MAC Layer, RX data --
   ------------------------
   U_MacRx : entity work.Eth1000BaseXMacRx  
      generic map (
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map ( 
         -- 125 MHz ethernet clock in
         ethRxClk       => ethClk125,       --: in sl;
         ethRxRst       => ethClk125Rst,    --: in sl := '0';
         -- Incoming data from the 16-to-8 mux
         macDataIn      => macRxData,       --: in EthMacDataType;
         -- Outgoing bytes and flags to the applications
         macRxData      => userRxData,      --: out slv(7 downto 0);
         macRxDataValid => userRxDataValid, --: out sl;
         macRxDataLast  => userRxDataLast,  --: out sl;
         macRxBadFrame  => open,            --: out sl;
         -- Monitoring flags
         macBadCrcCount => macBadCrcCount   --: out slv(15 downto 0)
      ); 
   ------------------------
   -- MAC Layer, TX data --
   ------------------------
   U_MacTx : entity work.Eth1000BaseXMacTx 
      generic map (
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map ( 
         -- 125 MHz ethernet clock in
         ethTxClk         => ethClk125,       --: in  sl;
         ethTxRst         => ethClk125Rst,    --: in  sl := '0';
         -- User data to be sent
         userDataIn       => userTxData,      --: in  slv(7 downto 0);
         userDataValid    => userTxDataValid, --: in  sl;
         userDataLastByte => userTxDataLast,  --: in  sl;
         userDataReady    => userTxDataReady, --: out sl;
         -- Data out to the GTX
         macDataOut       => macTxData        --: out EthMacDataType
      ); 
      
   ---------------------------------------------------------------------------
   -- Resets
   ---------------------------------------------------------------------------
   -- Generate stable reset signal
   U_PwrUpRst : entity work.InitRst
      generic map (
         RST_CNT_G    => 7812500,
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map (
         clk     => gte2Clk,
         syncRst => gte2ClkRst
      );
   -- Synchronize the reset to the 125 MHz domain
   U_RstSync125 : entity work.SyncBit
      generic map (
         INIT_STATE_G    => '1',
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map (
         clk      => ethClk125,
         rst      => '0',
         asyncBit => gte2ClkRst,
         syncBit  => ethClk125Rst
      );
   -- Synchronize the reset to the 62 MHz domain
   U_RstSync62 : entity work.SyncBit
      generic map (
         INIT_STATE_G    => '1',
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map (
         clk      => ethClk62,
         rst      => '0',
         asyncBit => gte2ClkRst,
         syncBit  => ethClk62Rst
      );
   -- User reset
   U_RstSyncUser : entity work.SyncBit
      generic map (
         INIT_STATE_G    => '1',
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map (
         clk      => userClk,
         rst      => '0',
         asyncBit => ethClk62Rst or not(ethAutoNegDone) or userRstIn,
         syncBit  => userRst
      );

         
end Behavioral;