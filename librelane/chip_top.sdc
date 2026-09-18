current_design $::env(DESIGN_NAME)
set_units -time ns

set clock_port __VIRTUAL_CLK__
if { [info exists ::env(CLOCK_PORT)] } {
    set port_count [llength $::env(CLOCK_PORT)]
    if { $port_count == "0" } {
        puts "\[WARNING] No CLOCK_PORT found. A dummy clock will be used."
    } elseif { $port_count != "1" } {
        puts "\[WARNING] Multi-clock files are not currently supported by the base SDC file. Only the first clock will be constrained."
    }
    if { $port_count > "0" } {
        set ::clock_port [lindex $::env(CLOCK_PORT) 0]
    }
}

if { $::env(CLOCK_PORT) == $::env(CLOCK_NET) } {
    set port_args [get_ports $clock_port]
} else {
    set port_args [get_pins [lindex $::env(CLOCK_NET) 0]]
}

puts "\[INFO] Using clock $clock_port…"
create_clock {*}$port_args -name $clock_port -period $::env(CLOCK_PERIOD)

set input_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set output_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
puts "\[INFO] Setting output delay to: $output_delay_value"
puts "\[INFO] Setting input delay to: $input_delay_value"

set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
}
if { [info exists ::env(MAX_CAPACITANCE_CONSTRAINT)] } {
    set_max_capacitance $::env(MAX_CAPACITANCE_CONSTRAINT) [current_design]
}

set clocks [get_clocks $clock_port]

# ---------------------------------------------------------------------------
# ASC v0.43 source-synchronous DPI interface
#
#   bidir_PAD[0]     = forwarded PCLK
#   bidir_PAD[1]     = HSYNC
#   bidir_PAD[2]     = VSYNC
#   bidir_PAD[3]     = DE
#   bidir_PAD[27:4]  = RGB[23:0]
#   bidir_PAD[37:28] = reserved / input mode
#
# PCLK is not ordinary output data.  It is a 1:1 forwarded copy of clk_PAD,
# so model it as a generated clock at the external PCLK pad.  DPI data/sync
# output delays are then checked relative to that forwarded clock.
#
# The generic IO_DELAY_CONSTRAINT budget is intentionally retained here until
# the final HDMI/DP bridge device and PCB timing budget are fixed.
# ---------------------------------------------------------------------------

set pclk_output_port [get_ports {bidir_PAD[0]}]

create_generated_clock \
    -name PCLK_OUT \
    -master_clock $clock_port \
    -source $port_args \
    -divide_by 1 \
    $pclk_output_port

set pclk_output_clock [get_clocks PCLK_OUT]

# DPI data/sync outputs. PCLK itself is deliberately excluded from
# set_output_delay: it is the forwarded reference clock, not output data.
set dpi_output_ports [get_ports {
    bidir_PAD[1] bidir_PAD[2] bidir_PAD[3] bidir_PAD[4] bidir_PAD[5] bidir_PAD[6] bidir_PAD[7] bidir_PAD[8] bidir_PAD[9] bidir_PAD[10] bidir_PAD[11] bidir_PAD[12] bidir_PAD[13] bidir_PAD[14] bidir_PAD[15] bidir_PAD[16] bidir_PAD[17] bidir_PAD[18] bidir_PAD[19] bidir_PAD[20] bidir_PAD[21] bidir_PAD[22] bidir_PAD[23] bidir_PAD[24] bidir_PAD[25] bidir_PAD[26] bidir_PAD[27]
}]
set_output_delay $output_delay_value -clock $pclk_output_clock $dpi_output_ports

# Only the reserved bidirectional pads are input-mode in ASC v0.43.
# bidir_PAD[0:27] are hard-wired to output mode by chip_core.
set clk_core_bidir_input_ports [get_ports {
    bidir_PAD[28] bidir_PAD[29] bidir_PAD[30] bidir_PAD[31] bidir_PAD[32] bidir_PAD[33] bidir_PAD[34] bidir_PAD[35] bidir_PAD[36] bidir_PAD[37]
}]
set_input_delay -min 0 -clock $clocks $clk_core_bidir_input_ports
set_input_delay -max $input_delay_value -clock $clocks $clk_core_bidir_input_ports

# Synchronous input-only pads. rst_n_PAD is intentionally excluded here:
# ASC v0.43 treats it as an asynchronous raw reset that terminates at the
# two-stage reset synchronizer, not as ordinary synchronous input data.
set clk_core_input_ports [get_ports {
    input_PAD[*]
}]
set_input_delay -min 0 -clock $clocks $clk_core_input_ports
set_input_delay -max $input_delay_value -clock $clocks $clk_core_input_ports

# External reset assertion/deassertion is asynchronous to clk_PAD. The v0.43
# reset synchronizer contains this asynchronous boundary; downstream logic sees
# only core_rst_n, whose release is synchronized to the core clock.
set_false_path -from [get_ports rst_n_PAD]

# Output load
set cap_load [expr $::env(OUTPUT_CAP_LOAD) / 1000.0]
puts "\[INFO] Setting load to: $cap_load"
set_load $cap_load [all_outputs]

puts "\[INFO] Setting clock uncertainty to: $::env(CLOCK_UNCERTAINTY_CONSTRAINT)"
set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) $clocks
set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) $pclk_output_clock

puts "\[INFO] Setting clock transition to: $::env(CLOCK_TRANSITION_CONSTRAINT)"
set_clock_transition $::env(CLOCK_TRANSITION_CONSTRAINT) $clocks

puts "\[INFO] Setting timing derate to: $::env(TIME_DERATING_CONSTRAINT)%"
set_timing_derate -early [expr 1-[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]
set_timing_derate -late [expr 1+[expr $::env(TIME_DERATING_CONSTRAINT) / 100]]

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}
