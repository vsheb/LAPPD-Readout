----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/13/2019 01:53:50 AM
-- Design Name: 
-- Module Name: tb_eth - Behavioral
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


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.UtilityPkg.all;
use work.LappdPkg.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


entity tb_eth is
end tb_eth;

architecture Behavioral of tb_eth is

   constant clock_period : time := 20 ns;
   signal clk : std_logic;

   signal userTxData      : slv(7 downto 0);
   signal userTxDataValid : sl;
   signal userTxDataLast  : sl;
   signal userTxDataReady : sl;

   signal adcBufEthEna      : sl := '0';
   signal adcBufEthAddrInc  : sl := '0';
   signal adcBufEthAddrRst  : sl := '0';
   signal adcBufEthAddr     : slv(7 downto 0)           := (others => '0');
   signal adcBufEthChan     : slv(5 downto 0)           := (others => '0');
   signal adcBufEthData     : slv16; --slv(11 downto 0); --: AdcDataArray(0 downto 0) := (others => (others => '0'));

   signal eventBuilderTrg : std_logic := '0';
   signal ethEvtData      : std_logic_vector(15 downto 0) := (others => '0');
   signal ethEvtTrigger   : std_logic := '0';
   signal ethEvtNumberOfFrames : integer := 0;
   signal ethEvtReady     : std_logic := '0';
   signal ethEvtBusy      : sl := '0';
   signal drsBusy         : sl := '0';
   signal drsRdReq        : sl := '0';
   signal drsRdAck        : sl := '0';

   signal drsCnt          : slv16 := (others => '0');

   signal trg             : std_logic := '0';
   signal axi_dout        :   std_logic_vector(15 downto 0);
   signal axi_valid       :   std_logic;
   signal axi_last        :   std_logic;
   signal axi_keep        :   std_logic_vector(1 downto 0);
   signal axi_ready       :   std_logic;

   signal wrEna           :   std_logic;
   signal wrData          :   AdcDataArray(0 to 1) := (others => (others => '0'));

   signal udpCurrentPort  : slv16 := (others => '0');
   signal udpNumOfPorts   : slv16 := (others => '0');

   signal cnt            : std_logic_vector(3 downto 0) := (others => '0');

begin

   -------------------------------------------------
   -- ADC buffer
   -------------------------------------------------
   U_AdcBuffer : entity work.AdcBuffer
   generic map(
      ADC_CHIPS_NUMBER    => 1,
      ADC_CHANNELS_NUMBER => 2,
      ADC_DATA_WIDTH      => 12,
      ADC_DATA_DEPTH      => 8 
   )
   port map(
      sysClk        => clk, --adcDataClk,
      sysRst        => '0', 

      rstWrAddr        => '0',


      WrEnable      => wrEna,
      dataValid     => (others => '1'),
      wrData        => wrData,

      pedArr          => (others => (others => '0')),
      pedSmpNumArr    => open,
      drsStopSampleArr => (others => (others => '0')),
      drsStopSmpValid  => '0',

      rdEthEnable      => adcBufEthEna,
      rdEthAddr        => adcBufEthAddr,
      rdEthChan        => adcBufEthChan,
      rdEthData        => adcBufEthData,

      -- reg interface
      rdChan        => (others => '0'),
      rdAddr        => (others => '0'),
      rdReq         => '0',
      rdAck         => open,
      rdData        => open,

      -- debug      
      curAddr       => open,
      nWordsWrtn    => open

   );

   -------------------------------------------------
   -- Event builder
   -------------------------------------------------
   U_EventBuilder : entity work.LappdEventBuilder
      generic map (
         ADC_DATA_DEPTH => 8 
      )
      port map (
         clk               => clk,
         rst               => '0',
                       
         trg               => trg,
         hitsMask          =>  X"0000_0000_0000_000" & b"0011",
         boardID           => (others => '1'),

         udpStartPort      => x"3000", 
         udpCurrentPort    => udpCurrentPort, 
         udpNumOfPorts     => x"0004",
   

         nSamples          => X"0010", --X"0008",
         nSamplInPacket    => x"0008", --x"0200", --X"0004",
         drsWaitStart      => x"0000",

         adcConvClk        => '0',

         tAdcChan          => 0,

         rdEnable          => adcBufEthEna,
         rdAddr            => adcBufEthAddr,
         rdChan            => adcBufEthChan,
         rdData            => adcBufEthData,
         timerClkRaw       => (others => '0'),

         drsStopSample     => (others => (others => '0')),

         drsReq            => drsRdReq,
         drsDone           => drsRdAck,

         drsBusy           => drsBusy,
         ethBusy           => ethEvtBusy,
         evtTrigger        => ethEvtTrigger,
         evtData           => ethEvtData,
         evtNFrames        => ethEvtNumberOfFrames,
         ethReady          => ethEvtReady,
         fragDisable       => '0'
      );
   -------------------------------------------------

   UUT : entity work.ex_eth_entity
      port map(
         clk                   => clk, 
         rst                   => '0',
         user_event_trigger    => ethEvtTrigger, 
         user_event_data       => ethEvtData,
         user_number_of_frames => ethEvtNumberOfFrames,
         user_event_ready      => ethEvtReady,
         DstMac                => X"AA_01_23_45_67_89",
         SrcMac                => X"BB_01_23_45_67_89",
         SrcIP                 => x"CCCC_1234",
         DstIP                 => x"DDDD_1234", 
         -- udp_header values supplied by microblaze
         UDP_DstPort => X"5555", 
         UDP_SrcPort => X"6666", 
         ----------------------------------------------------------------------
         -- I/O to axis stream fifo
         axis_data_stream_out  => axi_dout, --: out std_logic_vector(31 downto 0);
         axis_data_valid       => axi_valid, --: out std_logic;
         axis_data_last        => axi_last, --: out std_logic;
         axis_data_keep        => axi_keep, ----: out std_logic_vector(3 downto 0);
         axis_fifo_ready       => axi_ready, ----: in  std_logic
         busy                  => ethEvtBusy 
      );

   U_uBlazeWrapper : entity work.base_mb_wrapper
      port map (
         S_AXIS_1G_tdata  => (others => '0'),
         S_AXIS_1G_tready => open,
         S_AXIS_1G_tvalid => '0',
         S_AXIS_1G_tlast  => '0',
         reg_tkeep        => X"F",

         -- Pins that will eventually connect elsewhere on the boad
         S_AXIS_DATAOUT_tdata  => axi_dout,
         S_AXIS_DATAOUT_tvalid => axi_valid,
         S_AXIS_DATAOUT_tlast  => axi_last,
         S_AXIS_DATAOUT_tkeep  => axi_keep,
         S_AXIS_DATAOUT_tready => axi_ready,

         CLKIN_125 => clk,

         -- Drive reset to zero
         reset => '0',

         -- Wire the M_AXIS (master axi stream)

         -- to the PHY with the uBlaze produced outs 
         M_AXIS_1G_tdata  => userTxData,
         M_AXIS_1G_tvalid => userTxDataValid,
         M_AXIS_1G_tlast  => userTxDataLast,
         M_AXIS_1G_tready => userTxDataReady,

         -- Wire in the IO port
         IO_BUS_addr_strobe  => open, --out
         IO_BUS_address      => open,
         IO_BUS_byte_enable  => open,
         IO_BUS_read_data    => (others => '0'),
         IO_BUS_read_strobe  => open,
         IO_BUS_ready        => '0',
         IO_BUS_write_data   => open,
         IO_BUS_write_strobe => open 

         -- Wire in the bus reset
         --bus_struct_reset => bus_struct_reset                   
      );
   
      

   clk_proc : process                      
   begin                                     
      clk <= '0';                            
      wait for clock_period/2;                 
      clk <= '1';                            
      wait for clock_period/2;                 
   end process;                              
   
   drs : process(clk)
   begin
      if rising_edge(clk) then
         drsRdAck <= '0';
         if drsRdReq = '1' and drsBusy = '0' then
            drsBusy <= '1';
         end if;
         if drsBusy = '1' then
            drsCnt <= drsCnt + 1;
         end if;
         if drsCnt = x"0010" then
            drsBusy <= '0';
            drsRdAck <= '1';
            drsCnt <= (others => '0');
         end if;
      end if;
   end process;

   stim : process
   begin
      
      wait for 1000 ns;
      userTxDataReady <= '1';
      wait until clk = '1';
      wrEna <= '1';
      wrData(0) <= std_logic_vector(to_unsigned(1,12));
      wrData(1) <= std_logic_vector(to_unsigned(8,12));
      wait until clk = '1';
      wrEna <= '1';
      wrData(0) <= std_logic_vector(to_unsigned(2,12));
      wrData(1) <= std_logic_vector(to_unsigned(7,12));
      wait until clk = '1';
      wrEna <= '1';
      wrData(0) <= std_logic_vector(to_unsigned(3,12));
      wrData(1) <= std_logic_vector(to_unsigned(6,12));
      wait until clk = '1';
      wrEna <= '1';
      wrData(0) <= std_logic_vector(to_unsigned(4,12));
      wrData(1) <= std_logic_vector(to_unsigned(5,12));
      wait until clk = '1';
      wrEna <= '1';
      wrData(0) <= std_logic_vector(to_unsigned(5,12));
      wrData(1) <= std_logic_vector(to_unsigned(4,12));
      wait until clk = '1';
      wrEna <= '1';
      wrData(0) <= std_logic_vector(to_unsigned(6,12));
      wrData(1) <= std_logic_vector(to_unsigned(3,12));
      wait until clk = '1';
      wrEna <= '1';
      wrData(0) <= std_logic_vector(to_unsigned(7,12));
      wrData(1) <= std_logic_vector(to_unsigned(2,12));
      wait until clk = '1';
      wrEna <= '1';
      wrData(0) <= std_logic_vector(to_unsigned(8,12));
      wrData(1) <= std_logic_vector(to_unsigned(1,12));
      wait until clk = '1';
      wrData(0) <= std_logic_vector(to_unsigned(9,12));
      wrData(1) <= std_logic_vector(to_unsigned(8,12));
      wait until clk = '1';
      wrData(0) <= std_logic_vector(to_unsigned(10,12));
      wrData(1) <= std_logic_vector(to_unsigned(7,12));
      wait until clk = '1';
      wrData(0) <= std_logic_vector(to_unsigned(11,12));
      wrData(1) <= std_logic_vector(to_unsigned(6,12));
      wait until clk = '1';
      wrData(0) <= std_logic_vector(to_unsigned(12,12));
      wrData(1) <= std_logic_vector(to_unsigned(5,12));
      wait until clk = '1';
                        
      wrEna <= '0';

      wait for 500 ns;
      wait until clk = '1';
      trg <= '1';
      wait until clk = '1';
      trg <= '0';


      wait for 10 us;

   end process;


end Behavioral;



