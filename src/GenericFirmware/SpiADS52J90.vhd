library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.UtilityPkg.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity SpiADS52J90 is
   generic (
      NUM_CHIPS          : integer := 2;
      SCLK_HALF_PERIOD_G : integer := 5;
      ADDR_BITS_G        : integer := 8;
      DATA_BITS_G        : integer := 16;
      GATE_DELAY_G       : time    := 1 ns 
   );
   port(
      -- Clock and reset
      sysClk : in sl;
      sysRst : in sl;
      -- DAC serial IO
      Sclk   : out sl;
      Csb    : out slv(NUM_CHIPS-1 downto 0); -- two chips
      Sin    : out sl;
      Sout   : in  sl;
      -- Register mapping into this module
      Op     : in  sl;
      Req    : in  sl; -- keep high while transaction is in progress
      Sel    : in  sl; -- select one of two chips
      Ack    : out sl;
      Addr   : in  slv(ADDR_BITS_G-1 downto 0);
      WrData : in  slv(DATA_BITS_G-1 downto 0);
      RdData : out slv(DATA_BITS_G-1 downto 0);
      -- Shadow register output
      Shadow : out Word16Array(15 downto 0)
   ); 
end SpiADS52J90;

architecture Behavioral of SpiADS52J90 is

   constant TOT_DATA_BITS : integer := ADDR_BITS_G + DATA_BITS_G;

   type StateType     is (IDLE_S,DATA_OUT_S,SHIFT_BIT_S,LAST_BIT_S,DONE_S);
   
   type RegType is record
      state       : StateType;
      rdData      : slv(15 downto 0);
      bitCount    : slv(5 downto 0);
      holdCount   : slv(7 downto 0);
      dataOut     : slv(TOT_DATA_BITS-1 downto 0);
      op          : sl;
      ack         : sl;
      csb         : slv(1 downto 0);
      sin         : sl;
      sclk        : sl;
      shadowReg   : Word16Array(15 downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      rdData      => (others => '0'),
      bitCount    => (others => '0'),
      holdCount   => (others => '0'),
      dataOut     => (others => '0'),
      op          => '0',
      ack         => '0',
      csb         => (others => '1'),
      sin         => '0',
      sclk        => '1',
      shadowReg   => (others => (others => '0'))
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   Shadow <= r.shadowReg; 

   comb : process( r, sysRst, Sout, Op, Req, Addr, WrData, Sel) is
      variable v : RegType;
   begin
      v := r;

      -- Resets for pulsed outputs
      v.ack := '0';
      
      -- State machine 
      case(r.state) is 
         when IDLE_S =>
            v.csb       := (others => '1');
            v.sin       := '0'; -- Was '1', used to let it be high-Z in IDLE but maybe this was leaving the AD9645 in PDWN mode
            v.sclk      := '1';
            v.bitCount  := (others => '0');
            v.holdCount := (others => '0');
            v.rdData    := (others => '0');
            -- We have a request, drop CSB, prep the data out
            if Req = '1' then
               if Sel = '0' then
                  v.csb     := b"10";
               else 
                  v.csb     := b"01";
               end if;
               v.sclk    := '0';
               v.op      := Op;
               v.dataOut := Addr & WrData;
               v.state   := DATA_OUT_S;
            end if;
         when DATA_OUT_S  =>
            v.sclk := '0';
            -- We always write out 24 bits, RW, then "000", then A3-A0, then D15-D0
            -- For reads the output data bits are don't care 
            v.sin  := r.dataOut(TOT_DATA_BITS-1 - conv_integer(r.bitCount));
            if r.bitCount > ADDR_BITS_G then
               v.rdData(TOT_DATA_BITS-1-conv_integer(r.bitCount)) := Sout; -- Read in the bit
            end if;
            -- Hold this for half a clock period, then clock the bit out
            if (r.holdCount < SCLK_HALF_PERIOD_G) then
               v.holdCount := r.holdCount + 1;
            else
               v.state     := SHIFT_BIT_S;
               v.holdCount := (others => '0');
            end if;
         when SHIFT_BIT_S =>
            v.sclk := '1';
            if (r.holdCount < SCLK_HALF_PERIOD_G) then
               v.holdCount := r.holdCount + 1;
            else
               v.holdCount := (others => '0');
               if (r.bitCount < TOT_DATA_BITS-1) then
                  v.bitCount := r.bitCount + 1;
                  v.state    := DATA_OUT_S;
               else
                  v.state    := LAST_BIT_S;
               end if;
            end if;
         when LAST_BIT_S =>
            v.sclk := '0';
            v.sin  := '0';
            if (r.holdCount < SCLK_HALF_PERIOD_G) then
               v.holdCount := r.holdCount + 1;
            else
               v.state := DONE_S; 
            end if;            
         when DONE_S =>
            v.ack  := '1';
            v.csb  := (others => '1');
            if r.op = '1' then
               v.shadowReg(conv_integer(Addr)) := WrData;
            end if;
            if Req = '0' then
               v.ack   := '0';
               v.state := IDLE_S;
            end if;
         when others =>
            v.state := IDLE_S;
      end case;

      -- Reset logic
      if (sysRst = '1') then
         v := REG_INIT_C;
      end if;

      -- Outputs to ports
      Sclk   <= r.sclk;
      Csb    <= r.csb;
      Sin    <= r.sin;
      Ack    <= r.ack;
      RdData <= r.rdData;
      -- Register interfaces
      
      -- Assignment of combinatorial variable to signal
      rin <= v;

   end process;

   seq : process (sysClk) is
   begin
      if (rising_edge(sysClk)) then
         r <= rin after GATE_DELAY_G;
      end if;
   end process seq;

end Behavioral;

