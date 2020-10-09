library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.UtilityPkg.all;
--use work.Version.all;
--use work.P1Pkg.all;
-- For Xilinx primitives
library UNISIM;
use UNISIM.VComponents.all;

entity spi_tb is 
end spi_tb;

architecture beh of spi_tb is
    signal clk  : sl;
    signal sRst : sl;
    signal regAddr       : slv(31 downto 0);
    signal regWrData     : slv(31 downto 0);
    signal regRdData     : slv(31 downto 0);
    signal regReq        : sl;
    signal regOp         : sl;
    signal regAck        : sl;
    
    signal adcSclk       : sl;
    signal adcCsb        : slv(1 downto 0);
    signal adcSin        : sl;
    signal adcSout       : sl;
    signal adcAddr       : slv(7 downto 0);
    signal wrData        : slv(15 downto 0);
    signal rdData        : slv(15 downto 0);
    constant clk_period  : time := 10 ns;
begin

-- uuti : entity work.RegMap
--  port map (
--    clk           => clk, 
--    sRst          => sRst, 
--    -- Register interfaces to UART controller
--    regAddr       => regAddr,
--    regWrData     => regWrData,
--    regRdData     => regRdData,
--    regReq        => regReq,
--    regOp         => regOp,
--    regAck        => regAck,

--    -- adc serial IO
--    adcSclk       => adcSclk,
--    adcCsb        => adcCsb,
--    adcSin        => adcSin,
--    adcSout       => adcSout
--    );
    
    uut : entity work.SpiADS52J90
       port map(
          -- Clock and reset
          sysClk    => clk,
          sysRst    => sRst,
          -- adc serial IO
          Sclk   => adcSclk,
          Csb    => adcCsb,
          Sin    => adcSin,
          Sout   => adcSout,
          Sel    => '0',
          -- Register mapping into this module
          Op     => regOp,
          Req    => regReq,
          Ack    => regAck,
          Addr   => adcAddr,
          WrData => wrData,
          RdData => rdData,
          -- Shadow register output
          Shadow => open
       ); 

    
    

clk_process : process
begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
end process;

stim : process
begin
    sRst <= '0';
    regReq <= '0';
    regWrData <= (others => '0');
    regAddr   <= (others => '0');
    regOp <= '0';
    
    wait for 100 ns;
        regOp <= '0';

    adcAddr <= B"0000_0011";
    wrData  <= B"0100_0000_0000_1001";
--    regWrData <= X"0000_00AA";
    wait until clk = '1';
    regReq    <= '1';
    wait until clk = '0';
    wait for 10000 ns;
end process;


end beh;
