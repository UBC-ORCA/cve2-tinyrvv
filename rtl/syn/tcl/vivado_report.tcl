# Post-synthesis report generation for a completed `synth_1` run.
#
# FuseSoC/Edalize's auto-generated `<core>_synth.tcl` only does
# launch_runs/wait_on_run with no reporting step, so this is run as a
# separate pass against the already-synthesized project to pull timing and
# utilization numbers.
#
# Usage:
#   vivado -mode batch -source rtl/syn/tcl/vivado_report.tcl \
#       -tclargs <path-to-xpr> [period_ns]
#
# Example (FuseSoC-generated project):
#   vivado -mode batch -source rtl/syn/tcl/vivado_report.tcl -tclargs \
#       build/openhwgroup_cve2_cve2_top_vivado_0.1/synth-vivado/openhwgroup_cve2_cve2_top_vivado_0.1.xpr

set project_path [lindex $argv 0]
set period_ns    [expr {[llength $argv] > 1 ? [lindex $argv 1] : 10.0}]

open_project $project_path

if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    puts "ERROR: synth_1 has not completed (progress: [get_property PROGRESS [get_runs synth_1]])"
    exit 1
}

open_run synth_1

set out_dir [file join [file dirname $project_path] reports]
file mkdir $out_dir

report_timing_summary -delay_type max -max_paths 10 \
    -file [file join $out_dir timing_summary.rpt]
report_utilization \
    -file [file join $out_dir utilization.rpt]
report_utilization -hierarchical \
    -file [file join $out_dir utilization_hierarchical.rpt]

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -delay_type max]]
set fmax_mhz [expr {1000.0 / ($period_ns - $wns)}]

set summary [open [file join $out_dir fmax_summary.txt] w]
puts $summary "Constraint period : ${period_ns} ns"
puts $summary "WNS               : ${wns} ns"
puts $summary "Estimated Fmax    : [format %.2f $fmax_mhz] MHz"
close $summary

puts "=================================================="
puts "Constraint period : ${period_ns} ns"
puts "WNS               : ${wns} ns"
puts "Estimated Fmax    : [format %.2f $fmax_mhz] MHz"
puts "Reports written to : $out_dir"
puts "=================================================="
