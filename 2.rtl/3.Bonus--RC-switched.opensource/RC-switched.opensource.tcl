#*****************************************************************************
# RC-switched.opensource.tcl -- creates the Vivado project (.xpr) for
#                               RC-switched, the open-source SystemVerilog
#                               implementation
#
# Board : Acorn CLE-215P  ->  xc7a200tfbg484-3
# Link  : PCIe x1 Gen2
# Top   : RC_switched_opensource
#
# Run (from this folder):
#   vivado -mode batch -source RC-switched.opensource.tcl
#
# or from the Vivado Tcl console, from anywhere:
#   source <path>/RC-switched.opensource.tcl
#
# Options via Tcl variables (set them BEFORE source):
#   set ::origin_dir_loc    <path>   ;# project root (default: script folder)
#   set ::user_project_name <name>   ;# .xpr name (default: Vivado-v2024.2)
#
# Afterwards open  xbuild.Vivado-v2024.2/Vivado-v2024.2.xpr  in the Vivado GUI:
#   Run Synthesis -> Run Implementation -> Generate Bitstream
#
# NOTE: xbuild.Vivado-v2024.2/ is a fully regenerated folder -- the script
# creates it with -force, so every re-run deletes it and builds from scratch.
# Do not keep anything of your own inside. The sources of truth are only
# src/ , xdc/ and this script.
#*****************************************************************************

# ---- Project root = the folder this script lives in -------------------------
# ([info script] works even when the script is sourced from elsewhere, "." does not)
set origin_dir [file dirname [file normalize [info script]]]
if { [info exists ::origin_dir_loc] } {
  set origin_dir [file normalize $::origin_dir_loc]
}

set proj_name "Vivado-v2024.2"
if { [info exists ::user_project_name] } {
  set proj_name $::user_project_name
}
set proj_dir "$origin_dir/xbuild.Vivado-v2024.2"

# ---- Paths ------------------------------------------------------------------
set src_dir  "$origin_dir/src"
set pcie_dir "$origin_dir/src/pcie"
set xdc_file "$origin_dir/xdc/RC-switched.sv.x1g2.AcornCLE-215P.xdc"

set top_sv "$src_dir/RC_switched_opensource.sv"
set soc_sv "$src_dir/riscv_pcie_soc.sv"
set cpu_v  "$src_dir/picorv32.v"

# ---- CSR: PeakRDL-generated register block ----------------------------------
# csr_pkg.sv and csr.sv are generated from 4.build/csr_build/csr.rdl by
# "make -f MakefileCSR" in 4.build/. soc_csr.sv wraps that register block and
# bridges it to the picorv32 memory interface.
#
# To build the hand-written CSR instead, set this BEFORE sourcing the script:
#   set ::use_legacy_csr 1
# The choice comes from the shared configuration, 4.build/config.mk, so that
# the Vivado project and the firmware are always built the same way. Override
# it for a single run by setting this BEFORE sourcing the script:
#   set ::use_legacy_csr 1
# Capture the user's override BEFORE the default is assigned. A sourced script
# runs in the caller's scope, so "use_legacy_csr" and "::use_legacy_csr" are the
# same variable -- setting the default first would silently wipe the override.
if { [info exists ::use_legacy_csr] } {
  set user_legacy_csr $::use_legacy_csr
}

set use_legacy_csr 0

set cfg_file [file normalize "$origin_dir/../../4.build/config.mk"]
if { [file isfile $cfg_file] } {
  set fh [open $cfg_file r]
  set cfg [read $fh]
  close $fh
  if { [regexp -line {^\s*CSR\s*\?*=\s*(\S+)} $cfg -> cfg_csr] } {
    if { $cfg_csr eq "legacy" } {
      set use_legacy_csr 1
    } elseif { $cfg_csr ne "peakrdl" } {
      return -code error "config.mk: CSR must be \"peakrdl\" or \"legacy\", got \"$cfg_csr\""
    }
  }
}

if { [info exists user_legacy_csr] } {
  set use_legacy_csr $user_legacy_csr
  unset user_legacy_csr
}

set csr_gen_dir [file normalize "$origin_dir/../../4.build/csr_build/generated-files"]
set csr_pkg_sv  "$csr_gen_dir/csr_pkg.sv"
set csr_sv      "$csr_gen_dir/csr.sv"
set soc_csr_sv  "$src_dir/soc_csr.sv"

if { $use_legacy_csr } {
  set csr_files {}
} else {
  set csr_files [list $csr_pkg_sv $csr_sv $soc_csr_sv]
}

# firmware.hex is NOT kept in this repo -- it is a product of the sw_build stage:
#   <openPCIE>/4.build/sw_build/firmware.hex
# Build it with the switched firmware:  make VARIANT=switched
# Relative to here (2.rtl/3.Bonus--RC-switched.opensource) that is ../../4.build/sw_build/
set hex_file [file normalize "$origin_dir/../../4.build/sw_build/firmware.hex"]

# ---- Check everything exists before Vivado is even started ------------------
set missing {}
foreach f [concat [list $top_sv $soc_sv $cpu_v $xdc_file $hex_file] $csr_files] {
  if { ![file isfile $f] } { lappend missing $f }
}
if { ![file isdirectory $pcie_dir] } { lappend missing "$pcie_dir (folder)" }

if { [llength $missing] } {
  puts "=============================================================="
  puts " ERROR -- missing:"
  foreach f $missing { puts "   $f" }
  puts ""
  puts " If firmware.hex is missing: run the sw_build stage with"
  puts "   make VARIANT=switched"
  puts " before creating the RTL project."
  puts "=============================================================="
  return -code error "Missing source files -- project not created."
}

# ---- Create the project -----------------------------------------------------
create_project $proj_name $proj_dir -part xc7a200tfbg484-3 -force

set obj [current_project]
set_property -name "target_language"    -value "Verilog" -objects $obj
set_property -name "simulator_language" -value "Mixed"   -objects $obj
set_property -name "default_lib"        -value "xil_defaultlib" -objects $obj

# host_bridge.sv instantiates xpm_cdc_single (2x). Vivado finds XPM by itself for
# synthesis, but for simulation/elaboration the library must be included explicitly.
set_property -name "xpm_libraries" -value "XPM_CDC" -objects $obj

# ---- Source files -----------------------------------------------------------
# The glob is DELIBERATELY non-recursive: src/pcie/_catB_backup/ holds the
# original Xilinx files as *.sv.orig (reference for the rewrite) and they must
# not enter synthesis.
set svfiles [lsort [glob -nocomplain $pcie_dir/*.sv]]

# Any remaining .v in pcie/ (currently none -- everything has been ported to .sv)
set vfiles [lsort [glob -nocomplain $pcie_dir/*.v]]

if { ![llength $svfiles] } {
  return -code error "No .sv file found in $pcie_dir"
}

add_files -norecurse [concat $svfiles $vfiles $csr_files [list $cpu_v $soc_sv $top_sv]]

# Mark SystemVerilog explicitly. This matters because src/pcie/ contains an SV
# package (link_pkg.sv) and two SV interfaces (stream_if.sv, phy_lanes_if.sv) --
# if Vivado treats them as plain Verilog, elaboration fails.
foreach f [concat $svfiles $csr_files [list $soc_sv $top_sv]] {
  set_property file_type "SystemVerilog" [get_files [file normalize $f]]
}

# ---- firmware.hex as a Memory Initialization File ---------------------------
# riscv_pcie_soc.sv does  $readmemh("firmware.hex", ram)  with a bare name, so
# Vivado has to know where to look for it. The "Memory Initialization Files"
# type puts its directory into the synthesis search path.
add_files -norecurse $hex_file
set_property file_type {Memory Initialization Files} [get_files [file normalize $hex_file]]

# ---- Constraints ------------------------------------------------------------
add_files -fileset constrs_1 -norecurse $xdc_file
set_property file_type "XDC" [get_files [file normalize $xdc_file]]

# ---- Top module + compile order ---------------------------------------------
set_property top RC_switched_opensource [current_fileset]
set_property top_auto_set 0 [current_fileset]

# The legacy CSR sits behind `ifdef SOC_CSR_LEGACY in riscv_pcie_soc.sv
if { $use_legacy_csr } {
  set_property verilog_define {SOC_CSR_LEGACY} [current_fileset]
}
update_compile_order -fileset sources_1

# ---- Summary ----------------------------------------------------------------
puts ""
puts "=============================================================="
puts " PROJECT CREATED"
puts "--------------------------------------------------------------"
puts "  xpr       : $proj_dir/$proj_name.xpr"
puts "  part      : xc7a200tfbg484-3   (Acorn CLE-215P)"
puts "  top       : RC_switched_opensource"
puts "  src/pcie  : [llength $svfiles] .sv  +  [llength $vfiles] .v"
puts "  src/      : picorv32.v, riscv_pcie_soc.sv, RC_switched_opensource.sv"
puts "  csr       : [expr {$use_legacy_csr ? {hand-written (SOC_CSR_LEGACY)} : {PeakRDL -- csr_pkg.sv, csr.sv, soc_csr.sv}}]"
puts "  xdc       : [file tail $xdc_file]"
puts "  firmware  : $hex_file"
puts "--------------------------------------------------------------"
puts " Open the .xpr in the Vivado GUI, then:"
puts "   Run Synthesis -> Run Implementation -> Generate Bitstream"
puts "=============================================================="
puts ""
