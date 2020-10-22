library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use work.LappdPkg.all;
use work.RegDefs.all;
-- For Xilinx primitives
library UNISIM;
use UNISIM.VComponents.all;

entity RegMap is
  port (
    clk           : in  sl;
    sRst          : in  sl;
    -- Register interfaces to UART controller
    regAddr       : in  slv(31 downto 0);
    regWrData     : in  slv(31 downto 0);
    regRdData     : out slv(31 downto 0);
    regReq        : in  sl;
    regOp         : in  sl;
    regAck        : out sl;
   
    lappdCmd      : out LappdCmdType;
    regArrayOut   : out tRegDataArray(0 to NREG-1);
    regArrayIn    : in  tRegDataArray(0 to NREG-1);

    --EeveeTimer
    timerClkRaw   : out slv64;

    -- ADC buffer
    adcBufAddr    : out slv(G_ADC_BIT_DEPTH-1 downto 0);
    adcBufReq     : out sl;
    adcBufAck     : in  sl;
    adcBufData    : in  slv(31 downto 0);

    -- Pedestals memory
    drsPedReq      : out sl;
    drsPedWrEn     : out sl;
    drsPedAck      : in  sl;
    drsPedAddr     : out slv(15 downto 0); -- chan & addr
    drsPedWrData   : out slv(G_ADC_BIT_WIDTH-1 downto 0); 
    drsPedRdData   : in  slv(G_ADC_BIT_WIDTH-1 downto 0);

    -- DRS regs
    drsRegMode     : out sl; -- only two regsiters: 0--config 1--write
    drsRegData     : out slv(7 downto 0);
    drsRegReq      : out sl;
    drsRegAck      : in sl;

    -- DAC serial IO
    dacSclk       : out sl;
    dacCsb        : out sl;
    dacSin        : out sl;
    dacSout       : in  sl;

    -- ADC serial IO
    adcSclk       : out sl;
    adcCsb        : out slv(1 downto 0);
    adcSin        : out sl;
    adcSout       : in  sl
);
end RegMap;

architecture Behavioral of RegMap is
  
  signal efuseVal    : slv(31 downto 0);

  signal scratchPad  : slv(31 downto 0);
  
  
  -------------------------------------------
  -- Internal signals for the SPI DAC control
  -------------------------------------------
  -- This is private because we don't want the DAC trying to service every
  -- incoming request.
  signal SpiDAC_regReq : sl;

  -- This is private because we don't want the DAC speaking on behalf of
  -- someone else
  signal SpiDAC_regAck : sl;

  -- This is private to avoid garbage read out while servicing other requests
  signal SpiDAC_regRdData : slv(15 downto 0);

  -- These signals don't need to be private because they don't cause the DAC to
  -- act. 
  -- signal SpiDAC_regOp : sl;
  -- signal SpiDAC_regWrData : slv(31 downto 0);

  signal SpiADC_regReq : sl;
  signal SpiADC_regAck : sl;
  signal SpiADC_regRdData : slv(15 downto 0);
  signal SpiADC_chipSel : sl;

   -- Eevee Timer!  These are private for the same above reasons
  signal eeveeTimer_regRdData : slv(31 downto 0);
  signal eeveeTimer_regAck : sl;
  signal eeveeTimer_regReq : sl;

  attribute dont_touch : string;

  signal regAddr_r    :   slv(31 downto 0) := (others => '0');
  signal regWrData_r  :   slv(31 downto 0) := (others => '0');
  signal regReq_r     :   sl               := '0';
  signal regOp_r      :   sl               := '0';

  signal regArray     : tRegDataArray(0 to NREG-1) := REG_DEFAULTS;

  alias regSubAddr : std_logic_vector(11 downto 0) is regAddr_r(11 downto 0);
  alias regDevAddr : std_logic_vector(3  downto 0) is regAddr_r(21 downto 18);
  --alias regDevAddr : std_logic_vector(3  downto 0) is regAddr(15 downto 12);

begin

   regArrayOut   <= regArray;

   lappdCmd.Reset    <= regArray(getRegInd("CMD"))(C_CMD_RESET_BIT);
   lappdCmd.adcClear <= regArray(getRegInd("CMD"))(C_CMD_ADCCLEAR_BIT);
   lappdCmd.adcStart <= regArray(getRegInd("CMD"))(C_CMD_ADCSTART_BIT);
   lappdCmd.adcTxTrg <= regArray(getRegInd("CMD"))(C_CMD_ADCTXTRG_BIT);
   lappdCmd.adcReset <= regArray(getRegInd("CMD"))(C_CMD_ADCRESET_BIT);

  process (clk) 
    variable adcAddr : integer range 0 to 3 := 0;
  begin
    if rising_edge(clk) then
      regReq_r    <= regReq;
      regAddr_r   <= regAddr;
      regOp_r     <= regOp;
      regWrData_r <= regWrData;
      regAck      <= regReq_r;
      
      --
      -- Register mapping: provincial
      -- KC 10/20/18
      --
      -- *) Segmented at 4K boundaries based on "logical" subsystems
      -- *) Spaced by 32 bits to accommodate a full metadata register for
      --    each register.
      --
      for regInd in 0 to NREG-1 loop
         if REG_MAP(regInd).ACCTYPE = B"10" then
            regArray(regInd) <= regArrayIn(regInd);      
         end if;
         if REG_MAP(regInd).ACCTYPE = B"11" then
            regArray(regInd) <= (others => '0');      
         end if;
      end loop;

      ----------------------------------------------------
      -- Access from MB
      ----------------------------------------------------
      ----------------------------------------------------
      -- This is internal register land
      ----------------------------------------------------
      if regDevAddr = x"0" then
         regRdData <= x"B00BC0DE";

         for regInd in 0 to NREG-1 loop
            if regSubAddr = REG_MAP(regInd).ADDRESS(11 downto 0) then
               regRdData <= regArray(regInd);
               if regOp_r = '1' and regReq_r = '1' and REG_MAP(regInd).ACCTYPE(0) = '1' then
                  regArray(regInd) <= regWrData_r;
               end if;
            end if;
         end loop;

          -- EEVEE Timer!
         if regSubAddr = x"120" then 
            regRdData <= eeveeTimer_regRdData;
            eeveeTimer_regReq <= regReq_r;
            regAck <= eeveeTimer_regAck;
         elsif regSubAddr = x"124" then
            regRdData <= eeveeTimer_regRdData;
            eeveeTimer_regReq <= regReq_r;
            regAck <= eeveeTimer_regAck;
         elsif regSubAddr = x"128" then
            regRdData <= eeveeTimer_regRdData;
            eeveeTimer_regReq <= regReq_r;
            regAck <= eeveeTimer_regAck;
         end if;

      ----------------------------------------------------
      -- SpiDAC 
      ----------------------------------------------------
      elsif regDevAddr = x"1" then
        -- Signal SpiDAC
        -- We need to pass through the lowest accessible 4
        -- x300 becomes b(0011 0000 0000)
        -- The low 4 bits are not available (we increment registers by x0008)
        -- So grab the middle 4 bits, which give us all 16 channels, easily
        -- read in the register address itself
        regRdData <= x"0000" & SpiDAC_regRdData;
        SpiDAC_regReq <= regReq_r;      
        regAck        <= SpiDAC_regAck;
      ----------------------------------------------------
      -- ADC SPI
      ----------------------------------------------------
      elsif regDevAddr = x"2" then
        regRdData <= x"0000" & SpiADC_regRdData;
        SpiADC_regReq <= regReq_r;      
        regAck        <= SpiADC_regAck;
      ----------------------------------------------------
      -- ADC Buffer
      ----------------------------------------------------
      elsif regDevAddr = x"3" then
         regRdData    <= adcBufData;
         adcBufAddr   <= regAddr_r(G_ADC_BIT_DEPTH+1 downto 2);
         adcBufReq    <= regReq_r;
         regAck       <= adcBufAck;
      ----------------------------------------------------
      -- DRS4 config/write registers
      ----------------------------------------------------
      elsif regDevAddr = x"4" then
         regRdData    <= (others => '0');
         drsRegMode   <= regAddr_r(2);
         drsRegReq    <= regReq_r;
         drsRegData   <= regWrData_r(7 downto 0);   
         regAck       <= drsRegAck;
      ----------------------------------------------------
      -- Pedestals memory
      ----------------------------------------------------
      elsif regDevAddr = x"8" then
         regRdData    <= (others => '0');
         regRdData(G_ADC_BIT_WIDTH-1 downto 0) <= drsPedRdData;
         drsPedWrData <= regWrData_r(G_ADC_BIT_WIDTH-1 downto 0);
         drsPedWrEn   <= regOp_r;
         --drsPedAddr   <= b"000000" & regAddr(11 downto 2);
         drsPedAddr   <= regAddr_r(17 downto 2);
         drsPedReq    <= regReq_r;
         regAck       <= drsPedAck;
      else
        regRdData <= x"DEADC0DE";
      end if;
    end if;
  end process;

  -----------------------------------------------------
  -- Xilinx primitives or simple derivatives thereof --
  -----------------------------------------------------
  -- One-time burnable eFUSE (32-bit)
  U_Efuse : EFUSE_USR
    generic map (
      SIM_EFUSE_VALUE => X"00000000" -- Value of the 32-bit non-volatile value used in simulation
      )
    port map (
      EFUSEUSR => efuseVal -- 32-bit output: User eFUSE register value output
      );
  -- Device DNA (64-bit)
  
  
  
  U_SpiDAC : entity work.SpiDACx0508
     generic map (
      N_CHAINED => 2
     )
     port map (
       -- Clock and reset
       sysClk    => clk,     --: in sl;
       sysRst    => sRst,    --: in sl;
       -- DAC serial IO
       dacSclk   => dacSclk, --: out sl;
       dacCsb    => dacCsb,  --: out sl;
       dacSin    => dacSin,  -- out sl;
       dacSout   => dacSout, -- in  sl;
       -- Register mapping into this module
       dacOp     => regOp_r, -- in  sl;
       dacWrData => regWrData_r(15 downto 0), -- in  slv(15 downto 0);     
       dacRdData => SpiDAC_regRdData,
       dacReq    => SpiDAC_regReq, -- in  sl;
       dacAck    => SpiDAC_regAck, -- out sl;
       -- Based on our convention, we grab the middle nibble 
       dacAddr   => regAddr(5 downto 2), -- in  slv( 3 downto 0);

       -- Shadow register output
       dacShadow => open -- out Word16Array(15 downto 0)
    ); 

  -- only one ADC for now
  U_SpiADC : entity work.SpiADS52J90
     port map (
       -- Clock and reset
       sysClk    => clk,     --: in sl;
       sysRst    => sRst,    --: in sl;
       -- ADC serial IO
       Sclk   => adcSclk, --: out sl;
       Csb    => adcCsb,  --: out sl; TODO: this should be slv for all ADCs
       Sin    => adcSin,  -- out sl;
       Sout   => adcSout, -- in  sl;
       -- Register mapping into this module
       Op     => regOp_r, -- in  sl;
       Sel    => regAddr_r(10),
       WrData => regWrData_r(15 downto 0), -- in  slv(15 downto 0);     
       RdData => SpiADC_regRdData,
       Req    => SpiADC_regReq, -- in  sl;
       Ack    => SpiADC_regAck, -- out sl;
       -- Based on our convention, we grab the middle nibble 
       Addr   => regAddr_r(9 downto 2), -- in  slv( 3 downto 0);

       -- Shadow register output
       Shadow => open -- out Word16Array(15 downto 0)
    ); 

  U_EeveeTimer : entity work.EeveeTimer
    port map (
      clk => clk,
      rst => sRst,
      
      -- These can be set directly
      timerOp => regOp_r,
      timerWrData => regWrData_r,
      timerAddr => regAddr_r(3 downto 2),
      
      -- These must be set to the internals
      timerReq => eeveeTimer_regReq,
      timerAck => eeveeTimer_regAck,
      timerRdData => eeveeTimer_regRdData,

      clockRaw => timerClkRaw,
      -- We don't use these for now
      clockRst => '0'
      );
    
        

end Behavioral;
