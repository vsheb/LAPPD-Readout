library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.UtilityPkg.all;
use work.LappdPkg.all;



entity AdcBuffer is
   generic(
      ADC_CHANNELS_NUMBER : integer := 32;
      ADC_CHIPS_NUMBER    : integer := 2;
      ADC_DATA_WIDTH      : integer := 12;
      ADC_DATA_DEPTH      : integer := 10
   );
   port (
      sysClk        : in  sl;
      sysRst        : in  sl;

      rstWrAddr     : in  sl := '0';

      -- enable pedestal subtraction
      pedSubOn      : in  sl := '0'; 

      -- thresholds for the zero suppression (in 2's compliment format)
      zeroThreshArr : in AdcDataArray(0 to ADC_CHANNELS_NUMBER*ADC_CHIPS_NUMBER-1) := (others => (others => '0'));
      zsupPolarity  : in sl  := '0'; -- 0 - positive, 1 - negative
      zsupNsamples  : in slv(9 downto 0) := (others => '0'); -- number of samples over threshold

      -- input adc data
      wrEnable      : in  sl;
      dataValid     : in  slv(1 downto 0); 
      wrData        : in  AdcDataArray(0 to ADC_CHANNELS_NUMBER*ADC_CHIPS_NUMBER-1);

      -- pedestals data
      pedArr           : in  AdcDataArray(0 to ADC_CHANNELS_NUMBER*ADC_CHIPS_NUMBER-1);
      pedSmpNumArr     : out Word10Array(0 to 7);
      drsStopSampleArr : in  Word10Array(0 to 7) ;
      drsStopSmpValid  : in  sl; -- DRS4 stop sample is valid

      -- eth readout
      rdEthEnable   : in  sl;
      rdEthChan     : in  slv(5 downto 0) := (others => '0');
      rdEthAddr     : in  slv(ADC_DATA_DEPTH-1 downto 0);
      rdEthData     : out slv16; --(ADC_DATA_WIDTH-1 downto 0);
      
      -- reg interface 
      rdReq         : in  sl;
      rdChan        : in  slv(5 downto 0);
      rdAddr        : in  slv(ADC_DATA_DEPTH-1 downto 0);
      rdAck         : out sl;
      rdData        : out slv16; --(ADC_DATA_WIDTH-1 downto 0);

      -- zero suppressed hits mask
      hitsThrMask   : out slv(ADC_CHANNELS_NUMBER*ADC_CHIPS_NUMBER-1 downto 0); 

      --debug
      curAddr       : out slv(ADC_DATA_DEPTH-1 downto 0);
      nWordsWrtn    : out slv32
   );
end AdcBuffer;

architecture adcBufArch of AdcBuffer is
   ----------------------------------------------
   -- local types definitions
   ----------------------------------------------
   type AddrArrayType        is array(ADC_CHIPS_NUMBER-1 downto 0) of slv(ADC_DATA_DEPTH-1 downto 0);
   --subtype AdcDataVectorType is std_logic_vector(ADC_CHANNELS_NUMBER*ADC_DATA_WIDTH-1 downto 0);
   subtype AdcDataVectorType is std_logic_vector(ADC_CHANNELS_NUMBER*16-1 downto 0);
   type AdcDataVecArrayType  is array(ADC_CHIPS_NUMBER-1 downto 0) of AdcDataVectorType;

   ----------------------------------------------
   -- constants
   ----------------------------------------------
   constant subMin            : signed(ADC_DATA_WIDTH-1 downto 0) := x"800";
   constant subMax            : signed(ADC_DATA_WIDTH-1 downto 0) := x"7ff";
   
   ----------------------------------------------
   -- signals
   ----------------------------------------------
   signal   bufCurAddr        : AddrArrayType                     := (others => (others => '0')); 

   signal   wrData_r          : AdcDataArray(0 to ADC_CHANNELS_NUMBER*ADC_CHIPS_NUMBER-1) := (others => (others => '0'));
   signal   adcDataPedSub        : AdcDataArray(0 to ADC_CHANNELS_NUMBER*ADC_CHIPS_NUMBER-1) := (others => (others => '0'));


   signal   wrDataMerged      :  AdcDataVecArrayType              := (others => (others => '0'));
                                                                  
   signal   rdAddr_regIfc     : slv(ADC_DATA_DEPTH-1 downto 0)    := (others => '0');
   signal   rdAddr_i          : slv(ADC_DATA_DEPTH-1 downto 0)    := (others => '0');
   signal   wrEnable_r        : slv(ADC_CHIPS_NUMBER-1 downto 0)  := (others => '0');
   signal   wrEnable_2r       : slv(ADC_CHIPS_NUMBER-1 downto 0)  := (others => '0');
   signal   rdChan_i          : slv(5 downto 0)                   := (others => '0');
   signal   rdData_r          : slv16; --(ADC_DATA_WIDTH-1 downto 0);
   signal   ethData_r         : slv16; --(ADC_DATA_WIDTH-1 downto 0);
                                                                  
   signal   rdAdc             : natural                           := 0; -- adc chip index 
   signal   rdAdcChan_i       : natural                           := 0; -- adc channel number
                                                                  
   signal   localRdData       : AdcDataVecArrayType               := (others => (others => '0'));
                                                                  
   signal   pedSubOn_r        : sl                                := '0';
                                                                  
   signal   rdReqR            : sl                                := '0';
   signal   rdReqRR           : sl                                := '0'; 
                                                                  
   signal   pedSmpNumArr_i    : Word10Array(0 to 7)               := (others => (others => '0'));
   signal   pedArr_r          : AdcDataArray(0 to ADC_CHANNELS_NUMBER*ADC_CHIPS_NUMBER-1);

   signal   hitsMask_i        : slv(ADC_CHANNELS_NUMBER*ADC_CHIPS_NUMBER-1 downto 0) := (others => '0');

   type     SignedArrayType     is array(integer range<>) of signed(ADC_DATA_WIDTH-1 downto 0);
   signal   minAdcArr         : SignedArrayType(0 to ADC_CHANNELS_NUMBER*ADC_CHIPS_NUMBER-1) := (others => (others => '0'));
   
   signal   zsupPolarity_r    : sl; 
   signal   zsupNsamples_r    : slv(9 downto 0);
   signal   smpOverThrCnt     : Word10Array(0 to ADC_CHANNELS_NUMBER*ADC_CHIPS_NUMBER-1);

   ----------------------------------------------
   -- FSM states
   ----------------------------------------------
   type PedStatesType  is (PED_WAIT_STOP_SAMPLE_S, NEXT_SAMPLE_S);
   signal   pedState          : PedStatesType := PED_WAIT_STOP_SAMPLE_S;


begin

   ---------------------------------------------------------------------
   -- take DRS4 pedestals for the current sample
   ---------------------------------------------------------------------
   process (sysClk)
   begin
      if rising_edge (sysClk) then
         pedSubOn_r <= pedSubOn;
         case pedState is
            when PED_WAIT_STOP_SAMPLE_S =>
               pedSmpNumArr_i <= (others => (others => '0'));
               if drsStopSmpValid = '1' then
                  for i in 0 to 7 loop
                     pedSmpNumArr_i(i) <= drsStopSampleArr(i);
                  end loop;
                  pedState <= NEXT_SAMPLE_S;
               end if;

            when NEXT_SAMPLE_S => 
               if drsStopSmpValid = '0' then
                  pedState <= PED_WAIT_STOP_SAMPLE_S;
               end if;
               --if dataValid(0) = '1' and wrEnable = '1' then -- FIXME: AND of dataValid
               if wrEnable_r(0) = '1' then 
                  for i in 0 to 3 loop
                        pedSmpNumArr_i(i) <= std_logic_vector(unsigned(pedSmpNumArr_i(i)) + 1);
                  end loop;
               end if;
               if wrEnable_r(1) = '1' then 
                  for i in 4 to 7 loop
                        pedSmpNumArr_i(i) <= std_logic_vector(unsigned(pedSmpNumArr_i(i)) + 1);
                  end loop;
               end if;
               pedArr_r <= pedArr;
            when others =>
               pedState <= PED_WAIT_STOP_SAMPLE_S;
         end case;
      end if;
   end process;
   pedSmpNumArr <= pedSmpNumArr_i;
   ---------------------------------------------------------------------

   ---------------------------------------------------------------------
   GEN_ADC_CHIP : for iAdc in 0 to ADC_CHIPS_NUMBER-1 generate
      GEN_ADC_CHAN : for iChan in 0 to ADC_CHANNELS_NUMBER-1 generate
         process (sysClk)
            variable adc    : integer := 0;
            variable ped    : integer := 0;
            variable sub    : integer := 0;
            variable min    : integer := 0;
            variable fla    : std_logic_vector(3 downto 0) := (others => '0');
            constant ch : integer := ADC_CHANNELS_NUMBER*iAdc + iChan;
         begin
            if rising_edge (sysClk) then
               
               adc := to_integer(signed(wrData_r(ch)));

               if pedSubOn_r = '1' then
                  ped := to_integer(signed(pedArr_r(ch)));
               else
                  ped := 0;
               end if;

               min := to_integer(subMin) + ped;

               -- make underflow/overflow flags
               if adc < min then
                  -- underflow
                  sub := to_integer(subMin);
                  fla := b"0001";
               elsif adc = subMax then
                  --overflow
                  fla := b"0010";
                  sub := adc;
               else
                  sub := adc - ped;
                  fla := b"0000";
               end if;

               wrDataMerged(iAdc)(16*(iChan+1)-1 downto 16*(iChan)) <= 
                  std_logic_vector(to_signed(sub,ADC_DATA_WIDTH)) & fla;
               adcDataPedSub(ch) <= std_logic_vector(to_signed(sub,ADC_DATA_WIDTH));
               
            end if;
         end process;
      end generate GEN_ADC_CHAN;

      process (sysClk)
      begin
         if rising_edge (sysClk) then
            wrData_r <= wrData;
            wrEnable_r(iAdc) <= wrEnable and dataValid(iAdc);
            wrEnable_2r(iAdc) <= wrEnable_r(iAdc);
         end if;
      end process;

      ---------------------------------------------------
      -- generate BRAM instances
      ---------------------------------------------------
      U_Mem : entity work.bram_sdp 
         generic map (
            DATA  => 16*ADC_CHANNELS_NUMBER, --ADC_DATA_WIDTH * ADC_CHANNELS_NUMBER,
            ADDR  => ADC_DATA_DEPTH
         )
         port map (
            clka  => sysClk,
            wea   => wrEnable_2r(iAdc),
            addra => bufCurAddr(iAdc),
            dina  => wrDataMerged(iAdc),

            clkb  => sysClk,
            addrb => rdAddr_i,
            doutb => localRdData(iAdc)
         );
      ---------------------------------------------------

      ---------------------------------------------------
      -- manage write address
      ---------------------------------------------------
      process(sysClk)
      begin
         if rising_edge(sysClk) then
            if rstWrAddr = '1' then
               bufCurAddr(iAdc) <= (others => '0');
            elsif wrEnable_2r(iAdc) = '1' then 
               bufCurAddr(iAdc) <= std_logic_vector(unsigned(bufCurAddr(iAdc)) + 1);
            end if;
         end if;
      end process;
      ---------------------------------------------------

   end generate GEN_ADC_CHIP;
   ---------------------------------------------------------------------


   ---------------------------------------------------------------------
   -- zero suppression mask
   ---------------------------------------------------------------------
   process (sysClk)
   begin
      if rising_edge (sysClk) then
         if rstWrAddr = '1' then
            zsupPolarity_r <= zsupPolarity;
            zsupNsamples_r <= zsupNsamples;
         end if;
      end if;
   end process;

   GEN_ZEROSUP_ADC_CHIP : for iAdc in 0 to ADC_CHIPS_NUMBER-1 generate
      GEN_ZEROSUP_ADC_CHAN : for iChan in 0 to ADC_CHANNELS_NUMBER-1 generate
         process (sysClk)
            constant ch : integer := ADC_CHANNELS_NUMBER*iAdc + iChan;
         begin
            if rising_edge (sysClk) then
               if rstWrAddr = '1' then
                  hitsMask_i(ch)    <= '0';
                  smpOverThrCnt(ch) <= (others => '0');
               else 
                  if wrEnable_2r(iAdc) = '1' then
                     if zsupPolarity_r = '0' then
                        if signed(adcDataPedSub(ch)) >= signed(zeroThreshArr(ch)) then
                           smpOverThrCnt(ch) <= std_logic_vector(unsigned(smpOverThrCnt(ch)) + 1);
                        end if;
                     else 
                        if signed(adcDataPedSub(ch)) <= signed(zeroThreshArr(ch)) then
                           smpOverThrCnt(ch) <= std_logic_vector(unsigned(smpOverThrCnt(ch)) + 1);
                        end if;
                     end if;
                  end if;
                  if unsigned(smpOverThrCnt(ch)) > unsigned(zsupNsamples_r) then
                     hitsMask_i(ch) <= '1';
                  end if;
               end if;
            end if;
         end process;
      end generate GEN_ZEROSUP_ADC_CHAN;
   end generate GEN_ZEROSUP_ADC_CHIP;

   hitsThrMask <= hitsMask_i;
   ---------------------------------------------------------------------

   process(rdChan_i)
   begin
      if to_integer(unsigned(rdChan_i)) < 32 then
         rdAdc <= 0;
         rdAdcChan_i <= to_integer(unsigned(rdChan_i));
      else
         rdAdc <= 1;
         rdAdcChan_i <= to_integer(unsigned(rdChan_i)) - 32;
      end if;
   end process;

   rdChan_i <= rdEthChan when rdEthEnable = '1' else
             rdChan;
   rdAddr_i <= rdEthAddr when rdEthEnable = '1' else
             rdAddr_regIfc;

   -- read process
   process(sysClk)
   begin
      if rising_edge(sysClk) then
         rdReqR    <= rdReq;
         rdReqRR   <= rdReqR;

         rdAck     <= rdReqR;
         rdData_r  <= localRdData(rdAdc)((rdAdcChan_i+1)*16-1 downto 16*rdAdcChan_i); 
         ethData_r <= localRdData(rdAdc)((rdAdcChan_i+1)*16-1 downto 16*rdAdcChan_i);

         if rdAddr(7 downto 0) = x"01" then
            rdAddr_regIfc <= (others => '0');
         elsif rdReqR = '1' and rdReqRR = '0' then
            rdAddr_regIfc <= std_logic_vector(unsigned(rdAddr_regIfc) + 1); 
         end if;
         curAddr    <= bufCurAddr(0);
      end if;
   end process;

   rdEthData  <= rdData_r;
   rdData <= rdData_r;

end adcBufArch;

