library ieee;
use ieee.std_logic_1164.all;
   use ieee.numeric_std.all;
   use ieee.std_logic_unsigned.all;
library work;
use work.UtilityPkg.all;
use work.LappdPkg.All;

entity LappdEventBuilder is
   generic (
      ADC_DATA_DEPTH    : natural := 10
   );
   port (
      clk               : in sl;
      rst               : in sl;

      trg               : in sl;
      hitsMask          : in slv64; -- mask of the ADC channels to be sent 
      boardID           : in slv(47 downto 0);

      udpStartPort      : in  slv16;
      udpCurrentPort    : out slv16;
      udpNumOfPorts     : in  slv16;

      nSamples          : in slv16;
      nSamplInPacket    : in slv16;  -- FIXME change an name to e..g : ...Max

      adcConvClk        : in sl; -- for syncronisation DRS readout with ADC sampling
      timerClkRaw       : in slv64;

      tAdcChan          : in integer; -- debug FIXME remove
      drsStopSample     : Word10Array(0 to 7);
      drsWaitStart      : in slv16 := (others => '0');

      -- enable buffer read from here, disable reading via reg interface
      rdEnable          : out sl;
      -- addres in the waveform buffer
      rdAddr            : out slv(ADC_DATA_DEPTH-1 downto 0);
      rdChan            : out slv(5 downto 0);
      -- ADC data
      rdData            : in slv(15 downto 0);
      
      -- DRS Control ports
      drsReq            : out sl;
      drsDone           : in sl;
      drsBusy           : in sl;

      -- to/from ex_eth_entity
      ethBusy           : in sl;
      ethReady          : in sl;
      evtTrigger        : out sl;
      evtData           : out slv16;
      evtNFrames        : out integer;

      evtBusy           : out sl;

      debug             : out slv32;
      evtNumber         : out slv32;

      fragDisable       : in  sl -- disable hits fragmentation if high
   );
end entity LappdEventBuilder;

architecture behav of LappdEventBuilder is
   
   -------------------------------------------------------------------------------
   ---------------- FUNCTIONS ----------------------------------------------------
   -------------------------------------------------------------------------------
   
   function fCalcNumberOfHits( hit_mask : slv64) return integer is
      variable cnt   : unsigned(6 downto 0)  := (others => '0');
   begin
      cnt := b"0000000";   
      for i in 0 to 63 loop   
         cnt := cnt + ("000000" & hit_mask(i));
      end loop;

      -- no zero hits at the moment FIXME
      if cnt = b"0000000" then
         cnt := b"0000001";
      end if;
      
      return to_integer(cnt);
   end;

   function fGetDrsNum( adcChn : integer) return integer is
      variable drs : integer := 0;
   begin
      if adcChn >= 0 and adcChn < 8 then
         drs := 0;
      elsif adcChn >= 8 and adcChn < 16 then
         drs := 1;
      elsif adcChn >= 16 and adcChn < 24 then
         drs := 2;
      elsif adcChn >= 24 and adcChn < 32 then
         drs := 3;
      elsif adcChn >= 32 and adcChn < 40 then
         drs := 4;
      elsif adcChn >= 40 and adcChn < 48 then
         drs := 5;
      elsif adcChn >= 48 and adcChn < 56 then
         drs := 6;
      elsif adcChn >= 56 and adcChn < 64 then
         drs := 7;
      else
         drs := 0;
      end if;
      return drs;
   end;

   function fGetNextHit(hit_mask : slv64) return integer is
      variable ind : integer := 0; 
      variable found : boolean := false;
   begin
      for i in 0 to 63 loop   
         if hit_mask(i) = '1' and found = false then
            ind := i;
            found := true;
         end if;
      end loop;
      return ind;
   end;

   function fSwapBytes(ivec : slv16) return slv16 is
      variable ovec : slv16 := (others => '0');
   begin
      ovec := ivec(7 downto 0) & ivec(15 downto 8);
      return ovec;
   end;
   -------------------------------------------------------------------------------

   -------------------------------------------------------------------------------
   ---------------- TYPE DEFENITIONS ---------------------------------------------
   -------------------------------------------------------------------------------
   type StateType is (IDLE_S, TRG_RSVD_S, SEND_DRS_REQ_S, 
                      WAIT_DRS_START_S, WAIT_DRS_FINISH_S, WAIT_EVT_READY_S, 
                      INI_EVT_HDR_S, SND_EVT_HDR_S, 
                      INI_HIT_HDR_S, SND_HIT_HDR_S, SND_HIT_PLD_S, SND_HIT_FTR_S );

   type RegType is record
      state               : StateType;
      evtTrigger          : sl;       -- start UDP transaction
      evtData             : slv16;
      evtSize             : slv16;
      rdDataExt           : slv16;
      rdEnable            : sl;       -- ADC buffer read enable
      hitsMaskCur         : slv64;
      hitsMask            : slv64;
      relOffset           : slv16;
      evtNFrames          : integer;
      iWordCnt            : integer;
      iWordCntTot         : integer;
      seqNum              : slv64;
      iFragment           : integer;
      iHitCnt             : integer;
      hitsNumber          : integer; --slv16;
      adcChannel          : integer; -- currently processed channel
      adcChannelNxt       : integer; -- channel to be processed next
      rdChan              : slv(5 downto 0);
      trgTimestamp        : slv64;
      evtNumber           : slv32;
      nSamples            : integer;
      nSamplInPacket      : integer;
      rdAddr              : slv(ADC_DATA_DEPTH-1 downto 0);
      fragDisable         : sl;
      drsNum              : integer;
      drsStopSample       : slv(9 downto 0);
      drsOffset10         : slv(9 downto 0);
      drsStartCnt         : slv16;
      drsWaitStart        : slv16;
      drsReq              : sl;
      udpStartPort        : slv16;
      udpCurrentPort      : slv16;
      udpPortInc          : slv16;
      udpNumOfPorts       : slv16;
      dbg                 : slv16;
      evtHeaderWordsArray : LappdDataArrayType(0 to C_LappdNumberOfEvtHeaderWords-1);
      hitHeaderWordsArray : LappdDataArrayType(0 to C_LappdNumberOfHitHeaderWords-1);
      evtBusy             : sl; 

   end record;
   
   constant REG_INIT_C : RegType := (
      state               => IDLE_S,
      evtTrigger          => '0',
      evtData             => (others => '0'),
      evtSize             => (others => '0'),
      rdDataExt           => (others => '0'),
      hitsMaskCur         => (others => '0'),
      hitsMask            => (others => '0'),
      relOffset           => (others => '0'),
      rdEnable            => '0',
      evtNFrames          => 0,
      iWordCnt            => 0,
      iWordCntTot         => 0,
      iFragment           => 0,
      seqNum              => (others => '0'),
      iHitCnt             => 0,
      hitsNumber          => 0, --(others => '0'),
      adcChannel          => 0,
      adcChannelNxt       => 0,
      rdChan              => (others => '0'),
      trgTimestamp        => (others => '0'),
      evtNumber           => (others => '0'),
      nSamples            => 0,
      nSamplInPacket      => 0,
      rdAddr              => (others => '0'),
      fragDisable         => '0',
      drsNum              => 0,
      drsStopSample       => (others => '0'),
      drsOffset10         => (others => '0'),
      drsStartCnt         => (others => '0'),
      drsWaitStart        => (others => '0'),
      drsReq              => '0',
      udpStartPort        => (others => '0'),
      udpCurrentPort      => (others => '0'),
      udpPortInc          => (others => '0'),
      udpNumOfPorts       => (others => '0'),
      evtHeaderWordsArray => (others => (others => '0')),
      hitHeaderWordsArray => (others => (others => '0')),
      dbg                 => (others => '0'),
      evtBusy             => '0'
   );
   -------------------------------------------------------------------------------


   -------------------------------------------------------------------------------
   ---------------- SIGNALS   ----------------------------------------------------
   -------------------------------------------------------------------------------
   signal r_cur  : RegType := REG_INIT_C;
   signal r_nxt  : RegType := REG_INIT_C;
   signal clkCnt : slv64   := (others => '0');
   -------------------------------------------------------------------------------

begin

   -----------------------------------------------
   -- temporary. TODO switch to EeveeTimer timestamping
   -----------------------------------------------
   --process (clk)
   --begin
      --if rising_edge (clk) then
         --if rst = '1' then
            --clkCnt <= (others => '0');
         --else
            --clkCnt <= clkCnt + 1;
         --end if;
      --end if;
   --end process;
   -----------------------------------------------



   process(trg, r_cur, drsBusy, ethBusy, rdData, ethReady, nSamples, nSamplInPacket, tAdcChan, fragDisable, 
           drsWaitStart, drsStopSample, adcConvClk, hitsMask, boardID, timerClkRaw, drsDone, 
           udpStartPort, udpNumOfPorts)
      variable evtHeader : LappdEvtHeaderFormat := C_EvtHeaderZero;
      variable hitHeader : LappdHitHeaderFormat := C_HitHeaderZero;
      variable evtHeaderWordsArray : LappdDataArrayType(0 to C_LappdNumberOfEvtHeaderWords-1) := (others => (others => '0'));
      variable hitHeaderWordsArray : LappdDataArrayType(0 to C_LappdNumberOfHitHeaderWords-1) := (others => (others => '0'));
   begin
      evtHeader := C_EvtHeaderZero;
      hitHeader := C_HitHeaderZero;
      evtHeaderWordsArray := (others => (others => '0'));
      hitHeaderWordsArray := (others => (others => '0'));

      --r_nxt.rdDataExt    <=  rdData & (15-G_ADC_BIT_WIDTH downto 0 => '0');

      r_nxt <= r_cur;
      case r_cur.state is 

         when IDLE_S =>
            r_nxt.state         <= IDLE_S;
            r_nxt.rdEnable      <= '0';
            r_nxt.evtNFrames    <= 0;
            r_nxt.relOffset     <= (others => '0');
            r_nxt.iWordCnt      <= 0;
            r_nxt.iWordCntTot   <= 0;
            r_nxt.iFragment     <= 0;
            r_nxt.iHitCnt       <= 0;
            r_nxt.hitsNumber    <= 0; --(others => '0');
            r_nxt.rdAddr        <= (others => '0');
            r_nxt.evtTrigger    <= '0';
            r_nxt.dbg           <= (others => '0');
            r_nxt.drsOffset10   <= (others => '0');
            r_nxt.evtData       <= (others => '0');
            r_nxt.drsStartCnt   <= (others => '0');
            r_nxt.drsWaitStart  <= drsWaitStart;
            r_nxt.drsReq        <= '0';
            r_nxt.adcChannelNxt <= 0;
            r_nxt.trgTimestamp  <= (others => '0');

            r_nxt.fragDisable   <= fragDisable;
            r_nxt.hitsMask      <= hitsMask;
            r_nxt.hitsMaskCur   <= hitsMask;
            r_nxt.udpNumOfPorts <= udpNumOfPorts;
            r_nxt.evtBusy       <= '0';

            r_nxt.udpStartPort  <= udpStartPort; -- little endian from MB
            if r_cur.udpCurrentPort = x"0000" then
               r_nxt.udpCurrentPort <= udpStartPort;
            end if;

            if trg = '1' and ethBusy = '0' and drsBusy = '0' then
               r_nxt.state      <= TRG_RSVD_S;
               r_nxt.evtBusy  <= '1';
            end if;

            if nSamples <= x"0400"  then
               r_nxt.nSamples       <= to_integer(unsigned(nSamples));
            else
               r_nxt.nSamples       <= 1024;
            end if;

            if nSamples <= nSamplInPacket then
               r_nxt.nSamplInPacket <= to_integer(unsigned(nSamples));
            else 
               r_nxt.nSamplInPacket <= to_integer(unsigned(nSamplInPacket));
            end if;


         when TRG_RSVD_S =>
            --r_nxt.seqNum        <= (others => '0');
            r_nxt.adcChannel <= fGetNextHit(r_cur.hitsMask);
            r_nxt.state      <= SEND_DRS_REQ_S;
            if r_cur.udpNumOfPorts = x"0000" or udpNumOfPorts = x"0001" then
               r_nxt.udpCurrentPort <= r_cur.udpStartPort;
            else
               if r_cur.udpPortInc >= r_cur.udpNumOfPorts then
                  r_nxt.udpPortInc <= x"0001"; --(others => '0');
                  r_nxt.udpCurrentPort <= r_cur.udpStartPort;
               else
                  r_nxt.udpPortInc     <= r_cur.udpPortInc + 1;
                  r_nxt.udpCurrentPort <= r_cur.udpStartPort + fSwapBytes(r_cur.udpPortInc);
               end if;
            end if;
            r_nxt.evtBusy  <= '1';

         -- start DRS4 readout sequence
         when SEND_DRS_REQ_S => 
            r_nxt.hitsNumber <= fCalcNumberOfHits(r_cur.hitsMask);
            if r_cur.drsStartCnt = r_cur.DrsWaitStart then
               if adcConvClk = '0' then
                  r_nxt.drsReq <= '1';
                  r_nxt.state <= WAIT_DRS_START_S;
                  -- timestamp here
                  r_nxt.trgTimestamp <= timerClkRaw;
               end if;
            else
               r_nxt.drsStartCnt <= r_cur.drsStartCnt + 1;
            end if;


         -- trigger received wait uniti DRS started to process 
         when WAIT_DRS_START_S =>
            r_nxt.dbg <= X"0001";
            r_nxt.rdEnable <= '1';
            if drsBusy = '1' then
               r_nxt.state <= WAIT_DRS_FINISH_S;
               r_nxt.drsNum <= fGetDrsNum(r_cur.adcChannel);
            end if;

         -- wait until DRS4 finished to process input signals
         when WAIT_DRS_FINISH_S =>
            r_nxt.dbg <= X"0002";
            if drsDone = '1' then
               r_nxt.state  <= WAIT_EVT_READY_S;
               r_nxt.drsReq <= '0';
               r_nxt.drsStopSample <= drsStopSample(r_cur.drsNum);
            end if;
         
         -- prepare some event data
         when WAIT_EVT_READY_S =>
            r_nxt.evtSize <= std_logic_vector(to_unsigned(r_cur.hitsNumber*r_cur.nSamples*2, 16));
            --r_nxt.state   <= INI_EVT_HDR_S;
            r_nxt.state   <= INI_HIT_HDR_S;

         
         -- initialize hit header
         when INI_HIT_HDR_S =>
            r_nxt.dbg <= X"0005";
            hitHeader.board_id      := boardID;
            --hitHeader.board_id      := x"123456789abc";
            hitHeader.rel_offset    := r_cur.relOffset;
            hitHeader.seqnum        := r_cur.seqNum;
            hitHeader.event_num     := r_cur.evtNumber;
            hitHeader.trigger_low   := r_cur.trgTimestamp(31 downto 0);
            hitHeader.channel_mask  := r_cur.hitsMask;
            hitHeader.num_payload_samples  := std_logic_vector(to_unsigned(r_cur.nSamplInPacket,16));
            hitHeader.channel       := std_logic_vector(to_unsigned(r_cur.adcChannel,16));
            hitHeader.num_samples   := std_logic_vector(to_unsigned(r_cur.nSamples,16)); 
            hitHeader.drs4_stop     := std_logic_vector(to_unsigned(0,6)) & r_cur.drsStopSample;


            makeHitHeaderDataArray(hitHeader, hitHeaderWordsArray);
            r_nxt.hitHeaderWordsArray <= hitHeaderWordsArray;
            r_nxt.rdChan  <= std_logic_vector(to_unsigned(r_cur.adcChannel,6));

            -- mark hit as processed
            r_nxt.hitsMaskCur(r_cur.adcChannel) <= '0';

            --r_nxt.evtNFrames <= C_LappdNumberOfHitHeaderWords + r_cur.nSamplInPacket + 1; -- +1 for footer
            r_nxt.evtNFrames <= C_LappdNumberOfHitHeaderWords + r_cur.nSamplInPacket;

            if ethBusy = '0' then
               r_nxt.evtTrigger <= '1';
               r_nxt.iWordCnt <= r_cur.iWordCnt + 1; 
               --r_nxt.evtData <= fSwapBytes(hitHeaderWordsArray(r_cur.iWordCnt));
               r_nxt.evtData <= hitHeaderWordsArray(r_cur.iWordCnt);
               r_nxt.state  <= SND_HIT_HDR_S;
               r_nxt.seqNum <= r_cur.seqNum + 1;
               --if r_cur.udpCurrentPort = r_cur.udpStartPort then
                  --r_nxt.seqNum <= r_cur.seqNum + 1;
               --end if;
            end if;

         -- send hit header
         when SND_HIT_HDR_S =>
            r_nxt.dbg <= X"0006";
            r_nxt.evtTrigger <= '0';
            r_nxt.adcChannelNxt  <= fGetNextHit(r_cur.hitsMaskCur);

            if ethReady = '1' then
               r_nxt.iWordCnt <= r_cur.iWordCnt + 1; 
               --r_nxt.evtData <= fSwapBytes(r_cur.hitHeaderWordsArray(r_cur.iWordCnt));      
               r_nxt.evtData <= r_cur.hitHeaderWordsArray(r_cur.iWordCnt);      
               if r_cur.iWordCnt = C_LappdNumberOfHitHeaderWords-2 then
                  r_nxt.rdAddr   <= r_cur.rdAddr + 1;
               end if;
               if r_cur.iWordCnt = C_LappdNumberOfHitHeaderWords-1 then
                  r_nxt.rdAddr   <= r_cur.rdAddr + 1;
                  r_nxt.state     <= SND_HIT_PLD_S;
                  r_nxt.iWordCnt  <= 0;
               end if;
            end if;

         -- send hit payloads
         when SND_HIT_PLD_S =>
            r_nxt.dbg <= X"0007";
            --r_nxt.evtData  <= fSwapBytes(rdData & (15-G_ADC_BIT_WIDTH downto 0 => '0'));
            --r_nxt.evtData  <= rdData & (15-G_ADC_BIT_WIDTH downto 0 => '0');
            r_nxt.evtData  <= rdData;

            if r_cur.iWordCnt = r_cur.nSamplInPacket then
               --r_nxt.evtData  <= fSwapBytes(C_HIT_FOOTER_MAGIC);
               r_nxt.iFragment <= r_cur.iFragment + 1;
               r_nxt.relOffset <= r_cur.relOffset + std_logic_vector(to_unsigned(r_cur.nSamplInPacket,16)) ;
               r_nxt.state     <= SND_HIT_FTR_S;
               r_nxt.drsNum    <= fGetDrsNum(r_cur.adcChannelNxt);
            else
               r_nxt.rdAddr      <= r_cur.rdAddr      + 1;
               r_nxt.iWordCnt    <= r_cur.iWordCnt    + 1; 
               r_nxt.iWordCntTot <= r_cur.iWordCntTot + 1; 
            end if;

         -- send hit footer
         when SND_HIT_FTR_S => 
            r_nxt.dbg <= X"0008";
            if r_cur.iWordCntTot >= r_cur.nSamples or r_cur.fragDisable = '1' then
               r_nxt.rdAddr      <= (others => '0');
               r_nxt.iHitCnt     <= r_cur.iHitCnt + 1;
               if r_cur.iHitCnt = r_cur.hitsNumber - 1 then
                  -- finished
                  r_nxt.evtNumber <= r_cur.evtNumber + 1;
                  r_nxt.state       <= IDLE_S; 
               else
                  -- send next hit
                  r_nxt.iWordCnt      <= 0;
                  r_nxt.iWordCntTot   <= 0;
                  r_nxt.iFragment     <= 0;
                  r_nxt.adcChannel    <= r_cur.adcChannelNxt;
                  r_nxt.drsOffset10   <= drsStopSample(r_cur.drsNum);
                  r_nxt.drsStopSample <= drsStopSample(r_cur.drsNum);
                  r_nxt.state         <= INI_HIT_HDR_S;
                  r_nxt.relOffset     <= (others => '0');
               end if;
            else
               -- send next fragment
               r_nxt.drsOffset10 <= r_cur.drsStopSample + 
                                      std_logic_vector(to_unsigned(r_cur.iFragment*r_cur.nSamplInPacket, 10));
               r_nxt.nSamplInPacket <= r_cur.nSamples - r_cur.iWordCnt; 
               r_nxt.rdAddr      <= r_cur.rdAddr    - 1; -- FIXME
               r_nxt.state       <= INI_HIT_HDR_S;
               r_nxt.iWordCnt  <= 0;
            end if;

         when others => 
            r_nxt.dbg <= X"FFFF";
            r_nxt.state <= IDLE_S; 
      end case;

   end process;


   process(clk) 
   begin
      if rising_edge(clk) then
         if rst = '1' then
            r_cur <= REG_INIT_C;
         else
            r_cur <= r_nxt;
         end if;
      end if;
   end process;

   ------ outputs -------------------
   debug              <= r_cur.dbg & std_logic_vector(to_unsigned(r_cur.iWordCnt,16));
   evtTrigger         <= r_cur.evtTrigger; 
   evtData            <= r_cur.evtData;
   evtNFrames         <= r_cur.evtNFrames;
   rdEnable           <= r_cur.rdEnable;
   rdAddr             <= r_cur.rdAddr;
   drsReq             <= r_cur.drsReq;
   rdChan             <= r_cur.rdChan;

   evtBusy            <= r_cur.evtBusy;
   evtNumber          <= r_cur.evtNumber;
   
   udpCurrentPort     <= r_cur.udpCurrentPort;
   ----------------------------------
   

end behav;
