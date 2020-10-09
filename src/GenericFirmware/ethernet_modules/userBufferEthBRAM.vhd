-------------------------------------------------------------------------------
-- Title      : user BRAM
-- Project    : ntcScrod
-------------------------------------------------------------------------------
-- File       : userBufferEthBRAM.vhd
-- Author     : Kevin Keefe  <kevinkeefe@Kevins-MBP.home>
-- Company    : UH Manoa
-- Created    : 2019-07-02
-- Last update: 2019-09-13
-- Platform   : Spartan 6
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: for use in conjunction with the ex_eth_entity module. When a user
-- is not sure how many data frames their packet will provide, they can
-- instantiate this module as a layer inbetween the ethHeader module. It is
-- assumed that the user is using an axi-like protocol to speak with this
-- module. The BRAM will store data supplied by the user and will use the
-- number clk cycles between the first high tvalid signal up to and including
-- the tlast signal as the number of frames for the output.
--
-- TO USE: connect any axis-stream output to the userDataIn and userT<ports> of
-- this module. Then connect userDataOut and userData<ports> to ex_eth_entity module..
-- max_packet_length is the MAXIMUM number of packets during a transaction. If
-- a user sends more packets than max_packet_length, some of that data will be
-- overwritten, and this module will then ship some repeated data..
--
-- This module also supports input axis stream interface. It has been tested to
-- work when reading from an axis fifo sending data in packet mode.
--
-- The outputs of this port should ALWAYS AND ONLY ever be connected to
-- ex_eth_entity module.
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-02  1.0      kevinkeefe  Created
-------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity userBufferEthBRAM is

generic (
  GATE_DELAY_G      : time    := 2 ns;
  -- this determines maximum number of words you will send in a packet
  max_packet_length : natural := 1024);  -- expected max memory locations needed
port (
  -- user inputs to layer between ethHeader wrapper
  userClk           : in  std_logic;    -- same clk as ethHeader
  userRst           : in  std_logic;    -- same rst as ethHeader
  -- user AXIS stream stuff
  userDataIn        : in  std_logic_vector(31 downto 0);  -- data to axis stream
  userTValid        : in  std_logic;    -- goes high when data is good to send
  userTLast         : in  std_logic;    -- goes high for last packet from user
  userTReady        : out std_logic;
  -- outputs to send to the eth header wrapper
  userDataOut       : out std_logic_vector(31 downto 0);
  userDataSize      : out integer;  -- how many 32 bit frames the user will be sending out
  userDataBeginRead : out std_logic;
  userDataTReady    : in  std_logic);

end entity userBufferEthBRAM;

architecture rtl of userBufferEthBRAM is

-- component declaration of the BRAM
component BRAM_eth is
  generic (
    addr_cnt : integer := max_packet_length);
  port (
    clk  : in  std_logic;
    en   : in  std_logic;
    we   : in  std_logic;
    addr : in  std_logic_vector(9 downto 0);
    di   : in  std_logic_vector(31 downto 0);
    do   : out std_logic_vector(31 downto 0));
end component BRAM_eth;

-- states for the FSM
type state is (IDLE_S, BUFFER_S, SEND_S, DONE_S);

-- record to control the FSM states
type ethBRAM_fsm is record
  state     : state;
  en        : std_logic;
  we        : std_logic;
  addr      : std_logic_vector(9 downto 0);
  di        : std_logic_vector(31 downto 0);
  ready     : std_logic;
  dataOut   : std_logic_vector(31 downto 0);
  dataSize  : integer;
  dataRead  : integer;
  dataBegin : std_logic;
  user_data_hold : std_logic_vector(31 downto 0);
  user_data_interrupt : boolean;
end record ethBRAM_fsm;

constant HIT_INIT_C : ethBRAM_fsm :=
  (
  state     => IDLE_S,
  en        => '0',
  we        => '0',
  addr      => (others => '0'),
  ready     => '1', -- ready in the idle state..
  di        => (others => '0'),
  dataOut   => (others => '0'),
  dataSize  => 0,
  dataRead  => 0,
  dataBegin => '0',
  user_data_hold => (others => '0'),
  user_data_interrupt => false
);

-- fsm control signals
signal r   : ethBRAM_fsm := HIT_INIT_C;
signal rin : ethBRAM_fsm;

-- signal to hold the output of the BRAM. FSM decides whether to send out to
-- user
signal dout : std_logic_vector(31 downto 0);

begin  -- architecture rtl

-- instantiate a version of the BRAM component
BRAM_1 : BRAM_eth
  port map(
    clk  => userClk,
    -- connect the BRAM control members
    en   => r.en,
    we   => r.we,
    addr => r.addr,
    di   => r.di,
    -- get the output stored into a signal
    do   => dout);

userDataOut <= r.dataOut;

-- comb process to move through the FSM
process(r, dout, userDataIn, userTValid, userTLast, userRst, userDataTReady) is
  -- make the variable for the FSM
  variable v : ethBRAM_fsm;
begin

  -- make sure we're looking at the current states..
  v := r;
  -- don't do things to the BRAM unless the data we're writing is good..
  v.en := '0';
  v.we := '0';

  case (r.state) is

    when IDLE_S =>
      -- we're in the boring idle state waiting looking for 'good' data
      v := HIT_INIT_C;
      -- get ready to send data, if it's valid and if the ethHeader is ready..
      if(userTValid = '1') then
        -- write to the memory:
        v.en       := '1';
        v.we       := '1';
        v.di       := userDataIn;
        v.addr     := (others => '0');  -- begin writing at the beginning
        -- keep track of the size
        v.dataSize := 1;
        -- go to the next state and begin buffering
        v.state    := BUFFER_S;
      end if;

    when BUFFER_S =>
      -- check to make sure incoming data is valid..
      if(userTValid = '1') then
        -- write to the memory:
        v.en        := '1';
        v.we        := '1';
        -- v.dataOut   := (others => '0');   -- not sending data yet
        v.dataRead  := 0;
        v.dataBegin := '0';
        -- get the data from the user
        v.di        := userDataIn;
        -- go to the next address to send write this data
        v.addr      := std_logic_vector(unsigned(r.addr) + 1);
        -- continue counting user data size
        v.dataSize  := r.dataSize + 1;
        -- look for the last signal from the user
        if(userTLast = '1') then
          v.state    := SEND_S;
          v.dataRead := 0;              -- starting the read count
          v.ready    := '0';            -- not ready for more data as we're sending it..
        end if;
      end if;

    when SEND_S =>

      v.en       := '1';
      v.we       := '0';                 -- only reading
      v.ready    := '0';                 -- sending data, not ready to receive
      v.di       := (others => '0');   
      -- read from the memory:
      if(userDataTReady = '1') then
         v.user_data_interrupt := false;      
         v.dataSize := r.dataSize;          -- store the size we found
         v.dataRead := r.dataRead + 1;      -- reading the next value

         -- we've sent all of the data packets
         if (r.dataRead = r.dataSize + 2) then
           v.state     := DONE_S;
           v.addr      := std_logic_vector(unsigned(r.addr) + 1);
           v.dataBegin := '0';
         elsif(r.dataRead = 0) then
           v.dataBegin := '0';              -- don't continually restart the header
           v.addr      := (others => '0');  -- start at beginning
         -- read first BRAM lags behind by two clock cycles
         elsif(r.dataRead = 2) then
           v.dataBegin := '1';             -- don't continually restart the header
           v.addr      := std_logic_vector(unsigned(r.addr) + 1);
         else
           v.dataBegin := '0';             -- don't continually restart the header
           v.addr      := std_logic_vector(unsigned(r.addr) + 1);
         end if;
         
        -- current output depends if we've just been interrupted or not..
        if(r.user_data_interrupt = false) then
            v.dataOut := dout;
        else
            v.dataOut := r.user_data_hold;
        end if;
      
      else
            -- we've just been interrupted..
            v.user_data_interrupt := true;           
            -- hold the value of the bram to use for later
            if(r.user_data_interrupt = false) then
               v.user_data_hold    := dout;
            end if;   
      end if;

    when DONE_S =>
        v       := HIT_INIT_C;
        v.state := IDLE_S;

    when others =>
        v       := HIT_INIT_C;
        v.state := IDLE_S;

  end case;

    -- Reset logic
    if (userRst = '1') then
      v := HIT_INIT_C;
    end if;

    -- make the assignments to the signal
    rin               <= v;
    -- tie the fsm signals to eth header wrapper:
    -- userDataOut       <= r.dataOut;
    userDataSize      <= r.dataSize;
    userDataBeginRead <= r.dataBegin;   -- when high begins building packet
    userTReady        <= r.ready;

end process;

-- top lvl of fsm to update
process(userClk, userRst) is
begin
  if rising_edge(userClk) then
    r <= rin after GATE_DELAY_G;
  end if;
end process;

end architecture rtl;
