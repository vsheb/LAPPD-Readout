library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.UtilityPkg.all;
library UNISIM;
use UNISIM.VComponents.all;

entity GtpA7Wrapper is
   port ( 
      -- Direct GT connections
      gtTxP           : out sl;
      gtTxN           : out sl;
      gtRxP           : in  sl;
      gtRxN           : in  sl;
      gtClkP          : in  sl;
      gtClkN          : in  sl;
      -- Clocks out
      txUserClkOut    : out sl;
      ethClk125       : out sl;
      clkGteDiv2Out   : out sl;
      -- Resets in
      resetIn         : in  sl;
      linkSynced      : in  sl;
      -- Resets are done
      txFsmResetDoneOut : out sl;
      rxFsmResetDoneOut : out sl;
      rxResetDoneOut    : out sl;
      txResetDoneOut    : out sl;
      -- PLL is locked
      gtPllLock         : out sl;
      -- RX data interfaces
      rxDataOut         : out slv(15 downto 0);
      rxCharIsK         : out slv(1 downto 0);
      -- RX error detection
      rxDispErr         : out slv(1 downto 0);
      rxNotInTable      : out slv(1 downto 0);
      rxByteAligned     : out sl;
      -- TX data interfaces
      txDataIn          : in  slv(15 downto 0);
      txCharIsK         : in  slv(1 downto 0)
   );
end GtpA7Wrapper;

architecture Behavioral of GtpA7Wrapper is

   -- IP Core (Transceiver Wizard)
   component GtpA7GbE
      port (
         SOFT_RESET_TX_IN                        : in   std_logic;
         SOFT_RESET_RX_IN                        : in   std_logic;
         DONT_RESET_ON_DATA_ERROR_IN             : in   std_logic;
         Q0_CLK0_GTREFCLK_PAD_N_IN               : in   std_logic;
         Q0_CLK0_GTREFCLK_PAD_P_IN               : in   std_logic;
   
         GT0_TX_FSM_RESET_DONE_OUT               : out  std_logic;
         GT0_RX_FSM_RESET_DONE_OUT               : out  std_logic;
         GT0_DATA_VALID_IN                       : in   std_logic;
         --GT0_TX_MMCM_LOCK_OUT                    : out  std_logic;
         --GT0_RX_MMCM_LOCK_OUT                    : out  std_logic;
    
          GT0_TXUSRCLK_OUT                        : out  std_logic;
          GT0_TXUSRCLK2_OUT                       : out  std_logic;
          GT0_RXUSRCLK_OUT                        : out  std_logic;
          GT0_RXUSRCLK2_OUT                       : out  std_logic;
   
          --_________________________________________________________________________
          --GT0  (X0Y0)
          --____________________________CHANNEL PORTS________________________________
          ---------------------------- Channel - DRP Ports  --------------------------
          gt0_drpaddr_in                          : in   std_logic_vector(8 downto 0);
          gt0_drpdi_in                            : in   std_logic_vector(15 downto 0);
          gt0_drpdo_out                           : out  std_logic_vector(15 downto 0);
          gt0_drpen_in                            : in   std_logic;
          gt0_drprdy_out                          : out  std_logic;
          gt0_drpwe_in                            : in   std_logic;
          ------------------------------- Loopback Ports -----------------------------
          gt0_loopback_in                         : in   std_logic_vector(2 downto 0);
          ------------------------------ Power-Down Ports ----------------------------
          gt0_rxpd_in                             : in   std_logic_vector(1 downto 0);
          gt0_txpd_in                             : in   std_logic_vector(1 downto 0);
          --------------------- RX Initialization and Reset Ports --------------------
          gt0_eyescanreset_in                     : in   std_logic;
          gt0_rxuserrdy_in                        : in   std_logic;
          -------------------------- RX Margin Analysis Ports ------------------------
          gt0_eyescandataerror_out                : out  std_logic;
          gt0_eyescantrigger_in                   : in   std_logic;
          ------------------------- Receive Ports - CDR Ports ------------------------
          gt0_rxcdrhold_in                        : in   std_logic;
          ------------------- Receive Ports - Clock Correction Ports -----------------
          gt0_rxclkcorcnt_out                     : out  std_logic_vector(1 downto 0);
          ------------------ Receive Ports - FPGA RX Interface Ports -----------------
          gt0_rxdata_out                          : out  std_logic_vector(15 downto 0);
          ------------------- Receive Ports - Pattern Checker Ports ------------------
          gt0_rxprbserr_out                       : out  std_logic;
          gt0_rxprbssel_in                        : in   std_logic_vector(2 downto 0);
          ------------------- Receive Ports - Pattern Checker ports ------------------
          gt0_rxprbscntreset_in                   : in   std_logic;
          ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
          gt0_rxchariscomma_out                   : out  std_logic_vector(1 downto 0);
          gt0_rxcharisk_out                       : out  std_logic_vector(1 downto 0);
          gt0_rxdisperr_out                       : out  std_logic_vector(1 downto 0);
          gt0_rxnotintable_out                    : out  std_logic_vector(1 downto 0);
          ------------------------ Receive Ports - RX AFE Ports ----------------------
          gt0_gtprxn_in                           : in   std_logic;
          gt0_gtprxp_in                           : in   std_logic;
          ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
          gt0_rxbufreset_in                       : in   std_logic;
          gt0_rxbufstatus_out                     : out  std_logic_vector(2 downto 0);
          -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
          gt0_rxbyteisaligned_out                 : out  std_logic;
          gt0_rxbyterealign_out                   : out  std_logic;
          gt0_rxcommadet_out                      : out  std_logic;
          gt0_rxmcommaalignen_in                  : in   std_logic;
          gt0_rxpcommaalignen_in                  : in   std_logic;
          ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
          gt0_dmonitorout_out                     : out  std_logic_vector(14 downto 0);
          -------------------- Receive Ports - RX Equailizer Ports -------------------
          gt0_rxlpmhfhold_in                      : in   std_logic;
          --gt0_rxlpmhfovrden_in                    : in   std_logic;
          gt0_rxlpmlfhold_in                      : in   std_logic;
          --------------- Receive Ports - RX Fabric Output Control Ports -------------
          gt0_rxoutclkfabric_out                  : out  std_logic;
          ------------- Receive Ports - RX Initialization and Reset Ports ------------
          gt0_gtrxreset_in                        : in   std_logic;
          gt0_rxlpmreset_in                       : in   std_logic;
          gt0_rxpcsreset_in                       : in   std_logic;
          gt0_rxpmareset_in                       : in   std_logic;
          ----------------- Receive Ports - RX Polarity Control Ports ----------------
          gt0_rxpolarity_in                       : in   std_logic;
          -------------- Receive Ports -RX Initialization and Reset Ports ------------
          gt0_rxresetdone_out                     : out  std_logic;
          ------------------------ TX Configurable Driver Ports ----------------------
          gt0_txpostcursor_in                     : in   std_logic_vector(4 downto 0);
          gt0_txprecursor_in                      : in   std_logic_vector(4 downto 0);
          --------------------- TX Initialization and Reset Ports --------------------
          gt0_gttxreset_in                        : in   std_logic;
          gt0_txuserrdy_in                        : in   std_logic;
          ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
          gt0_txdata_in                           : in   std_logic_vector(15 downto 0);
          --------------------- Transmit Ports - PCI Express Ports -------------------
          gt0_txelecidle_in                       : in   std_logic;
          ------------------ Transmit Ports - Pattern Generator Ports ----------------
          gt0_txprbsforceerr_in                   : in   std_logic;
          ------------------ Transmit Ports - TX 8B/10B Encoder Ports ----------------
          gt0_txchardispmode_in                   : in   std_logic_vector(1 downto 0);
          gt0_txchardispval_in                    : in   std_logic_vector(1 downto 0);
          gt0_txcharisk_in                        : in   std_logic_vector(1 downto 0);
          ---------------------- Transmit Ports - TX Buffer Ports --------------------
          gt0_txbufstatus_out                     : out  std_logic_vector(1 downto 0);
          --------------- Transmit Ports - TX Configurable Driver Ports --------------
          gt0_gtptxn_out                          : out  std_logic;
          gt0_gtptxp_out                          : out  std_logic;
          gt0_txdiffctrl_in                       : in   std_logic_vector(3 downto 0);
          gt0_txinhibit_in                        : in   std_logic;
          ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
          gt0_txoutclkfabric_out                  : out  std_logic;
          gt0_txoutclkpcs_out                     : out  std_logic;
          ------------- Transmit Ports - TX Initialization and Reset Ports -----------
          gt0_txpcsreset_in                       : in   std_logic;
          gt0_txpmareset_in                       : in   std_logic;
          gt0_txresetdone_out                     : out  std_logic;
          ----------------- Transmit Ports - TX Polarity Control Ports ---------------
          gt0_txpolarity_in                       : in   std_logic;
          ------------------ Transmit Ports - pattern Generator Ports ----------------
          gt0_txprbssel_in                        : in   std_logic_vector(2 downto 0);
      
          --____________________________COMMON PORTS________________________________
         GT0_PLL0RESET_OUT      : out std_logic;
         GT0_PLL0OUTCLK_OUT     : out std_logic;
         GT0_PLL0OUTREFCLK_OUT  : out std_logic;
         GT0_PLL0LOCK_OUT       : out std_logic;
         GT0_PLL0REFCLKLOST_OUT : out std_logic;    
         GT0_PLL1OUTCLK_OUT     : out std_logic;
         GT0_PLL1OUTREFCLK_OUT  : out std_logic;
  
         sysclk_in              : in   std_logic
      );
   end component;

   -- Clocking wizard
   component clk_wiz_0
      port (
         clk125  : out std_logic;
         reset   : in  std_logic;
         locked  : out std_logic;
         clk_in1 : in  std_logic
    );
   end component;

   component clk_wiz_1
   port (
      -- Clock in ports
      -- Clock out ports
      clk100 : out std_logic;
      -- Status and control signals
      locked : out std_logic;
      clk156 : in  std_logic
   );
   end component;

   --signal txMmcmLockOut : sl;
   --signal rxMmcmLockOut : sl;
   
   signal txOutClkFabric : sl;
   signal rxBufStatus    : slv(2 downto 0);
   signal txBufStatus    : slv(1 downto 0);
   
   signal iRxByteAligned : sl;
   signal iRxByteRealign : sl;

   signal iTxUserClkOut     : sl;
   signal iTxUserClkOutBufg : sl;

   signal clkGteDiv2     : sl;
   signal clkGteDiv2Bufg : sl;

   signal iRxDataOut  : slv(15 downto 0);
   signal iRxCharIsK  : slv( 1 downto 0);
   signal iRxCommaDet : sl;

   signal iGtPllLock  : sl;
   
   signal doReset     : sl;

   signal tryLinkReset : sl;

   attribute dont_touch : string;
   attribute dont_touch of iRxByteAligned : signal is "true";
   attribute dont_touch of iRxByteRealign : signal is "true";  
   attribute dont_touch of iRxDataOut     : signal is "true";
   attribute dont_touch of iRxCharIsK     : signal is "true";
   attribute dont_touch of iRxCommaDet    : signal is "true";
   

begin

   rxByteAligned <= iRxByteAligned;
   clkGteDiv2Out <= clkGteDiv2Bufg;
   txUserClkOut  <= iTxUserClkOutBufg;
   rxDataOut     <= iRxDataOut;
   rxCharIsK     <= iRxCharIsK;
   gtPllLock     <= iGtPllLock;

   U_GtpA7GbE : GtpA7GbE
      port map (
         SOFT_RESET_TX_IN            => '0',
         SOFT_RESET_RX_IN            => doReset,
         DONT_RESET_ON_DATA_ERROR_IN => '0',
         Q0_CLK0_GTREFCLK_PAD_N_IN   => gtClkN,
         Q0_CLK0_GTREFCLK_PAD_P_IN   => gtClkP,
   
         GT0_TX_FSM_RESET_DONE_OUT   => txFsmResetDoneOut,
         GT0_RX_FSM_RESET_DONE_OUT   => rxFsmResetDoneOut,
         GT0_DATA_VALID_IN           => iRxByteAligned,
         --GT0_TX_MMCM_LOCK_OUT        => txMmcmLockOut,
         --GT0_RX_MMCM_LOCK_OUT        => rxMmcmLockOut,
    
         GT0_TXUSRCLK_OUT            => iTxUserClkOut,
         GT0_TXUSRCLK2_OUT           => open,
         GT0_RXUSRCLK_OUT            => open,
         GT0_RXUSRCLK2_OUT           => open,
   
         --_________________________________________________________________________
         --GT0  (X0Y0)
         --____________________________CHANNEL PORTS________________________________
         ---------------------------- Channel - DRP Ports  --------------------------
         gt0_drpaddr_in                  =>      (others => '0'),
         gt0_drpdi_in                    =>      (others => '0'),
         gt0_drpdo_out                   =>      open,
         gt0_drpen_in                    =>      '0',
         gt0_drprdy_out                  =>      open,
         gt0_drpwe_in                    =>      '0',
         ------------------------------- Loopback Ports -----------------------------
         gt0_loopback_in                 =>      "000",
         ------------------------------ Power-Down Ports ----------------------------
         gt0_rxpd_in                     =>      "00",
         gt0_txpd_in                     =>      "00",
         --------------------- RX Initialization and Reset Ports --------------------
         gt0_eyescanreset_in             =>      '0',
         gt0_rxuserrdy_in                =>      '1',
         -------------------------- RX Margin Analysis Ports ------------------------
         gt0_eyescandataerror_out        =>      open,
         gt0_eyescantrigger_in           =>      '0',
         ------------------------- Receive Ports - CDR Ports ------------------------
         gt0_rxcdrhold_in                =>      '0',
         ------------------- Receive Ports - Clock Correction Ports -----------------
         gt0_rxclkcorcnt_out             =>      open,
         ------------------ Receive Ports - FPGA RX Interface Ports -----------------
         gt0_rxdata_out                  =>      iRxDataOut,
         ------------------- Receive Ports - Pattern Checker Ports ------------------
         gt0_rxprbserr_out               =>      open,
         gt0_rxprbssel_in                =>      "000",
         ------------------- Receive Ports - Pattern Checker ports ------------------
         gt0_rxprbscntreset_in           =>      '0',
         ------------------ Receive Ports - RX 8B/10B Decoder Ports -----------------
         gt0_rxchariscomma_out           =>      open,
         gt0_rxcharisk_out               =>      iRxCharIsK,
         gt0_rxdisperr_out               =>      rxDispErr,
         gt0_rxnotintable_out            =>      rxNotInTable,
         ------------------------ Receive Ports - RX AFE Ports ----------------------
         gt0_gtprxn_in                   =>      gtRxN,
         gt0_gtprxp_in                   =>      gtRxP,
         ------------------- Receive Ports - RX Buffer Bypass Ports -----------------
         gt0_rxbufreset_in               =>      '0',
         gt0_rxbufstatus_out             =>      rxBufStatus,
         -------------- Receive Ports - RX Byte and Word Alignment Ports ------------
         gt0_rxbyteisaligned_out         =>      iRxByteAligned,
         gt0_rxbyterealign_out           =>      iRxByteRealign,
         gt0_rxcommadet_out              =>      iRxCommaDet,
         gt0_rxmcommaalignen_in          =>      not(iRxByteAligned),
         gt0_rxpcommaalignen_in          =>      not(iRxByteAligned),
         ------------ Receive Ports - RX Decision Feedback Equalizer(DFE) -----------
         gt0_dmonitorout_out             =>      open,
         -------------------- Receive Ports - RX Equailizer Ports -------------------
         gt0_rxlpmhfhold_in              =>      '0',
         -- gt0_rxlpmhfovrden_in            =>      '0',
         gt0_rxlpmlfhold_in              =>      '0',
         --------------- Receive Ports - RX Fabric Output Control Ports -------------
         gt0_rxoutclkfabric_out          =>      open,
         ------------- Receive Ports - RX Initialization and Reset Ports ------------
         gt0_gtrxreset_in                =>      '0',
         gt0_rxlpmreset_in               =>      '0',
         gt0_rxpcsreset_in               =>      '0',
         gt0_rxpmareset_in               =>      '0',
         ----------------- Receive Ports - RX Polarity Control Ports ----------------
         gt0_rxpolarity_in               =>      '0',
         -------------- Receive Ports -RX Initialization and Reset Ports ------------
         gt0_rxresetdone_out             =>      rxResetDoneOut,
         ------------------------ TX Configurable Driver Ports ----------------------
         gt0_txpostcursor_in             =>      "00000",
         gt0_txprecursor_in              =>      "00000",
         --------------------- TX Initialization and Reset Ports --------------------
         gt0_gttxreset_in                =>      '0',
         gt0_txuserrdy_in                =>      '1',
         ------------------ Transmit Ports - FPGA TX Interface Ports ----------------
         gt0_txdata_in                   =>      txDataIn,
         --------------------- Transmit Ports - PCI Express Ports -------------------
         gt0_txelecidle_in               =>      '0',
         ------------------ Transmit Ports - Pattern Generator Ports ----------------
         gt0_txprbsforceerr_in           =>      '0',
         ------------------ Transmit Ports - TX 8B/10B Encoder Ports ----------------
         gt0_txchardispmode_in           =>      "00",
         gt0_txchardispval_in            =>      "00",
         gt0_txcharisk_in                =>      txCharIsK,
         ---------------------- Transmit Ports - TX Buffer Ports --------------------
         gt0_txbufstatus_out             =>      txBufStatus,
         --------------- Transmit Ports - TX Configurable Driver Ports --------------
         gt0_gtptxn_out                  =>      gtTxN,
         gt0_gtptxp_out                  =>      gtTxP,
         gt0_txdiffctrl_in               =>      "0000",
         gt0_txinhibit_in                =>      '0',
         ----------- Transmit Ports - TX Fabric Clock Output Control Ports ----------
         gt0_txoutclkfabric_out          =>      txOutClkFabric,
         gt0_txoutclkpcs_out             =>      open,
         ------------- Transmit Ports - TX Initialization and Reset Ports -----------
         gt0_txpcsreset_in               =>      '0',
         gt0_txpmareset_in               =>      '0',
         gt0_txresetdone_out             =>      txResetDoneOut,
         ----------------- Transmit Ports - TX Polarity Control Ports ---------------
         gt0_txpolarity_in               =>      '0',
         ------------------ Transmit Ports - pattern Generator Ports ----------------
         gt0_txprbssel_in                =>      "000",

         --____________________________COMMON PORTS________________________________
         GT0_PLL0RESET_OUT      => open,
         GT0_PLL0OUTCLK_OUT     => open,
         GT0_PLL0OUTREFCLK_OUT  => open,
         GT0_PLL0LOCK_OUT       => iGtPllLock,
         GT0_PLL0REFCLKLOST_OUT => open,  -- Can't use this if we want to use BUF_GTE2    
         GT0_PLL1OUTCLK_OUT     => open,
         GT0_PLL1OUTREFCLK_OUT  => open,
         sysclk_in              => clkGteDiv2Bufg
   );

   U_ClkWizard : clk_wiz_1
      port map ( 
     -- Clock out ports  
      clk100 => clkGteDiv2Bufg,
     -- Status and control signals                
      locked => open,
      -- Clock in ports
      clk156 => txOutClkFabric
    );

   U_BUFG_TXUSER : BUFG
      port map (
         I => iTxUserClkOut,
         O => iTxUserClkOutBufg
      );

   U_ClkWiz : clk_wiz_0
      port map ( 
     -- Clock out ports  
      clk125  => ethClk125,
     -- Status and control signals                
      reset   => '0',
      locked  => open,
      -- Clock in ports
      clk_in1 => iTxUserClkOutBufG
    );
      
   -- Synchronize linkSynced to clkGteDiv2Bufg clock domain
   U_SyncBit : entity work.SyncBit 
      port map ( 
             -- Clock and reset
             clk         => clkGteDiv2Bufg,
             rst         => '0',
             -- Incoming bit, asynchronous
             asyncBit    => linkSynced or not(iGtPllLock),
             -- Outgoing bit, synced to clk
             syncBit     => tryLinkReset
      );
      
   -- Simple watchdog timer
   process(clkGteDiv2Bufg) 
      variable watchdogCount : integer := 10000000;
   begin
      if rising_edge(clkGteDiv2Bufg) then
         doReset <= '0';
         --if linkSynced = '1' or iGtPllLock = '0' then
         if tryLinkReset = '1' then
            watchdogCount := 10000000;
         else 
            if watchdogCount = 0 then
               doReset <= '1';
               watchdogCount := 10000000;
            else
               watchdogCount := watchdogCount - 1;
            end if;
         end if;
      end if;
   end process;

end Behavioral;
