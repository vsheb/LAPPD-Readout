library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.UtilityPkg.all;

-- RegMap uses Numeric_std
-- This uses logic_arith, which is probably bad
-- use ieee.std_logic_arith.all;
-- use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity EeveeTimer is
  generic (
    GATE_DELAY_G : time := 1 ns
    );
  port ( 
    clk       : in  sl;
    rst       : in  sl;

    -- Raw access ports
    clockRst   : in sl;
    clockRaw   : out slv(63 downto 0);
    
    --period     : in slv(31 downto 0);

    rawTimer    : out slv(63 downto 0);

    --scaledTimer : out slv(31 downto 0);

    -- Register mapping into this module
    -- Directly linked
    timerOp     : in  sl;
    timerAddr   : in  slv(1 downto 0);
    timerWrData : in  slv(31 downto 0);
    
    -- Indirectly linked
    timerReq    : in  sl;
    timerAck    : out sl;
    timerRdData : out slv(31 downto 0)
    );
end EeveeTimer;

architecture Behavioral of EeveeTimer is

  type StateType     is (IDLE_S, DONE_S);
  
  type RegType is record
    state        : StateType;

    -- Tell the register controller we are done?
    ack : sl;

    -- Flag for whether to pull from cache
    cacheValid : sl;
    
    -- Used to cache the clock, once a raw register read is initiated
    -- This guarantees an atomic read of the clock
    cachedClock : unsigned(63 downto 0);

    -- The actual value of the clock
    clockVal : unsigned(63 downto 0);

    -- The value of the clock the last time we incremented
    -- the scaled timer
    -- lastTime : unsigned(63 downto 0);
    
    -- The scaled value of the clock for ease of use (32 bit)
    scaledVal : unsigned(31 downto 0);

    -- The scaling in ticks per scaled clock increment
    period : unsigned(31 downto 0);
    remainingTicks : unsigned(31 downto 0);
    
    -- The thing to put on the pipe
    timerRdData : slv(31 downto 0);
    
  end record RegType;
  
  constant REG_INIT_C : RegType := (
    state => IDLE_S,
    ack => '0',

    cachedClock => (others => '0'),
    cacheValid => '0',
    clockVal => (others => '0'),
    scaledVal => (others => '0'),

    -- The initial period is just 32-bit rollover
    period => (others => '1'),
    remainingTicks  => (others => '1'),
    timerRdData => (others => '0')
    );

  signal r   : RegType := REG_INIT_C;
  signal rin : RegType;

begin

  comb : process( r, rst, clockRst, timerAddr, timerOp, timerReq, timerWrData ) is
    variable v : RegType;
    variable clockSource : unsigned(63 downto 0);
  begin
    -- This is the mutable state configuration which will become r on the next
    -- pass through
    v := r;

    -- FIX timer decrement!
    
    -- state machine 
    case (r.state) is
      when IDLE_S =>
        -- We're not acknowledging anything usually...
        v.ack := '0';

        -- Unless we are requested to do something
        if timerReq = '1' then

          -- Anytime we perform a write, rebase the timer
          if timerOp = '1' then
            -- We've requested a rebase in the timer, so reset the times
            v.scaledVal := (others => '0');
            v.remainingTicks := unsigned(timerWrData);
            v.period := unsigned(timerWrData);
            v.cacheValid := '0';
            
            -- Map the register out to the scled value
            v.timerRdData := std_logic_vector(r.scaledVal); 
          else
            -- Handle reads!
            if timerAddr = "00" then
              -- We are doing a simple scaled read, so invalidate cache
              v.timerRdData := std_logic_vector(r.scaledVal);
              v.cacheValid := '0';
            else
              -- Raw reads
              if r.cacheValid = '1' then
                clockSource := r.cachedClock;
                v.cacheValid := '0';
              else
                clockSource := r.clockVal;
                v.cachedClock := r.clockVal;
                v.cacheValid := '1';
              end if;
              
              case (timerAddr) is
                when "01" =>
                  v.timerRdData := std_logic_vector(clockSource(31 downto 0));
                when "10" =>
                  v.timerRdData := std_logic_vector(clockSource(63 downto 32));
                when others =>
                  -- This will only catch "11"
                  v.timerRdData := (others => '1');
              end case;
            end if;
          end if;
          
          -- Signal valid data on timerRdData
          v.ack := '1';
          
          -- Move to the done state to wait for req to fall low
          v.state := DONE_S;
        end if;
        
      when DONE_S =>
        -- Hold at DONE_S and ack high unless we're done servicing
        if timerReq = '0' then
          
          -- Reset handshaking ack
          v.ack := '0';

          -- Back to IDLE
          v.state := IDLE_S;
        end if;   
    end case;

    -- Outputs to ports the (previous value)
    -- Cannot use v because v was getting written to at the same time everywhere
    -- here!

    -- Always increment the raw clock
    v.clockVal := r.clockVal + 1;

    -- Decrement the previous round ticks if we didn't just reset them.
    if not (timerOp = '1' and timerReq = '1' and r.state = IDLE_S) then
      v.remainingTicks := r.remainingTicks - 1;
    end if;   

    -- See if we increment the scaled clock?
    if r.remainingTicks = x"00000000" then

      -- Reset the countdown
      v.remainingTicks := r.period;
      
      -- Increment the timer
      v.scaledVal := r.scaledVal + 1;
    end if;

    -- Assert something on ack always
    timerAck <= r.ack;

    -- Always expose the raw clock
    clockRaw <= std_logic_vector(r.clockVal);

    -- Always map the timerRdData port to something
    timerRdData <= r.timerRdData;

    -- A clock reset for synchronization.
    -- Keeps the same period setting, but sets the clocks to zero
    if clockRst = '1' then
      v.cacheValid := '0';
      v.clockVal := (others => '0');
      v.scaledVal := (others => '0');
      v.remainingTicks := r.period;
    end if;     

    -- System-wide reset takes use back to the future
    if rst = '1' then
      v := REG_INIT_C;
    end if;


    -- Assignment of combinatorial variable to signal
    rin <= v;
    
  end process;

  seq : process (clk) is
  begin
    if (rising_edge(clk)) then
      r <= rin after GATE_DELAY_G;
    end if;
  end process seq;
end Behavioral;
