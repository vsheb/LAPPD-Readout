library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
use work.LappdPkg.all;
use work.RegDefs.all;

entity RegControl is
   generic (
      GATE_DELAY_G : time := 1 ns;
      FAIL_WORD_G  : slv(31 downto 0) := x"4641494C";
      TIMEOUT_G    : unsigned(23 downto 0) := x"EE6B28" -- 100 ms timeout 
   );
   port (
      -- Clock and synchronous reset
      clk            : in  sl;
      sRst           : in  sl;
      -- Register interface to Microblaze IO module
      regAddr        : in  slv(31 downto 0);
      regAddrStrb    : in  sl;
      regWrStrb      : in  sl;
      regRdStrb      : in  sl;
      regReady       : out sl;
      regWrData      : in  slv(31 downto 0);
      regRdData      : out slv(31 downto 0);
      regDataByteEn  : in  slv(3 downto 0);

      -- status and configuration registers
      lappdCmd       : out LappdCmdType;
      regArrayOut    : out tRegDataArray(0 to NREG-1);
      regArrayIn     : in  tRegDataArray(0 to NREG-1);

      timerClkRaw    : out slv64;

      -- ADC buffer IO
      adcBufReq      : out sl;
      adcBufAck      : in  sl;
      adcBufAddr     : out slv(G_ADC_BIT_DEPTH-1 downto 0);
      adcBufData     : in  slv32;

      -- Pedestals memory
      drsPedReq      : out sl;
      drsPedWrEn     : out sl;
      drsPedAck      : in  sl;
      drsPedAddr     : out slv(15 downto 0); -- chan & addr
      drsPedWrData   : out slv(G_ADC_BIT_WIDTH-1 downto 0);
      drsPedRdData   : in  slv(G_ADC_BIT_WIDTH-1 downto 0);

      -- DRS regs
      drsRegMode     : out slv(1 downto 0); -- only two regsiters: 0--config 1--write, 2--writeconf
      drsRegData     : out slv(7 downto 0);
      drsRegReq      : out sl;
      drsRegAck      : in sl;

      
      -- DAC serial IO
      dacSclk   : out sl;
      dacCsb    : out sl;
      dacSin    : out sl;
      dacSout   : in  sl;

      -- ADC serial IO
      adcSclk   : out sl;
      adcCsb    : out slv(1 downto 0);
      adcSin    : out sl;
      adcSout   : in  sl

   );
end RegControl;

architecture Behavioral of RegControl is

   signal iRegAck    : sl;
   signal iRegRdData : slv(31 downto 0);

   type StateType is (IDLE_S, READ_S, WRITE_S, WAIT_S);

   type RegType is record
      state     : StateType;
      regAddr   : slv(31 downto 0);
      regWrData : slv(31 downto 0);
      regRdData : slv(31 downto 0);
      regReq    : sl;
      regOp     : sl;
      regReady  : sl;
      timer     : unsigned(23 downto 0);
   end record;
   
   constant REG_INIT_C : RegType := (
      state     => IDLE_S,
      regAddr   => (others => '0'),
      regWrData => (others => '0'),
      regRdData => (others => '0'),
      regReq    => '0',
      regOp     => '0',
      regReady  => '0',
      timer     => (others => '0')
   );
   
   signal curReg : RegType := REG_INIT_C;
   signal nxtReg : RegType := REG_INIT_C;

begin
   
   regReady <= curReg.regReady;
   regRdData <= curReg.regRdData;
   
   -- Asynchronous state logic
   process(curReg, regAddr, regAddrStrb, regWrStrb, regRdStrb, regWrData, regDataByteEn, iRegAck, iRegRdData) begin
      -- Set defaults
      nxtReg          <= curReg;
      nxtReg.regReq   <= '0';
      nxtReg.regReady <= '0';
      -- Actual state definitions
      case(curReg.state) is
         when IDLE_S  =>
            nxtReg.timer   <= (others => '0');
            if regAddrStrb = '1' then
               nxtReg.regAddr <= regAddr;
            end if;
            if regWrStrb = '1' then
               nxtReg.regReq    <= '1';
               nxtReg.regWrData <= regWrData;
               nxtReg.regOp     <= '1';
               nxtReg.state     <= WRITE_S;
            end if;
            if regRdStrb = '1' then
               nxtReg.regReq    <= '1';
               nxtReg.regOp     <= '0';
               nxtReg.state     <= READ_S;
            end if;
         when READ_S  =>
            nxtReg.timer  <= curReg.timer + 1;
            nxtReg.regReq <= '1';
            if iRegAck = '1' then
               nxtReg.regRdData <= iRegRdData;
               nxtReg.regReq    <= '0';
               nxtReg.state     <= WAIT_S;
            elsif curReg.timer = TIMEOUT_G then
               nxtReg.regRdData <= FAIL_WORD_G;
               nxtReg.regReq    <= '0';
               nxtReg.state     <= WAIT_S;
            end if; 
         when WRITE_S =>
            nxtReg.regReq <= '1';
            nxtReg.timer  <= curReg.timer + 1;
            if iRegAck = '1' then
               nxtReg.regReq <= '0';
               nxtReg.state  <= WAIT_S;
            elsif curReg.timer = TIMEOUT_G then
               nxtReg.regReq <= '0';
               nxtReg.state  <= WAIT_S;               
            end if;
         when WAIT_S =>
            nxtReg.regReq <= '0';
            if iRegAck = '0' then
               nxtReg.regReady <= '1';
               nxtReg.state    <= IDLE_S;
            end if;
         when others  =>
            nxtReg.state <= IDLE_S;
      end case;         
   end process;
   
   -- Synchronous part of state machine, including reset
   process(clk) begin
      if rising_edge(clk) then
         if (sRst = '1') then
            curReg <= REG_INIT_C after GATE_DELAY_G;
         else
            curReg <= nxtReg after GATE_DELAY_G;
         end if;
      end if;
   end process;

   -----------------------------------------
   -- Interface to main register map here --
   -----------------------------------------
   U_RegMap : entity work.RegMap
      port map (
         clk           => clk,
         sRst          => sRst,

         regAddr       => curReg.regAddr,
         regWrData     => curReg.regWrData,
         regRdData     => iRegRdData,
         regReq        => curReg.regReq,
         regOp         => curReg.regOp,
         regAck        => iRegAck,

         lappdCmd      => lappdCmd,
         regArrayIn    => regArrayIn,
         regArrayOut   => regArrayOut,

         timerClkRaw   => timerClkRaw,

         adcBufReq     => adcBufReq, 
         adcBufAck     => adcBufAck,
         adcBufData    => adcBufData,
         adcBufAddr    => adcBufAddr,

         -- Pedestals memory
         drsPedReq     => drsPedReq,
         drsPedWrEn    => drsPedWrEn, 
         drsPedAck     => drsPedAck,  
         drsPedAddr    => drsPedAddr, 
         drsPedWrData  => drsPedWrData,
         drsPedRdData  => drsPedRdData,

         -- DRS regs
         drsRegMode    => drsRegMode,
         drsRegData    => drsRegData,
         drsRegReq     => drsRegReq,
         drsRegAck     => drsRegAck,

                -- DAC serial IO
         dacSclk   => dacSclk, --: out sl;
         dacCsb    => dacCsb, --: out sl;
         dacSin    => dacSin, -- out sl;
         dacSout   => dacSout, -- in  sl;

         adcSclk   => adcSclk, --: out sl;
         adcCsb    => adcCsb, --: out sl;
         adcSin    => adcSin, -- out sl;
         adcSout   => adcSout -- in  sl;

      );

end Behavioral;
