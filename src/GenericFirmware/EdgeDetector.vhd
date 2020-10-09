library ieee;
use ieee.std_logic_1164.all;

entity EdgeDetector is
generic(
   N_INPUT_PIPELINE : natural := 0;
   REG_OUT          : boolean := TRUE
);
port (
   clk    : in  std_logic;
   rst    : in  std_logic;
   input  : in  std_logic;
   output : out std_logic);
end EdgeDetector;

architecture rtl of EdgeDetector is
   signal input_q   : std_logic_vector(N_INPUT_PIPELINE downto 0);
   signal input_r1  : std_logic;
   signal input_r2  : std_logic;
   signal output_i  : std_logic;
begin

   process(clk)
   begin
      if rising_edge(clk) then
         if rst = '1' then
            input_q <= (others => '0');
         else
            input_q <= input_q(input_q'left-1 downto 0) & input;
         end if;
      end if;
   end process;

   process(clk,rst)
   begin
      if rising_edge(clk) then
         if rst = '1' then
           input_r1 <= '0';
           input_r2 <= '0';
         else 
           input_r1 <= input_q(input_q'left);
           input_r2 <= input_r1;
         end if;
      end if;
   end process;

   output_i <= not input_r2 and input_r1;
   
   GEN_OUT_REG : if REG_OUT = TRUE generate
      process (clk)
      begin
         if rising_edge (clk) then
            output <= output_i;
         end if;
      end process;
   end generate GEN_OUT_REG;   

   GEN_OUT_DIR : if REG_OUT = FALSE generate
      output <= output_i;
   end generate GEN_OUT_DIR;   

end rtl;
----------------------------------------------


----------------------------------------------
-- Strobe Transition 
----------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.VComponents.all;

entity StrobeTransition is
generic(
   STRETCH : natural := 4
);
port (
   clka    : in  std_logic;
   inpa    : in  std_logic;
   clkb    : in  std_logic;
   outb    : out std_logic
);
end StrobeTransition;

architecture rtl of StrobeTransition is
   signal    cnt      : std_logic_vector(STRETCH-1 downto 0) := (others => '0');
   constant  cnt_zero : std_logic_vector(STRETCH-1 downto 0) := (others => '0');
   signal    inp_ext  : std_logic := '0';
   signal    inp_ext_a : std_logic := '0';
   signal    inp_ext_ar : std_logic := '0';
   signal    inp_ext_b : std_logic := '0';
   signal    inp_ext_br : std_logic := '0';
begin
   process(clka)
   begin
      if rising_edge(clka) then
         if inpa = '1' then 
            inp_ext <= '1';
            cnt <= (others => '1');
         elsif cnt = cnt_zero then
            inp_ext <= '0';
         end if;
         if inp_ext = '1' and cnt /= cnt_zero then
            cnt <= cnt - 1;
         end if;
      end if;
   end process;

   U_reg1 : FDRE
   generic map (
      INIT => '0'
   )
   port map (
      C    => clka,
      CE   => '1',
      R    => '0',
      D    => inp_ext,
      Q    => inp_ext_a
   );

   U_reg2 : FDRE
   generic map (
      INIT => '0'
   )
   port map (
      C    => clka,
      CE   => '1',
      R    => '0',
      D    => inp_ext_a,
      Q    => inp_ext_ar
   );

   U_reg3 : FDRE
   generic map (
      INIT => '0'
   )
   port map (
      C    => clkb,
      CE   => '1',
      R    => '0',
      D    => inp_ext_ar,
      Q    => inp_ext_b
   );

   U_reg4 : FDRE
   generic map (
      INIT => '0'
   )
   port map (
      C    => clkb,
      CE   => '1',
      R    => '0',
      D    => inp_ext_b,
      Q    => inp_ext_br
   );

   edge_det_u : entity work.EdgeDetector 
   port map (
      clk    => clkb,
      rst    => '0',
      input  => inp_ext_br,
      output => outb 
   );

end rtl;
----------------------------------------------




----------------------------------------------
-- VecSyns
----------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;


entity VecSync is
generic(
   W      : natural := 32;
   STAGES : natural := 2
);
port (
   rst     : in  std_logic;
   clka    : in  std_logic;
   inpa    : in  std_logic_vector(W-1 downto 0);
   clkb    : in  std_logic;
   outb    : out std_logic_vector(W-1 downto 0)
);
end VecSync;

architecture rtl of VecSync is
   type vecPipeType is array(0 to STAGES) of std_logic_vector(W-1 downto 0);
   signal ipipe : vecPipeType := (others => (others => '0'));
   signal opipe : vecPipeType := (others => (others => '0'));
begin



   IBIT_GEN : for ibit in 0 to W-1 generate

      U_reg1 : FDRE
      generic map (
        INIT => '0'
      )
      port map (
        C    => clka,
        CE   => '1',
        R    => rst,
        D    => inpa(ibit),
        Q    => ipipe(0)(ibit)
      );

      STAGE_GEN : for istage in 0 to STAGES-1 generate

         U_reg2 : FDRE
         generic map (
           INIT => '0'
         )
         port map (
           C    => clka,
           CE   => '1',
           R    => rst,
           D    => ipipe(0+istage)(ibit),
           Q    => ipipe(1+istage)(ibit) 
         );

         U_reg3 : FDRE
         generic map (
           INIT => '0'
         )
         port map (
           C    => clkb,
           CE   => '1',
           R    => rst,
           D    => opipe(0+istage)(ibit),
           Q    => opipe(1+istage)(ibit)
         );

      end generate STAGE_GEN;

      U_reg4 : FDRE
      generic map (
        INIT => '0'
      )
      port map (
        C    => clkb,
        CE   => '1',
        R    => rst,
        D    => ipipe(STAGES)(ibit),
        Q    => opipe(0)(ibit)
      );
   end generate IBIT_GEN;

   outb <= opipe(STAGES);

end rtl;
----------------------------------------------


----------------------------------------------
-- VecSync
----------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;


entity BitSync is
generic(
   STAGES : natural := 2
);
port (
   rst     : in  std_logic;
   clka    : in  std_logic;
   inpa    : in  std_logic;
   clkb    : in  std_logic;
   outb    : out std_logic
);
end BitSync;

architecture rtl of BitSync is
   signal ipipe : std_logic_vector(STAGES downto 0) := (others => '0');
   signal opipe : std_logic_vector(STAGES downto 0) := (others => '0');

begin

   U_reg1 : FDRE
   generic map (
     INIT => '0'
   )
   port map (
     C    => clka,
     CE   => '1',
     R    => rst,
     D    => inpa,
     Q    => ipipe(0)
   );

   STAGE_GEN : for istage in 0 to STAGES-1 generate

      U_reg2 : FDRE
      generic map (
        INIT => '0'
      )
      port map (
        C    => clka,
        CE   => '1',
        R    => rst,
        D    => ipipe(0+istage),
        Q    => ipipe(1+istage) 
      );

      U_reg3 : FDRE
      generic map (
        INIT => '0'
      )
      port map (
        C    => clkb,
        CE   => '1',
        R    => rst,
        D    => opipe(0+istage),
        Q    => opipe(1+istage)
      );

   end generate STAGE_GEN;

   U_reg4 : FDRE
   generic map (
     INIT => '0'
   )
   port map (
     C    => clkb,
     CE   => '1',
     R    => rst,
     D    => ipipe(STAGES),
     Q    => opipe(0)
   );

   outb <= opipe(STAGES);

end rtl;
----------------------------------------------

----------------------------------------------
-- Strobe Transition 
----------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library UNISIM;
use UNISIM.VComponents.all;


entity VecSync2 is
generic(
   W      : natural := 32
);
port (
   rst     : in  std_logic;
   clka    : in  std_logic;
   inpa    : in  std_logic_vector(W-1 downto 0);
   clkb    : in  std_logic;
   outb    : out std_logic_vector(W-1 downto 0)
);
end VecSync2;

architecture rtl of VecSync2 is
   type vecPipeType is array(0 to 4) of std_logic_vector(W-1 downto 0);
   signal ipipe : vecPipeType := (others => (others => '0'));
   signal opipe : vecPipeType := (others => (others => '0'));
begin

   process(clka)
   begin
      if rising_edge(clka) then
         ipipe(0) <= inpa;
         ipipe(1) <= ipipe(0);
         ipipe(2) <= ipipe(1);
         if ipipe(2) = ipipe(1) then
            ipipe(3) <= ipipe(2);
         end if;
      end if;
      
   end process;

   process(clkb)
   begin
      if rising_edge(clkb) then
         opipe(0) <= ipipe(3);
         opipe(1) <= opipe(0);
         opipe(2) <= opipe(1);
      end if;
   end process;

   outb <= opipe(2);

end rtl;
----------------------------------------------


