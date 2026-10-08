#*****************************************************************************
# RC.opensource.tcl -- creates the Vivado project (.xpr) for one of the two
#                      open-source SystemVerilog root complexes
#
# Board : Acorn CLE-215P  ->  xc7a200tfbg484-3
# Link  : PCIe x1 Gen2
# Top   : RC_opensource
#
# Not run directly. Each root complex has a short wrapper that names itself
# and sources this script:
#   2.rtl/2.RC-direct.opensource/RC-direct.opensource.tcl            (direct)
#   2.rtl/3.Bonus--RC-switched.opensource/RC-switched.opensource.tcl (switched)
#
# Run a wrapper (from its folder):
#   vivado -mode batch -source RC-direct.opensource.tcl
#
# or from the Vivado Tcl console, from anywhere:
#   source <path>/RC-direct.opensource.tcl
#
# Options via Tcl variables (set them BEFORE source):
#   set ::origin_dir_loc    <path>   ;# variant folder (default: the wrapper's)
#   set ::user_project_name <name>   ;# .xpr name (default: Vivado-v2024.2)
#
# Afterwards open  xbuild.Vivado-v2024.2/Vivado-v2024.2.xpr  in the variant's
# folder in the Vivado GUI:
#   Run Synthesis -> Run Implementation -> Generate Bitstream
#
# NOTE: xbuild.Vivado-v2024.2/ is a fully regenerated folder -- the script
# creates it with -force, so every re-run deletes it and builds from scratch.
# Do not keep anything of your own inside. The sources of truth are only
# 0.common.opensource/ (RTL, shared constraints, this script) and the
# variant's wrapper and xdc/ (its GT lane).
#*****************************************************************************

# ---- Variant ----------------------------------------------------------------
# ([info script] works even when the script is sourced from elsewhere, "." does not)
set common_dir [file dirname [file normalize [info script]]]

if { ![info exists ::rc_variant] } {
  return -code error "Source a wrapper, not this script:\
 2.RC-direct.opensource/RC-direct.opensource.tcl or\
 3.Bonus--RC-switched.opensource/RC-switched.opensource.tcl"
}
switch -- $::rc_variant {
  direct {
    set origin_dir "$common_dir/../2.RC-direct.opensource"
    set lane_xdc   "RC-direct.sv.x1g2.AcornCLE-215P.xdc"
    set fw_make    "make"
  }
  switched {
    set origin_dir "$common_dir/../3.Bonus--RC-switched.opensource"
    set lane_xdc   "RC-switched.sv.x1g2.AcornCLE-215P.xdc"
    set fw_make    "make VARIANT=switched"
  }
  default {
    return -code error "rc_variant must be \"direct\" or \"switched\", got \"$::rc_variant\""
  }
}
set origin_dir [file normalize $origin_dir]
if { [info exists ::origin_dir_loc] } {
  set origin_dir [file normalize $::origin_dir_loc]
}

set proj_name "Vivado-v2024.2"
if { [info exists ::user_project_name] } {
  set proj_name $::user_project_name
}
set proj_dir "$origin_dir/xbuild.Vivado-v2024.2"

# ---- Paths ------------------------------------------------------------------
# RTL and the shared constraints come from 0.common.opensource/; only the GT
# lane LOC is the variant's own.
set src_dir   "$common_dir/src"
set pcie_dir  "$common_dir/src/pcie"
set xdc_files [list "$common_dir/xdc/RC.sv.x1g2.AcornCLE-215P.xdc" \
                    "$origin_dir/xdc/$lane_xdc"]

set top_sv "$src_dir/RC_opensource.sv"
set soc_sv "$src_dir/riscv_pcie_soc.sv"
set cpu_v  "$src_dir/picorv32.CHILI.sv"

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

set cfg_file [file normalize "$common_dir/../../4.build/config.mk"]
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

set csr_gen_dir [file normalize "$common_dir/../../4.build/csr_build/generated-files"]
set csr_pkg_sv  "$csr_gen_dir/csr_pkg.sv"
set csr_sv      "$csr_gen_dir/csr.sv"
set soc_csr_sv  "$src_dir/soc_csr.sv"

if { $use_legacy_csr } {
  set csr_files {}
} else {
  set csr_files [list $csr_pkg_sv $csr_sv $soc_csr_sv]
}

# firmware.hex is a product of the sw_build stage. The copy checked in is the
# RC-direct one; for RC-switched, rebuild it with  make VARIANT=switched
#   <openPCIE>/4.build/sw_build/firmware.hex
set hex_file [file normalize "$common_dir/../../4.build/sw_build/firmware.hex"]

# ---- Check everything exists before Vivado is even started ------------------
set missing {}
foreach f [concat [list $top_sv $soc_sv $cpu_v $hex_file] $xdc_files $csr_files] {
  if { ![file isfile $f] } { lappend missing $f }
}
if { ![file isdirectory $pcie_dir] } { lappend missing "$pcie_dir (folder)" }

if { [llength $missing] } {
  puts "=============================================================="
  puts " ERROR -- missing:"
  foreach f $missing { puts "   $f" }
  puts ""
  puts " If firmware.hex is missing: run the sw_build stage with"
  puts "   $fw_make"
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
# if Vivado treats them as plain Verilog, elaboration fails. picorv32.CHILI.sv is
# SystemVerilog too.
foreach f [concat $svfiles $csr_files [list $cpu_v $soc_sv $top_sv]] {
  set_property file_type "SystemVerilog" [get_files [file normalize $f]]
}

# ---- firmware.hex as a Memory Initialization File ---------------------------
# riscv_pcie_soc.sv does  $readmemh("firmware.hex", ram)  with a bare name, so
# Vivado has to know where to look for it. The "Memory Initialization Files"
# type puts its directory into the synthesis search path.
add_files -norecurse $hex_file
set_property file_type {Memory Initialization Files} [get_files [file normalize $hex_file]]

# ---- Constraints ------------------------------------------------------------
add_files -fileset constrs_1 -norecurse $xdc_files
foreach f $xdc_files {
  set_property file_type "XDC" [get_files [file normalize $f]]
}

# ---- Top module + compile order ---------------------------------------------
set_property top RC_opensource [current_fileset]
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
puts "  variant   : $::rc_variant"
puts "  top       : RC_opensource"
puts "  src/pcie  : [llength $svfiles] .sv  +  [llength $vfiles] .v   (0.common.opensource)"
puts "  src/      : picorv32.CHILI.sv, riscv_pcie_soc.sv, RC_opensource.sv"
puts "  csr       : [expr {$use_legacy_csr ? {hand-written (SOC_CSR_LEGACY)} : {PeakRDL -- csr_pkg.sv, csr.sv, soc_csr.sv}}]"
puts "  xdc       : [join [lmap f $xdc_files {file tail $f}] {, }]"
puts "  firmware  : $hex_file"
puts "--------------------------------------------------------------"
puts " Open the .xpr in the Vivado GUI, then:"
puts "   Run Synthesis -> Run Implementation -> Generate Bitstream"
puts "=============================================================="
puts ""
