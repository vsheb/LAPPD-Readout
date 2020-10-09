library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

library work;
use work.UtilityPkg.all;
use work.LappdPkg.all;
use work.RegDefs.all;

entity LappdPedMemory is
   generic (
      ADC_DATA_WIDTH  : integer := 12;
      ADC_CHAN_NUMBER : integer := 64;
      ADC_DATA_DEPTH  : integer := 10
   );
   port (
      clk            : in std_logic;
      rst            : in std_logic;
                     
      --smpNum         : in  slv(ADC_DATA_DEPTH-1 downto 0);
      smpNumArr      : in  Word10Array(0 to 7);
      pedArr         : out AdcDataArray(0 to ADC_CHAN_NUMBER-1);

      -- event is being read out, block reg interface
      evtBusy        : in sl;

      -- reg interface
      regReq         : in  sl;
      regChan        : in  slv(5 downto 0);
      regAddr        : in  slv(ADC_DATA_DEPTH-1 downto 0);
      regAck         : out sl;
      regWrEn        : in  sl;
      regWrData      : in  slv(ADC_DATA_WIDTH-1 downto 0);
      regRdData      : out slv(ADC_DATA_WIDTH-1 downto 0)
      
   );
end entity LappdPedMemory;

architecture behav of LappdPedMemory is
   --type AddrArrayType is array(0 to ADC_CHAN_NUMBER-1) of slv(ADC_DATA_DEPTH-1 downto 0);
   signal memWrEn      : slv(ADC_CHAN_NUMBER-1 downto 0)                     := (others => '0');
   signal memWrAddr    : slv(ADC_DATA_DEPTH-1 downto 0)                      := (others => '0');
   signal memAddr      : slv(ADC_DATA_DEPTH-1 downto 0)                    := (others => '0');
   signal memAddrArr   : Word10Array(0 to ADC_CHAN_NUMBER-1); --AddrArrayType := (others => (others => '0'));
   --signal memWrData    : slv(ADC_DATA_WIDTH*ADC_CHAN_NUMBER-1 downto 0)    := (others => '0');
   signal memWrData    : slv(ADC_DATA_WIDTH-1 downto 0);
   signal memRdData    : slv(ADC_DATA_WIDTH*ADC_CHAN_NUMBER-1 downto 0)    := (others => '0');
   signal memRdArr     : AdcDataArray(0 to ADC_CHAN_NUMBER-1)              := (others => (others => '0'));

begin

   GEN_CHAN : for iCh in 0 to ADC_CHAN_NUMBER generate
      -- temporary FIXME
      GEN_IF : if (iCh > 7 and iCh < 16) or (iCh > 47 and iCh < 56) generate
         U_Mem : entity work.bram_sp 
            generic map (
               WIDTH   => ADC_DATA_WIDTH,
               DEPTH   => ADC_DATA_DEPTH,
               STYLE   => "distributed"
            )
            port map (
               clk  => clk,
               we    => memWrEn(iCh),
               en    => '1',
               addr  => memAddrArr(iCh),
               di    => memWrData,

               do    => memRdArr(iCh)
            );
      end generate GEN_IF;
   end generate GEN_CHAN; 

   process (smpNumArr, regAddr, regChan, memAddr, evtBusy, memRdArr)
   begin
      if evtBusy = '1' then
         for i in 0 to 7 loop
            for j in 0 to 7 loop
               memAddrArr(i*8 + j) <= smpNumArr(i);
            end loop;
         end loop;

         regRdData <= (others => '0');
      else
         memAddrArr <= (others => regAddr);
         regRdData <= memRdArr(to_integer(unsigned(regChan)));
      end if;
      
   end process;

   process (clk)
   begin
      if rising_edge (clk) then
         regAck     <= regReq;

         memWrEn   <= (others => '0');
         if evtBusy = '0' then
            memWrEn(to_integer(unsigned(regChan))) <= regWrEn;
         end if;

         memWrData <= regWrData;
      end if;
   end process;

   pedArr    <= memRdArr;


end behav;




