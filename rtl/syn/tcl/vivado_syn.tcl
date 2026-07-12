# Batch-mode Fmax estimate for cve2_top on a Xilinx part via an existing
# Vivado project (e.g. rtl/cve2_tinyrvv_fp4/tinyrvv_fp4.xpr).
#
# This drives project-mode synthesis rather than re-deriving a non-project
# source list, since a working project with the full RTL + FP4/RVV sources
# already exists; re-listing them here would just be a second copy to keep
# in sync.
#
# Usage:
#   vivado -mode batch -source rtl/syn/tcl/vivado_syn.tcl \
#       -tclargs <path-to-xpr> [top_module] [period_ns]
#
# Example:
#   vivado -mode batch -source rtl/syn/tcl/vivado_syn.tcl \
#       -tclargs rtl/cve2_tinyrvv_fp4/tinyrvv_fp4.xpr cve2_top 10.0

set project_path [lindex $argv 0]
set top          [expr {[llength $argv] > 1 ? [lindex $argv 1] : "cve2_top"}]
set period_ns    [expr {[llength $argv] > 2 ? [lindex $argv 2] : 10.0}]

set script_dir [file dirname [file normalize [info script]]]
set xdc_path   [file normalize [file join $script_dir .. vivado cve2_top.xdc]]

open_project $project_path

set_property top $top [get_filesets sources_1]
update_compile_order -fileset sources_1

if {[llength [get_files -quiet $xdc_path]] == 0} {
    add_files -fileset constrs_1 -norecurse $xdc_path
}
set_property target_constrs_file $xdc_path [current_fileset -constrset]

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1

if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    puts "ERROR: synth_1 did not complete successfully"
    puts [get_property STATUS [get_runs synth_1]]
    exit 1
}

open_run synth_1

set out_dir [file dirname $project_path]
report_timing_summary -delay_type max -max_paths 10 \
    -file [file join $out_dir cve2_top_timing_summary.rpt]

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -delay_type max]]
set fmax_mhz [expr {1000.0 / ($period_ns - $wns)}]

puts "=================================================="
puts "Constraint period : ${period_ns} ns"
puts "WNS                : ${wns} ns"
puts "Estimated Fmax     : [format %.2f $fmax_mhz] MHz"
puts "Timing report       : [file join $out_dir cve2_top_timing_summary.rpt]"
puts "=================================================="
