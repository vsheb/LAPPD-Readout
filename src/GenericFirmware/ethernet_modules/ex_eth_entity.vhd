-------------------------------------------------------------------------------
-- Title      : Example Architecture of Ethernet Package
-- Project    :
-------------------------------------------------------------------------------
-- File       : ex_eth_entity.vhd
-- Author     : Kevin Keefe
-- Company    :
-- Created    : 2019-04-23
-- Last update: 2019-09-13
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: it is strongly recommended to use this package in conjuction
-- with userBufferEthBRAM.vhd.. The reason for this is the the data input stream of
-- this module assumes that there are no packets lost after user_event trigger
-- goes high.. So if you send in data on user_event_data, this module will read
-- from that stream equal to the value of user_number_of_frames during the
-- first time user_event_trigger goes high. Afterwards, this state will read
-- and send packets for exactly that long.. If you do not know if your data
-- stream will be uninterrupted , or if you do not know how many data words you
-- will send at the same time you trigger this module, connect your data first
-- to userBufferEthBRAM, and then tie the output ports of userBufferEthBRAM to
-- the input ports of this one.
--
-- The main reason this module has been made separate from
-- userBufferEthBRAM.vhd is that if the user knows immediately and always how
-- many data words they will send, then there is no need to spend a full frame
-- time counting the frames to put onto the ethHeader. Thus, there is faster
-- output data to use this module without userBufferEthBRAM..
--
-- if you want to use this module without userBufferEthBRAM your data must be
-- able to do the following:

-- First : you need to be able to determine number of 32b words your data
-- packet not including the ETH / IPv4 / UDP header lengths. This header
-- assumes all of the data you are sending is kept, thus the total bytes you
-- will ship is your number of wordsx4 (32bit words = 4 bytes).

-- Second : The data stream that this FSM connects to is an axis-stream which
-- includes the following ports: data / data_keep / data_last / data_ready / data_valid.
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-04-23  1.0      kevinkeefe      Created
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

--include the ethernet package - ensure you've added this file to your design..
use work.ex_pkg.ALL;

entity ex_eth_entity is

   generic (
      GATE_DELAY  : time    := 2ns;
      buffer_size : integer := 1024;  -- how many frames to hold while building header
      -- only currently supported size
      frame_size  : integer := 16);  -- how many bits the frame being sent is.
   port (
      -- use the clk where the data is coming in on..
      clk                   : in  std_logic;
      rst                   : in  std_logic;  -- include a user rst if you wish
      ----------------------------------------------------------------------
      -- user FSM supplies these three pins
      user_event_trigger    : in std_logic;                      -- begin build when high
      user_event_data       : in std_logic_vector(15 downto 0);  -- stream data
      user_number_of_frames : in integer;                        -- total int number of frames to be received
      user_event_ready      : out std_logic;                     -- gotta know if
                                                               -- we're sending
                                                               -- or not
      ----------------------------------------------------------------------
      -- eth_header values supplied by microblaze
      DstMac                : in  std_logic_vector(47 downto 0);
      SrcMac                : in  std_logic_vector(47 downto 0);
      -- ipv4_header values supplied by microblaze
      SrcIP                 : in  std_logic_vector(31 downto 0);
      DstIP                 : in  std_logic_vector(31 downto 0);
      -- udp_header values supplied by microblaze
      UDP_DstPort           : in  std_logic_vector(15 downto 0);
      UDP_SrcPort           : in  std_logic_vector(15 downto 0);
      ----------------------------------------------------------------------
      -- I/O to axis stream fifo
      axis_data_stream_out  : out std_logic_vector(15 downto 0);
      axis_data_valid       : out std_logic;
      axis_data_last        : out std_logic;
      axis_data_keep        : out std_logic_vector(1 downto 0);
      axis_fifo_ready       : in  std_logic;

      busy : out std_logic
   );

end entity ex_eth_entity;

architecture behavioral of ex_eth_entity is

   type StateType is (
      IDLE, INI1, INI2, ETH_HEADER_S, USER_DATA_FRAMES_S, DONE_S
   );

   type USER_FSM is record
      state             : StateType;
      user_FSM_control  : natural;  -- controls output state of packet
      we                : std_logic;
      en                : std_logic;
      user_Data_out     : std_logic_vector(15 downto 0);  -- values sent out to fifo
      user_data_hold    : std_logic_vector(15 downto 0);
      user_Data_in      : std_logic_vector(15 downto 0);  -- values sent out to fifo
      user_DataValid    : std_logic;      -- indicates ready state of packets
      user_DataKeep     : std_logic_vector(1 downto 0);  -- for axis fifo, keep bytes
      user_dataReady    : std_logic;
      user_data_last    : std_logic;
      user_data_interrupt : boolean;
      -- control values for the user buffer
      user_buffer_write : unsigned(9 downto 0);
      user_buffer_read  : unsigned(9 downto 0);
      -- count and max determine how many frames to send from the user data..
      user_buffer_count : integer;
      user_buffer_max   : integer;
      user_buffer_maxm1 : integer;
      fsm_eth_header    : ethernet_values; -- record type in eth package
      busy              : std_logic;
   end record USER_FSM;

   signal eth_header : ethernet_values := EMPTY_ETH_HEADER;

   constant HIT_INIT_C : USER_FSM := (
      state             => IDLE,
      user_FSM_control  => 0,
      we => '0',
      en => '0',
      user_Data_out     => (others => '0'),
      user_data_hold    => (others => '0'),
      user_Data_in      => (others => '0'),
      user_DataValid    => '0',
      user_DataKeep     => (others => '0'),
      user_dataReady    => '0',
      user_data_last    => '0',
      user_data_interrupt => false,
      -- control values for the user buffer
      user_buffer_write => (others => '0'),
      user_buffer_read  => (others => '0'),
      user_buffer_count => 0,
      user_buffer_max   => 0,
      user_buffer_maxm1 => 0,
      fsm_eth_header    => EMPTY_ETH_HEADER,
      busy              => '0'
   );

   -- define the fsm signals
   signal r   : USER_FSM := HIT_INIT_C;
   signal rin : USER_FSM;

   constant data_frame_byte_size   : integer                       := 2;
   --constant PacketID  : std_logic_vector(15 downto 0) := x"D191";

   signal bram_out    : std_logic_vector(15 downto 0) := (others => '0');
   signal bram_buffer : std_logic_vector(15 downto 0) := (others => '0');
   signal chksm : unsigned(31 downto 0);

begin  -- architecture behavioral

-- instantiate a version of the BRAM component
BRAM_1 : entity work.eth_simple_dual_port_BRAM
   port map(
      -- connect the BRAM control members
      cLk => clk,
      en     => r.en,
      we     => r.we,
      addr_i => std_logic_vector(r.user_buffer_write),
      addr_o => std_logic_vector(r.user_buffer_read),
      di     => r.user_Data_in,
      -- get the output stored into a signal
      do     => bram_out);

   process (clk)
   begin
      if rising_edge (clk) then
         eth_header.DstMac       <= DstMac;
         eth_header.SrcMac       <= SrcMac;
         eth_header.SrcIP        <= SrcIP;
         eth_header.DstIP        <= DstIP;
         eth_header.UDP_DstPort  <= UDP_DstPort;
         eth_header.UDP_SrcPort  <= UDP_SrcPort;
         CalcIPv4CheckSum1(eth_header.SrcIP, eth_header.DstIP, chksm);
      end if;
   end process;


   eth_header_FSM : process (DstMac, DstIP,
                            SrcIP, SrcMac,
                            UDP_DstPort, UDP_SrcPort,
                            axis_fifo_ready, r, rst,
                            user_event_data, user_event_trigger,
                            user_number_of_frames, bram_out, eth_header, chksm) is
       variable v : USER_FSM;
  begin  -- process eth_header_FSM

      v                := r;
      -- Resets for pulsed outputs
      --v.user_DataValid := '0';
      v.en := '0';
      v.we := '0';


      case r.state is

         -- waiting for packets
         when IDLE =>
            v.busy           := '0';
            v                := HIT_INIT_C;
            v.fsm_eth_header       := eth_header;
            v.user_buffer_max   := user_number_of_frames; -- set max buffer position


            -- move to begin building ethernet frames
            if (user_event_trigger = '1' and axis_fifo_ready = '1') then
               v.busy              := '1';
               v.state             := INI1;
               v.user_FSM_control  := 0;  -- make sure that the state count starts at 0

               -- read data --
               v.user_Data_in      := user_event_data;                    -- get the header word
               v.user_data_hold    := user_event_data; 							-- first word to send
            end if;
         
         when INI1 =>
             v.busy              := '1';
             if r.user_buffer_max > 0 then
               v.user_buffer_maxm1 := r.user_buffer_max - 1;
             else
                v.user_buffer_maxm1 := 0;
             end if;
             v.user_buffer_max   := r.user_buffer_max; -- set max buffer position
             -- calculate the eth values we need before we go into the frame
             -- eth_procedure to calculate IPv4 / UDP lengths - little endian calculation
             CalcEthHeaderLength(data_frame_byte_size, 
                                 r.user_buffer_max, 
                                 v.fsm_eth_header.EthPacketLength, 
                                 v.fsm_eth_header.UDPPacketLength);
             v.state             := INI2;
              v.user_dataReady := '1';        -- data only ready in this state

         when INI2 =>
             -- IPv4 Checksum Calculation - little endian calculation
             v.busy              := '1';
             CalcIPv4CheckSum2(
                              r.fsm_eth_header.EthPacketLength, 
                              chksm,
                              v.fsm_eth_header.IPv4_ChkSum);

             v.state             := ETH_HEADER_S;
             v.en                := '1';
             v.we                := '1';


         -- begin building the enter eth / ipv4 / udp headers
         when ETH_HEADER_S =>

            v.busy := '1';
            v.en := '1';
            --v.user_dataValid := '0';        -- we're sending good data
            -- continue reading the user data as long as user said
            if (to_integer(r.user_buffer_write) < r.user_buffer_maxm1) then
               v.user_dataReady := '1';        -- sending to fifo, we can stil read
               v.user_buffer_write := r.user_buffer_write + 1;
               v.user_Data_in      := user_event_data;
               v.we := '1';
            else
               v.user_dataReady := '0';
               v.we := '0';
            end if;

            -- only send some stuff if the slave fifo is ready..
            if(axis_fifo_ready = '1' ) then
               v.user_data_interrupt := false;
               v.user_dataValid     := '1';
               if (r.user_FSM_control > 19) then
                  v.state             := USER_DATA_FRAMES_S;
                  v.user_FSM_control  := 0;
                  v.user_buffer_read  := v.user_buffer_read  + 1;                      
                  v.user_buffer_count := v.user_buffer_count + 1;                      
                  v.user_data_out     := r.user_data_hold; -- send the header word     
                  v.user_buffer_read  := r.user_buffer_read + 1;                       
                  v.user_DataKeep     := b"11";      -- keep the entire header word
               -- the eth_header is entirely controlled by the procedure..
               else
                  if r.user_dataValid = '1' then
                     -- increment count position in eth state
                     v.user_FSM_control := r.user_FSM_control + 1;
                     -- begin changing BRAM outPutS
                     if (r.user_FSM_CONTROL = 19) then
                        v.user_buffer_read := r.user_buffer_read + 1;
                     end if;
                  end if;
                  -- procedure to calculate eth_header values. outputs are appended to
                  BuildEthFrameHeader(v.user_FSM_control, 
                                      r.fsm_eth_header, 
                                      v.user_Data_out, 
                                      v.user_DataKeep, 
                                      v.user_DataValid);
               end if;	  
              -- can't write this turn
            else
            v.user_data_interrupt := true;
            if(r.user_data_interrupt = false) then
               v.user_data_hold    := bram_out;
               v.user_buffer_read  := r.user_buffer_read;
               v.user_buffer_count := r.user_buffer_count;
            end if;	 
         end if;
              
         -- this state is the place holder for all user data states
         when USER_DATA_FRAMES_S =>

            v.busy := '1';
            -- keep writting to the BRAM while we're in this stage..
            v.en := '1';
            v.user_dataValid := '1';
    
             -- continue writing to the buffer from the user data as long as user said
            if (to_integer(r.user_buffer_write) < r.user_buffer_maxm1) then
               v.we := '1';
               v.user_buffer_write := r.user_buffer_write + 1;
               v.user_Data_in      := user_event_data;
               v.user_dataReady := '1';  -- dual port allows us to still read while
            else
               v.user_dataReady := '0';
               v.we := '0';
            end if;

            if (r.user_buffer_count >= r.user_buffer_max) then
               v.user_data_last    := '1';
            end if;
             

            -- only send some stuff if the slave fifo is ready..
            if  axis_fifo_ready = '1'  then
               v.user_data_interrupt := false;
               v.user_DataKeep  := b"11"; -- keep everything user sends
               v.user_DataValid := '1';  -- what we're reading is good
               -- note that count and max can exceed max data buffer size.. thus the
               -- BRAM has the ability to 'loop' around the max ethFrame size..
               if (r.user_buffer_count >= r.user_buffer_max and r.user_data_last = '1') then
                  if r.user_DataValid = '1' then
                     v.user_buffer_read  := (others => '0');  -- begin reading from the beginning again
                     v.user_buffer_write := (others => '0');  -- begin writing from the beginning as wel..
                     v.user_buffer_count := 0;
                     v.user_data_last    := '0';
                     v.state             := DONE_S;
                     v.user_DataValid := '0'; 
                  end if;
              else 
                  if r.user_DataValid = '1' then
                     v.user_buffer_read  := r.user_buffer_read  + 1;
                     v.user_buffer_count := r.user_buffer_count + 1;
                  end if;
              end if;			

               if(r.user_data_interrupt = true) then
                  v.user_data_out  := r.user_data_hold;
               else
                  v.user_data_out  := bram_out;
               end if;

            else
               -- we've just been interrupted..
               v.user_data_interrupt := true;
               -- hold the value of the bram to use for later
            end if;
               if(r.user_data_interrupt = false) then
                   v.user_data_hold    := bram_out;
                   v.user_buffer_read  := r.user_buffer_read;
                   v.user_buffer_count := r.user_buffer_count;
                   v.user_DataValid := '1';  
               end if;

         -- force a reset for a clock cycle to empty the buffer from the last write
         when DONE_S =>
            v.state := IDLE;
            --v := HIT_INIT_C;

         when others =>
            v.state := IDLE;
            v := HIT_INIT_C;

      end case;
      -- Assignment of combinatorial variable to signal when not in eth_state
      rin <= v;

  end process eth_header_FSM;

   -- slave side assignments for reading data
   user_event_ready     <= r.user_dataReady;

   -- state machine assignments to connect to axis-stream
   axis_data_stream_out <= r.user_Data_out;
   axis_data_keep       <= r.user_DataKeep;
   axis_data_last       <= r.user_data_last;
   axis_data_valid      <= r.user_DataValid;
   busy                 <= r.busy;

  -- remember to actually update the signal you read from!!
  seq : process (clk) is
  begin
    if (rising_edge(clk)) then
      if rst = '1' then
         r <= HIT_INIT_C;
      else 
         r <= rin after GATE_DELAY;
      end if;
    end if;
  end process seq;

end architecture behavioral;
