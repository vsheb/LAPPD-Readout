library ieee;
use ieee.std_logic_1164.all;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;

library work;

----------------------------------------------------------------------
----- REGISTERS MAPPING ----------------------------------------------
----------------------------------------------------------------------
-- reg_info record : 
-- NAME     : register name   : string (1 to 10)
-- ADDRESS   : register number : t_reg_data
-- DEFVAL   : default value   : std_logic_vector(15 downto 0)
-- ACC TYPE : access type     : std_logic_vector(1 downto 0)
--                              bit 0 - write access inside of project 
--                              bit 1 - write access from microblaze
--                              "01"  -- register may be changed only from fpga project
--                                       such registers operate in always enable mode 
--                                       for writing from internal design
--                              "11"  -- control registers, set from CPU for single clock
--                                       on next clock reset to zero
----------------------------------------------------------------------


package RegDefs is

   ----- FW VERSION -----------------------------------
   constant FW_VERSION     : integer := 111;
   constant FW_VERSION_SLV : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(FW_VERSION, 32));
   ----------------------------------------------------

   constant SYS_FREQ       : integer := 125;
   constant SYS_FREQ_SLV   : std_logic_vector(31 downto 0) := std_logic_vector(to_unsigned(SYS_FREQ, 32));
   
   
   constant REG_DATA_WIDTH : natural := 32;
   constant REG_ADDR_WIDTH : natural := 16;
   constant BAD_REG_ADDR   : natural := 999999;
   type string_pointer  is access string;

   -- record of register parameters
   type tRegInfo is record
      NAME     : string(1 to 16);
      ADDRESS  : std_logic_vector(REG_ADDR_WIDTH-1 downto 0); 
      DEFVAL   : std_logic_vector(REG_DATA_WIDTH-1 downto 0);
      ACCTYPE  : std_logic_vector(1 downto 0);  -- bit 0 - access from inside of project 
                                                -- bit 1 - access from microblaze
      ARRLEN   : natural;
  end record tRegInfo; 

  subtype tRegData is std_logic_vector(REG_DATA_WIDTH-1 downto 0);
  type    tRegDataArray        is array(integer range <>) of tRegData;
  type    tRegInfoArray        is array(integer range <>) of tRegInfo;

  constant cZeroRegInfo : tRegInfo := ((others => ' '), X"0000", X"0000_0000", B"00", 0);

  ---------------------------------------------------
  --- GENERAL REGISTERS -----------------------------
  ---------------------------------------------------
  constant REG_MAP_INI : tRegInfoArray := (
    -- NAME                ADDRESS   DEFAULT     ACCESS NUM_ELEMENTS
    ( "SW_VERSION      ",  X"0000", X"C0DE_CAFE", B"00",1), 
    ( "FW_VERSION      ",  X"0004", FW_VERSION_SLV, B"00",1), 
    ( "DEVICEDNA_L     ",  X"0008", X"0000_0000", B"10",1), 
    ( "DEVICEDNA_H     ",  X"0010", X"0000_0000", B"10",1), 
    ( "EFUSEVAL        ",  X"0018", X"0000_0000", B"10",1), 
    ( "SCRATCH         ",  X"0020", X"0000_0000", B"10",1), 
    ( "SYS_FREQ        ",  X"0030", SYS_FREQ_SLV, B"00",1), 
--#define EEVEE_OFFSET 0x0100
--#define REG_EEVEE_SRCMAC_LOW 0x0000
--#define REG_EEVEE_SRCMAC_HIGH 0x0008
--#define REG_EEVEE_SRCIP 0x0010
--#define REG_EEVEE_CLOCK 0x0020
--#define REG_EEVEE_TICKS_LOW 0x0024
--#define REG_EEVEE_TICKS_HIGH 0x0028
    ( "SRCMAC_LOW      ",  X"0100", X"0000_0000", B"01",1), 
    ( "SRCMAC_HIGH     ",  X"0108", X"0000_0000", B"01",1), 
    ( "SRCIP           ",  X"0110", X"0000_0000", B"01",1), 
    ( "EEVEE_CLOCK     ",  X"0120", X"0000_0000", B"01",1), 
--#define NBIC_OFFSET 0x0200
--#define REG_NBIC_DESTMAC_LOW 0x0000
--#define REG_NBIC_DESTMAC_HIGH 0x0008
--#define REG_NBIC_DESTIP 0x0010
--// Source port is low u16, destination port is high u16
--#define REG_NBIC_PORTS 0x0018
    ( "DESTMAC_LOW     ",  X"0200", X"0000_0000", B"01",1), 
    ( "DESTMAC_HIGH    ",  X"0208", X"0000_0000", B"01",1), 
    ( "DESTIP          ",  X"0210", X"0000_0000", B"01",1), 
    ( "NBIC_PORTS      ",  X"0218", X"0000_0000", B"01",1), 
---
    ( "CMD             ",  X"0320", X"0000_0000", B"11",1), 
    ( "ADCBUFNUMWORDS  ",  X"0328", X"0000_0400", B"01",1), 
    ( "ADCDEBUG1       ",  X"0330", X"0000_0000", B"10",1), 
    ( "ADCBUFDEBUG     ",  X"0338", X"0000_0000", B"10",1), 
    ( "ADCCLKDELAY     ",  X"0340", X"0000_000F", B"01",2), 
    ( "ADCFRAMEDELAY   ",  X"0348", X"0000_000E", B"01",2), 
    ( "BITSLIP         ",  X"0350", X"0000_0000", B"11",2), 
    ( "ADCWORDSWRITTEN ",  X"0358", X"0000_0000", B"10",1),
    ( "ADCDEBUGCHAN    ",  X"0360", X"0000_0000", B"01",1),
    ( "BITSLIPCNT      ",  X"0368", X"0000_0000", B"10",2),
    ( "MODE            ",  X"0370", X"0000_0000", B"01",1),
    ( "DRSPLLLCK       ",  X"0378", X"0000_0000", B"10",1),
    ( "ADCBUFCURADDR   ",  X"0380", X"0000_0000", B"10",1),
    ( "STATUS          ",  X"0388", X"0000_0000", B"10",1),
    ( "DRSREFCLKRATIO  ",  X"0390", X"0000_0033", B"01",1),
    ( "ADCFRAMEDEBUG   ",  X"03A8", X"0000_0000", B"10",2),
    ( "ADCDATADELAY    ",  X"0400", X"0000_000E", B"01",32),
    --( "ADCDELAYDEBUG   ",  X"0500", X"0000_0000", B"10",36), --(16+2)*2
    ( "DRSADCPHASE     ",  X"0600", X"0000_0000", B"01",1),
    ( "DRSIDLEMODE     ",  X"0608", X"0000_0000", B"01",1),
    ( "NSAMPLEPACKET   ",  X"0610", X"0000_0200", B"01",1),
    ( "DRSVALIDPHASE   ",  X"0618", X"0000_0000", B"01",1),
    ( "DRSVALIDDELAY   ",  X"0620", X"0000_0038", B"00",1),
    ( "EBDEBUG         ",  X"0628", X"0000_0000", B"10",1),
    ( "DRSWAITADDR     ",  X"0638", X"0000_0010", B"01",1),
    ( "DRSWAITSTART    ",  X"0640", X"0000_0000", B"01",1),
    ( "DRSWAITINIT     ",  X"0648", X"0000_0000", B"01",1),
    ( "DRSSTOPSAMPLE   ",  X"0650", X"0000_0000", B"10",8),
    ( "ADCCHANMASK     ",  X"0670", X"0000_0000", B"01",2),
    ( "NUDPPORTS       ",  X"0678", X"0000_0001", B"01",1),
    ( "CURRENTPORT     ",  X"0680", X"0000_0000", B"10",1),
    ( "ZEROTHRESH      ",  X"0700", X"0000_0000", B"01",64),
    ( "EXTTRGCNT       ",  X"0800", X"0000_0000", B"10",1),
    ( "CUREVTNUM       ",  X"0808", X"0000_0000", B"10",1),
    ( "DRSPLLLOSCNT    ",  X"0810", X"0000_0000", B"10",8),
    ( "ADCTHRESHMASK   ",  X"0850", X"0000_0000", B"10",2)
  );
  ---------------------------------------------------


  constant C_CMD_RESET_BIT         : natural := 0;
  constant C_CMD_ADCCLEAR_BIT      : natural := 1;
  constant C_CMD_ADCSTART_BIT      : natural := 2; -- obsolete
  constant C_CMD_ADCTXTRG_BIT      : natural := 3;
  constant C_CMD_ADCRESET_BIT      : natural := 4;
  constant C_CMD_ADCBTSLP_BIT      : natural := 5;
  constant C_CMD_READREQ_BIT       : natural := 6;
  constant C_CMD_RUNRESET_BIT      : natural := 7;
  constant C_CMD_ADCRDRESET_BIT    : natural := 8;

  constant C_MODE_ADCBUF_WREN_BIT  : natural := 0;
  constant C_MODE_DRS_TRANS_BIT    : natural := 1;
  constant C_MODE_DRS_DENABLE_BIT  : natural := 2;
  constant C_MODE_TCA_ENA_BIT      : natural := 3;
  constant C_MODE_EB_FRDISABLE_BIT : natural := 4;
  constant C_MODE_EXTTRG_EN_BIT    : natural := 5;
  constant C_MODE_DRS_REVRS_BIT    : natural := 6;
  constant C_MODE_CLKIN_TRG_BIT    : natural := 7;
  constant C_MODE_PEDSUB_EN_BIT    : natural := 8;
  constant C_MODE_ZERSUP_EN_BIT    : natural := 9;
  constant C_MODE_ADC_PDN_F_BIT    : natural := 10;
  constant C_MODE_ADC_PDN_G_BIT    : natural := 11;
  constant C_MODE_RFSWITCH_BIT     : natural := 13;

  function vec2str(value : std_logic_vector) return string;


  -- calculate number of registers taking ARRLEN into account
  function get_number_of_regs(iRec : tRegInfoArray) return natural;  
  constant NREG : natural := get_number_of_regs(REG_MAP_INI);

  -- expand register arrays (ARRLEN) to single array
  function expandRegMap (iRec : tRegInfoArray; numRegs : natural) return tRegInfoArray;
  constant REG_MAP : tRegInfoArray(0 to NREG-1) := expandRegMap(REG_MAP_INI, NREG);
  
  -- make array of the registers default values
  function genRegDataFromRegInfoArray (iRec : tRegInfoArray) return tRegDataArray;
  constant REG_DEFAULTS     : tRegDataArray(0 to NREG-1) := genRegDataFromRegInfoArray(REG_MAP);


  -- get index of the register in the array by its name
  function getRegInd(NAME : string) return natural;
  function getRegIndexByAddr(ADDR : std_logic_vector(REG_ADDR_WIDTH-1 downto 0)) return natural;
  function getRegAccType(ADDR : std_logic_vector(REG_ADDR_WIDTH-1 downto 0)) return std_logic_vector;
  

  
  -- generate array of registers by given array of registers parameters
end package RegDefs;

-------------------------------------------------------------------
-- PACKAGE BODY ---------------------------------------------------
-------------------------------------------------------------------
 
package body RegDefs is

  -------------------------------------------------------------------
  -- get index of the register by given name
  -------------------------------------------------------------------
  function getRegInd 
  (NAME : string) return natural is
    variable index     : natural := BAD_REG_ADDR;
    variable v_name    : string(1 to cZeroRegInfo.NAME'length) := (others => ' ');
    variable v_reginfo : tRegInfo;
    variable v_reginfo_arr : tRegInfoArray(0 to REG_MAP'length-1) := REG_MAP;
  begin
    -- for simulation
    --v_reginfo := v_reginfo_arr(1);
    if NAME'length > cZeroRegInfo.NAME'length then
        assert FALSE report "Reg name is too long" severity failure;
    end if;

    v_name(1 to NAME'length) := NAME;

    for ii in 0 to NREG-1 loop
      if v_reginfo_arr(ii).NAME = v_name then
        index := ii;
      end if;
    end loop;
    -- for simulation
    report "REG NAME :: " & NAME(1 to NAME'length) & " INDEX :: " & integer'image(index);
    if index = BAD_REG_ADDR then
       assert FALSE report "Register not found!" & NAME & "|" & v_name severity failure;
    end if;
    return index;
  end function getRegInd;
  -------------------------------------------------------------------

  -------------------------------------------------------------------
  -- get array index by given reg address
  -------------------------------------------------------------------
  function getRegIndexByAddr 
  (ADDR : std_logic_vector(REG_ADDR_WIDTH-1 downto 0)) return natural is
    variable index     : natural := BAD_REG_ADDR;
    variable v_addr    : std_logic_vector := ADDR;
    variable v_reginfo : tRegInfo;
    variable v_reginfo_arr : tRegInfoArray(0 to REG_MAP'length-1) := REG_MAP;
    variable dupl : natural := 0;
  begin
    for ii in 0 to REG_MAP'length-1 loop
      if v_reginfo_arr(ii).ADDRESS = v_addr then
        index := ii;
        dupl  := dupl + 1;
      end if;
    end loop;


    return index;
  end function getRegIndexByAddr;
  -------------------------------------------------------------------

  -------------------------------------------------------------------
  -- get access type of the reg with given address 
  -------------------------------------------------------------------
  function getRegAccType 
  (ADDR : std_logic_vector(REG_ADDR_WIDTH-1 downto 0)) return std_logic_vector is
    variable v_addr    : std_logic_vector := ADDR;
    variable v_reginfo : tRegInfo;
    variable v_reginfo_arr : tRegInfoArray(0 to REG_MAP_INI'length-1) := REG_MAP_INI;
    variable dupl : natural := 0;
    variable acc_type : std_logic_vector(1 downto 0) := B"00"; 
  begin
    for ii in 0 to REG_MAP_INI'length-1 loop
      if v_reginfo_arr(ii).ADDRESS = v_addr then
        acc_type := v_reginfo_arr(ii).ACCTYPE;
        dupl  := dupl + 1;
      end if;
    end loop;
    return acc_type;
  end function getRegAccType;
  -------------------------------------------------------------------

  -------------------------------------------------------------------
  -- generate array of default registers data from registers info array
  -------------------------------------------------------------------
  function genRegDataFromRegInfoArray (iRec : tRegInfoArray) return tRegDataArray is
    constant nregstot : natural := get_number_of_regs(iRec);
    variable v_data : tRegDataArray(0 to nregstot-1) := (others => (others => '0'));
    variable v_reginfo_arr : tRegInfoArray(0 to iRec'length-1) := iRec;
    variable ind  : natural := 0;
    variable nreg : natural := 0;
    variable x : tRegInfo;
  begin
    for i in 0 to v_reginfo_arr'length-1 loop 
      nreg := v_reginfo_arr(i).ARRLEN;
      for j in 0 to nreg-1 loop
         v_data(ind) := v_reginfo_arr(i).DEFVAL;
         x := v_reginfo_arr(i);
         report "REGISTER: " & x.NAME(1 to x.NAME'length) & " INDEX :: " & integer'image(ind) & " ADDR :: " & vec2str(x.ADDRESS);
         ind := ind + 1;
      end loop;
    end loop;
    return v_data;
  end function genRegDataFromRegInfoArray;
  -------------------------------------------------------------------

  -------------------------------------------------------------------
  -- generate array of default registers data from registers info array
  -------------------------------------------------------------------
  function get_number_of_regs (iRec : tRegInfoArray) return natural is
    variable v_reginfo_arr : tRegInfoArray(0 to iRec'length-1) := iRec;
    variable nregstot : integer := 0;
    variable n_regs_in_arr    : integer := 0;
  begin
    for ii in 0 to v_reginfo_arr'length-1 loop 
      n_regs_in_arr := v_reginfo_arr(ii).ARRLEN;
      nregstot := nregstot + n_regs_in_arr;

    end loop;
    report "TOTAL NUMBER REGISTERS:: " & integer'image(nregstot);
    return nregstot;
  end function get_number_of_regs;
  -------------------------------------------------------------------

  -------------------------------------------------------------------
  --
  -------------------------------------------------------------------
  function expandRegMap (iRec : tRegInfoArray; numRegs : natural) return tRegInfoArray is
    variable v_reginfo_arr_in  : tRegInfoArray(0 to iRec'length-1) := iRec;
    variable v_reginfo_arr_out : tRegInfoArray(0 to numRegs-1);
    variable n_regs_in_arr    : integer := 0;
    variable ind  : natural := 0;
    variable x : tRegInfo;
    variable basename_len : natural := 0;
    variable v_addr : std_logic_vector(REG_ADDR_WIDTH-1 downto 0);
    variable v_defval : tRegData;
    variable v_acc    : std_logic_vector(cZeroRegInfo.ACCTYPE'length-1 downto 0);

    variable v_name : string(1 to 20) := (others=>' ');   
    variable v_len  : integer    := 0;                    

  begin
    -- check for registers duplication
    for i in 0 to v_reginfo_arr_in'length-1 loop
       for j in i+1 to v_reginfo_arr_in'length-1 loop
         if v_reginfo_arr_in(i).ADDRESS = v_reginfo_arr_in(j).ADDRESS then
            assert FALSE report "Duplicated registers!" severity failure;
         end if;
         if v_reginfo_arr_in(i).NAME = v_reginfo_arr_in(j).NAME then
            assert FALSE report "Duplicated registers!" severity failure;
         end if;
       end loop;
    end loop;
       
    for i in 0 to v_reginfo_arr_in'length-1 loop 
      x := v_reginfo_arr_in(i);
      n_regs_in_arr := x.ARRLEN;
      
      L : for strInd in 1 to x.NAME'length loop
         basename_len := strInd;
         exit L when x.NAME(strInd) = ' '; 
      end loop;
      basename_len := basename_len - 1;

      for j in 0 to n_regs_in_arr-1 loop
         --v_len := integer'IMAGE(j)'LENGTH; doesn't work.. WHY?
         -- so calculate it in the sdupid way
         if j < 10 then
            v_len := 1;
         elsif j > 9 and j < 100 then
            v_len := 2;
         elsif j > 99 and j < 1000 then
            v_len := 3;
         else
            v_len := 4; -- probably we will not have more than 10000 regs
         end if;
         v_name := (others => ' ');
         if n_regs_in_arr > 1 then
            v_name(1 to v_len + 1 + basename_len) := x.NAME(1 to basename_len) & "_" & integer'IMAGE(j);
         else
            v_name(1 to cZeroRegInfo.NAME'length) := x.NAME;
         end if;
         -- increment addres 
         v_addr   := x.ADDRESS + std_logic_vector(to_unsigned(j*4,x.ADDRESS'length));           
         v_defval := x.DEFVAL;
         v_acc    := x.ACCTYPE;
         v_reginfo_arr_out(ind) := (v_name(1 to cZeroRegInfo.NAME'length), v_addr, v_defval, v_acc, 1);                
         ind := ind + 1;
      end loop;
    end loop;
    return v_reginfo_arr_out;
  end function expandRegMap;
  -------------------------------------------------------------------

   function vec2str (value : STD_LOGIC_VECTOR) return STRING is
      constant NULLS  : string(1 to 1) := "X";
      constant ne     : INTEGER := (value'length+3)/4;
      variable pad    : std_logic_vector(0 to (ne*4 - value'length) - 1) := (others => '0');
      variable ivalue : std_logic_vector(0 to ne*4 - 1) := (others => '0');
      variable result : STRING(1 to ne);
      variable quad   : std_logic_vector(0 to 3);
   begin
      if value'length < 1 then
         return NULLS;
      else
         if value (value'left) = 'Z' then
            pad := (others => 'Z');
         else
            pad := (others => '0');
         end if;
         ivalue := pad & value;
         for i in 0 to ne-1 loop
            quad := To_X01Z(ivalue(4*i to 4*i+3));
            case quad is
               when x"0"   => result(i+1) := '0';
               when x"1"   => result(i+1) := '1';
               when x"2"   => result(i+1) := '2';
               when x"3"   => result(i+1) := '3';
               when x"4"   => result(i+1) := '4';
               when x"5"   => result(i+1) := '5';
               when x"6"   => result(i+1) := '6';
               when x"7"   => result(i+1) := '7';
               when x"8"   => result(i+1) := '8';
               when x"9"   => result(i+1) := '9';
               when x"A"   => result(i+1) := 'A';
               when x"B"   => result(i+1) := 'B';
               when x"C"   => result(i+1) := 'C';
               when x"D"   => result(i+1) := 'D';
               when x"E"   => result(i+1) := 'E';
               when x"F"   => result(i+1) := 'F';
               when "ZZZZ" => result(i+1) := 'Z';
               when others => result(i+1) := 'X';
            end case;
         end loop;
         return result;
      end if;
   end function vec2str;
end package body RegDefs;
