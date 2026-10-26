#*****************************************************************************
# RC.opensource.tcl -- creates the Vivado project (.xpr) for one of the two
#                      open-source SystemVerilog root complexes
#
# Board : Acorn CLE-215P  ->  xc7a200tfbg484-3
# Link  : PCIe x4 (default, direct only) or x1; Gen1 at x4, Gen2 at x1 (defaults)
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
#   set ::pcie_lanes        1|4      ;# link width (default: 4 direct, 1 switched)
#   set ::pcie_gen          1|2      ;# link speed (default: 1 at x4, 2 at x1)
#   set ::cpu               edubos5|edubos5_3stg|picorv32  ;# (default: edubos5;
#                                    edubos5_3stg at x4 Gen2, for its 250 MHz user clock)
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
# x4 runs only on the direct link; the switch ports are x1
switch -- $::rc_variant {
  direct {
    set pcie_lanes [expr { [info exists ::pcie_lanes] ? $::pcie_lanes : 4 }]
    if { $pcie_lanes ni {1 4} } {
      return -code error "pcie_lanes must be 1 or 4, got \"$pcie_lanes\""
    }
    set origin_dir "$common_dir/../2.RC-direct.opensource"
    set lane_xdc   "RC-direct.x${pcie_lanes}g2.AcornCLE-215P.xdc"
    set fw_make    "make"
  }
  switched {
    set pcie_lanes [expr { [info exists ::pcie_lanes] ? $::pcie_lanes : 1 }]
    if { $pcie_lanes != 1 } {
      return -code error "RC-switched is x1 only, got pcie_lanes \"$pcie_lanes\""
    }
    set origin_dir "$common_dir/../3.Bonus--RC-switched.opensource"
    set lane_xdc   "RC-switched.x1g2.AcornCLE-215P.xdc"
    set fw_make    "make VARIANT=switched"
  }
  default {
    return -code error "rc_variant must be \"direct\" or \"switched\", got \"$::rc_variant\""
  }
}
# Default speed: Gen1 at x4 (x4 Gen2 closes timing in Vivado only), Gen2 at x1
set pcie_gen [expr { [info exists ::pcie_gen] ? $::pcie_gen : ($pcie_lanes == 4 ? 1 : 2) }]
if { $pcie_gen ni {1 2} } {
  return -code error "pcie_gen must be 1 or 2, got \"$pcie_gen\""
}
# Default CPU: the 3-stage eduBOS5 at x4 Gen2 (250 MHz user clock), else the 2-stage
set cpu_def [expr { $pcie_lanes == 4 && $pcie_gen == 2 ? "edubos5_3stg" : "edubos5" }]
set cpu [expr { [info exists ::cpu] ? $::cpu : $cpu_def }]
if { $cpu ni {edubos5 edubos5_3stg picorv32} } {
  return -code error "cpu must be edubos5, edubos5_3stg or picorv32, got \"$cpu\""
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
set xdc_files [list "$common_dir/xdc/RC.x1g2.AcornCLE-215P.xdc" \
                    "$origin_dir/xdc/$lane_xdc"]

set top_sv "$src_dir/RC_opensource.sv"
set soc_sv "$src_dir/riscv_pcie_soc.sv"
# CPU: eduBOS5 (the default, riscv_pcie_soc.sv) and picorv32 (SOC_CPU_PICORV32)
set cpu_v  [list {*}[lmap f {edubos5_pkg.sv edubos5_rf.sv edubos5_alu.sv edubos5.sv} \
                       {file join $src_dir CPU.eduBOS5 $f}] \
                 "$src_dir/picorv32.CHILI.sv"]
set cpu_defines [dict get {edubos5 {} edubos5_3stg SOC_EDUBOS5_3STG picorv32 SOC_CPU_PICORV32} $cpu]
# The 3-stage pipeline's multicycle paths, implementation only (post-synthesis names)
set mcp_xdc [expr { $cpu eq "edubos5_3stg" ? "$src_dir/CPU.eduBOS5/edubos5.3STG-ONLY.mcp.xdc" : "" }]

# ---- CSR: PeakRDL-generated register block ----------------------------------
# csr_pkg.sv and csr.sv are generated from 4.build/csr_build/csr.rdl by
# "make -f MakefileCSR" in 4.build/. soc_csr.sv wraps that register block and
# bridges it to the picorv32 memory interface.
set csr_gen_dir [file normalize "$common_dir/../../4.build/csr_build/generated-files"]
set csr_pkg_sv  "$csr_gen_dir/csr_pkg.sv"
set csr_sv      "$csr_gen_dir/csr.sv"
set soc_csr_sv  "$src_dir/soc_csr.sv"

set csr_files [list $csr_pkg_sv $csr_sv $soc_csr_sv]

# firmware.hex is a product of the sw_build stage. The copy checked in is the
# RC-direct one; for RC-switched, rebuild it with  make VARIANT=switched
#   <openPCIE>/4.build/sw_build/firmware.hex
set hex_file [file normalize "$common_dir/../../4.build/sw_build/firmware.hex"]

# ---- Check everything exists before Vivado is even started ------------------
set missing {}
foreach f [concat [list $top_sv $soc_sv $hex_file] $cpu_v $xdc_files $mcp_xdc $csr_files] {
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


# ---- Source files -----------------------------------------------------------
# The glob is deliberately non-recursive: only the .sv files directly in
# src/pcie/ enter synthesis, never anything a subfolder might hold.
set svfiles [lsort [glob -nocomplain $pcie_dir/*.sv]]

# Any remaining .v in pcie/ (currently none -- everything has been ported to .sv)
set vfiles [lsort [glob -nocomplain $pcie_dir/*.v]]

if { ![llength $svfiles] } {
  return -code error "No .sv file found in $pcie_dir"
}

add_files -norecurse [concat $svfiles $vfiles $csr_files $cpu_v [list $soc_sv $top_sv]]

# Link width and speed for link_pkg.sv, for synthesis and simulation alike
set link_defines [list "PCIE_LANES=$pcie_lanes" "PCIE_GEN=$pcie_gen" {*}$cpu_defines]
set_property verilog_define $link_defines [get_filesets sources_1]
set_property verilog_define $link_defines [get_filesets sim_1]

# Mark SystemVerilog explicitly. This matters because src/pcie/ contains SV
# packages (link_pkg.sv, pcie_pkg.sv) and SV interfaces (axis_if, trn_if, pipe_if,
# cfg_if, mem_if, mim_if, gtp_if) --
# if Vivado treats them as plain Verilog, elaboration fails. picorv32.CHILI.sv is
# SystemVerilog too.
foreach f [concat $svfiles $csr_files $cpu_v [list $soc_sv $top_sv]] {
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
if { $mcp_xdc ne "" } {
  add_files -fileset constrs_1 -norecurse $mcp_xdc
  set_property USED_IN_SYNTHESIS false [get_files [file normalize $mcp_xdc]]
}

# ---- Top module + compile order ---------------------------------------------
set_property top RC_opensource [current_fileset]
set_property top_auto_set 0 [current_fileset]

update_compile_order -fileset sources_1

# ---- Summary ----------------------------------------------------------------
puts ""
puts "=============================================================="
puts " PROJECT CREATED"
puts "--------------------------------------------------------------"
puts "  xpr       : $proj_dir/$proj_name.xpr"
puts "  part      : xc7a200tfbg484-3   (Acorn CLE-215P)"
puts "  variant   : $::rc_variant"
puts "  link      : x$pcie_lanes Gen$pcie_gen"
puts "  cpu       : $cpu"
puts "  top       : RC_opensource"
puts "  src/pcie  : [llength $svfiles] .sv  +  [llength $vfiles] .v   (0.common.opensource)"
puts "  src/      : CPU.eduBOS5/, picorv32.CHILI.sv, riscv_pcie_soc.sv, RC_opensource.sv"
puts "  csr       : PeakRDL -- csr_pkg.sv, csr.sv, soc_csr.sv"
puts "  xdc       : [join [lmap f [concat $xdc_files $mcp_xdc] {file tail $f}] {, }]"
puts "  firmware  : $hex_file"
puts "--------------------------------------------------------------"
puts " Open the .xpr in the Vivado GUI, then:"
puts "   Run Synthesis -> Run Implementation -> Generate Bitstream"
puts "=============================================================="
puts ""

# -----------------------------------------------------------------------------
# Project:     openPCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        May 24, 2024
# -----------------------------------------------------------------------------
