library ieee;
   use   ieee.std_logic_1164.all;
   use   ieee.std_logic_unsigned.all; 
   use   ieee.numeric_std.all;

entity PulseShaper is
   port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      len    : in  std_logic_vector(15 downto 0) := (others => '0');
      del    : in  std_logic_vector(15 downto 0) := (others => '0');
      din    : in  std_logic;
      dou    : out std_logic
   );
end entity PulseShaper;

architecture behav of PulseShaper is

   type fsm_states is (IDLE_S, DELAY_S, STRETCH_S); 
   signal st    : fsm_states := IDLE_S;

   signal cnt   : std_logic_vector(15 downto 0) := (others => '0');
   signal len_r : std_logic_vector(15 downto 0) := (others => '0');
   signal del_r : std_logic_vector(15 downto 0) := (others => '0');
   signal sig   : std_logic := '0';

begin
   
   process (clk)
   begin
      if rising_edge (clk) then
         if rst = '1' then
            st <= IDLE_S;
         else
            sig <= '0';
            case st is 
               when IDLE_S => 
                  cnt  <= (others => '0');
                  len_r <= len;
                  del_r <= del;
                  if din = '1' then
                     if del_r > 1 then 
                        st <= DELAY_S;
                     else
                        if len_r > x"0000" then
                           st <= STRETCH_S;
                        else
                           st <= IDLE_S;
                        end if;
                     end if;
                  end if;
               when DELAY_S =>
                  cnt <= cnt + 1;
                  if cnt = del_r-1 then
                     cnt <= (others => '0');
                     --sig <= '1';
                     if len_r > x"0000" then
                        st  <= STRETCH_S;
                     else
                        st  <= IDLE_S;
                     end if;
                  end if;
               when STRETCH_S => 
                  cnt <= cnt + 1;
                  sig <= '1';
                  if cnt = len_r-1 then
                     st  <= IDLE_S;
                     --sig <= '0';
                  end if;
               when others =>
                  st <= IDLE_S;
            end case;
         end if;
      end if;
   end process;

   dou <= sig;

end behav;
