library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.UtilityPkg.all;
use work.LappdPkg.all;

entity lappdEthUnpacker is
   generic (
      
   );
   port (
      clk       : in  sl;
      rst       : in  sl;

      -- AXI interface
      TxData    : in  slv(7 downto 0);
      TxValid   : in  sl;
      TxLast    : in  sl;
      TxReady   : out sl
      
      
   );
end entity lappdEthUnpacker;

architecture behav of lappdEthUnpacker is

   

begin

   process (clk)
   begin
      if rising_edge (clk) then
         if TxValid = '1' and r.TxReady = '1' then
            r.data8    <= data;
            r.data8q   <= r.data8;
            r.byteCnt  <= r.byteCnt + '1';
            if r.byteCnt = '1' then
            end if;

         end if;
      end if;
   end process;

   process ()
   begin
      case r.state is 
         when IDLE_S =>
            r_nxt.TxReady <= '1';
            if TxValid = '1' then
               r_nxt.data <= TxData;
               r_nxt.state <= UDP_HEADER_S;
            end if;

         when UDP_HEADER_S => 
         when EVT_HEADER_S =>
         when HIT_HEADER_S =>
         when HIT_PAYLOAD_S =>
         when HIT_FOOTER_S =>
      end case;
   end process;


end behav;
