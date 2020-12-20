--Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2018.1 (lin64) Build 2188600 Wed Apr  4 18:39:19 MDT 2018
--Date        : Mon Dec 21 05:43:09 2020
--Host        : hPC running 64-bit Ubuntu 20.04.1 LTS
--Command     : generate_target base_mb_wrapper.bd
--Design      : base_mb_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity base_mb_wrapper is
  port (
    CLKIN_125 : in STD_LOGIC;
    IO_BUS_addr_strobe : out STD_LOGIC;
    IO_BUS_address : out STD_LOGIC_VECTOR ( 31 downto 0 );
    IO_BUS_byte_enable : out STD_LOGIC_VECTOR ( 3 downto 0 );
    IO_BUS_read_data : in STD_LOGIC_VECTOR ( 31 downto 0 );
    IO_BUS_read_strobe : out STD_LOGIC;
    IO_BUS_ready : in STD_LOGIC;
    IO_BUS_write_data : out STD_LOGIC_VECTOR ( 31 downto 0 );
    IO_BUS_write_strobe : out STD_LOGIC;
    M_AXIS_1G_tdata : out STD_LOGIC_VECTOR ( 7 downto 0 );
    M_AXIS_1G_tkeep : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXIS_1G_tlast : out STD_LOGIC;
    M_AXIS_1G_tready : in STD_LOGIC;
    M_AXIS_1G_tvalid : out STD_LOGIC;
    S_AXIS_1G_tdata : in STD_LOGIC_VECTOR ( 7 downto 0 );
    S_AXIS_1G_tlast : in STD_LOGIC;
    S_AXIS_1G_tready : out STD_LOGIC;
    S_AXIS_1G_tvalid : in STD_LOGIC;
    S_AXIS_DATAOUT_tdata : in STD_LOGIC_VECTOR ( 15 downto 0 );
    S_AXIS_DATAOUT_tkeep : in STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXIS_DATAOUT_tlast : in STD_LOGIC;
    S_AXIS_DATAOUT_tready : out STD_LOGIC;
    S_AXIS_DATAOUT_tvalid : in STD_LOGIC;
    reg_tkeep : in STD_LOGIC_VECTOR ( 3 downto 0 );
    reset : in STD_LOGIC
  );
end base_mb_wrapper;

architecture STRUCTURE of base_mb_wrapper is
  component base_mb is
  port (
    S_AXIS_1G_tvalid : in STD_LOGIC;
    S_AXIS_1G_tready : out STD_LOGIC;
    S_AXIS_1G_tdata : in STD_LOGIC_VECTOR ( 7 downto 0 );
    S_AXIS_1G_tlast : in STD_LOGIC;
    M_AXIS_1G_tvalid : out STD_LOGIC;
    M_AXIS_1G_tready : in STD_LOGIC;
    M_AXIS_1G_tdata : out STD_LOGIC_VECTOR ( 7 downto 0 );
    M_AXIS_1G_tkeep : out STD_LOGIC_VECTOR ( 0 to 0 );
    M_AXIS_1G_tlast : out STD_LOGIC;
    S_AXIS_DATAOUT_tvalid : in STD_LOGIC;
    S_AXIS_DATAOUT_tready : out STD_LOGIC;
    S_AXIS_DATAOUT_tdata : in STD_LOGIC_VECTOR ( 15 downto 0 );
    S_AXIS_DATAOUT_tkeep : in STD_LOGIC_VECTOR ( 1 downto 0 );
    S_AXIS_DATAOUT_tlast : in STD_LOGIC;
    reset : in STD_LOGIC;
    CLKIN_125 : in STD_LOGIC;
    reg_tkeep : in STD_LOGIC_VECTOR ( 3 downto 0 );
    IO_BUS_addr_strobe : out STD_LOGIC;
    IO_BUS_address : out STD_LOGIC_VECTOR ( 31 downto 0 );
    IO_BUS_byte_enable : out STD_LOGIC_VECTOR ( 3 downto 0 );
    IO_BUS_read_data : in STD_LOGIC_VECTOR ( 31 downto 0 );
    IO_BUS_read_strobe : out STD_LOGIC;
    IO_BUS_ready : in STD_LOGIC;
    IO_BUS_write_data : out STD_LOGIC_VECTOR ( 31 downto 0 );
    IO_BUS_write_strobe : out STD_LOGIC
  );
  end component base_mb;
begin
base_mb_i: component base_mb
     port map (
      CLKIN_125 => CLKIN_125,
      IO_BUS_addr_strobe => IO_BUS_addr_strobe,
      IO_BUS_address(31 downto 0) => IO_BUS_address(31 downto 0),
      IO_BUS_byte_enable(3 downto 0) => IO_BUS_byte_enable(3 downto 0),
      IO_BUS_read_data(31 downto 0) => IO_BUS_read_data(31 downto 0),
      IO_BUS_read_strobe => IO_BUS_read_strobe,
      IO_BUS_ready => IO_BUS_ready,
      IO_BUS_write_data(31 downto 0) => IO_BUS_write_data(31 downto 0),
      IO_BUS_write_strobe => IO_BUS_write_strobe,
      M_AXIS_1G_tdata(7 downto 0) => M_AXIS_1G_tdata(7 downto 0),
      M_AXIS_1G_tkeep(0) => M_AXIS_1G_tkeep(0),
      M_AXIS_1G_tlast => M_AXIS_1G_tlast,
      M_AXIS_1G_tready => M_AXIS_1G_tready,
      M_AXIS_1G_tvalid => M_AXIS_1G_tvalid,
      S_AXIS_1G_tdata(7 downto 0) => S_AXIS_1G_tdata(7 downto 0),
      S_AXIS_1G_tlast => S_AXIS_1G_tlast,
      S_AXIS_1G_tready => S_AXIS_1G_tready,
      S_AXIS_1G_tvalid => S_AXIS_1G_tvalid,
      S_AXIS_DATAOUT_tdata(15 downto 0) => S_AXIS_DATAOUT_tdata(15 downto 0),
      S_AXIS_DATAOUT_tkeep(1 downto 0) => S_AXIS_DATAOUT_tkeep(1 downto 0),
      S_AXIS_DATAOUT_tlast => S_AXIS_DATAOUT_tlast,
      S_AXIS_DATAOUT_tready => S_AXIS_DATAOUT_tready,
      S_AXIS_DATAOUT_tvalid => S_AXIS_DATAOUT_tvalid,
      reg_tkeep(3 downto 0) => reg_tkeep(3 downto 0),
      reset => reset
    );
end STRUCTURE;
