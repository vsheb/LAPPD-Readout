library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

library UNISIM;
   use UNISIM.Vcomponents.all;

library work;
   use work.UtilityPkg.all;
   use work.LappdPkg.all;
   use work.Eth1000BaseXPkg.all;
   use work.GigabitEthPkg.all;
   use work.RegDefs.all;

entity A22 is
   generic (
      REG_ADDR_BITS_G : integer := 16;
      REG_DATA_BITS_G : integer := 16;
      NUM_IP_G        : integer := 2;
      GATE_DELAY_G    : time    := 1 ns   
   );
   port ( 
      -- Direct GT connections
      gtTxP        : out sl;
      gtTxN        : out sl;
      gtRxP        :  in sl;
      gtRxN        :  in sl;
      gtClkP       :  in sl;
      gtClkN       :  in sl;
     
      -- For driving the 100Mhz oscillator enable (standby) pin
      tca_Cntl     : out sl;

      -- ADC ports
      adcDoClkP  : in slv(1 downto 0);
      adcDoClkN  : in slv(1 downto 0);
      adcFrClkP  : in slv(1 downto 0);
      adcFrClkN  : in slv(1 downto 0);
      adcDataInP : in slv(G_N_ADC_LINES*G_N_ADC_CHIPS-1 downto 0);
      adcDataInN : in slv(G_N_ADC_LINES*G_N_ADC_CHIPS-1 downto 0);
      adcClkP    : out slv(G_N_ADC_CHIPS-1 downto 0);
      adcClkN    : out slv(G_N_ADC_CHIPS-1 downto 0);
      adcPdnFast : out std_logic;
      adcPdnGlb  : out std_logic;

      -- DRS4 ports
      --drsResetN   : out std_logic; not connected in PCB
      drsDEnable  : out std_logic;                   
      drsDWrite   : out std_logic;                   
      drsSrClk    : out std_logic;                   
      drsSrIn     : out std_logic;                   
      drsAddr     : out std_logic_vector(3 downto 0);
      drsRsrLoad  : out std_logic;                   
      drsRefClkP  : out std_logic;
      drsRefClkN  : out std_logic;
      drsPllLck   : in  std_logic_vector(G_N_DRS-1 downto 0);
      drsSrOut    : in  std_logic_vector(G_N_DRS-1 downto 0);
      drsDTap     : in  std_logic_vector(G_N_DRS-1 downto 0);

      adcTxTrig  : out sl;
      adcReset   : out sl;

      extTrigIn    : in  sl;
      extTrigInDir : out sl; -- has to be tied to GND 

      extClkIn     : in  sl;
      extClkInDir  : out  sl;

      -- SPI Dac ports
      dacSclk   : out sl;
      dacCsb    : out sl;
      dacSin    : out sl;
      dacSout   : in  sl;

      -- SPI Dac ports
      adcSclk   : out sl; --v(G_N_ADC_CHIPS-1 downto 0);
      adcCsb    : out slv(G_N_ADC_CHIPS-1 downto 0);
      adcSin    : out sl;
      adcSout   : in  slv(G_N_ADC_CHIPS-1 downto 0);

      rfSwitch  : out sl

      -- These are not required for the A.20 Ultralytics board]
      -- They are requred by the Artix-7 Eval board.
      -- SFP_MGT_CLK_SEL1 : out sl;
      -- SFP_MGT_CLK_SEL0 : out sl;
      
      -- turn off the UART
      -- Extend the Top level to give me some outs
      --rs232_uart_rxd : in sl;
      --rs232_uart_txd : out sl
   );
end A22;

architecture Behavioral of A22 is

   -- clocks
   signal ethClk62          : sl;
   signal ethClk125         : sl;
   -- reset                 
   signal userRst           : sl;
   signal Rst               : sl;
                            
   -- trigger               
   signal extTrg_r          : sl;
   signal extTrg            : sl;
                            
   signal ethRxLinkSync     : sl;
   signal ethAutoNegDone    : sl;
   
   ----------------------------------------------
   -- User Data interfaces
   ----------------------------------------------
   signal userTxData        : slv(7 downto 0);
   signal userTxDataValid   : sl;
   signal userTxDataLast    : sl;
   signal userTxDataReady   : sl;
   signal userRxData        : slv(7 downto 0);
   signal userRxDataValid   : sl;
   signal userRxDataLast    : sl;
   signal userRxDataReady   : sl;
   ----------------------------------------------

   -- These were ports...
   signal txDisable         : sl;
   signal ethSync           : sl;
   signal ethReady          : sl;
   signal led               : slv(15 downto 0);

   ----------------------------------------------
   -- Registers control
   ----------------------------------------------
   signal regAddr           : slv(31 downto 0);
   signal regAddrStrb       : sl;
   signal regWrStrb         : sl;
   signal regRdStrb         : sl;
   signal regReady          : sl;
   signal regWrData         : slv(31 downto 0);
   signal regRdData         : slv(31 downto 0);
   signal regDataByteEn     : slv(3 downto 0);

   -- array of configuration registers
   signal regArrCfg         : tRegDataArray(0 to NREG-1);
   -- array of status registers
   signal regArrSta         : tRegDataArray(0 to NREG-1);
   ----------------------------------------------

   signal clkCnt            : slv(1 downto 0) := (others => '0');
   ----------------------------------------------
   -- ADC readout module signals
   ----------------------------------------------
   signal adcBufRCLR        : sl;
   signal adcBufRCE         : sl;


   type   adcDelaysArrayT  is array(0 to G_N_ADC_CHIPS-1) of Word5Array( 0 to G_N_ADC_LINES-1 );
   signal adcDataDelayArray    : adcDelaysArrayT := (others => (others => (others => '0')));
   signal adcDataValid         : slv(G_N_ADC_CHIPS-1 downto 0); 
   signal adcDataValidReg      : slv(G_N_ADC_CHIPS-1 downto 0); 
   signal adcConvClk           : sl;
   signal adcConvClkReg        : sl;
                               
   signal adcData              : AdcDataArray(0 to G_N_CHN_TOT-1);
                               
   signal iDelayRefClk         : sl  := '0';
   signal iAdcBitslipGood      : slv(G_N_ADC_CHIPS-1 downto 0)  := (others => '0');
   signal adcSync              : sl;
   ----------------------------------------------


   ----------------------------------------------
   -- Pedestal memory
   ----------------------------------------------
   signal pedSmpNumArr         : Word10Array(0 to 7);
   signal pedArr               : AdcDataArray(0 to 63) := (others => (others => '0'));
   signal pedRegReq            : sl               := '0';
   signal pedRegAddr16         : slv16            := (others => '0');
   signal pedRegAck            : sl               := '0';
   signal pedRegWrEn           : sl               := '0';
   signal pedRegWrData         : slv(G_ADC_BIT_WIDTH-1 downto 0) := (others => '0');
   signal pedRegRdData         : slv(G_ADC_BIT_WIDTH-1 downto 0) := (others => '0');





   ----------------------------------------------
   -- signals for ADC buffer
   ----------------------------------------------
   signal adcBufWrEn           : sl;
   signal adcBufReq            : sl;
   signal adcBufAck            : sl;
   --signal adcBufRdData         : slv(G_ADC_BIT_WIDTH-1 downto 0);
   signal adcBufRdData         : slv16;
   signal adcBufRdData32       : slv32;
   signal adcBufRdAddr         : slv(G_ADC_BIT_DEPTH-1 downto 0);
   signal adcBufCurAddr        : slv(G_ADC_BIT_DEPTH-1 downto 0);
   signal adcBufEthEna         : sl := '0';
   signal adcBufEthAddr        : slv(G_ADC_BIT_DEPTH-1 downto 0)           := (others => '0');
   --signal adcBufEthData        : slv(G_ADC_BIT_WIDTH-1 downto 0);
   signal adcBufEthData        : slv16;
   signal adcBufEthChan        : slv(5 downto 0);
   signal zeroThreshArr        : AdcDataArray(0 to G_N_CHN_TOT-1);
   signal adcBufThrMask        : slv64;
   ----------------------------------------------


   signal lappdCmd             : LappdCmdType;
                               
                               
   signal deviceDna            : slv(63 downto 0);

   ----------------------------------------------
   -- DRS4 signals
   ----------------------------------------------
   -- drs4 registers signals 
   signal drsRegMode           : slv(1 downto 0);
   signal drsRegData           : slv(7 downto 0);
   signal drsRegReq            : sl;
   signal drsRegAck            : sl;
                               
   -- drs4 readout signals     
   signal drsRdReq             : sl;
   signal drsRdAck             : sl;
   signal drsStopSampleArr     : Word10Array(0 to G_N_DRS-1);
   signal drsStopSampleValid   : sl;
   signal drsSampleValid       : sl; 
   signal drsCtrlBusy          : sl;
   signal drsPllLosCnt         : Word32Array(0 to 7); 
   signal drsPllLckSync        : slv(G_N_DRS-1 downto 0);
   ----------------------------------------------

   ----------------------------------------------
   -- event builder signals
   ----------------------------------------------
   signal eventBuilderTrg      : sl        := '0';
   signal evtBusy              : sl        := '0';
   signal ethEvtData           : slv(15 downto 0) := (others => '0');
   signal ethEvtTrigger        : sl        := '0';
   signal ethEvtNumberOfFrames : integer := 0;
   signal ethEvtReady          : sl        := '0';
   signal ethEvtBusy           : sl;
   ----------------------------------------------

   signal timerClkRaw          : slv64;


   ----------------------------------------------
   -- axi stream signals for output data stream
   ----------------------------------------------
   signal axiDataOut_tdata  : std_logic_vector(15 downto 0) := (others => '0');
   signal axiDataOut_tvalid : std_logic := '0';
   signal axiDataOut_tlast  : std_logic := '0';
   signal axiDataOut_tkeep  : std_logic_vector(1 downto 0) := (others => '0');
   signal axiDataOut_tready : std_logic := '0';
   ----------------------------------------------

   -- Vivado attributes to keep signals for debugging
   attribute dont_touch : string;
   attribute dont_touch of led : signal is "true";  

   signal SrcMac : std_logic_vector (47 downto 0) := (others => '0');
   signal DestMac : std_logic_vector (47 downto 0) := (others => '0');

   -- SPI ADC interface signals
   signal iAdcSClk       : sl;
   signal iAdcSout       : sl;
   

   ----------------------------------------------
   -- aliases for easy access to the configuration registers
   ----------------------------------------------
   -- MODE register
   alias a_modeAdcBufEn : sl is regArrCfg(getRegInd("MODE"))(C_MODE_ADCBUF_WREN_BIT);
   alias a_modeExtTrgEn : sl is regArrCfg(getRegInd("MODE"))(C_MODE_EXTTRG_EN_BIT);
   alias a_modeUseClkIn : sl is regArrCfg(getRegInd("MODE"))(C_MODE_CLKIN_TRG_BIT);
   alias a_modePedSubEn : sl is regArrCfg(getRegInd("MODE"))(C_MODE_PEDSUB_EN_BIT);
   alias a_modeZerSupEn : sl is regArrCfg(getRegInd("MODE"))(C_MODE_ZERSUP_EN_BIT);
   alias a_modeAdcPdnF  : sl is regArrCfg(getRegInd("MODE"))(C_MODE_ADC_PDN_F_BIT);
   alias a_modeAdcPdnG  : sl is regArrCfg(getRegInd("MODE"))(C_MODE_ADC_PDN_G_BIT);

   -- CMD register
   alias a_cmdReset      : sl is regArrCfg(getRegInd("CMD"))(C_CMD_RESET_BIT);
   alias a_cmdRunReset   : sl is regArrCfg(getRegInd("CMD"))(C_CMD_RUNRESET_BIT);
   alias a_cmdDrsRdStart : sl is regArrCfg(getRegInd("CMD"))(C_CMD_READREQ_BIT);
   alias a_cmdAdcTxTrig  : sl is regArrCfg(getRegInd("CMD"))(C_CMD_ADCTXTRG_BIT);
   alias a_cmdAdcReset   : sl is regArrCfg(getRegInd("CMD"))(C_CMD_ADCRESET_BIT);
   alias a_cmdAdcRdReset : sl is regArrCfg(getRegInd("CMD"))(C_CMD_ADCRDRESET_BIT);

   alias a_regClkRatio    : slv32 is regArrCfg(getRegInd("DRSREFCLKRATIO"));
   alias a_drsNSamples    : slv16 is regArrCfg(getRegInd("ADCBUFNUMWORDS"))(15 downto 0);
   alias a_phaseAdcSrClk  : slv(2 downto 0)  is regArrCfg(getRegInd("DRSADCPHASE"))(2 downto 0);
   
   alias a_drsDEnable     : sl    is regArrCfg(getRegInd("MODE"))(C_MODE_DRS_DENABLE_BIT);
   alias a_ebFragDisable  : sl    is regArrCfg(getRegInd("MODE"))(C_MODE_EB_FRDISABLE_BIT);
   alias a_drsStopReverse : sl    is regArrCfg(getRegInd("MODE"))(C_MODE_DRS_REVRS_BIT);

   alias a_drsIdleMode    : slv(1 downto 0) is regArrCfg(getRegInd("DRSIDLEMODE"))(1 downto 0); 

   alias a_adcDbgChan     : slv(5 downto 0)  is regArrCfg(getRegInd("ADCDEBUGCHAN"))(5 downto 0);
   alias a_nSamplInPacket : slv16  is regArrCfg(getRegInd("NSAMPLEPACKET"))(15 downto 0);
   alias a_drsValidPhase  : slv(5 downto 0)  is regArrCfg(getRegInd("DRSVALIDPHASE"))(5 downto 0);
   alias a_drsValidDelay  : slv(7 downto 0)  is regArrCfg(getRegInd("DRSVALIDDELAY"))(7 downto 0);
   alias a_drsWaitAddr    : slv16  is regArrCfg(getRegInd("DRSWAITADDR"));
   alias a_drsWaitInit    : slv16  is regArrCfg(getRegInd("DRSWAITINIT"));
   alias a_drsWaitStart   : slv16  is regArrCfg(getRegInd("DRSWAITSTART"));

   

   alias a_NBICSrcMac_L  : slv32 is regArrCfg(getRegInd("SRCMAC_LOW"));
   alias a_NBICSrcMac_H  : slv32 is regArrCfg(getRegInd("SRCMAC_HIGH"));
   alias a_NBICSrcIP     : slv32 is regArrCfg(getRegInd("SRCIP"));
   alias a_NBICSrcPort   : slv16 is regArrCfg(getRegInd("NBIC_PORTS"))(15 downto 0);

   alias a_NBICDestMac_L  : slv32 is regArrCfg(getRegInd("DESTMAC_LOW"));
   alias a_NBICDestMac_H  : slv32 is regArrCfg(getRegInd("DESTMAC_HIGH"));
   alias a_NBICDestIP     : slv32 is regArrCfg(getRegInd("DESTIP"));
   alias a_NBICDestPort   : slv16 is regArrCfg(getRegInd("NBIC_PORTS"))(31 downto 16);
   alias a_udpNumOfPorts  : slv16 is regArrCfg(getRegInd("NUDPPORTS"))(15 downto 0);

   alias a_ChanMaskAdc1   : slv32 is regArrCfg(getRegInd("ADCCHANMASK_0"));
   alias a_ChanMaskAdc2   : slv32 is regArrCfg(getRegInd("ADCCHANMASK_1"));
   ----------------------------------------------

   signal extTrigCnt   : slv32 := (others => '0');

   signal NBICDestPort   : slv16;
   signal chanMaskAdc    : slv64;

   attribute keep : string;
   attribute keep of adcDataValid    : signal is "TRUE";

begin
   
   ethSync  <= ethRxLinkSync;
   ethReady <= ethAutoNegDone;

   tca_Cntl   <= regArrCfg(getRegInd("MODE"))(C_MODE_TCA_ENA_BIT);
   rfSwitch   <= regArrCfg(getRegInd("MODE"))(C_MODE_RFSWITCH_BIT);

   extTrigInDir <= '0';

   extClkInDir <= '0';

   -- mux select on the AC701
   --SFP_MGT_CLK_SEL0 <= '0';
   --SFP_MGT_CLK_SEL1 <= '0';

   -------------------------------------
   -- uBlaze + Paradromics-style AXIS --
   -------------------------------------

   -- KC 9/17/18
   -- He seems to put everything into a work namespace, though I don't see where this namespace
   -- is defined for this project.

   -- KC 9/17/18
   -- Reconstructed Syntax:
   -- In behavioural begin
   --  our outputs <= our internal signals
   -- In entity sub blocks
   --  entity's whatever => our internal signals or ports
   --  arrow does not encode flow here, only a "physical" wiring linkage
   -- tl;dr the thing on the left of the operator refers to the immediately scoped block
   --

   U_uBlazeWrapper : entity work.base_mb_wrapper
      port map (
         -- Note stupid LR parser shit, so all <= need to preceed =>
         -- Wire the S_AXIS (slave axi stream)
         -- Drive our signals with the shit coming out from this entity
         S_AXIS_1G_tdata  => userRxData,
         S_AXIS_1G_tready => userRxDataReady,
         S_AXIS_1G_tvalid => userRxDataValid,
         S_AXIS_1G_tlast  => userRxDataLast,
         reg_tkeep        => X"F",

         -- Pins that will eventually connect elsewhere on the boad
         S_AXIS_DATAOUT_tdata  => axiDataOut_tdata,
         S_AXIS_DATAOUT_tvalid => axiDataOut_tvalid,
         S_AXIS_DATAOUT_tlast  => axiDataOut_tlast,
         S_AXIS_DATAOUT_tkeep  => axiDataOut_tkeep,
         S_AXIS_DATAOUT_tready => axiDataOut_tready,

         CLKIN_125 => ethClk125,

         -- Drive reset to zero
         reset => '0',

         -- Wire the M_AXIS (master axi stream)

         -- to the PHY with the uBlaze produced outs 
         M_AXIS_1G_tdata => userTxData,
         M_AXIS_1G_tvalid => userTxDataValid,
         M_AXIS_1G_tlast => userTxDataLast,
         M_AXIS_1G_tready => userTxDataReady,

         -- Wire in the IO port
         IO_BUS_addr_strobe => regAddrStrb,
         IO_BUS_address => regAddr,
         IO_BUS_byte_enable => regDataByteEn,
         IO_BUS_read_data => regRdData,
         IO_BUS_read_strobe => regRdStrb,
         IO_BUS_ready => regReady,
         IO_BUS_write_data => regWrData,
         IO_BUS_write_strobe => regWrStrb

         -- Wire in the bus reset
         --bus_struct_reset => bus_struct_reset                   
      );
   
   -------------------------------------
      
   --------------------------------
   -- Gigabit Ethernet Interface --
   --------------------------------
   U_A7EthTop : entity work.A7EthTop
      generic map (
         GATE_DELAY_G => GATE_DELAY_G
      )
      port map (
      
         -- KC 9/17/18
         -- This "probably" means "connect the work.A7EthTop->gtTxP pin to OUR gtTxP pin
         -- Direct GT connections
         gtTxP           => gtTxP,
         gtTxN           => gtTxN,
         gtRxP           => gtRxP,
         gtRxN           => gtRxN,
         gtClkP          => gtClkP,
         gtClkN          => gtClkN,
         -- SFP transceiver disable pin
         txDisable       => txDisable,
         -- Clocks out from Ethernet core
         ethUsrClk62     => ethClk62,
         ethUsrClk125    => ethClk125,
         -- Status and diagnostics out
         ethSync         => ethRxLinkSync,
         ethReady        => ethAutoNegDone,
         led             => led,
         -- User clock inputs
         userClk         => ethClk125,
         userRstIn       => '0',
         userRstOut      => userRst,
         -- User data interfaces
         userTxData      => userTxData,
         userTxDataValid => userTxDataValid,
         userTxDataLast  => userTxDataLast,
         userTxDataReady => userTxDataReady,
         userRxData      => userRxData,
         userRxDataValid => userRxDataValid,
         userRxDataLast  => userRxDataLast,
         userRxDataReady => userRxDataReady
      );


   -------------------------------------------------
   -- Registers Control
   -------------------------------------------------
   adcBufRdData32  <= X"0000" & adcBufRdData;
   U_RegControl : entity work.RegControl 
      port map (
         -- Clock and synchronous reset
         clk => ethClk125,
         sRst => '0', 
         --bus_struct_reset(0),
         
         -- Register interface to Microblaze IO module
         regAddr       => regAddr,
         regAddrStrb   => regAddrStrb,
         regWrStrb     => regWrStrb,
         regRdStrb     => regRdStrb,
         regReady      => regReady,
         regWrData     => regWrData,
         regRdData     => regRdData,
         regDataByteEn => regDataByteEn,

         -- registers content in/out to top
         lappdCmd      => lappdCmd,
         regArrayOut   => regArrCfg,
         regArrayIn    => regArrSta,

         timerClkRaw   => timerClkRaw,

         -- ADC buffer IO
         adcBufReq     => adcBufReq,
         adcBufAck     => adcBufAck,
         adcBufAddr    => adcBufRdAddr,
         adcBufData    => adcBufRdData32,

         -- Pedestal memory
         drsPedReq       => pedRegReq,
         drsPedAddr      => pedRegAddr16, -- chan(6b) & addr(10b)   
         drsPedAck       => pedRegAck,    
         drsPedWrEn      => pedRegWrEn,   
         drsPedWrData    => pedRegWrData, 
         drsPedRdData    => pedRegRdData,

         -- DRS regs
         drsRegMode    => drsRegMode,
         drsRegData    => drsRegData,
         drsRegReq     => drsRegReq,
         drsRegAck     => drsRegAck,

         -- DAC serial IO
         dacSclk       => dacSclk, --: out sl;
         dacCsb        => dacCsb,  --: out sl;
         dacSin        => dacSin,  -- out sl;
         dacSout       => dacSout, -- in  sl;

         -- DAC serial IO
         adcSclk       => adcSclk, --: out sl;
         adcCsb        => adcCsb,  --: out sl;
         adcSin        => adcSin,  -- out sl;
         adcSout       => iAdcSout  -- in  sl;
      );
      -- at the moment chip is selected by CSB signal
      -- now multiplexing for SCLK and SOUT just concatinate and OR
      -- FIXME ?
      --adcSclk  <= iAdcSclk;
      iAdcSout <= adcSout(0) or adcSout(1);
   -------------------------------------------------

   --------------------------------------
   -- DRS4 address/serial interface 
   --------------------------------------
   U_DrsControl : entity work.DrsControl
   generic map (
      NCHIPS                 => G_N_DRS,
      SR_CLOCK_HALF_PERIOD_G => 8 
   )
   port map ( 
      -- System clock and reset
      sysClk        => ethClk125,
      sysRst        => a_cmdReset,
      
      adcSync       => adcSync,
      refClkRatio   => a_regClkRatio, 

      -- User requests
      regMode       => drsRegMode,
      regData       => drsRegData,
      regReq        => drsRegReq,
      regAck        => drsRegAck,

      -- Perform the normal readout sequence
      readoutReq    => drsRdReq,
      readoutAck    => drsRdAck,

      nSamples      => a_drsNSamples(11 downto 0),
      
      phaseAdcSrClk => a_phaseAdcSrClk,
      stopSample    => drsStopSampleArr,
      stopSmpValid  => drsStopSampleValid,

      validDelay    => a_drsValidDelay,
      sampleValid   => drsSampleValid,
      
      validPhase    => a_drsValidPhase,
      waitAfterAddr => a_drsWaitAddr, -- debug FIXME remove
      --waitBeforeIni => a_drsWaitInit, -- debug FIXME remove
      
      idleMode      => a_drsIdleMode,
      DEnable       => a_drsDEnable,
      
      -- DRS4 address & serial interfacing
      drsRefClkN    => drsRefClkN,
      drsRefClkP    => drsRefClkP,
      drsAddr       => drsAddr,    -- out slv4
      drsSrClk      => drsSrClk,   -- out sl
      drsSrIn       => drsSrIn,    -- out sl
      drsRsrLoad    => drsRsrLoad, -- out sl
      drsSrOut      => drsSrOut,   -- in slvN
      drsDWrite     => drsDWrite,  -- sl
      drsDEnable    => drsDEnable, -- sl
      drsPllLck     => drsPllLck,   -- in slvN
      drsPllLckSync => drsPllLckSync,  
      drsPllLosCnt  => drsPllLosCnt,
      
      drsBusy       => drsCtrlBusy
   );
   -------------------------------------------------

   -------------------------------------------------
   --  Put DRS parameters to registers
   -------------------------------------------------
   DRS_STOPSAMPLE_GEN : for iDrs in  G_N_DRS-1 downto 0 generate
      process(ethClk125) 
      begin
         if rising_edge(ethClk125) then
            regArrSta(getRegInd("DRSSTOPSAMPLE_0")+iDrs)(drsStopSampleArr(iDrs)'range) <= 
                                                drsStopSampleArr(iDrs);
            regArrSta(getRegInd("DRSPLLLOSCNT_0") + iDrs) <= drsPllLosCnt(iDrs);
         end if;
      end process;
   end generate DRS_STOPSAMPLE_GEN;

   process (ethClk125)
   begin
      if rising_edge (ethClk125) then
            regArrSta(getRegInd("DRSPLLLCK"))(7  downto 0) <= drsPllLckSync;
            regArrSta(getRegInd("DRSPLLLCK"))(15 downto 8) <= drsDTap;
      end if;
   end process;
   -------------------------------------------------


   -------------------------------------------------
   -- Reference clock for IODELAYE2 modules of ADC readout
   -------------------------------------------------
   U_clk_wiz_idelay_refclk : entity work.clk_wiz_idelay_refclk
   port map(
      reset    => '0',
      clk_in1  => ethClk125,
      clk_out1 => iDelayRefClk,
      locked   => open
   );
   -------------------------------------------------

   -------------------------------------------------
   -- generate ADC conversion clock
   -------------------------------------------------
   process(ethClk125)
   begin
      if rising_edge(ethClk125) then
         clkCnt        <= clkCnt + 1;    
         adcConvClk    <= clkCnt(1);
         -- delay for one more clk cycle 
         -- because there is one extra DFF in AdcReadout for IOB packing
         adcConvClkReg <= adcConvClk; 
      end if;
   end process;
   -------------------------------------------------

   U_AdcIniControl : entity work.AdcIniControl
   port map(
      -- clocks/reset
      sysClk        => ethClk125, 
      syncRst       => a_cmdReset,

      -- adc conversion clock
      adcConvClk    => adcConvClk,

      -- external commands
      txTrigCmd     => a_cmdAdcTxTrig,
      adcResetCmd   => a_cmdAdcReset,

      -- BUFRs allignment
      bufRCLR       => adcBufRCLR,
      bufRCE        => adcBufRCE,

      -- top level ports
      adcTxTrig     => adcTxTrig,
      adcReset      => adcReset,
      
      -- output sync
      adcSync       => adcSync
   );

   -------------------------------------------------
   -- ADC readout
   -------------------------------------------------

   ADC_GEN : for iADC in 0 to 1 generate 

      U_AdcReadout : entity work.AdcReadout
      generic map (
         N_DATA_LINES        => G_N_ADC_LINES,
         ADCDOUT_INVERT_MASK => G_ADCDOUT_INVERT_MASK(iADC)
      )
      port map(
         -- clocks/reset
         sysClk        => ethClk125, 
         syncRst       => a_cmdAdcRdReset, --a_cmdReset or a_cmdAdcRdReset,
         iDelayRefClk  => iDelayRefClk,

         -- adc conversion clock
         adcConvClk    => adcConvClk,
         adcSync       => adcSync,

         bufRCLR       => adcBufRCLR,
         bufRCE        => adcBufRCE,

         bitslip       => regArrCfg(getRegInd("BITSLIP_0")+iADC)(G_N_ADC_LINES-1 downto 0),

         -- IDelay parameters
         adcFrameDelay => regArrCfg(getRegInd("ADCFRAMEDELAY_0")+iADC)(4 downto 0),
         adcDataDelay  => adcDataDelayArray(iADC),
         adcClkDelay   => regArrCfg(getRegInd("ADCCLKDELAY_0")+iADC)(4 downto 0),

         -- top level ports
         adcDoClkP     => adcDoClkP(iADC),
         adcDoClkN     => adcDoClkN(iADC),
         adcFrClkP     => adcFrClkP(iADC),
         adcFrClkN     => adcFrClkN(iADC),
         adcDataInP    => adcDataInP(G_N_ADC_LINES*(iADC+1)-1 downto G_N_ADC_LINES*iADC),
         adcDataInN    => adcDataInN(G_N_ADC_LINES*(iADC+1)-1 downto G_N_ADC_LINES*iADC),
         adcClkP       => adcClkP(iADC),
         adcClkN       => adcClkN(iADC),
         
         -- debug ports
         adcDelayDebug => open, --adcDelayDebug,
         bitslipCnt    => regArrSta(getRegInd("BITSLIPCNT_0")+iADC),
         adcFrameOut   => open, 
         bitslipGood   => iAdcBitslipGood(iADC),

         -- output data 
         adcDataOut    => adcData(G_N_ADC_CHN*iADC to G_N_ADC_CHN*(iADC+1)-1 ), 
         adcDataValid  => adcDataValid(iADC) -- out
      );
   end generate ADC_GEN;

   ADCDLY_CHIP : for i in 0 to G_N_ADC_CHIPS-1 generate  
      ADCDLY_CHN : for j in 0 to G_N_ADC_LINES-1 generate
         adcDataDelayArray(i)(j) <= 
            regArrCfg(getRegInd("ADCDATADELAY_0") + G_N_ADC_LINES*i + j)(4 downto 0);
      end generate ADCDLY_CHN;
   end generate ADCDLY_CHIP;

   regArrSta(getRegInd("STATUS"))(G_N_ADC_CHIPS-1 downto 0) <= iAdcBitslipGood;

   adcPdnFast <= a_modeAdcPdnF;
   adcPdnGlb  <= a_modeAdcPdnG;
   -------------------------------------------------


   -------------------------------------------------
   -- temporary for debugging
   -------------------------------------------------
   process(ethClk125)
      variable adc_debug_chan : integer := 0;
   begin
      if rising_edge(ethClk125) then 
         adc_debug_chan := conv_integer(a_adcDbgChan);
         regArrSta(getRegInd("ADCDEBUG1"))    <= X"00000" & adcData(adc_debug_chan);
      end if;
   end process;
   -------------------------------------------------

   -------------------------------------------------
   -- Pedestals memory
   -------------------------------------------------
   LappdPedMemory_U : entity work.LappdPedMemory
      port map (
         clk          => ethClk125,
         rst          => '0',

         smpNumArr    => pedSmpNumArr,
         pedArr       => pedArr,

         evtBusy      => evtBusy,

         regReq       => pedRegReq,
         --regChan      => (others => '0'), --pedRegAddr16(15 downto 10),   
         regChan      => pedRegAddr16(15 downto 10),   
         regAddr      => pedRegAddr16(9 downto 0),   
         regAck       => pedRegAck,    
         regWrEn      => pedRegWrEn,   
         regWrData    => pedRegWrData, 
         regRdData    => pedRegRdData(G_ADC_BIT_WIDTH-1 downto 0) 
      );
   -------------------------------------------------

   -------------------------------------------------
   -- redirect zero suppression thresholds
   -------------------------------------------------
   GEN_ZERO : for i in 0 to G_N_CHN_TOT-1 generate
      zeroThreshArr(i) <= regArrCfg(getRegInd("ZEROTHRESH_0")+i); 
   end generate GEN_ZERO;
   -------------------------------------------------

   -------------------------------------------------
   -- ADC buffer
   -------------------------------------------------
   adcBufWrEn <= (drsRdReq and drsSampleValid) or a_modeAdcBufEn;

   U_AdcBuffer : entity work.AdcBuffer
   generic map(
      ADC_CHANNELS_NUMBER => G_N_ADC_CHN,
      ADC_CHIPS_NUMBER    => G_N_ADC_CHIPS,
      ADC_DATA_WIDTH      => G_ADC_BIT_WIDTH,
      ADC_DATA_DEPTH      => G_ADC_BIT_DEPTH
   )
   port map(
      sysClk        => ethClk125, 
      sysRst        => '0', 

      -- reset write pointer to 0
      rstWrAddr     => eventBuilderTrg,

      -- enable pedestal subtraction
      pedSubOn      => a_modePedSubEn,

      -- thresholds for zero suppression
      zeroThreshArr  => zeroThreshArr,

      -- input data
      WrEnable      => adcBufWrEn,
      dataValid     => adcDataValid,
      wrData        => adcData,
      
      -- drs4 pedestals data
      pedArr           => pedArr,
      pedSmpNumArr     => pedSmpNumArr,
      drsStopSampleArr => drsStopSampleArr,
      drsStopSmpValid  => drsStopSampleValid,

      -- eth readout interface
      rdEthEnable   => adcBufEthEna,
      rdEthAddr     => adcBufEthAddr,
      rdEthChan     => adcBufEthChan,
      rdEthData     => adcBufEthData,
      
      -- reg interface
      rdChan        => a_adcDbgChan,
      rdAddr        => adcBufRdAddr,
      rdReq         => adcBufReq,
      rdAck         => adcBufAck,
      rdData        => adcBufRdData,

      hitsThrMask   => adcBufThrMask,

      -- debug      
      curAddr       => adcBufCurAddr,
      nWordsWrtn    => regArrSta(getRegInd("ADCWORDSWRITTEN"))
   );
   -------------------------------------------------

   -------------------------------------------------
   -- External trigger TODO : move into entity
   -------------------------------------------------
   process (ethClk125)
   begin
      if rising_edge (ethClk125) then
         if a_modeExtTrgEn = '1' then
            if a_modeUseClkIn = '0' then 
               extTrg_r <= extTrigIn;
            else 
               extTrg_r <= extClkIn;
            end if;
         end if;
      end if;
   end process;

   TrgEdge_U : entity work.EdgeDetector
      port map ( 
         clk    => ethClk125,
         rst    => '0',
         input  => extTrg_r,
         output => extTrg
      );
   -- count number of received external triggers
   process (ethClk125)
   begin
      if rising_edge (ethClk125) then
         if a_cmdReset = '1' then
            extTrigCnt <= (others => '0');
         else
            if extTrg = '1' then
               extTrigCnt <= extTrigCnt + 1;
            end if;
         end if;
      end if;
   end process;
   regArrSta(getRegInd("EXTTRGCNT")) <= extTrigCnt;
   -------------------------------------------------

   -------------------------------------------------
   -- Hits mask for event builder
   -------------------------------------------------
   process (ethClk125)
   begin
      if rising_edge (ethClk125) then
         if a_modeZerSupEn = '1' then 
            chanMaskAdc     <= (a_ChanMaskAdc2 & a_ChanMaskAdc1) and adcBufThrMask;
         else
            chanMaskAdc     <= a_ChanMaskAdc2 & a_ChanMaskAdc1;
         end if;
         regArrSta(getRegInd("ADCTHRESHMASK_0"))   <= adcBufThrMask(31 downto 0);
         regArrSta(getRegInd("ADCTHRESHMASK_0")+1) <= adcBufThrMask(63 downto 32);
      end if;
   end process;
   -------------------------------------------------


   -------------------------------------------------
   -- Event builder
   -------------------------------------------------
   eventBuilderTrg <= a_cmdDrsRdStart or extTrg;
   U_EventBuilder : entity work.LappdEventBuilder
      generic map(
        ADC_DATA_DEPTH     => G_ADC_BIT_DEPTH
      )
      port map (
         clk               => ethClk125,
         rst               => a_cmdReset or a_cmdRunReset,

         adcConvClk        => adcConvClkReg, 
         timerClkRaw       => timerClkRaw,
         
         trg               => eventBuilderTrg,
         hitsMask          => chanMaskAdc,
         boardID           => SrcMac,

         udpStartPort      => a_NBICDestPort,    
         udpCurrentPort    => NBICDestPort,
         udpNumOfPorts     => a_udpNumOfPorts, 

         nSamples          => a_drsNSamples, 
         nSamplInPacket    => a_nSamplInPacket,
         tAdcChan          => to_integer(unsigned(a_adcDbgChan)),
         drsStopSample     => drsStopSampleArr,

         drsWaitStart      => a_drsWaitStart,

         fragDisable       => a_ebFragDisable,

         rdEnable          => adcBufEthEna,
         rdAddr            => adcBufEthAddr,
         rdChan            => adcBufEthChan,
         rdData            => adcBufEthData,

         drsReq            => drsRdReq,

         drsDone           => drsRdAck,
         drsBusy           => drsCtrlBusy,
         ethBusy           => ethEvtBusy,
         evtTrigger        => ethEvtTrigger,
         evtData           => ethEvtData,
         evtNFrames        => ethEvtNumberOfFrames,
         ethReady          => ethEvtReady,
         evtBusy           => evtBusy,
         evtNumber         => regArrSta(getRegInd("CUREVTNUM")),
         debug             => regArrSta(getRegInd("EBDEBUG")) 
      );
   regArrSta(getRegInd("CURRENTPORT"))(15  downto 0) <= NBICDestPort;
   -------------------------------------------------


   -------------------------------------------------
   -- Eth/UDP module 
   -------------------------------------------------
   DestMac <= a_NBICDestMac_H(15 downto 0) & a_NBICDestMac_L;
   SrcMac  <= a_NBICSrcMac_H(15 downto 0)  & a_NBICSrcMac_L;

   U_EthModule : entity work.ex_eth_entity
      port map(
         clk                   => ethClk125,
         rst                   => a_cmdReset,
         -- user FSM supplies these three pins
         user_event_trigger    => ethEvtTrigger,
         user_event_data       => ethEvtData,
         user_number_of_frames => ethEvtNumberOfFrames,
         user_event_ready      => ethEvtReady,
         -- eth_header values supplied by microblaze
         DstMac                => DestMac, 
         SrcMac                => SrcMac,
         -- ipv4_header values supplied by microblaze
         SrcIP                 => a_NBICSrcIP,
         DstIP                 => a_NBICDestIP,
         -- udp_header values supplied by microblaze
         UDP_DstPort           => NBICDestPort,
         UDP_SrcPort           => a_NBICSrcPort,
         -- I/O to axis stream fifo
         axis_data_stream_out  => axiDataOut_tdata, 
         axis_data_valid       => axiDataOut_tvalid,
         axis_data_last        => axiDataOut_tlast,
         axis_data_keep        => axiDataOut_tkeep,
         axis_fifo_ready       => axiDataOut_tready,
         -- busy signal
         busy => ethEvtBusy
      );
   -------------------------------------------------


   -------------------------------------------------
   -- Device DNA
   -------------------------------------------------
   U_DeviceDna : entity work.DeviceDna
      port map ( 
         clk       => ethClk125,
         rst       => Rst,
         -- Parallel interface for current ticks value
         dnaOut    => deviceDna
      );
   regArrSta(getRegInd("DEVICEDNA_L")) <= deviceDna(31 downto 0);
   regArrSta(getRegInd("DEVICEDNA_H")) <= deviceDna(63 downto 32);
   -------------------------------------------------


end Behavioral;





