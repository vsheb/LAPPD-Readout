----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/11/2016 02:36:25 PM
-- Design Name: 
-- Module Name: AdcReadout - Behavioral
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
use ieee.std_logic_unsigned.all;
use work.UtilityPkg.all;
use work.LappdPkg.All;

library UNISIM;
use UNISIM.VComponents.all;

entity AdcReadout is
   generic (
      N_DATA_LINES        : integer range 1 to 16 := 16;
      BIT_WIDTH           : integer := 12;
      ADCDOUT_INVERT_MASK : std_logic_vector(15 downto 0) := (others => '0')
   );
   port (
      -- clocks
      sysClk        : in std_logic; -- system clock
      syncRst       : in std_logic; -- reset

      iDelayRefClk  : in std_logic; -- IDELAY reference clock
      adcConvClk    : in std_logic; -- read clock for ADC
      adcSync       : in std_logic;

      bitslip       : in slv(N_DATA_LINES-1 downto 0);

      bufRCLR       : in std_logic;
      bufRCE        : in std_logic;

      -- configuration pins
      adcFrameDelay : in std_logic_vector(4 downto 0);
      adcDataDelay  : in Word5Array(0 to N_DATA_LINES-1);
      adcClkDelay   : in std_logic_vector(4 downto 0);

      -- Input ports from the chip
      adcDoClkP     : in std_logic; -- data clock 
      adcDoClkN     : in std_logic;   
      adcFrClkP     : in std_logic; -- frame clock
      adcFrClkN     : in std_logic;
      adcDataInP    : in std_logic_vector(N_DATA_LINES-1 downto 0); 
      adcDataInN    : in std_logic_vector(N_DATA_LINES-1 downto 0); 

      -- Output ports to chip
      adcClkP       : out std_logic;
      adcClkN       : out std_logic;

      adcDelayDebug : out Word5Array(0 to 17);
      bitslipCnt    : out std_logic_vector(31 downto 0);
      bitslipGood   : out sl;
      adcChanMask   : in slv(31 downto 0) := (others => '1');

      -- outputs to fabric
      adcFrameOut   : out std_logic_vector(BIT_WIDTH-1 downto 0);
      adcDataOut    : out AdcDataArray(0 to 2*N_DATA_LINES-1);
      adcDataValid  : out std_logic
   );
end AdcReadout;

architecture Behavioral of AdcReadout is


   type Word2Array    is array(integer range<>) of std_logic_vector(1 downto 0);
   type HalfWordArray is array(integer range<>) of std_logic_vector(BIT_WIDTH/2-1 downto 0);
   
   signal iRst               : std_logic;
   signal iRstDivClk         : std_logic;
   signal iRstDivClkEx       : std_logic;

   signal iDelayCtrlRdy      : std_logic;

   signal adcConvClkR        : std_logic;
   signal iAdcConvClk        : std_logic;
   signal iAdcConvClkR       : std_logic;

   signal adcDoClkShifted    : std_logic;
   signal adcFrClkShifted    : std_logic;
   signal adcDataShifted     : std_logic_vector(N_DATA_LINES-1 downto 0);

   signal frameDataDivClk    : std_logic_vector(BIT_WIDTH-1 downto 0);
   signal frameDataDivClkQ   : std_logic_vector(BIT_WIDTH/2-1 downto 0);
   signal frameDataDivClkReg : std_logic_vector(BIT_WIDTH-1 downto 0); 
   --signal frameSerdesShift   : std_logic_vector(1 downto 0);
   
   signal adcDataDivClkQ      : HalfWordArray(0 to N_DATA_LINES-1);
   signal adcDataDivClk       : AdcDataArray(0 to N_DATA_LINES-1);
   signal adcDataDivClkReg    : AdcDataArray(0 to N_DATA_LINES-1);
   signal adcDataDivClkOut    : AdcDataArray(0 to 2*N_DATA_LINES-1);
   signal adcDataOutR         : AdcDataArray(0 to 2*N_DATA_LINES-1);
   signal adcDataOutSysClk    : AdcDataArray(0 to 2*N_DATA_LINES-1);
   signal adcDataValidDivClk  : std_logic;
   signal adcDataValidDivClkR : std_logic;
   signal adcDataValidSysClk  : std_logic;

   signal doBitslip           : std_logic := '0';
   signal doBitslipData       : std_logic_vector(N_DATA_LINES-1 downto 0) := (others => '0');
   signal doBitslipFrame      : std_logic := '0';
   signal doBitslipManual     : std_logic_vector(N_DATA_LINES-1 downto 0) := (others => '0');

   signal adcDataIn           : std_logic_vector(N_DATA_LINES-1 downto 0);
   signal adcDataInInv        : std_logic_vector(N_DATA_LINES-1 downto 0);
   signal adcDataInDir        : std_logic_vector(N_DATA_LINES-1 downto 0);

   signal doBitslipAuto       : std_logic := '0';
   signal adcDoClkIBuf        : std_logic;
   signal adcDoClkIBufInv     : std_logic;
   signal adcDoClk            : std_logic;
   signal adcDoClkInv         : std_logic;
   signal adcDoClkMR          : std_logic;
   signal adcFrClk            : std_logic;
   signal adcDoClkBufR        : std_logic;
   signal adcDoClkBufIo       : std_logic;
   signal adcDoClkBufIoInv    : std_logic;

   signal counter             : std_logic_vector(3 downto 0)  := (others => '0');
   signal iBitslipCnt         : std_logic_vector(31 downto 0) := (others => '0');
   signal iBitslipGoodCnt     : std_logic_vector(15 downto 0) := (others => '0');

   signal nPipeOut            : natural := 0;
   signal adcChanMaskR        : std_logic_vector(31 downto 0);


--   -- Vivado attributes to keep signals (for debugging)
--   attribute dont_touch : string;
--   attribute dont_touch of frameDataDivClk    : signal is "true";    
   attribute IOB : string;                               
   --attribute IOB of adcConvClk         : signal is "TRUE";    
   attribute IOB of adcFrClk           : signal is "TRUE";    
   attribute IOB of adcDoClk           : signal is "TRUE";    
   attribute IOB of adcDoClkBufR       : signal is "TRUE";    
   attribute IOB of adcDoClkBufIo      : signal is "TRUE";    
   attribute IOB of adcDoClkBufIoInv   : signal is "TRUE";    
   attribute IOB of adcDataIn          : signal is "TRUE";    
   attribute IOB of adcDataShifted     : signal is "TRUE";    
   attribute IOB of adcFrClkShifted    : signal is "TRUE";
   attribute IOB of frameDataDivClkQ   : signal is "TRUE";    
   attribute IOB of adcDataDivClkQ     : signal is "TRUE";    
   attribute IOB of iAdcConvClkR       : signal is "TRUE";

   attribute keep : string;
   attribute keep of adcFrClk           : signal is "TRUE";    
   attribute keep of adcDoClk           : signal is "TRUE";    
   attribute keep of adcDoClkBufR       : signal is "TRUE";    
   attribute keep of adcDoClkBufIo      : signal is "TRUE";    
   attribute keep of adcDoClkBufIoInv   : signal is "TRUE";    
   attribute keep of adcDataIn          : signal is "TRUE";    
   attribute keep of adcDataShifted     : signal is "TRUE";    
   attribute keep of adcFrClkShifted    : signal is "TRUE";
   attribute keep of iAdcConvClkR       : signal is "TRUE";
   attribute keep of frameDataDivClkQ   : signal is "TRUE";    
   attribute keep of adcDataDivClkQ     : signal is "TRUE";    

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

   FDRE_ConvClk : FDRE
   generic map (   
      INIT => '0'
   )  
   port map (   
      Q  => iAdcConvClkR,
      C  => sysClk,
      CE => '1',
      R  => '0',
      D  => adcConvClk
   );

   
   OBUFDS_ADC_CLK : OBUFDS 
   port map (
      I  => iAdcConvClkR, 
      O  => adcClkP, 
      OB => adcClkN
   );

   ---------------------------------------------------
   -- Differential buffers for input clock from ADC
   ----------------------------------------------------
   IBUFDS_ADC_DCO : IBUFGDS 
   generic map (
      DIFF_TERM => TRUE
   )
   port map (
      O   => adcDoClkIBuf, 
      I  => adcDoClkP, 
      IB => adcDoClkN
   );

   IDELAYE2_AdcDoClk : IDELAYE2
      generic map (
         CINVCTRL_SEL          => "FALSE",   -- Enable dynamic clock inversion (FALSE, TRUE)
         DELAY_SRC             => "IDATAIN", -- Delay input (IDATAIN, DATAIN)
         HIGH_PERFORMANCE_MODE => "TRUE",   -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
         IDELAY_TYPE           => "VAR_LOAD",   -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
         IDELAY_VALUE          => 0,         -- Input delay tap setting (0-31)
         PIPE_SEL              => "FALSE",   -- Select pipelined mode, FALSE, TRUE
         REFCLK_FREQUENCY      => 200.0,     -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
         SIGNAL_PATTERN        => "CLOCK"    -- DATA, CLOCK input signal
      )
      port map (
         CNTVALUEOUT => adcDelayDebug(16),            -- 5-bit output: Counter value output
         DATAOUT     => adcDoClk,        -- 1-bit output: Delayed data output
         C           => sysClk,      -- 1-bit input: Clock input
         CE          => '0',             -- 1-bit input: Active high enable increment/decrement input
         CINVCTRL    => '0',             -- 1-bit input: Dynamic clock inversion input
         CNTVALUEIN  => adcClkDelay,      -- 5-bit input: Counter value input
         DATAIN      => '0',             -- 1-bit input: Internal delay data input
         IDATAIN     => adcDoClkIBuf,        -- 1-bit input: Data input from the I/O
         INC         => '0',             -- 1-bit input: Increment / Decrement tap delay input
         LD          => '1',             -- 1-bit input: Load IDELAY_VALUE input
         LDPIPEEN    => '0',             -- 1-bit input: Enable PIPELINE register to load data input
         REGRST      => '0'              -- 1-bit input: Active-high reset tap-delay input
      );   
   ----------------------------------------------------

   BUFIO_AdcDoClk : BUFIO port map (I => adcDoClk, O => adcDoClkBufIo);
   adcDoClkInv <= not adcDoClkBufIo;


   BUFMRCE_U : BUFMRCE 
   generic map (
      CE_TYPE  => "ASYNC",
      INIT_OUT => 0
   )
   port map (
      I  => adcDoClk,
      CE => bufRCE,
      O  => adcDoClkMR
   );

   BUFR_AdcDoClk   : BUFR 
      generic map ( 
         BUFR_DIVIDE => "3" 
      ) 
      port map ( 
         CE  => '1', 
         CLR => bufRCLR, --'0', 
         I   => adcDoClkMR,  
         O   => adcDoClkBufR 
      );


   IBUFDS_ADC_FCO : IBUFDS
   generic map (
      DIFF_TERM => TRUE
   )
   port map (
      O  => adcFrClk, 
      I  => adcFrClkP, 
      IB => adcFrClkN
   );
   ----------------------------------------------------



   ---------------------------------------------------
   -- Differential buffers for ADC data lines 
   ----------------------------------------------------
   GEN_ADC_DO : for iAdcChan in 0 to N_DATA_LINES-1 generate 
      
      IBUFDS_ADC_DATA_I  : IBUFDS_DIFF_OUT
         generic map (
            DIFF_TERM => TRUE
         )
         port map (
            O  =>  adcDataInDir(iAdcChan), 
            OB =>  adcDataInInv(iAdcChan), 
            I  =>  adcDataInP(iAdcChan), 
            IB =>  adcDataInN(iAdcChan)
         );
      
      DIRECT_GEN : if ADCDOUT_INVERT_MASK(iAdcChan) = '0' generate 
         adcDataIn(iAdcChan) <= adcDataInDir(iAdcChan);
      end generate DIRECT_GEN;

      INVERTED_GEN : if ADCDOUT_INVERT_MASK(iAdcChan) = '1' generate 
         adcDataIn(iAdcChan) <= adcDataInInv(iAdcChan);
      end generate INVERTED_GEN;

   end generate GEN_ADC_DO;
   ----------------------------------------------------

   -- IDELAYCTRL is necessary to use IDELAYE2 primitives 
   IDelayCtrl200MHz : IDELAYCTRL
      port map (
         RDY    => iDelayCtrlRdy, -- 1-bit output: Ready output
         REFCLK => iDelayRefClk,  -- 1-bit input: Reference clock input
         RST    => '0' --iRst
      );

   ----------------------------------------------------
   -- Frame signal 
   ----------------------------------------------------
   IDELAYE2_AdcFrClk : IDELAYE2
      generic map (
         CINVCTRL_SEL          => "FALSE",   -- Enable dynamic clock inversion (FALSE, TRUE)
         DELAY_SRC             => "IDATAIN", -- Delay input (IDATAIN, DATAIN)
         HIGH_PERFORMANCE_MODE => "TRUE",   -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
         IDELAY_TYPE           => "VAR_LOAD",  -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
         IDELAY_VALUE          => 0,         -- Input delay tap setting (0-31)
         PIPE_SEL              => "FALSE",   -- Select pipelined mode, FALSE, TRUE
         REFCLK_FREQUENCY      => 200.0,     -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
         SIGNAL_PATTERN        => "DATA"    -- DATA, CLOCK input signal
      )
      port map (
         CNTVALUEOUT => adcDelayDebug(17),            -- 5-bit output: Counter value output
         DATAOUT     => adcFrClkShifted, -- 1-bit output: Delayed data output
         C           => sysClk,      -- 1-bit input: Clock input
         CE          => '0',             -- 1-bit input: Active high enable increment/decrement input
         CINVCTRL    => '0',             -- 1-bit input: Dynamic clock inversion input
         CNTVALUEIN  => adcFrameDelay,   -- 5-bit input: Counter value input
         DATAIN      => '0',             -- 1-bit input: Internal delay data input
         IDATAIN     => adcFrClk,        -- 1-bit input: Data input from the I/O
         INC         => '0',             -- 1-bit input: Increment / Decrement tap delay input
         LD          => '1',             -- 1-bit input: Load IDELAY_VALUE input
         LDPIPEEN    => '0',             -- 1-bit input: Enable PIPELINE register to load data input
         REGRST      => '0'              -- 1-bit input: Active-high reset tap-delay input
      );   

   ISERDESE2_FrameMaster : ISERDESE2
      generic map (
         DATA_RATE         => "DDR",        -- DDR, SDR
         DATA_WIDTH        => BIT_WIDTH/2,           -- Parallel data width (2-8,10,14)
         DYN_CLKDIV_INV_EN => "FALSE",      -- Enable DYNCLKDIVINVSEL inversion (FALSE, TRUE)
         DYN_CLK_INV_EN    => "FALSE",      -- Enable DYNCLKINVSEL inversion (FALSE, TRUE) 
         INTERFACE_TYPE    => "NETWORKING", -- MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
         IOBDELAY          => "IFD",       -- NONE, BOTH, IBUF, IFD
         NUM_CE            => 1,            -- Number of clock enables (1,2)
         OFB_USED          => "FALSE",      -- Select OFB path (FALSE, TRUE)
         SERDES_MODE       => "MASTER",     -- MASTER, SLAVE
         INIT_Q1  => '0', INIT_Q2  => '0', INIT_Q3  => '0', INIT_Q4  => '0', -- INIT_Q1 - INIT_Q4: Initial value on the Q outputs (0/1)
         SRVAL_Q1 => '0', SRVAL_Q2 => '0', SRVAL_Q3 => '0', SRVAL_Q4 => '0'  -- SRVAL_Q1 - SRVAL_Q4: Q output values when SR is used (0/1)
      )
      port map (
         O            => open,                -- 1-bit output: Combinatorial output
         Q1           => frameDataDivClkQ(5), 
         Q2           => frameDataDivClkQ(4),
         Q3           => frameDataDivClkQ(3),
         Q4           => frameDataDivClkQ(2),
         Q5           => frameDataDivClkQ(1),
         Q6           => frameDataDivClkQ(0),
         Q7           => open,
         Q8           => open, 
         SHIFTOUT1    => open, 
         SHIFTOUT2    => open,
         BITSLIP      => doBitslipFrame,           -- 1-bit input: The BITSLIP pin performs a Bitslip operation synchronous to
                                              -- CLKDIV when asserted (active High). Subsequently, the data seen on the
                                              -- Q1 to Q8 output ports will shift, as in a barrel-shifter operation, one
                                              -- position every time Bitslip is invoked (DDR operation is different from
                                              -- SDR).
         CE1          => '1',                 -- CE1, CE2: 1-bit (each) input: Data register clock enable inputs
         CE2          => '0',
         CLKDIVP      => '0',                 -- 1-bit input: TBD
                                              -- Clocks: 1-bit (each) input: ISERDESE2 clock input ports
         CLK          => adcDoClkBufIo,            -- 1-bit input: High-speed clock
         CLKB         => adcDoClkInv,         -- 1-bit input: High-speed secondary clock
         CLKDIV       => adcDoClkBufR,        -- 1-bit input: Divided clock
         OCLK         => '0',                 -- 1-bit input: High speed output clock used when INTERFACE_TYPE="MEMORY"
                                              -- Dynamic Clock Inversions: 1-bit (each) input: Dynamic clock inversion pins to switch clock polarity
         DYNCLKDIVSEL => '0',                 -- 1-bit input: Dynamic CLKDIV inversion
         DYNCLKSEL    => '0',                 -- 1-bit input: Dynamic CLK/CLKB inversion
                                              -- Input Data: 1-bit (each) input: ISERDESE2 data input ports
         D            => '0', --adcFrClk,            -- 1-bit input: Data input
         DDLY         => adcFrClkShifted,     -- 1-bit input: Serial data from IDELAYE2
         OFB          => '0',                 -- 1-bit input: Data feedback from OSERDESE2
         OCLKB        => '0',                 -- 1-bit input: High speed negative edge output clock
         RST          => iRstDivClkEx,        -- 1-bit input: Active high asynchronous reset
         SHIFTIN1     => '0',                 -- SHIFTIN1, SHIFTIN2: 1-bit (each) input: Data width expansion input ports
         SHIFTIN2     => '0'
      );


   ----------------------------------------------------
   -- Data signal  
   ----------------------------------------------------
   G_IDELAYE2_ADC_DATA : for i in N_DATA_LINES-1 downto 0 generate
      IDELAYE2_AdcData : IDELAYE2
         generic map (
            CINVCTRL_SEL          => "FALSE",   -- Enable dynamic clock inversion (FALSE, TRUE)
            DELAY_SRC             => "IDATAIN", -- Delay input (IDATAIN, DATAIN)
            HIGH_PERFORMANCE_MODE => "TRUE",   -- Reduced jitter ("TRUE"), Reduced power ("FALSE")
            IDELAY_TYPE           => "VAR_LOAD",   -- FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
            IDELAY_VALUE          => 0,         -- Input delay tap setting (0-31)
            PIPE_SEL              => "FALSE",   -- Select pipelined mode, FALSE, TRUE
            REFCLK_FREQUENCY      => 200.0,     -- IDELAYCTRL clock input frequency in MHz (190.0-210.0, 290.0-310.0).
            SIGNAL_PATTERN        => "DATA"    -- DATA, CLOCK input signal
         )
         port map (
            CNTVALUEOUT => adcDelayDebug(i),              -- 5-bit output: Counter value output
            DATAOUT     => adcDataShifted(i), -- 1-bit output: Delayed data output
            C           => sysClk,        -- 1-bit input: Clock input
            CE          => '0',               -- 1-bit input: Active high enable increment/decrement input
            CINVCTRL    => '0',               -- 1-bit input: Dynamic clock inversion input
            CNTVALUEIN  => adcDataDelay(i),      -- 5-bit input: Counter value input
            DATAIN      => '0',               -- 1-bit input: Internal delay data input
            IDATAIN     => adcDataIn(i),      -- 1-bit input: Data input from the I/O
            INC         => '0',               -- 1-bit input: Increment / Decrement tap delay input
            LD          => '1',               -- 1-bit input: Load IDELAY_VALUE input
            LDPIPEEN    => '0',               -- 1-bit input: Enable PIPELINE register to load data input
            REGRST      => '0'                -- 1-bit input: Active-high reset tap-delay input
         );      

      ISERDESE2_ADCMaster : ISERDESE2
         generic map (
            DATA_RATE         => "DDR",        -- DDR, SDR
            DATA_WIDTH        => BIT_WIDTH/2,           -- Parallel data width (2-8,10,14)
            DYN_CLKDIV_INV_EN => "FALSE",      -- Enable DYNCLKDIVINVSEL inversion (FALSE, TRUE)
            DYN_CLK_INV_EN    => "FALSE",      -- Enable DYNCLKINVSEL inversion (FALSE, TRUE) 
            INTERFACE_TYPE    => "NETWORKING", -- MEMORY, MEMORY_DDR3, MEMORY_QDR, NETWORKING, OVERSAMPLE
            IOBDELAY          => "IFD",       -- NONE, BOTH, IBUF, IFD
            NUM_CE            => 1,            -- Number of clock enables (1,2)
            OFB_USED          => "FALSE",      -- Select OFB path (FALSE, TRUE)
            SERDES_MODE       => "MASTER",     -- MASTER, SLAVE
            INIT_Q1  => '0', INIT_Q2  => '0', INIT_Q3  => '0', INIT_Q4  => '0', -- INIT_Q1 - INIT_Q4: Initial value on the Q outputs (0/1)
            SRVAL_Q1 => '0', SRVAL_Q2 => '0', SRVAL_Q3 => '0', SRVAL_Q4 => '0'  -- SRVAL_Q1 - SRVAL_Q4: Q output values when SR is used (0/1)
         )
         port map (
            O            => open,                 -- 1-bit output: Combinatorial output
            Q1           => adcDataDivClkQ(i)(5),
            Q2           => adcDataDivClkQ(i)(4),
            Q3           => adcDataDivClkQ(i)(3),
            Q4           => adcDataDivClkQ(i)(2),
            Q5           => adcDataDivClkQ(i)(1),
            Q6           => adcDataDivClkQ(i)(0),
            Q7           => open,
            Q8           => open,
            SHIFTOUT1    => open, 
            SHIFTOUT2    => open,
            BITSLIP      => doBitslipData(i),           -- 1-bit input: The BITSLIP pin performs a Bitslip operation synchronous to
                                                 -- CLKDIV when asserted (active High). Subsequently, the data seen on the
                                                 -- Q1 to Q8 output ports will shift, as in a barrel-shifter operation, one
                                                 -- position every time Bitslip is invoked (DDR operation is different from
                                                 -- SDR).
            CE1          => '1',                 -- CE1, CE2: 1-bit (each) input: Data register clock enable inputs
            CE2          => '0',
            CLKDIVP      => '0',                 -- 1-bit input: TBD
                                                 -- Clocks: 1-bit (each) input: ISERDESE2 clock input ports
            CLK          => adcDoClkBufIo,       -- 1-bit input: High-speed clock
            CLKB         => adcDoClkInv,  -- 1-bit input: High-speed secondary clock
            CLKDIV       => adcDoClkBufR,        -- 1-bit input: Divided clock
            OCLK         => '0',                 -- 1-bit input: High speed output clock used when INTERFACE_TYPE="MEMORY"
                                                 -- Dynamic Clock Inversions: 1-bit (each) input: Dynamic clock inversion pins to switch clock polarity
            DYNCLKDIVSEL => '0',                 -- 1-bit input: Dynamic CLKDIV inversion
            DYNCLKSEL    => '0',                 -- 1-bit input: Dynamic CLK/CLKB inversion
                                                 -- Input Data: 1-bit (each) input: ISERDESE2 data input ports
            D            => '0', --adcDataIn(i),        -- 1-bit input: Data input
            DDLY         => adcDataShifted(i),   -- 1-bit input: Serial data from IDELAYE2
            OFB          => '0',                 -- 1-bit input: Data feedback from OSERDESE2
            OCLKB        => '0',                 -- 1-bit input: High speed negative edge output clock
            RST          => iRstDivClkEx,             -- 1-bit input: Active high asynchronous reset
            SHIFTIN1     => '0',                 -- SHIFTIN1, SHIFTIN2: 1-bit (each) input: Data width expansion input ports
            SHIFTIN2     => '0'
         );

   end generate;

   ---------------------------------
   -- Our logic for grabbing data --
   ---------------------------------
   process (adcDoClkBufR)
   begin
      if rising_edge(adcDoClkBufR) then
         --frameDataDivClk <= frameDataDivClk(BIT_WIDTH/2-1 downto 0) & frameDataDivClkQ;
         frameDataDivClk <= frameDataDivClkQ & frameDataDivClk(BIT_WIDTH-1 downto BIT_WIDTH/2);
         frameDataDivClkReg <= frameDataDivClk;
         for i in N_DATA_LINES-1 downto 0 loop
            --adcDataDivClk(i) <= adcDataDivClk(i)(BIT_WIDTH/2-1 downto 0) & adcDataDivClkQ(i);
            adcDataDivClk(i) <= adcDataDivClkQ(i) & adcDataDivClk(i)(BIT_WIDTH-1 downto BIT_WIDTH/2);
            adcDataDivClkReg(i) <= adcDataDivClk(i);
         end loop;

         doBitslipAuto <= '0';
         if frameDataDivClkQ /= b"111111" and frameDataDivClkQ /= b"000000" then
            counter <= counter + 1; 
            if counter = B"1111" then
               doBitslipAuto  <= '1';
               counter <= (others => '0');
            end if;
         end if;
         
         if frameDataDivClkReg = b"000000000000" then
            adcDataValidDivClk <= '0';
            for i in 0 to N_DATA_LINES-1 loop
               adcDataDivClkOut(i*2) <= adcDataDivClkReg(i);
            end loop;
         elsif frameDataDivClkReg = b"111111111111" then
            adcDataValidDivClk <= '1';
            for i in 0 to N_DATA_LINES-1 loop
               adcDataDivClkOut(2*i+1) <= adcDataDivClkReg(i);
            end loop;
         else
            adcDataValidDivClk <= '0';
         end if;

         if adcDataValidDivClk = '1' then
            adcDataOutR   <= adcDataDivClkOut;
         end if;
         adcDataValidDivClkR <= adcDataValidDivClk;
         

         if iRstDivClk = '1' then 
            iBitslipCnt <= (others => '0');
         elsif doBitslipAuto = '1' then
               iBitslipCnt <= iBitslipCnt + 1;
         end if;

         if doBitslipAuto = '1' then
            iBitslipGoodCnt <= (others => '0');
         else 
            if iBitslipGoodCnt /= x"ffff" then
               iBitslipGoodCnt <= iBitslipGoodCnt + 1;
           end if;
         end if;

      end if;
   end process;

   process (sysClk)
   begin
      if rising_edge (sysClk) then
         bitslipGood <= iBitslipGoodCnt(12);
      end if;
   end process;

   OUTSYNC_GEN : for iCH in 0 to 31 generate
      adcDataSync_U : entity work.VecSync 
         generic map(
            W      => adcDataOutR(0)'length
         )
         port map (
            clka   => adcDoClkBufR,
            rst    => '0',
            inpa   => adcDataOutR(iCH),
            clkb   => sysClk,
            outb   => adcDataOutSysClk(iCH)
         );
   end generate OUTSYNC_GEN;

   adcFrameSync_U : entity work.VecSync 
      generic map(
         W      => adcDataOutR(0)'length
      )
      port map (
         clka   => adcDoClkBufR,
         rst    => '0',
         inpa   => frameDataDivClkReg,
         clkb   => sysClk,
         outb   => adcFrameOut
      );

   adcValidSync_U : entity work.BitSync
      port map (
         clka  => adcDoClkBufR,
         rst   => '0',
         inpa  => adcDataValidDivClkR,
         clkb  => sysClk,
         outb  => adcDataValidSysClk
      );

   ADCOUT_GEN : for i in 0 to 2*N_DATA_LINES-1 generate 
      process (sysClk)
      begin
         if rising_edge (sysClk) then
            adcChanMaskR(i) <= adcChanMask(i);
            if adcSync = '1' then
               adcDataValid <= '1';
               
               if adcChanMaskR(i) = '1' then
                  adcDataOut(i)   <= adcDataOutSysClk(i);
               else 
                  adcDataOut(i)   <= (others => '0');
               end if;
            else
               adcDataValid <= '0';
            end if;
         end if;
      end process;
   end generate ADCOUT_GEN;


   doBitslipFrame <= doBitslipAuto;

   BITSLIP_GEN : for iLine in 0 to N_DATA_LINES-1 generate
      process (adcDoClkBufR)
      begin
         if rising_edge (adcDoClkBufR) then
            doBitslipData(iLine)  <= doBitslipAuto or doBitslipManual(iLine);
         end if;
      end process;
   end generate BITSLIP_GEN;


   BITSLIPSTROBE_GEN : for jLine in 0 to N_DATA_LINES-1 generate
     bitslipStrobe_U : entity work.StrobeTransition
        port map (
           clka => sysClk,
           inpa => bitslip(jLine),
           clkb => adcDoClkBufR,
           outb => doBitslipManual(jLine)
        );
      end generate BITSLIPSTROBE_GEN;

  rstTrans_U : entity work.StrobeTransition
     port map (
        clka => sysClk,
        inpa => syncRst,
        clkb => adcDoClkBufR,
        outb => iRstDivClk
     );

   rstShape_U : entity work.PulseShaper
      port map(
        clk => sysClk,
        rst => '0',
        len => x"0008",
        del => x"0000",
        din => iRstDivClk,
        dou => iRstDivClkEx
      );
   
   process(sysClk)
   begin
      if rising_edge(sysClk) then
         bitslipCnt <= iBitslipCnt;
      end if;
   end process;
   

end Behavioral;
