----------------------------------------------------------------------------------
-- Company:  University of Hawaii
-- Engineer: K. Nishimura
-- Module Name: SpiDACx0508 - Behavioral
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.UtilityPkg.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
--use IEEE.NUMERIC_STD.ALL;
--library UNISIM;
--use UNISIM.VComponents.all;

entity SpiDACx0508 is
   generic (
      SCLK_HALF_PERIOD_G : integer := 5;
      GATE_DELAY_G       : time    := 1 ns;
      N_CHAINED          : integer := 1
   );
   port(
      -- Clock and reset
      sysClk    : in sl;
      sysRst    : in sl;
      -- DAC serial IO
      dacSclk   : out sl;
      dacCsb    : out sl;
      dacSin    : out sl;
      dacSout   : in  sl;
      -- Register mapping into this module
      dacOp     : in  sl;
      dacReq    : in  sl;
      dacAck    : out sl;
      dacAddr   : in  slv( 3 downto 0);
      dacWrData : in  slv(15 downto 0);
      dacRdData : out slv(15 downto 0);
      -- Shadow register output
      dacShadow : out Word16Array(15 downto 0)
   ); 
end SpiDACx0508;

architecture Behavioral of SpiDACx0508 is

   type StateType     is (IDLE_S,DATA_OUT_S,SHIFT_BIT_S,LAST_BIT_S,DONE_S);
   
   type RegType is record
      state       : StateType;
      rdData      : slv(15 downto 0);
      bitCount    : slv(5 downto 0);
      holdCount   : slv(7 downto 0);
      dataOut     : slv(23 downto 0);
      chipCount   : slv(3 downto 0);
      op          : sl;
      ack         : sl;
      csb         : sl;
      sin         : sl;
      sclk        : sl;
      shadowReg   : Word16Array(15 downto 0);
   end record RegType;
   
   constant REG_INIT_C : RegType := (
      state       => IDLE_S,
      rdData      => (others => '0'),
      bitCount    => (others => '0'),
      holdCount   => (others => '0'),
      chipCount   => (others => '0'),
      dataOut     => (others => '0'),
      op          => '0',
      ack         => '0',
      csb         => '1',
      sin         => '0',
      sclk        => '1',
      shadowReg   => (others => (others => '0'))
   );

   signal r   : RegType := REG_INIT_C;
   signal rin : RegType;

begin

   dacShadow <= r.shadowReg; 

   comb : process( r, sysRst, dacSout, dacOp, dacReq, dacAddr, dacWrData) is
      variable v : RegType;
   begin
      v := r;

      -- Resets for pulsed outputs
      v.ack := '0';
      
      -- State machine 
      case(r.state) is 
         when IDLE_S =>
            v.csb       := '1';
            v.sin       := '0'; -- Was '1', used to let it be high-Z in IDLE but maybe this was leaving the AD9645 in PDWN mode
            v.sclk      := '1';
            v.bitCount  := (others => '0');
            v.holdCount := (others => '0');
            v.rdData    := (others => '0');
            v.chipCount := (others => '0');
            -- We have a request, drop CSB, prep the data out
            if dacReq = '1' then
               v.csb     := '0';
               v.sclk    := '1';
               v.op      := dacOp;
               v.dataOut := not(dacOp) & "000" & dacAddr & dacWrData;
               v.state   := DATA_OUT_S;
--               if dacOp = '1' then
--                  v.state := DATA_OUT_S;
--               else
--                  v.state := DONE_S;
--               end if; 
               v.chipCount := r.chipCount + 1;
            end if;
         when DATA_OUT_S  =>
            v.sclk := '1';
            -- We always write out 24 bits, RW, then "000", then A3-A0, then D15-D0
            -- For reads the output data bits are don't care 
            v.sin  := r.dataOut(23 - conv_integer(r.bitCount));
            if r.bitCount > 7 then
               v.rdData(23-conv_integer(r.bitCount)) := dacSout; -- Read in the bit
            end if;
            -- Hold this for half a clock period, then clock the bit out
            if (r.holdCount < SCLK_HALF_PERIOD_G) then
               v.holdCount := r.holdCount + 1;
            else
               v.state     := SHIFT_BIT_S;
               v.holdCount := (others => '0');
            end if;
         when SHIFT_BIT_S =>
            v.sclk := '0';
            if (r.holdCount < SCLK_HALF_PERIOD_G) then
               v.holdCount := r.holdCount + 1;
            else
               v.holdCount := (others => '0');
               if (r.bitCount < 23) then
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
               if r.chipCount = N_CHAINED then
                  v.state := DONE_S; 
               else
                  v.bitCount  := (others => '0');
                  v.holdCount := (others => '0');
                  v.chipCount := r.chipCount + 1;
                  v.state     := DATA_OUT_S; 
               end if;
            end if;            
         when DONE_S =>
            v.ack  := '1';
            v.csb  := '1';
            if r.op = '1' then
               v.shadowReg(conv_integer(dacAddr)) := dacWrData;
--            else
--               v.rdData := r.shadowReg(conv_integer(dacAddr));
            end if;
            if dacReq = '0' then
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
      dacSclk   <= r.sclk;
      dacCsb    <= r.csb;
      dacSin    <= r.sin;
      dacAck    <= r.ack;
      dacRdData <= r.rdData;
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
