library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.UtilityPkg.all;
use work.LappdPkg.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity tb_dac is
end tb_dac;



architecture behav of tb_dac is
   constant T_clk    : time := 20 ns;
   signal clk        : std_logic;
   signal rst        : std_logic := '0';

   signal dacSclk    : sl;
   signal dacCsb     : sl;
   signal dacSin     : sl;
   signal dacSout    : sl;
   signal SpiDAC_regReq : sl;
   signal SpiDAC_regAck : sl;
   signal SpiDAC_regRdData : slv(15 downto 0);

   signal regAddr    :   slv(4 downto 0) := (others => '0');
   signal regWrData  :   slv(15 downto 0) := (others => '0');
   signal regOp      :   sl               := '0';
   
begin

  U_SpiDAC : entity work.SpiDACx0508
     generic map (
      N_CHAINED => 1
     )
     port map (
       -- Clock and reset
       sysClk    => clk,     --: in sl;
       sysRst    => rst,    --: in sl;
       -- DAC serial IO
       dacSclk   => dacSclk, --: out sl;
       dacCsb    => dacCsb,  --: out sl;
       dacSin    => dacSin,  -- out sl;
       dacSout   => dacSout, -- in  sl;
       -- Register mapping into this module
       dacOp     => regOp, -- in  sl;
       dacWrData => regWrData(15 downto 0), -- in  slv(15 downto 0);     
       dacRdData => SpiDAC_regRdData,
       dacReq    => SpiDAC_regReq, -- in  sl;
       dacAck    => SpiDAC_regAck, -- out sl;
       -- Based on our convention, we grab the middle nibble 
       dacAddr   => regAddr(4 downto 0), -- in  slv( 4 downto 0);

       -- Shadow register output
       dacShadow => open -- out Word16Array(15 downto 0)
    ); 


   ------------------------------------------
   -- clock process 
   ------------------------------------------
   clk_proc : process                      
   begin                                     
      clk <= '0';                            
      wait for T_clk/2;                 
      clk <= '1';                            
      wait for T_clk/2;                 
   end process;                              
   ------------------------------------------
   
   stim : process 
   begin
      wait for 100 ns;
      rst <= '1';
      wait for 100 ns; 
      rst <= '0';

      wait until clk = '1';
      regOp <= '1';
      regWrData <= x"000A";
      SpiDAC_regReq <= '1';
      regAddr       <= b"00001";
      
      wait until SpiDAC_regAck = '1';
      SpiDAC_regReq <= '0';

      wait for 1 us;
      wait until clk = '1';

      regOp <= '1';
      regWrData <= x"000A";
      SpiDAC_regReq <= '1';
      regAddr       <= b"10001";
      wait until SpiDAC_regAck = '1';
      SpiDAC_regReq <= '0';


   end process;

end behav;

