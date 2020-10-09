library ieee;
    use ieee.std_logic_1164.all;
library work;
    use work.UtilityPkg.all;

------------------------------------------------
-- package LappdPkg
------------------------------------------------
package LappdPkg is

    constant G_ADC_BIT_WIDTH : integer  := 12;
    constant G_ADC_BIT_DEPTH : integer  := 10;
    constant G_N_ADC_CHIPS   : integer  := 2;
    constant G_N_ADC_LINES   : integer  := 16;
    constant G_N_ADC_CHN     : integer  := G_N_ADC_LINES * 2;
    constant G_N_CHN_TOT     : integer  := G_N_ADC_CHN*G_N_ADC_CHIPS;
    constant G_N_DRS         : integer  := 8;
    --constant G_TOT_ADC_CHN   : integer  := G_N_ADC_LINES*G_N_ADC_CHIPS; 

    subtype AdcDataType     is std_logic_vector(G_ADC_BIT_WIDTH-1 downto 0);
    type    AdcDataArray    is array(integer range<>) of AdcDataType;
    subtype AdcDataArrayL   is AdcDataArray(G_N_ADC_LINES*2-1 downto 0);
    type    AdcData2DArray  is array(integer range<>) of AdcDataArrayL;

    type AdcInvertMaskType is array(0 to 1) of slv16;
    constant G_ADCDOUT_INVERT_MASK1 : std_logic_vector(15 downto 0) := (0 => '1', 7 => '1', 8 => '1', 15 => '1', others => '0');
    constant G_ADCDOUT_INVERT_MASK2 : std_logic_vector(15 downto 0) := (2 => '1', 3 => '1', 4 => '1', 7 => '1',  others => '0');
    constant G_ADCDOUT_INVERT_MASK  : AdcInvertMaskType := (0 => G_ADCDOUT_INVERT_MASK1, 1 => G_ADCDOUT_INVERT_MASK2);
    type LappdCmdType is record
      Reset    : sl;
      adcClear : sl;
      adcStart : sl;
      adcTxTrg : sl;
      adcReset : sl;
    end record;

   constant G_LappdCmdZero : LappdCmdType := (
      Reset    => '0',
      adcClear => '0', 
      adcStart => '0', 
      adcTxTrg => '0',
      adcReset => '0'
   );


    type LappdStatusType is record
        DummyStat    : slv32;
        adcDebug     : slv32;
        adcBufDebug  : slv32;
        adcWordsWrtn : slv32;
        adcDelayDebug: slv32;
    end record;

    type LappdConfigType is record 
        adcNumWordsToWrite : slv32;
        adcDataDelay       : slv(4 downto 0);
        adcClkDelay        : slv(4 downto 0);
    end record;

    constant LappdConfigDefaults : LappdConfigType := (
        adcNumWordsToWrite => X"0000_000F",
        adcDataDelay       => (others => '0'),
        adcClkDelay        => b"01111" 
    );

   -------------------------------------------------------------
   -- LAPPD header format:
   -------------------------------------------------------------
   -- EVT_HEADER_MAGIC_WORD (16 bits) - just pick something easily readable in the hex stream for now
   -- BOARD_ID (48 bits)              - Low 48 bits of the Xilinx Device DNA, also equal to the board MAC address apart from a broadcast bit.
   -- EVT_TYPE (8 bits)               - encode ADC bit width, compression level if any, etc.
   -- ADC_BIT_WIDTH (3 bits)
   -- RESERVED (5 bits)
   -- EVT_NUMBER (16 bits)            - global event identifier, assumed sequential
   -- EVT_SIZE (16 bits)              - event size in bytes
   -- NUM_HITS (8 bits)               - for easy alignment and reading
   -- TRIGGER_TIMESTAMP_H (32-bits)
   -- TRIGGER_TIMESTAMP_L (32-bits)
   -- RESERVED (64-bits)
   -------------------------------------------------------------

   constant C_EVT_HEADER_MAGIC : std_logic_vector(15 downto 0) := X"39AB";
   type LappdDataArrayType   is array(integer range<>) of std_logic_vector(15 downto 0);

   type LappdEvtHeaderFormat is record
      magic            : std_logic_vector(15 downto 0);
      board_id         : std_logic_vector(47 downto 0);
      evt_type         : std_logic_vector(7  downto 0);
      adc_bit_width    : std_logic_vector(2  downto 0);
      reserved         : std_logic_vector(7  downto 0);
      evt_number       : std_logic_vector(15 downto 0);
      evt_size         : std_logic_vector(15 downto 0);
      num_hits         : std_logic_vector(7  downto 0);
      trg_timestamp_h  : std_logic_vector(31 downto 0);
      trg_timestamp_l  : std_logic_vector(31 downto 0);
      reserved2        : std_logic_vector(63 downto 0);
   end record;
   
   constant C_EvtHeaderZero : LappdEvtHeaderFormat := (
      magic           =>  (others => '0'),
      board_id        =>  (others => '0'), 
      evt_type        =>  (others => '0'), 
      adc_bit_width   =>  (others => '0'), 
      reserved        =>  (others => '0'), 
      evt_number      =>  (others => '0'), 
      evt_size        =>  (others => '0'), 
      num_hits        =>  (others => '0'), 
      trg_timestamp_h =>  (others => '0'), 
      trg_timestamp_l =>  (others => '0'), 
      reserved2       =>  (others => '0') 
   );

   constant C_LappdNumberOfEvtHeaderWords : natural := 16;
   procedure makeEvtHeaderDataArray(variable i : in  LappdEvtHeaderFormat; 
                                    variable o : out LappdDataArrayType(0 to C_LappdNumberOfEvtHeaderWords-1) );


   -------------------------------------------------------------
   -- LAPPD hit format
   -------------------------------------------------------------
   -- HIT_MAGIC (16 bits) (2 bytes)
   -- CHANNEL_ID (8 bits) (1 byte)
   -- DRS4_OFFSET (12 bits) (1.5 bytes)
   -- SEQ (4 bits) (0.5 bytes)
   -- HIT_PAYLOAD_SIZE (16 bits, representing byte length of all seq packet payloads WITHIN THIS HIT)
   -- TRIGGER_TIMESTAMP_L (32 bits) (4 bytes)
   -- ----------------------------------- (bitstruct for the above fixed header, 11 bytes)
   -- PAYLOAD (arbitrary, but less than an Ethernet MTU for sure)
   -- HIT_FOOTER_MAGIC (16 bits)
   -------------------------------------------------------------
   constant C_HIT_HEADER_MAGIC : std_logic_vector(15 downto 0) := X"039A";
   --constant C_HIT_FOOTER_MAGIC : std_logic_vector(15 downto 0) := X"000B";
   constant C_HIT_FOOTER_MAGIC : std_logic_vector(15 downto 0) := X"0400";

   type LappdHitHeaderFormat is record
      -- assembly part
      board_id           : std_logic_vector(47 downto 0);
      rel_offset         : std_logic_vector(15 downto 0);
      seqnum             : std_logic_vector(63 downto 0);
      -- header
      event_num          : std_logic_vector(31 downto 0);
      trigger_low        : std_logic_vector(31 downto 0);
      channel_mask       : std_logic_vector(63 downto 0);
      -- channel
      num_payload_samples           : std_logic_vector(15 downto 0);
      channel            : std_logic_vector(15 downto 0);
      num_samples        : std_logic_vector(15 downto 0);
      drs4_stop          : std_logic_vector(15 downto 0);

   end record;

   constant C_HitHeaderZero : LappdHitHeaderFormat := (
      -- assembly part
      board_id          =>  (others => '0'),
      rel_offset        =>  (others => '0'), 
      seqnum            =>  (others => '0'), 
      -- header
      event_num         =>  (others => '0'), 
      trigger_low       =>  (others => '0'), 
      channel_mask      =>  (others => '0'), 
      -- channel
      num_payload_samples  =>  (others => '0'), 
      channel           =>  (others => '0'), 
      num_samples       =>  (others => '0'), 
      drs4_stop         =>  (others => '0')
      --magic            =>  (others => '0'),
      --channel_id       =>  (others => '0'),
      --drs4_offset      =>  (others => '0'),
      --seq              =>  (others => '0'),
      --payload_size     =>  (others => '0'),
      --trg_timestamp_l  =>  (others => '0')
   );

   constant C_LappdNumberOfHitHeaderWords : natural := 20; --6;
   procedure makeHitHeaderDataArray(variable i : in  LappdHitHeaderFormat; 
                                    variable o : out LappdDataArrayType(0 to C_LappdNumberOfHitHeaderWords-1) );


end package LappdPkg;
----------------------------------------------


package body LappdPkg is
   procedure makeHitHeaderDataArray(variable i : in  LappdHitHeaderFormat; 
                                    variable o : out LappdDataArrayType(0 to C_LappdNumberOfHitHeaderWords-1) ) is
   begin
      --o(0)  := i.board_id(47 downto 32);
      --o(1)  := i.board_id(31 downto 16);
      --o(2)  := i.board_id(15 downto 0);
      --o(3)  := i.rel_offset(15 downto 0);
      --o(4)  := i.seqnum(63 downto 48);
      --o(5)  := i.seqnum(47 downto 32);
      --o(6)  := i.seqnum(31 downto 16);
      --o(7)  := i.seqnum(15 downto 0);
      --o(8)  := i.event_num(31 downto 16);
      --o(9)  := i.event_num(15 downto 0);
      --o(10) := i.trigger_low(31 downto 16);
      --o(11) := i.trigger_low(15 downto 0);
      --o(12) := i.channel_mask(63 downto 48);
      --o(13) := i.channel_mask(47 downto 32);
      --o(14) := i.channel_mask(31 downto 16);
      --o(15) := i.channel_mask(15 downto 0);
      --o(16) := i.reserved(23 downto 16);
      --o(17) := i.reserved(7 downto 0) & i.channel(7 downto 0);
      --o(18) := i.num_samples(15 downto 0);
      --o(19) := i.drs4_stop(15 downto 0);

      o(0)  := i.board_id(15 downto 0);
      o(1)  := i.board_id(31 downto 16);
      o(2)  := i.board_id(47 downto 32);
      o(3)  := i.rel_offset(15 downto 0);
      o(4)  := i.seqnum(15 downto 0);
      o(5)  := i.seqnum(31 downto 16);
      o(6)  := i.seqnum(47 downto 32);
      o(7)  := i.seqnum(63 downto 48);
      o(8)  := i.event_num(15 downto 0);
      o(9)  := i.event_num(31 downto 16);
      o(10) := i.trigger_low(15 downto 0);
      o(11) := i.trigger_low(31 downto 16);
      o(12) := i.channel_mask(15 downto 0);
      o(13) := i.channel_mask(31 downto 16);
      o(14) := i.channel_mask(47 downto 32);
      o(15) := i.channel_mask(63 downto 48);
      --o(16) := i.reserved(23 downto 8);
      o(16) := i.num_payload_samples(15 downto 0);
      o(17) := i.channel(15 downto 0);
      o(18) := i.num_samples(15 downto 0);
      o(19) := i.drs4_stop(15 downto 0);
      --o(0) := i.magic(15 downto 0);
      --o(1) := i.channel_id(7 downto 0) & i.drs4_offset(15 downto 8);
      --o(2) := i.drs4_offset(7 downto 0) & i.seq(7 downto 0);
      --o(3) := i.payload_size(15 downto 0);
      --o(4) := i.trg_timestamp_l(31 downto 16);
      --o(5) := i.trg_timestamp_l(15 downto  0);
   end makeHitHeaderDataArray;
   
   procedure makeEvtHeaderDataArray(variable i : in  LappdEvtHeaderFormat; 
                                    variable o : out LappdDataArrayType(0 to C_LappdNumberOfEvtHeaderWords-1) ) is
   begin
      o(0)  := i.magic(15 downto 0);
      o(1)  := i.board_id(47 downto 32);
      o(2)  := i.board_id(31 downto 16);
      o(3)  := i.board_id(15 downto 0);
      o(4)  := i.reserved(7 downto 0) & i.adc_bit_width(2 downto 0) & i.reserved(4 downto 0);  --i.evt_type(7 downto 0) & i.adc_bit_width(2 downto 0) & i.reserved(4 downto 0);
      o(5)  := i.evt_number(15 downto 0);
      o(6)  := i.evt_size(15 downto 0);
      o(7)  := i.num_hits(7 downto 0)  & X"00";
      o(8)  := i.trg_timestamp_h(31 downto 16);
      o(9)  := i.trg_timestamp_h(15 downto 0);
      o(10) := i.trg_timestamp_l(31 downto 16);
      o(11) := i.trg_timestamp_l(15 downto 0);
      o(12) := i.reserved2(63 downto 48);
      o(13) := i.reserved2(47 downto 32);
      o(14) := i.reserved2(31 downto 16);
      o(15) := i.reserved2(15 downto 0);
   end makeEvtHeaderDataArray;


end package body LappdPkg;



