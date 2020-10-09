----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/27/2016 05:20:23 PM
-- Design Name: 
-- Module Name: DrsControl - Behavioral
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
use work.UtilityPkg.all;
--use ieee.std_logic_arith.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;

entity DrsControl is
   generic (
      NCHIPS                 : integer := 1;
      SR_CLOCK_HALF_PERIOD_G : integer := 2;
      GATE_DELAY_G           : time    := 1 ns
   ); 
   port ( 
      -- System clock and reset
      sysClk        : in  sl;
      sysRst        : in  sl;

      adcSync       : in  sl;
      refClkRatio   : in slv(31 downto 0);

      -- User requests
      regMode       : in  sl; -- 0 for config reg, 1 for write reg
      regData       : in  slv(7 downto 0);
      regReq        : in  sl;
      regAck        : out sl;

      -- Perform the normal readout sequence
      readoutReq    : in  sl;
      readoutAck    : out sl;
      nSamples      : in  slv(11 downto 0); -- bit 11 full RO flag
      phaseAdcSrClk : in  slv(3 downto 0);
      validPhase    : in  slv(5 downto 0);
      srClkCutOff   : in  slv(15 downto 0) := (others => '1');
      waitAfterAddr : in  slv(15 downto 0) := (others => '0');  
      waitBeforeIni : in  slv(15 downto 0) := (others => '0');

      stopSample    : out Word10Array(0 to NCHIPS-1);
      stopSmpValid  : out sl;

      validDelay    : in  slv(5 downto 0) := (others => '0');
      sampleValid   : out sl;

      -- modes
      transModeOn   : in  sl;
      DEnable       : in  sl;
      
      -- DRS4 address & serial interfacing
      drsRefClkN    : out sl;
      drsRefClkP    : out sl;
      drsAddr       : out slv(3 downto 0);
      drsSrClk      : out sl;
      drsSrIn       : out sl;
      drsRsrLoad    : out sl;
      drsSrOut      : in  slv(NCHIPS-1 downto 0);
      drsDWrite     : out sl;
      drsDEnable    : out sl;
      drsPllLck     : in  slv(NCHIPS-1 downto 0);

      drsBusy       : out sl
   );
end DrsControl;

architecture Behavioral of DrsControl is

   type StateType     is (IDLE_S,
                          LOAD_CONFIG_S, NEXT_CONFIG_S, DONE_CONFIG_S,
                          STOP_WRITE_S, 
                          WAIT_BEFORE_INI_S, DATA_INI_FULL_S, NEXT_INI_FULL_S,
                          ADC_SYNC_S, TUNE_ADC_PHASE_S,
                          DATA_RD_FULL_S,  NEXT_DATA_RD_FULL_S,
                          DATA_RSR_S, DATA_RSR_NEXT_S, 
                          READOUT_DATA_S, NEXT_DATA_S,
                          WAIT_AFTER_ADDR_S,
                          REMAINDER_DATA_S, WAIT_DONE_DATA_S, DONE_DATA_S, 
                          CLEANUP_S, NEXT_CLEANUP_S);
   
   type RegType is record
      state        : StateType;
      addr         : slv(3 downto 0);
      srClk        : sl;
      srIn         : sl;
      rsrLoad      : sl;
      dWrite       : sl;
      dEnable      : sl;
      regData      : slv(7 downto 0);
      regAck       : sl;
      dataAck      : sl;
      nSamples     : slv(10 downto 0);
      fullWF       : sl;
      stopSample   : Word10Array(0 to NCHIPS-1);
      stopSmpValid : sl;
      sampleValid  : sl;
      waitCount    : slv(15 downto 0);
      validPhase   : slv(5 downto 0);
      validCount   : slv(7 downto 0);
      bitCount     : slv(9 downto 0);
      drsBusy      : sl;
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      state        => IDLE_S,
      addr         => (others => '1'),
      srClk        => '0',
      srIn         => '0',
      rsrLoad      => '0',
      dWrite       => '0',
      dEnable      => '0',
      regData      => (others => '0'),
      regAck       => '0',
      dataAck      => '0',
      fullWF       => '0',
      nSamples     => (others => '0'),
      stopSample   => (others => (others => '0')),
      stopSmpValid => '0',
      sampleValid  => '0',
      waitCount    => (others => '0'),
      validPhase   => (others => '0'),
      validCount   => (others => '0'),
      bitCount     => (others => '0'),
      drsBusy      => '0'
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

   signal iRefClk          : sl;
   signal iSrClk           : sl;

   signal sampleValidQ : slv(63 downto 0);

   constant TRANSP_ADDR_C  : slv(3 downto 0) := "1010";
   constant RDSHIFT_ADDR_C : slv(3 downto 0) := "1011";
   constant CONFIG_ADDR_C  : slv(3 downto 0) := "1100";
   constant WRITE_ADDR_C   : slv(3 downto 0) := "1101";
   constant STANDBY_ADDR_C : slv(3 downto 0) := "1111";
   constant READALL_ADDR_C : slv(3 downto 0) := "1001";

   attribute IOB : string;                               
   attribute IOB of drsRefClkP         : signal is "TRUE";    
   attribute IOB of drsRefClkN         : signal is "TRUE";    

begin

   comb : process( r, sysRst, regData, regReq, readoutReq, nSamples, DEnable, drsSrOut, phaseAdcSrClk, 
                   validPhase, srClkCutOff, waitBeforeIni, waitAfterAddr, transModeOn, regMode, adcSync) is
      variable v : RegType;
   begin
      v := r;

      -- Resets for pulsed outputs
      v.regAck      := '0';
      v.dataAck     := '0';
      v.sampleValid := '0';
      
      -- State machine 
      case(r.state) is 
         when IDLE_S =>
            if transModeOn = '1' then 
               v.addr      := TRANSP_ADDR_C;
            else
               --v.addr      := RDSHIFT_ADDR_C;
               v.addr      := READALL_ADDR_C;
               --v.addr      := STANDBY_ADDR_C;
            end if;
            v.srClk        := '0';
            v.srIn         := '0';
            v.rsrLoad      := '0';
            v.fullWF       := '0';
                           
            v.drsBusy      := '0';

            v.stopSmpValid := '0';


            if DEnable = '1' then
               v.dWrite    := '1';
               v.dEnable   := '1';
            elsif DEnable = '0' then
               v.dWrite := '0';
               if r.dWrite = '0' then
                  v.dEnable := '0';
               end if;
            end if;

            
            v.validCount := (others => '0');
            v.waitCount  := (others => '0');
            v.bitCount   := (others => '0');
            if RegReq = '1' then
               v.regData    := regData;
               if regMode = '0' then
                  v.addr    := CONFIG_ADDR_C;
               else
                  v.addr    := WRITE_ADDR_C;
               end if;
               v.state      := LOAD_CONFIG_S;
               --v.drsBusy     := '1';
            elsif readoutReq = '1' then
               if nSamples > x"400" then 
                  v.fullWF   := '1';
                  v.nSamples := std_logic_vector(to_unsigned(1023,11)); 
               else
                  v.nSamples := nSamples(10 downto 0) - 1;
                  v.fullWF   := '0';
               end if;
               v.validPhase := validPhase;
         --      v.addr     := READALL_ADDR_C;
               v.state    := STOP_WRITE_S;
            end if;

         when LOAD_CONFIG_S =>
            v.drsBusy     := '1';
            v.srIn := r.regData(7-conv_integer(r.bitCount));
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G then
               v.waitCount := r.waitCount + 1;
            else
               v.srClk     := '1';
               v.waitCount := (others => '0');
               v.state     := NEXT_CONFIG_S;
            end if;

         when NEXT_CONFIG_S =>
            v.drsBusy     := '1';
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G then
               v.waitCount := r.waitCount + 1;
            else
               v.srClk     := '0';
               v.waitCount := (others => '0');
               if r.bitCount < 7 then
                  v.bitCount := r.bitCount + 1;
                  v.state    := LOAD_CONFIG_S;
               else
                  v.bitCount := (others => '0');
                  v.state    := DONE_CONFIG_S;
               end if;
            end if;            

         when DONE_CONFIG_S =>
            v.drsBusy   := '1';
            v.srClk     := '0';
            v.srIn      := '0';
            v.regAck := '1';
            if regReq = '0' then
               v.regAck := '0';
               v.state     := IDLE_S;
            end if; 

         when STOP_WRITE_S =>
            v.drsBusy   := '1';
            v.dWrite  := '0';
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G then
               v.waitCount := r.waitCount + 1;
            else
               v.waitCount := (others => '0');
               v.state     := WAIT_BEFORE_INI_S;
               if r.fullWF = '1' then
                  -- Full waveform readout
                  v.addr   := RDSHIFT_ADDR_C;
                  --v.state  := WAIT_BEFORE_INI_S; 
               else
                  -- ROI readout 
                  v.addr     := READALL_ADDR_C;
                  --v.state    := DATA_RSR_S;
               end if;
            end if;            
            v.stopSample := (others => (others => '0'));

         when WAIT_BEFORE_INI_S =>  -- debug TODO : remove
            v.drsBusy     := '1';
            v.srClk       := '0';
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G-1 then
               v.waitCount := r.waitCount + 1;
            else
               v.waitCount := (others => '0');
               if r.fullWF = '1' then
                  -- Full waveform readout
                  v.addr      := RDSHIFT_ADDR_C;
                  v.state     := DATA_INI_FULL_S;
               else
                  -- ROI readout 
                  v.addr     := READALL_ADDR_C;
                  v.state    := ADC_SYNC_S;
               end if;
            end if;

         when ADC_SYNC_S => 
            if adcSync = '1' then
               v.state     := TUNE_ADC_PHASE_S;
               v.waitCount := (others => '0');
            end if;

         when TUNE_ADC_PHASE_S => 
            if r.waitCount < phaseAdcSrClk  then
               v.waitCount := r.waitCount + 1;
            else
               v.waitCount := (others => '0');
               if r.fullWF = '1' then
                  -- Full waveform readout
                  --v.addr      := READALL_ADDR_C;
                  v.state     := WAIT_AFTER_ADDR_S;
               else
                  -- ROI readout 
                  v.addr     := READALL_ADDR_C;
                  v.state    := DATA_RSR_S;
               end if;
            end if;
            

         -- ROI readout
         when DATA_RSR_S =>   
            v.drsBusy   := '1';
            if r.waitCount < srClkCutOff then
               v.rsrLoad := '1';
            else
               v.rsrLoad := '0';
            end if;
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G-1 then
               v.waitCount := r.waitCount + 1;
            else
               --v.rsrLoad   := '0';
               v.waitCount := (others => '0');
               v.state     := DATA_RSR_NEXT_S;
            end if;            
         when DATA_RSR_NEXT_S =>   
            v.drsBusy   := '1';
            v.rsrLoad := '0';
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G-1 + waitAfterAddr then
               v.waitCount := r.waitCount + 1;
            else
               v.rsrLoad   := '0';
               v.waitCount := (others => '0');
               v.state     := READOUT_DATA_S;
            end if;            
            v.validCount:= (others => '0');

         when READOUT_DATA_S => 
            v.drsBusy   := '1';
            if r.bitCount < r.nSamples then
               if r.waitCount < srClkCutOff then
                  v.srClk     := '1';
               else
                  v.srClk     := '0';
               end if;
            else
               v.srClk     := '0';
            end if;
            if r.stopSmpValid = '0' then 
               if (r.bitCount < 10) then
                  for iChip in NCHIPS-1 downto 0 loop
                     v.stopSample(iChip)(9 - conv_integer(r.bitCount)) := drsSrOut(iChip);
                  end loop;
               end if;
            end if;
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G-1 then
               v.waitCount := r.waitCount + 1;
            else
               v.waitCount := (others => '0');
               v.state     := NEXT_DATA_S;
            end if;

            if r.stopSmpValid = '1' then
               if r.validPhase = b"111111" then
                  v.sampleValid := '1';
               else
                  if r.validCount(7 downto 2) = r.validPhase then
                     v.sampleValid := '1';
                  else
                     v.sampleValid := '0';
                  end if;
               end if;
            end if;
            v.validCount := r.validCount + 1;

         when NEXT_DATA_S => 
            v.drsBusy   := '1';
            --v.sampleValid := '1';
            v.srClk       := '0';
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G-1 then
               v.waitCount := r.waitCount + 1;
               v.validCount := r.validCount + 1;
            else
               v.validCount:= (others => '0');
               v.waitCount := (others => '0');

               if r.bitCount < r.nSamples then
                  v.bitCount := r.bitCount + 1;
                  v.state    := READOUT_DATA_S;
               else
                  v.bitCount := (others => '0');
                  v.state    := WAIT_DONE_DATA_S;
               end if;

               if r.stopSmpValid = '0' then 
                  if (r.bitCount = 9) then
                     v.bitCount := (others => '0');
                     v.state := DATA_RSR_S; 
                     v.stopSmpValid := '1';
                  end if;
               end if;
            end if;      

            if r.stopSmpValid = '1' then
               if r.validPhase = b"111111" then
                  v.sampleValid := '1';
               else
                  if r.validCount(7 downto 2) = r.validPhase then
                     v.sampleValid := '1';
                  else
                     v.sampleValid := '0';
                  end if;
               end if;
            end if;


         -- Full readout initialization 
         when DATA_INI_FULL_S => 
            v.drsBusy   := '1';
            v.srClk       := '1';
            if r.bitCount = r.nSamples then
               v.srIn := '1';
            else
               v.srIn := '0';
            end if;
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G-1 then
               v.waitCount := r.waitCount + 1;
            else
               v.waitCount := (others => '0');
               v.state     := NEXT_INI_FULL_S;
            end if;

         when NEXT_INI_FULL_S => 
            v.drsBusy   := '1';
            --if r.waitCount = 1 then
               --v.srIn        := '0';
            --end if;
            v.srClk       := '0';
            if r.bitCount = r.nSamples then
               v.srIn := '1';
            end if;

            if r.waitCount < SR_CLOCK_HALF_PERIOD_G-1 then
               v.waitCount := r.waitCount + 1;
            else
               v.waitCount := (others => '0');
               if r.bitCount < r.nSamples then
                  v.bitCount := r.bitCount + 1;
                  v.state    := DATA_INI_FULL_S;
               else
                  v.bitCount := (others => '0');
                  v.state    := ADC_SYNC_S;
                  --v.addr     := READALL_ADDR_C;
                  v.srIn := '0';
               end if;
            end if;      

         when WAIT_AFTER_ADDR_S => 
            v.addr      := READALL_ADDR_C;
            v.drsBusy   := '1';
            v.srClk       := '0';
            if r.waitCount < 2*SR_CLOCK_HALF_PERIOD_G-1 + waitAfterAddr  then
               v.waitCount := r.waitCount + 1;
            else
               v.waitCount := (others => '0');
               v.state    := DATA_RD_FULL_S;
            end if;      
            v.validCount:= (others => '0');

         -- Full waveform readout
         when DATA_RD_FULL_S => 
            v.drsBusy   := '1';

            if r.waitCount < srClkCutOff then
               v.srClk       := '1';
            else
               v.srClk       := '0';
            end if;

            if r.validPhase = b"111111" then
               v.sampleValid := '1';
            else
               if r.validCount(7 downto 2) = r.validPhase then
                  v.sampleValid := '1';
               else
                  v.sampleValid := '0';
               end if;
            end if;
            v.validCount := r.validCount + 1;
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G-1 then
               v.waitCount := r.waitCount + 1;
            else
               v.waitCount := (others => '0');
               v.state     := NEXT_DATA_RD_FULL_S;
            end if;


         when NEXT_DATA_RD_FULL_S => 
            v.drsBusy   := '1';
            if r.validPhase = b"111111" then
               v.sampleValid := '1';
            else
               if r.validCount(7 downto 2) = r.validPhase then
                  v.sampleValid := '1';
               else
                  v.sampleValid := '0';
               end if;
            end if;
            --v.sampleValid := '1';
            v.srClk       := '0';
            if r.waitCount < SR_CLOCK_HALF_PERIOD_G-1 then
               v.waitCount := r.waitCount + 1;
               v.validCount := r.validCount + 1;
            else
               v.validCount:= (others => '0');
               v.waitCount := (others => '0');
               if r.bitCount < r.nSamples then
                  v.bitCount := r.bitCount + 1;
                  v.state    := DATA_RD_FULL_S;
               else
                  v.bitCount := (others => '0');
                  --v.state    := DONE_DATA_S;
                  v.state    := WAIT_DONE_DATA_S;
               end if;
            end if;      

         when WAIT_DONE_DATA_S =>
            v.addr      := TRANSP_ADDR_C;
            v.drsBusy   := '1';
            v.sampleValid := '0';
            if r.waitCount < 20*SR_CLOCK_HALF_PERIOD_G-1 then
               v.waitCount := r.waitCount + 1;
            else
               v.state    := DONE_DATA_S;
            end if;      

         
         when DONE_DATA_S => 
            v.drsBusy := '1';
            v.srClk   := '0';
            v.srIn    := '0';
            v.dataAck := '1';
            v.waitCount := (others => '0');
            if readoutReq = '0' then
               v.dataAck := '0';
               v.state   := CLEANUP_S;
               v.addr    := RDSHIFT_ADDR_C;
            end if;

         when CLEANUP_S => 
            v.drsBusy   := '1';
            v.srClk       := '1';
            v.srIn := '0';
            if r.waitCount < 1 then  -- FIXME hadcoded
               v.waitCount := r.waitCount + 1;
            else
               v.waitCount := (others => '0');
               v.state     := NEXT_CLEANUP_S;
            end if;

         when NEXT_CLEANUP_S => 
            v.drsBusy   := '1';
            v.srClk       := '0';

            if r.waitCount < 1 then -- FIXME hadcoded
               v.waitCount := r.waitCount + 1;
            else
               v.waitCount := (others => '0');
               if r.bitCount < 1023 then
                  v.bitCount := r.bitCount + 1;
                  v.state    := CLEANUP_S;
               else
                  v.bitCount := (others => '0');
                  v.state    := IDLE_S;
                  v.srIn := '0';
               end if;
            end if;      
         when others =>
            v.state := IDLE_S;
      end case;

      -- Reset logic
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Outputs to ports
      regAck        <= r.regAck;
      readoutAck    <= r.dataAck;
      stopSample    <= r.stopSample;
      --sampleValid   <= r.sampleValid;
      drsAddr       <= r.addr;
      drsSrIn       <= r.srIn;
      drsRsrLoad    <= r.rsrLoad;
      drsDWrite     <= r.dWrite;
      drsDEnable    <= r.dEnable;
      stopSmpValid  <= r.stopSmpValid;
      iSrClk        <= r.srClk;

      -- Assignment of combinatorial variable to signal
      rin <= v;

   end process;
   drsSrClk      <= iSrClk;

   drsBusy       <= r.drsBusy;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         if sysRst = '1' then
            r <= REG_INIT_C;
         else 
            r <= rin after GATE_DELAY_G;
         end if;
      end if;
   end process seq;

   U_RefClk : entity work.clk_div 
   port map (
      clk       => sysClk,
      rst       => sysRst,
      ratio     => refClkRatio,
      strb      => '0',

      clkdiv    => iRefClk,
      hb        => open,
      sync_strb => open
   );

   FDRE_REFP : FDRE
   generic map (   
      INIT => '0'
   )  
   port map (   
      D  => iRefClk,
      C  => sysClk,
      CE => '1',
      R  => '0',
      Q  => drsRefClkP
   );

   FDRE_REFN : FDRE
   generic map (   
      INIT => '0'
   )  
   port map (   
      D  => not iRefClk,
      C  => sysClk,
      CE => '1',
      R  => '0',
      Q  => drsRefClkN
   );

   --drsRefClkP <= iRefClk;
   --drsRefClkN <= not iRefClk;

   process (sysClk)
   begin
      if rising_edge (sysClk) then
         sampleValidQ <= sampleValidQ(62 downto 0) & rin.sampleValid;
      end if;
   end process;
   sampleValid <= sampleValidQ(to_integer(unsigned(validDelay)));


end Behavioral;
