# Pin placements
set_property PACKAGE_PIN A8 [get_ports gtRxN]
set_property PACKAGE_PIN B8 [get_ports gtRxP]
set_property PACKAGE_PIN A4 [get_ports gtTxN]
set_property PACKAGE_PIN B4 [get_ports gtTxP]
#Clock pins for SFP
set_property PACKAGE_PIN F6 [get_ports gtClkP]
set_property PACKAGE_PIN E6 [get_ports gtClkN]
create_clock -period 8.000 -name gtrefclk -add [get_ports gtClkP]
#create_clock -period 6.400 -name gtrefclk -add [get_ports gtClkP]
create_clock -period 2.667 -name adcclk -add [get_ports adcDoClkP]
#create_clock -period 1.3333 -name adcclk -add [get_ports adcDoClkP]


# New nishiphy for artix-7 watchdog fix
# 11/21/18 KAN
set_property async_reg true [get_cells -hierarchical *cdc_reg*]
set_false_path -from [get_clocks *] -to [get_cells -hierarchical *cdc_reg*]

# For TCA sine wave verficiation, we drive this 100 MHz oscillator out of standby
set_property PACKAGE_PIN M6 [get_ports tca_Cntl]
set_property IOSTANDARD LVCMOS25 [get_ports tca_Cntl]

#set_max_delay 8.0 -from [get_clocks clk125_clk_wiz_0] -to [get_clocks adcDoClkBufR]
set_multicycle_path -setup -rise_from [get_clocks clk125_clk_wiz_0] -rise_to [get_clocks adcDoClkBufR*] 3
set_multicycle_path -hold -rise_from [get_clocks clk125_clk_wiz_0] -rise_to [get_clocks adcDoClkBufR*] 2

set_multicycle_path -setup -rise_from [get_clocks adcDoClkBufR*] -rise_to [get_clocks clk125_clk_wiz_0] 3
set_multicycle_path -hold -rise_from [get_clocks adcDoClkBufR*] -rise_to [get_clocks clk125_clk_wiz_0] 2


set_property PACKAGE_PIN U21 [get_ports rfSwitch]
set_property IOSTANDARD LVCMOS25 [get_ports rfSwitch]

#############################################################
#ADC-1
#############################################################
set_property PACKAGE_PIN R4 [get_ports {adcDoClkP[0]}]
set_property PACKAGE_PIN T4 [get_ports {adcDoClkN[0]}]
set_property PACKAGE_PIN Y4 [get_ports {adcFrClkP[0]}]
set_property PACKAGE_PIN AA4 [get_ports {adcFrClkN[0]}]

set_property PACKAGE_PIN R3 [get_ports {adcDataInP[0]}]
set_property PACKAGE_PIN R2 [get_ports {adcDataInN[0]}]
set_property PACKAGE_PIN T1 [get_ports {adcDataInP[1]}]
set_property PACKAGE_PIN U1 [get_ports {adcDataInN[1]}]
set_property PACKAGE_PIN U2 [get_ports {adcDataInP[2]}]
set_property PACKAGE_PIN V2 [get_ports {adcDataInN[2]}]
set_property PACKAGE_PIN U3 [get_ports {adcDataInP[3]}]
set_property PACKAGE_PIN V3 [get_ports {adcDataInN[3]}]
set_property PACKAGE_PIN W1 [get_ports {adcDataInP[4]}]
set_property PACKAGE_PIN Y1 [get_ports {adcDataInN[4]}]
set_property PACKAGE_PIN W2 [get_ports {adcDataInP[5]}]
set_property PACKAGE_PIN Y2 [get_ports {adcDataInN[5]}]
set_property PACKAGE_PIN Y3 [get_ports {adcDataInP[6]}]
set_property PACKAGE_PIN AA3 [get_ports {adcDataInN[6]}]
set_property PACKAGE_PIN AA1 [get_ports {adcDataInP[7]}]
set_property PACKAGE_PIN AB1 [get_ports {adcDataInN[7]}]
set_property PACKAGE_PIN AB3 [get_ports {adcDataInP[8]}]
set_property PACKAGE_PIN AB2 [get_ports {adcDataInN[8]}]
set_property PACKAGE_PIN Y6 [get_ports {adcDataInP[9]}]
set_property PACKAGE_PIN AA6 [get_ports {adcDataInN[9]}]
set_property PACKAGE_PIN AA5 [get_ports {adcDataInP[10]}]
set_property PACKAGE_PIN AB5 [get_ports {adcDataInN[10]}]
set_property PACKAGE_PIN Y8 [get_ports {adcDataInP[11]}]
set_property PACKAGE_PIN Y7 [get_ports {adcDataInN[11]}]
set_property PACKAGE_PIN W6 [get_ports {adcDataInP[12]}]
set_property PACKAGE_PIN W5 [get_ports {adcDataInN[12]}]
set_property PACKAGE_PIN W9 [get_ports {adcDataInP[13]}]
set_property PACKAGE_PIN Y9 [get_ports {adcDataInN[13]}]
set_property PACKAGE_PIN AB7 [get_ports {adcDataInP[14]}]
set_property PACKAGE_PIN AB6 [get_ports {adcDataInN[14]}]
set_property PACKAGE_PIN AA8 [get_ports {adcDataInP[15]}]
set_property PACKAGE_PIN AB8 [get_ports {adcDataInN[15]}]
#############################################################


#############################################################
#ADC-2
#############################################################
set_property PACKAGE_PIN D17 [get_ports {adcDoClkP[1]}]
set_property PACKAGE_PIN C17 [get_ports {adcDoClkN[1]}]
set_property PACKAGE_PIN B21 [get_ports {adcFrClkP[1]}]
set_property PACKAGE_PIN A21 [get_ports {adcFrClkN[1]}]

set_property PACKAGE_PIN E22 [get_ports {adcDataInP[16]}]
set_property PACKAGE_PIN D22 [get_ports {adcDataInN[16]}]
set_property PACKAGE_PIN E21 [get_ports {adcDataInP[17]}]
set_property PACKAGE_PIN D21 [get_ports {adcDataInN[17]}]
set_property PACKAGE_PIN G21 [get_ports {adcDataInP[18]}]
set_property PACKAGE_PIN G22 [get_ports {adcDataInN[18]}]
set_property PACKAGE_PIN F18 [get_ports {adcDataInP[19]}]
set_property PACKAGE_PIN E18 [get_ports {adcDataInN[19]}]
set_property PACKAGE_PIN F19 [get_ports {adcDataInP[20]}]
set_property PACKAGE_PIN F20 [get_ports {adcDataInN[20]}]
set_property PACKAGE_PIN E19 [get_ports {adcDataInP[21]}]
set_property PACKAGE_PIN D19 [get_ports {adcDataInN[21]}]
set_property PACKAGE_PIN D20 [get_ports {adcDataInP[22]}]
set_property PACKAGE_PIN C20 [get_ports {adcDataInN[22]}]
set_property PACKAGE_PIN C22 [get_ports {adcDataInP[23]}]
set_property PACKAGE_PIN B22 [get_ports {adcDataInN[23]}]
set_property PACKAGE_PIN B20 [get_ports {adcDataInP[24]}]
set_property PACKAGE_PIN A20 [get_ports {adcDataInN[24]}]
set_property PACKAGE_PIN C18 [get_ports {adcDataInP[25]}]
set_property PACKAGE_PIN C19 [get_ports {adcDataInN[25]}]
set_property PACKAGE_PIN B17 [get_ports {adcDataInP[26]}]
set_property PACKAGE_PIN B18 [get_ports {adcDataInN[26]}]
set_property PACKAGE_PIN A18 [get_ports {adcDataInP[27]}]
set_property PACKAGE_PIN A19 [get_ports {adcDataInN[27]}]
set_property PACKAGE_PIN B15 [get_ports {adcDataInP[28]}]
set_property PACKAGE_PIN B16 [get_ports {adcDataInN[28]}]
set_property PACKAGE_PIN C14 [get_ports {adcDataInP[29]}]
set_property PACKAGE_PIN C15 [get_ports {adcDataInN[29]}]
set_property PACKAGE_PIN A15 [get_ports {adcDataInP[30]}]
set_property PACKAGE_PIN A16 [get_ports {adcDataInN[30]}]
set_property PACKAGE_PIN A13 [get_ports {adcDataInP[31]}]
set_property PACKAGE_PIN A14 [get_ports {adcDataInN[31]}]
#############################################################


#############################################################
# ADC IOSTANDARDS
#############################################################
set_property IOSTANDARD LVDS_25 [get_ports adcDoClk*]
set_property IOSTANDARD LVDS_25 [get_ports adcFrClk*]
set_property IOSTANDARD LVDS_25 [get_ports adcClk*]
set_property PACKAGE_PIN E2 [get_ports {adcClkP[1]}]
set_property PACKAGE_PIN D2 [get_ports {adcClkN[1]}]
set_property PACKAGE_PIN L5 [get_ports {adcClkP[0]}]
set_property PACKAGE_PIN L4 [get_ports {adcClkN[0]}]
set_property IOSTANDARD LVDS_25 [get_ports adcDataInP*]
set_property IOSTANDARD LVDS_25 [get_ports adcDataInN*]
#############################################################

#############################################################
# ADC commons
#############################################################
set_property PACKAGE_PIN J20 [get_ports adcTxTrig]
set_property PACKAGE_PIN K21 [get_ports adcReset]
set_property PACKAGE_PIN N22 [get_ports adcPdnFast]
set_property PACKAGE_PIN N20 [get_ports adcPdnGlb]
#set_property PACKAGE_PIN K21 [get_ports adcReset] #RESET
set_property IOSTANDARD LVCMOS18 [get_ports adcTxTrig]
set_property IOSTANDARD LVCMOS18 [get_ports adcReset]
set_property IOSTANDARD LVCMOS18 [get_ports adcPdnFast]
set_property IOSTANDARD LVCMOS18 [get_ports adcPdnGlb]
#############################################################


############## ADC serial interface #########################
# common for all chips
set_property PACKAGE_PIN L19 [get_ports adcSclk]
set_property PACKAGE_PIN G20 [get_ports adcSin]
#ADC-1
set_property PACKAGE_PIN M21 [get_ports {adcCsb[0]}]
set_property PACKAGE_PIN N18 [get_ports {adcSout[0]}]

#ADC-2
set_property PACKAGE_PIN J19 [get_ports {adcCsb[1]}]
set_property PACKAGE_PIN H20 [get_ports {adcSout[1]}]

# IOSTANDARDS
set_property IOSTANDARD LVCMOS18 [get_ports adcSclk]
#set_property IOSTANDARD LVCMOS18 [get_ports {adcSclk[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adcCsb[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adcCsb[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports adcSin]
set_property IOSTANDARD LVCMOS18 [get_ports {adcSout[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {adcSout[0]}]
#############################################################


#############################################################
# External trigger
#############################################################
set_property PACKAGE_PIN J17 [get_ports extTrigIn]
set_property PACKAGE_PIN H17 [get_ports extTrigInDir]
set_property IOSTANDARD LVCMOS18 [get_ports extTrigIn]
set_property IOSTANDARD LVCMOS18 [get_ports extTrigInDir]
#############################################################
set_property PACKAGE_PIN K18 [get_ports extClkIn]
set_property PACKAGE_PIN L13 [get_ports extClkInDir]
set_property IOSTANDARD LVCMOS18 [get_ports extClkIn]
set_property IOSTANDARD LVCMOS18 [get_ports extClkInDir]

#############################################################
#   DRS-4
#############################################################
#DRS4-COMMON
set_property PACKAGE_PIN P4 [get_ports drsDEnable]
set_property PACKAGE_PIN P2 [get_ports drsDWrite]
set_property PACKAGE_PIN M1 [get_ports drsSrClk]
set_property PACKAGE_PIN P5 [get_ports drsSrIn]
set_property PACKAGE_PIN R1 [get_ports {drsAddr[0]}]
set_property PACKAGE_PIN P1 [get_ports {drsAddr[1]}]
set_property PACKAGE_PIN N2 [get_ports {drsAddr[2]}]
set_property PACKAGE_PIN P6 [get_ports {drsAddr[3]}]
set_property PACKAGE_PIN N3 [get_ports drsRsrLoad]
set_property PACKAGE_PIN M3 [get_ports drsRefClkP]
set_property PACKAGE_PIN M2 [get_ports drsRefClkN]

#DRS4-1
set_property PACKAGE_PIN N4 [get_ports {drsPllLck[0]}]
set_property PACKAGE_PIN M5 [get_ports {drsSrOut[0]}]
set_property PACKAGE_PIN N5 [get_ports {drsDTap[0]}]
#DRS4-2 ** instrumented in A21
set_property PACKAGE_PIN L1 [get_ports {drsPllLck[1]}]
set_property PACKAGE_PIN K1 [get_ports {drsSrOut[1]}]
set_property PACKAGE_PIN L3 [get_ports {drsDTap[1]}]
#DRS4-3
set_property PACKAGE_PIN K3 [get_ports {drsPllLck[2]}]
set_property PACKAGE_PIN J1 [get_ports {drsSrOut[2]}]
set_property PACKAGE_PIN L6 [get_ports {drsDTap[2]}]
#DRS4-4
set_property PACKAGE_PIN K4 [get_ports {drsPllLck[3]}]
set_property PACKAGE_PIN H2 [get_ports {drsSrOut[3]}]
set_property PACKAGE_PIN J4 [get_ports {drsDTap[3]}]
#DRS4-5
set_property PACKAGE_PIN A1 [get_ports {drsPllLck[4]}]
set_property PACKAGE_PIN E3 [get_ports {drsSrOut[4]}]
set_property PACKAGE_PIN B1 [get_ports {drsDTap[4]}]
#DRS4-6
set_property PACKAGE_PIN D1 [get_ports {drsPllLck[5]}]
set_property PACKAGE_PIN E1 [get_ports {drsSrOut[5]}]
set_property PACKAGE_PIN F3 [get_ports {drsDTap[5]}]
#DRS4-7 ** instrumented in A21
set_property PACKAGE_PIN F4 [get_ports {drsPllLck[6]}]
set_property PACKAGE_PIN G3 [get_ports {drsSrOut[6]}]
set_property PACKAGE_PIN G4 [get_ports {drsDTap[6]}]
#DRS4-8
set_property PACKAGE_PIN G2 [get_ports {drsPllLck[7]}]
set_property PACKAGE_PIN H3 [get_ports {drsSrOut[7]}]
set_property PACKAGE_PIN H4 [get_ports {drsDTap[7]}]

# IO standards
set_property IOSTANDARD LVCMOS25 [get_ports drsDEnable]
set_property DRIVE 4 [get_ports drsDEnable]
set_property IOSTANDARD LVCMOS25 [get_ports drsDWrite]
set_property DRIVE 4 [get_ports drsDWrite]
set_property IOSTANDARD LVCMOS25 [get_ports drsSrClk]
set_property IOSTANDARD LVCMOS25 [get_ports drsSrIn]
set_property IOSTANDARD LVCMOS25 [get_ports {drsAddr[*]}]
set_property DRIVE 4 [get_ports {drsAddr[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports drsRsrLoad]
set_property IOSTANDARD LVCMOS25 [get_ports {drsPllLck[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports {drsDTap[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports {drsSrOut[*]}]
set_property IOSTANDARD LVCMOS25 [get_ports drsRefClkP]
set_property IOSTANDARD LVCMOS25 [get_ports drsRefClkN]
#############################################################



#############################################################
# Set up the SPI Dac so we can control our shiznit
#############################################################
set_property PACKAGE_PIN H13 [get_ports dacCsb]
set_property PACKAGE_PIN G13 [get_ports dacSclk]
set_property PACKAGE_PIN G15 [get_ports dacSin]
set_property PACKAGE_PIN G16 [get_ports dacSout]
set_property IOSTANDARD LVCMOS18 [get_ports dac*]
#############################################################






# AC701 is a 125Mhz clock.  1/125Mhz = 8ns
## create_clock -period 8.000 -name gtrefclk -add [get_ports gtClkP]

# Pin placements for the AC701
# IP Block works on the REFCLK1?
#set_property IOSTANDARD LVDS_25 [get_ports gtClkN]
## set_property PACKAGE_PIN AA13 [get_ports gtClkP]
## set_property PACKAGE_PIN AB13 [get_ports gtClkN]
#set_property IOSTANDARD LVDS_25 [get_ports glClkP]

## set_property PACKAGE_PIN AD12 [get_ports gtRxN]
## set_property PACKAGE_PIN AC12 [get_ports gtRxP]
## set_property PACKAGE_PIN AD10 [get_ports gtTxN]
## set_property PACKAGE_PIN AC10 [get_ports gtTxP]

#set_property IOSTANDARD LVDS_25 [get_ports gtRx*]
#set_property IOSTANDARD LVDS_25 [get_ports gtTx*]

# Consistent with AC701 spec Tbl 1-10, Note 2
## set_property PACKAGE_PIN B26 [get_ports SFP_MGT_CLK_SEL0]
## set_property PACKAGE_PIN C24 [get_ports SFP_MGT_CLK_SEL1]
## set_property IOSTANDARD LVCMOS25 [get_ports SFP_MGT_CLK_SEL*]

# Wire in the UART for the +uBlaze design
## set_property PACKAGE_PIN U19 [get_ports rs232_uart_txd]
## set_property PACKAGE_PIN T19 [get_ports rs232_uart_rxd]
## set_property IOSTANDARD LVCMOS18 [get_ports rs232_uart_*]

set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 66 [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]

##############################################################################


set_property MARK_DEBUG true [get_nets {regAddr[19]}]
set_property MARK_DEBUG true [get_nets {regAddr[1]}]
set_property MARK_DEBUG true [get_nets {regAddr[3]}]
set_property MARK_DEBUG true [get_nets {regAddr[5]}]
set_property MARK_DEBUG true [get_nets {regAddr[21]}]
set_property MARK_DEBUG true [get_nets {regAddr[15]}]
set_property MARK_DEBUG true [get_nets {regAddr[13]}]
set_property MARK_DEBUG true [get_nets {regAddr[17]}]
set_property MARK_DEBUG true [get_nets {regAddr[8]}]
set_property MARK_DEBUG true [get_nets {regAddr[9]}]
set_property MARK_DEBUG true [get_nets {regAddr[11]}]
set_property MARK_DEBUG true [get_nets {regWrData[0]}]
set_property MARK_DEBUG true [get_nets {regWrData[6]}]
set_property MARK_DEBUG true [get_nets {regWrData[7]}]
set_property MARK_DEBUG true [get_nets {regWrData[2]}]
set_property MARK_DEBUG true [get_nets {regRdData[28]}]
set_property MARK_DEBUG true [get_nets {regRdData[30]}]
set_property MARK_DEBUG true [get_nets {regRdData[0]}]
set_property MARK_DEBUG true [get_nets {regRdData[2]}]
set_property MARK_DEBUG true [get_nets {regRdData[4]}]
set_property MARK_DEBUG true [get_nets {regRdData[7]}]
set_property MARK_DEBUG true [get_nets {regRdData[10]}]
set_property MARK_DEBUG true [get_nets {regRdData[6]}]
set_property MARK_DEBUG true [get_nets {regRdData[16]}]
set_property MARK_DEBUG true [get_nets {regRdData[18]}]
set_property MARK_DEBUG true [get_nets {regRdData[12]}]
set_property MARK_DEBUG true [get_nets {regRdData[14]}]
set_property MARK_DEBUG true [get_nets {regRdData[24]}]
set_property MARK_DEBUG true [get_nets {regRdData[26]}]
set_property MARK_DEBUG true [get_nets {regRdData[20]}]
set_property MARK_DEBUG true [get_nets {regRdData[22]}]
set_property MARK_DEBUG true [get_nets {regWrData[4]}]
set_property MARK_DEBUG true [get_nets {regWrData[18]}]
set_property MARK_DEBUG true [get_nets {regWrData[16]}]
set_property MARK_DEBUG true [get_nets {regWrData[24]}]
set_property MARK_DEBUG true [get_nets {regWrData[26]}]
set_property MARK_DEBUG true [get_nets {regWrData[22]}]
set_property MARK_DEBUG true [get_nets {regWrData[28]}]
set_property MARK_DEBUG true [get_nets {regWrData[30]}]
set_property MARK_DEBUG true [get_nets {regWrData[20]}]
set_property MARK_DEBUG true [get_nets {regWrData[14]}]
set_property MARK_DEBUG true [get_nets {regWrData[12]}]
set_property MARK_DEBUG true [get_nets {regWrData[10]}]
set_property MARK_DEBUG true [get_nets regRdStrb]
set_property MARK_DEBUG true [get_nets regWrStrb]
set_property MARK_DEBUG true [get_nets {regAddr[6]}]
set_property MARK_DEBUG true [get_nets {regAddr[4]}]
set_property MARK_DEBUG true [get_nets {regAddr[2]}]
set_property MARK_DEBUG true [get_nets {regAddr[0]}]
set_property MARK_DEBUG true [get_nets {regAddr[12]}]
set_property MARK_DEBUG true [get_nets {regAddr[14]}]
set_property MARK_DEBUG true [get_nets {regAddr[20]}]
set_property MARK_DEBUG true [get_nets {regAddr[18]}]
set_property MARK_DEBUG true [get_nets {regAddr[16]}]
set_property MARK_DEBUG true [get_nets {regAddr[7]}]
set_property MARK_DEBUG true [get_nets {regAddr[10]}]
set_property MARK_DEBUG true [get_nets {regWrData[15]}]
set_property MARK_DEBUG true [get_nets {regWrData[1]}]
set_property MARK_DEBUG true [get_nets {regRdData[27]}]
set_property MARK_DEBUG true [get_nets {regRdData[29]}]
set_property MARK_DEBUG true [get_nets {regRdData[21]}]
set_property MARK_DEBUG true [get_nets {regRdData[31]}]
set_property MARK_DEBUG true [get_nets {regRdData[13]}]
set_property MARK_DEBUG true [get_nets {regRdData[23]}]
set_property MARK_DEBUG true [get_nets {regRdData[25]}]
set_property MARK_DEBUG true [get_nets {regRdData[19]}]
set_property MARK_DEBUG true [get_nets {regRdData[5]}]
set_property MARK_DEBUG true [get_nets {regRdData[15]}]
set_property MARK_DEBUG true [get_nets {regRdData[17]}]
set_property MARK_DEBUG true [get_nets {regRdData[11]}]
set_property MARK_DEBUG true [get_nets {regRdData[1]}]
set_property MARK_DEBUG true [get_nets {regRdData[8]}]
set_property MARK_DEBUG true [get_nets {regRdData[9]}]
set_property MARK_DEBUG true [get_nets {regRdData[3]}]
set_property MARK_DEBUG true [get_nets {regWrData[3]}]
set_property MARK_DEBUG true [get_nets {regWrData[5]}]
set_property MARK_DEBUG true [get_nets {regWrData[17]}]
set_property MARK_DEBUG true [get_nets {regWrData[11]}]
set_property MARK_DEBUG true [get_nets {regWrData[13]}]
set_property MARK_DEBUG true [get_nets {regWrData[23]}]
set_property MARK_DEBUG true [get_nets {regWrData[19]}]
set_property MARK_DEBUG true [get_nets {regWrData[25]}]
set_property MARK_DEBUG true [get_nets {regWrData[21]}]
set_property MARK_DEBUG true [get_nets {regWrData[31]}]
set_property MARK_DEBUG true [get_nets {regWrData[27]}]
set_property MARK_DEBUG true [get_nets {regWrData[29]}]
set_property MARK_DEBUG true [get_nets {regWrData[8]}]
set_property MARK_DEBUG true [get_nets {regWrData[9]}]
set_property MARK_DEBUG true [get_nets regAddrStrb]
set_property MARK_DEBUG true [get_nets regReady]

set_property MARK_DEBUG true [get_nets eventBuilderTrg]
set_property MARK_DEBUG true [get_nets {adcData[32][5]}]
set_property MARK_DEBUG true [get_nets {adcData[32][3]}]
set_property MARK_DEBUG true [get_nets {adcData[32][0]}]
set_property MARK_DEBUG true [get_nets {adcData[33][10]}]
set_property MARK_DEBUG true [get_nets {adcData[33][11]}]
set_property MARK_DEBUG true [get_nets {adcData[33][7]}]
set_property MARK_DEBUG true [get_nets {adcData[33][8]}]
set_property MARK_DEBUG true [get_nets {adcData[33][2]}]
set_property MARK_DEBUG true [get_nets {adcData[33][3]}]
set_property MARK_DEBUG true [get_nets {adcData[33][0]}]
set_property MARK_DEBUG true [get_nets {adcData[33][6]}]
set_property MARK_DEBUG true [get_nets {adcData[33][9]}]
set_property MARK_DEBUG true [get_nets {adcData[33][4]}]
set_property MARK_DEBUG true [get_nets {adcData[33][5]}]
set_property MARK_DEBUG true [get_nets {adcData[33][1]}]
set_property MARK_DEBUG true [get_nets {adcData[32][1]}]
set_property MARK_DEBUG true [get_nets {adcData[32][2]}]
set_property MARK_DEBUG true [get_nets {adcData[32][4]}]
set_property MARK_DEBUG true [get_nets {adcData[32][6]}]
set_property MARK_DEBUG true [get_nets {adcData[32][7]}]
set_property MARK_DEBUG true [get_nets {adcData[32][8]}]
set_property MARK_DEBUG true [get_nets {adcData[32][9]}]
set_property MARK_DEBUG true [get_nets {adcData[0][0]}]
set_property MARK_DEBUG true [get_nets {adcData[0][6]}]
set_property MARK_DEBUG true [get_nets {adcData[0][9]}]
set_property MARK_DEBUG true [get_nets {adcData[0][4]}]
set_property MARK_DEBUG true [get_nets {adcData[0][10]}]
set_property MARK_DEBUG true [get_nets {adcData[0][11]}]
set_property MARK_DEBUG true [get_nets {adcData[0][7]}]
set_property MARK_DEBUG true [get_nets {adcData[1][2]}]
set_property MARK_DEBUG true [get_nets {adcData[1][3]}]
set_property MARK_DEBUG true [get_nets {adcData[1][0]}]
set_property MARK_DEBUG true [get_nets {adcData[1][6]}]
set_property MARK_DEBUG true [get_nets {adcData[1][9]}]
set_property MARK_DEBUG true [get_nets {adcData[1][4]}]
set_property MARK_DEBUG true [get_nets {adcData[1][10]}]
set_property MARK_DEBUG true [get_nets {adcData[1][11]}]
set_property MARK_DEBUG true [get_nets {adcData[1][7]}]
set_property MARK_DEBUG true [get_nets {adcData[1][8]}]
set_property MARK_DEBUG true [get_nets {adcData[1][5]}]
set_property MARK_DEBUG true [get_nets {adcData[1][1]}]
set_property MARK_DEBUG true [get_nets {adcData[0][8]}]
set_property MARK_DEBUG true [get_nets {adcData[0][5]}]
set_property MARK_DEBUG true [get_nets {adcData[0][1]}]
set_property MARK_DEBUG true [get_nets {adcData[0][2]}]
set_property MARK_DEBUG true [get_nets {adcData[0][3]}]
set_property MARK_DEBUG true [get_nets {adcData[32][10]}]
set_property MARK_DEBUG true [get_nets {adcData[32][11]}]
set_property MARK_DEBUG true [get_nets p_129_out]
set_property MARK_DEBUG true [get_nets p_130_out]
set_property MARK_DEBUG true [get_nets adcSync]
set_property MARK_DEBUG true [get_nets {adcDataValid[0]}]
set_property MARK_DEBUG true [get_nets {adcDataValid[1]}]
set_property MARK_DEBUG true [get_nets U_EventBuilder_n_2]
connect_debug_port u_ila_0/probe10 [get_nets [list p_129_out]]
connect_debug_port u_ila_0/probe11 [get_nets [list p_130_out]]
connect_debug_port u_ila_0/probe16 [get_nets [list U_EventBuilder_n_2]]


set_property MARK_DEBUG true [get_nets drsDWrite_OBUF]
set_property MARK_DEBUG true [get_nets drsDEnable_OBUF]
set_property MARK_DEBUG true [get_nets drsRsrLoad_OBUF]
set_property MARK_DEBUG true [get_nets drsRefClkP_OBUF]
set_property MARK_DEBUG true [get_nets drsSampleValid]
set_property MARK_DEBUG true [get_nets adcTxTrig_OBUF]

set_property MARK_DEBUG true [get_nets drsSrClk_OBUF]

set_property MARK_DEBUG false [get_nets {ADC_GEN[1].U_AdcReadout/iAdcConvClkR}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[1].U_AdcReadout/adcConvClk}]

set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][0]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][1]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][2]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][3]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][4]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][5]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][6]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][7]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][8]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][9]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][10]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][11]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][2]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][0]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][1]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][3]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][4]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][5]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][6]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][7]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][8]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][9]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][10]}]
set_property MARK_DEBUG true [get_nets {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][11]}]
create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 1024 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list U_A7EthTop/U_GtpA7Wrapper/U_ClkWiz/inst/clk125]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 12 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][0]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][1]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][2]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][3]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][4]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][5]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][6]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][7]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][8]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][9]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][10]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[0][11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 12 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][0]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][1]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][2]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][3]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][4]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][5]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][6]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][7]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][8]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][9]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][10]} {ADC_GEN[0].U_AdcReadout/adcDataOutSysClk[1][11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 2 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {adcDataValid[0]} {adcDataValid[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {adcDataValid_orig__0[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 12 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {adcData[0][0]} {adcData[0][1]} {adcData[0][2]} {adcData[0][3]} {adcData[0][4]} {adcData[0][5]} {adcData[0][6]} {adcData[0][7]} {adcData[0][8]} {adcData[0][9]} {adcData[0][10]} {adcData[0][11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 12 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {adcData[1][0]} {adcData[1][1]} {adcData[1][2]} {adcData[1][3]} {adcData[1][4]} {adcData[1][5]} {adcData[1][6]} {adcData[1][7]} {adcData[1][8]} {adcData[1][9]} {adcData[1][10]} {adcData[1][11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 12 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {adcData[32][0]} {adcData[32][1]} {adcData[32][2]} {adcData[32][3]} {adcData[32][4]} {adcData[32][5]} {adcData[32][6]} {adcData[32][7]} {adcData[32][8]} {adcData[32][9]} {adcData[32][10]} {adcData[32][11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 12 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {adcData[33][0]} {adcData[33][1]} {adcData[33][2]} {adcData[33][3]} {adcData[33][4]} {adcData[33][5]} {adcData[33][6]} {adcData[33][7]} {adcData[33][8]} {adcData[33][9]} {adcData[33][10]} {adcData[33][11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 32 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {regAddr[0]} {regAddr[1]} {regAddr[2]} {regAddr[3]} {regAddr[4]} {regAddr[5]} {regAddr[6]} {regAddr[7]} {regAddr[8]} {regAddr[9]} {regAddr[10]} {regAddr[11]} {regAddr[12]} {regAddr[13]} {regAddr[14]} {regAddr[15]} {regAddr[16]} {regAddr[17]} {regAddr[18]} {regAddr[19]} {regAddr[20]} {regAddr[21]} {regAddr[22]} {regAddr[23]} {regAddr[24]} {regAddr[25]} {regAddr[26]} {regAddr[27]} {regAddr[28]} {regAddr[29]} {regAddr[30]} {regAddr[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 32 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {regRdData[0]} {regRdData[1]} {regRdData[2]} {regRdData[3]} {regRdData[4]} {regRdData[5]} {regRdData[6]} {regRdData[7]} {regRdData[8]} {regRdData[9]} {regRdData[10]} {regRdData[11]} {regRdData[12]} {regRdData[13]} {regRdData[14]} {regRdData[15]} {regRdData[16]} {regRdData[17]} {regRdData[18]} {regRdData[19]} {regRdData[20]} {regRdData[21]} {regRdData[22]} {regRdData[23]} {regRdData[24]} {regRdData[25]} {regRdData[26]} {regRdData[27]} {regRdData[28]} {regRdData[29]} {regRdData[30]} {regRdData[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 32 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {regWrData[0]} {regWrData[1]} {regWrData[2]} {regWrData[3]} {regWrData[4]} {regWrData[5]} {regWrData[6]} {regWrData[7]} {regWrData[8]} {regWrData[9]} {regWrData[10]} {regWrData[11]} {regWrData[12]} {regWrData[13]} {regWrData[14]} {regWrData[15]} {regWrData[16]} {regWrData[17]} {regWrData[18]} {regWrData[19]} {regWrData[20]} {regWrData[21]} {regWrData[22]} {regWrData[23]} {regWrData[24]} {regWrData[25]} {regWrData[26]} {regWrData[27]} {regWrData[28]} {regWrData[29]} {regWrData[30]} {regWrData[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {ADC_GEN[1].U_AdcReadout/adcConvClk}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list adcSync]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list adcTxTrig_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list drsDEnable_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list drsDWrite_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list drsRefClkP_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list drsRsrLoad_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list drsSampleValid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list drsSrClk_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list eventBuilderTrg]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list regAddrStrb]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list regRdStrb]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list regReady]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list regWrStrb]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets ethClk125]
