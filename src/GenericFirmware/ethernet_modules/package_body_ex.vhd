-- must use these librarys for the slv types..
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- need this for the unsigned values
use IEEE.NUMERIC_STD.all;

-- note a package must have a declaration and then a body definition

-- declaration of a package
package ex_pkg is

  -- define some word which indicates that the header word didn't succeed in building..
  constant C_ETH_FAIL_WORD   : std_logic_vector(15 downto 0) := x"1337";
  -- ethernet header constants used by following functions and procedure.
  constant C_EthIHL_VERSION    : std_logic_vector(7 downto 0)  := x"45";
  constant C_EthECN_DSCP       : std_logic_vector(7 downto 0)  := x"00";
  constant C_EthFlagsOffset    : std_logic_vector(7 downto 0)  := x"40";
  constant C_EthFragmentOffset : std_logic_vector(7 downto 0)  := x"00";
  constant C_EthTTL            : std_logic_vector(7 downto 0)  := x"03";
  constant C_IPv4Protocol      : std_logic_vector(7 downto 0)  := x"11";
  constant C_EthType_1         : std_logic_vector(7 downto 0)  := x"08"; -- IPv4
  constant C_EthType_2         : std_logic_vector(7 downto 0)  := x"00";
  constant C_UDPCheckSum       : std_logic_vector(15 downto 0) := x"0000";

  constant PacketID  : std_logic_vector(15 downto 0) := x"D191";

  -- define a record type to easily call the builder procedure.
  -- also a place to store all of the header values needed to build..
  type ethernet_values is record
    DstMac          : std_logic_vector(47 downto 0);
    SrcMac          : std_logic_vector(47 downto 0);
    EthPacketLength : std_logic_vector(15 downto 0);
    UDPPacketLength : std_logic_vector(15 downto 0);
    IPv4_ChkSum      : std_logic_vector(15 downto 0);
    SrcIP           : std_logic_vector(31 downto 0);
    DstIP           : std_logic_vector(31 downto 0);
    UDP_DstPort     : std_logic_vector(15 downto 0);
    UDP_SrcPort     : std_logic_vector(15 downto 0);
  end record;

  -- useful initializer for ethernet_values type when storing in another record
  constant EMPTY_ETH_HEADER : ethernet_values := (
    DstMac          => (others => '0'),
    SrcMac          => (others => '0'),
    EthPacketLength => (others => '0'),
    UDPPacketLength => (others => '0'),
    IPv4_ChkSum      => (others => '0'),
    SrcIP           => (others => '0'),
    DstIP           => (others => '0'),
    UDP_DstPort     => (others => '0'),
    UDP_SrcPort     => (others => '0')
);

 -- use this function to determine the number of bytes you will send in a data
 -- frame. This includes the necessary IPv4 and UDP header info..
procedure CalcEthHeaderLength (
   constant data_frame_byte_size  : in  integer;  -- number of bytes in a single data frame
   signal num_data_frames         : in  integer;  -- number of frames in a single transaction
   variable EthPacketLength       : out std_logic_vector(15 downto 0);  -- IPv4 length slv
   variable UDPPacketLength       : out std_logic_vector(15 downto 0)  -- UDP Length value
);

procedure CalcIPv4CheckSum1 (
   signal   SrcIP           : in  std_logic_vector(31 downto 0);
   signal   DstIP           : in  std_logic_vector(31 downto 0);
   signal IPv4_ChkSum      : out unsigned(31 downto 0)
);
procedure CalcIPv4CheckSum2 (
   signal EthPacketLength : in  std_logic_vector(15 downto 0);
   signal chksm     : in  unsigned(31 downto 0);
   variable IPv4_ChkSum      : out std_logic_vector(15 downto 0)
);
procedure CalcIPv4CheckSum (
   signal   SrcIP           : in  std_logic_vector(31 downto 0);
   signal   DstIP           : in  std_logic_vector(31 downto 0);
   signal EthPacketLength : in  std_logic_vector(15 downto 0);
   variable IPv4_ChkSum      : out std_logic_vector(15 downto 0)
);

 procedure BuildEthFrameHeader
   (variable user_FSM_control  : in  integer;
    signal eth               : in  ethernet_values;
    variable data_stream_out : out std_logic_vector(15 downto 0);
    variable data_keep       : out std_logic_vector(1 downto 0);
    variable data_valid      : out std_logic
    );

end package ex_pkg;
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- definition of the package body
---------------------------------------------------------------------------
package body ex_pkg is

   ---------------------------------------------------------------------------
   -- purpose: procedure to create UDP and IPv4 length signals
   ---------------------------------------------------------------------------
   procedure CalcEthHeaderLength (
      constant data_frame_byte_size  : in  integer;
      -- user supplies this information
      signal   num_data_frames       : in  integer;
      variable EthPacketLength       : out std_logic_vector(15 downto 0);
      variable UDPPacketLength       : out std_logic_vector(15 downto 0) )
   is
      variable total_bytes_int       : integer               := 0;
      variable total_bytes_unsgn     : unsigned(15 downto 0) := (others => '0');
      variable total_bytes_unsgn_udp : unsigned(15 downto 0) := (others => '0');
   begin  -- procedure CalcEthHeaderLength

      total_bytes_int       := data_frame_byte_size * num_data_frames;
      total_bytes_unsgn     := to_unsigned(total_bytes_int, 16);
      total_bytes_unsgn     := total_bytes_unsgn + 28; --include the bytes for the header
      total_bytes_unsgn_udp := total_bytes_unsgn - 20; -- don't count the length of the ipv4 frames

      EthPacketLength     := std_logic_vector(total_bytes_unsgn);
      UDPPacketLength     := std_logic_vector(total_bytes_unsgn_udp);

   end procedure CalcEthHeaderLength;
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- purpose: use this function to calculate the IPv4 header chksm
   ---------------------------------------------------------------------------
   procedure CalcIPv4CheckSum1 (
      signal SrcIP          : in  std_logic_vector(31 downto 0);
      signal DstIP     : in  std_logic_vector(31 downto 0);
      signal IPv4_ChkSum           : out unsigned(31 downto 0)
   ) is
      variable iWord5     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord6     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord8     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord9     : std_logic_vector(31 downto 0) := (others => '0');
   begin  -- function CalcIPv4CheckSum

      -- Prep words
      iWord5     := x"0000" & SrcIP(7 downto 0) & SrcIP(15 downto 8);
      iWord6     := x"0000" & SrcIP(23 downto 16) & SrcIP(31 downto 24);
      iWord8     := x"0000" & DstIP(7 downto 0) & DstIP(15 downto 8);
      iWord9     := x"0000" & DstIP(23 downto 16) & DstIP(31 downto 24);
      -- Static part
      IPv4_ChkSum <=  unsigned(iWord5) +
                      unsigned(iWord6) + 
                      unsigned(iWord8) +
                      unsigned(iWord9);
   end procedure CalcIPv4CheckSum1;


   procedure CalcIPv4CheckSum2 (
      signal EthPacketLength : in  std_logic_vector(15 downto 0);
      signal chksm     : in  unsigned(31 downto 0);
      variable IPv4_ChkSum   : out std_logic_vector(15 downto 0)
   ) is
      constant iWord1     : std_logic_vector(31 downto 0) := x"0000" & C_EthIHL_VERSION & C_EthECN_DSCP;
      variable iWord2     : std_logic_vector(31 downto 0) := (others => '0');
      constant iWord3     : std_logic_vector(31 downto 0) := x"0000" & C_EthFlagsOffset & C_EthFragmentOffset;
      variable iWord4     : std_logic_vector(31 downto 0) := x"0000" & C_EthTTL & C_IPv4Protocol;
      constant iWord7     : std_logic_vector(31 downto 0) := x"0000" & PacketID; 
      variable iChecksum1 : unsigned(31 downto 0)         := (others => '0');
      variable iChecksum2 : unsigned(31 downto 0)         := (others => '0');
      variable iChecksum3 : unsigned(31 downto 0)         := (others => '0');
      variable iChecksum4 : unsigned(15 downto 0)         := (others => '0');
   begin  -- function CalcIPv4CheckSum

      -- Prep words
      iWord2     := x"0000" & EthPacketLength;
      -- Static part
      iChecksum1 :=  chksm + 
                     unsigned(iWord1) +    -- x4500
                     unsigned(iWord2) +    -- x0318
                     -- + ipId(2 bytes)     --
                     unsigned(iWord3) +    -- x4000
                     unsigned(iWord4) +    -- x0311
                     unsigned(iWord7); 
      -- Do the carry once
      iChecksum3 := (x"0000" & iChecksum1(15 downto 0)) +
                    (x"0000" & iChecksum1(31 downto 16));
      -- Do the carry again
      iChecksum4 := iChecksum3(15 downto 0) + iChecksum3(31 downto 16);

      -- Perform one's complement
      --ipv4_header_checksum <= not(std_logic_vector(iChecksum4));
      IPv4_ChkSum := (not(std_logic_vector(iChecksum4)));
   end procedure CalcIPv4CheckSum2;
   ---------------------------------------------------------------------------


   ---------------------------------------------------------------------------
   -- purpose: use this function to calculate the IPv4 header chksm
   ---------------------------------------------------------------------------
   procedure CalcIPv4CheckSum (
      signal SrcIP          : in  std_logic_vector(31 downto 0);
      signal DstIP     : in  std_logic_vector(31 downto 0);
      signal EthPacketLength : in  std_logic_vector(15 downto 0);
      variable IPv4_ChkSum           : out std_logic_vector(15 downto 0)
   ) is
      constant iWord1     : std_logic_vector(31 downto 0) := x"0000" & C_EthIHL_VERSION & C_EthECN_DSCP;
      variable iWord2     : std_logic_vector(31 downto 0) := (others => '0');
      constant iWord3     : std_logic_vector(31 downto 0) := x"0000" & C_EthFlagsOffset & C_EthFragmentOffset;
      variable iWord4     : std_logic_vector(31 downto 0) := x"0000" & C_EthTTL & C_IPv4Protocol;
      variable iWord5     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord6     : std_logic_vector(31 downto 0) := (others => '0');
      constant iWord7     : std_logic_vector(31 downto 0) := x"0000" & PacketID; 
      variable iWord8     : std_logic_vector(31 downto 0) := (others => '0');
      variable iWord9     : std_logic_vector(31 downto 0) := (others => '0');
      variable iChecksum1 : unsigned(31 downto 0)         := (others => '0');
      variable iChecksum2 : unsigned(31 downto 0)         := (others => '0');
      variable iChecksum3 : unsigned(31 downto 0)         := (others => '0');
      variable iChecksum4 : unsigned(15 downto 0)         := (others => '0');
   begin  -- function CalcIPv4CheckSum

      -- Prep words
      iWord2     := x"0000" & EthPacketLength;
      iWord5     := x"0000" & SrcIP(7 downto 0) & SrcIP(15 downto 8);
      iWord6     := x"0000" & SrcIP(23 downto 16) & SrcIP(31 downto 24);
      iWord8     := x"0000" & DstIP(7 downto 0) & DstIP(15 downto 8);
      iWord9     := x"0000" & DstIP(23 downto 16) & DstIP(31 downto 24);
      -- Static part
      iChecksum1 :=  unsigned(iWord1) +    -- x4500
                     unsigned(iWord2) +    -- x0318
                     -- + ipId(2 bytes)     --
                     unsigned(iWord3) +    -- x4000
                     unsigned(iWord4) +    -- x0311
                     -- + ipChecksum(this)
                     -- ipSource words
                     unsigned(iWord5) +
                     unsigned(iWord6);     -- xC0A8
      -- Dynamic part
      iChecksum2 := iChecksum1 +
                     -- packet ID
                     unsigned(iWord7) +
                     -- ipDest words
                     unsigned(iWord8) +
                     unsigned(iWord9);
      -- Do the carry once
      iChecksum3 := (x"0000" & iChecksum2(15 downto 0)) +
                    (x"0000" & iChecksum2(31 downto 16));
      -- Do the carry again
      iChecksum4 := iChecksum3(15 downto 0) + iChecksum3(31 downto 16);

      -- Perform one's complement
      --ipv4_header_checksum <= not(std_logic_vector(iChecksum4));
      IPv4_ChkSum := (not(std_logic_vector(iChecksum4)));
   end procedure CalcIPv4CheckSum;
   ---------------------------------------------------------------------------

   ---------------------------------------------------------------------------
   -- purpose: place this bad boy in a single state in a FSM to build Eth_headers for you.
   ---------------------------------------------------------------------------
   procedure BuildEthFrameHeader
      (
      variable user_FSM_control  : in  integer;
      signal eth : in  ethernet_values;
      variable data_stream_out : out std_logic_vector(15 downto 0);
      variable data_keep       : out std_logic_vector(1 downto 0);
      variable data_valid      : out std_logic
   ) is

   begin  -- procedure BuildEthFrameHeader
      data_valid      := '1';
      data_keep       := b"11";
      -- use variables that update after these checks are made
      -- this forces these variables to behave like signals
      case user_FSM_control is
         -- Ethernet Phase
         when 0 =>
            data_stream_out := eth.DstMac(39 downto 32) & eth.DstMac(47 downto 40) ;
         when 1 =>
            data_stream_out := eth.DstMac(23 downto 16) & eth.DstMac(31 downto 24);
         when 2 =>
            data_stream_out := eth.DstMac(7  downto 0)  & eth.DstMac(15 downto 8);
         when 3 =>
            data_stream_out := eth.SrcMac(39 downto 32) & eth.SrcMac(47 downto 40);
         when 4 =>
            data_stream_out := eth.SrcMac(23 downto 16) & eth.SrcMac(31 downto 24);
         when 5 => 
            data_stream_out := eth.SrcMac(7  downto 0)  & eth.SrcMac(15 downto 8);
         when 6 => --0x0800 - ipv4
            data_stream_out := C_EthType_2   & C_EthType_1;
         --  IPv4 Phase
         when 7 =>
            data_stream_out := C_EthECN_DSCP & C_EthIHL_VERSION;
         when 8 =>
            data_stream_out := eth.EthPacketLength(7 downto 0) & eth.EthPacketLength(15 downto 8);
         when 9 =>
            data_stream_out := PacketID(7 downto 0) & PacketID(15 downto 8);
         when 10 =>
            data_stream_out := C_EthFragmentOffset & C_EthFlagsOffset;
         when 11 =>
            data_stream_out := C_IPv4Protocol & C_EthTTL;
         when 12 =>
            data_stream_out := eth.IPv4_ChkSum(7 downto 0) & eth.IPv4_ChkSum(15 downto 8);
         when 13 =>
            data_stream_out := eth.SrcIP(15 downto 0); -- IPs are little-endian
         when 14 =>
            data_stream_out := eth.SrcIP(31 downto 16);
         when 15 =>
            data_stream_out := eth.DstIP(15 downto 0);
         when 16 =>
            data_stream_out := eth.DstIP(31 downto 16);
         -- UDP / End Phase
         when 17 =>
            data_stream_out := eth.UDP_SrcPort;
         when 18 =>
            data_stream_out := eth.UDP_DstPort;
         when 19 =>
            data_stream_out := eth.UDPPacketLength(7 downto 0) & eth.UDPPacketLength(15 downto 8);
         when 20 =>
            data_stream_out := C_UDPCheckSum;
         when others =>
            data_stream_out := C_ETH_FAIL_WORD;
            data_keep       := b"00";
            data_valid      := '0';
      end case;
   end procedure BuildEthFrameHeader;
   ---------------------------------------------------------------------------

end package body ex_pkg;
