#########################################
# Content: Sample synthesis script for verilog RTL
# Tool: Cadence Genus(TM) Synthesis Solution 21.10-p002_1
# Library: TSMC 180nm Digital, Typical case
# 
# Course: Digital Design Course
# Univ: Sharif University of Technology
# Author: Dr. F. Baharvand & Group 8
#########################################

echo "-------------------------------------------------"
echo " Reading library"
echo "-------------------------------------------------"
source ./script/lib_scr.tcl

echo "-------------------------------------------------"
echo " Reading design RTL"
echo "-------------------------------------------------"

# Read the Verilog design
set file_list {../rtl_sources/crc16_ccitt.v \
                ../rtl_sources/otp_controller.v \
               }
# ../rtl_sources/otp_sim_rom.v


##### synthesis attributes
set_db auto_ungroup none
set_db write_vlog_top_module_first true

#set_db write_vlog_preserve_net_name true
#set_db hdl_error_on_latch true

set_db information_level 1
#set_db use_tiehilo_for_const unique
set_db remove_assigns true

#set_db invs_assign_removal true
#set_db invs_assign_buffer auto


read_hdl -language sv $file_list

echo "-------------------------------------------------"
echo " Elaborating"
echo "-------------------------------------------------"

elaborate

#set_units -time ns

echo "-------------------------------------------------"
echo " Setting top module and uniquifying"
echo "-------------------------------------------------"

# Set the top-level module
set_top_module otp_controller

#uniquify buf12_chip

echo "-------------------------------------------------"
echo " Checking for unresolved references"
echo "-------------------------------------------------"
check_design -unresolved

echo "-------------------------------------------------"
echo " Define clocks and their constraints"
echo "-------------------------------------------------"
source ./script/otp_controller_clock_const.tcl


# MMMC flow
#read_mmmc ./scripts/mmmc_scr.tcl

echo "-------------------------------------------------"
echo " Initializing (loading) design"
echo "-------------------------------------------------"
# initialize design - necessary for mmmc flow
init_design
time_info init_design


echo "-------------------------------------------------"
echo " Checking clocks definitions"
echo "-------------------------------------------------"
report_clocks


echo "-------------------------------------------------"
echo " Running synthesis"
echo "-------------------------------------------------"

syn_generic
syn_map 
syn_opt

echo "-------------------------------------------------"
echo " Generating post-synthesis reports"
echo "-------------------------------------------------"

#set_interactive_constraint_modes {constraint_mode_typ}

set_clock_latency -max 0.1 -clock clk -source clk -late

# Report the synthesis results
report_clocks
report_timing
report_area
report_power
report_gates


echo "-------------------------------------------------"
echo " Wrting netlists and physical scripts"
echo "-------------------------------------------------"

write_hdl                                        > ./synout/otp_controller_postsyn.v
write_sdf -version 3.0 -timescale ps -nonegcheck > ./synout/otp_controller_postsyn.sdf

#write_sdc       -view view_typ                   > ./otp_controller.constraint_mode_typ.sdc

write_script                                     > ./constraints.g

write_design -basename otp_controller -tcf -innovus -hierarchical otp_controller

