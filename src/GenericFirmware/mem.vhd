------------------------------------------------------------------------
---- SIMPLE DUAL PORT BRAM WITH COMMON CLOCK ---------------------------
------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
 
entity bram_sdp_cc is
generic (
    DATA     : integer := 16;
    ADDR     : integer := 10
);
port (
    -- Port A
    clka   : in  std_logic;
    wea    : in  std_logic;
    addra  : in  std_logic_vector(ADDR-1 downto 0);
    dina   : in  std_logic_vector(DATA-1 downto 0);
    -- Port B
    addrb  : in  std_logic_vector(ADDR-1 downto 0);
    doutb  : out std_logic_vector(DATA-1 downto 0)
);
end bram_sdp_cc;
 
architecture rtl of bram_sdp_cc is
    -- Shared memory
    type mem_type is array ( (2**ADDR)-1 downto 0 ) of std_logic_vector(DATA-1 downto 0);
    signal mem : mem_type := (others => (others => '0'));
begin
 
process(clka)
begin
    if(clka'event and clka='1') then
        if(wea='1') then
            mem(conv_integer(addra)) <= dina;
        end if;
        doutb <= mem(conv_integer(addrb));
    end if;
end process;
 
end rtl;
------------------------------------------------------------------------

------------------------------------------------------------------------
---- SIMPLE DUAL PORT BRAM ---------------------------------------------
------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
 
entity bram_sdp is
generic (
    DATA     : integer := 16;
    ADDR     : integer := 10
);
port (
    -- Port A
    clka   : in  std_logic;
    wea    : in  std_logic;
    addra  : in  std_logic_vector(ADDR-1 downto 0);
    dina   : in  std_logic_vector(DATA-1 downto 0);
    -- Port B
    clkb   : in  std_logic;
    addrb  : in  std_logic_vector(ADDR-1 downto 0);
    doutb  : out std_logic_vector(DATA-1 downto 0)
);
end bram_sdp;
 
architecture rtl of bram_sdp is
    -- Shared memory
    type mem_type is array ( (2**ADDR)-1 downto 0 ) of std_logic_vector(DATA-1 downto 0);
    signal mem : mem_type := (others => (others => '0'));
   begin
    
   process(clka)
   begin
       if(clka'event and clka='1') then
           if(wea='1') then
               mem(conv_integer(addra)) <= dina;
           end if;
       end if;
   end process;

   process(clkb)
   begin
       if(clkb'event and clkb='1') then
           doutb <= mem(conv_integer(addrb));
       end if;
   end process;
 
end rtl;
------------------------------------------------------------------------

------------------------------------------------------------------------
---- Single-port RAM with write first
------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity bram_sp is
generic (
    WIDTH    : integer := 16;
    DEPTH    : integer := 10;
    STYLE    : string  := "block"
);
port (
    -- Port A
    clk   : in  std_logic;
    we    : in  std_logic;
    en    : in  std_logic;
    addr  : in  std_logic_vector(DEPTH-1 downto 0);
    di    : in  std_logic_vector(WIDTH-1 downto 0);
    do    : out std_logic_vector(WIDTH-1 downto 0)
);
end bram_sp;
 
architecture rtl of bram_sp is
    type mem_type is array ( (2**DEPTH)-1 downto 0 ) of std_logic_vector(WIDTH-1 downto 0);
    signal mem : mem_type := (others => (others => '0'));

    attribute ram_style : string;
    attribute ram_style of mem : signal is STYLE;
   begin
    
   process(clk)
   begin
       if(clk'event and clk='1') then
           if(en='1') then
               if(we='1') then
                   mem(to_integer(unsigned(addr))) <= di;
                   do <= di;
               else 
                   do <= mem(to_integer(unsigned(addr)));
               end if;
           end if;
       end if;
   end process;
 
end rtl;
------------------------------------------------------------------------

