#*****************************************************************************
# RC-direct.opensource.tcl -- pravi Vivado projekat (.xpr) za RC-direct,
#                             open-source SystemVerilog implementaciju
#
# Ploca : Acorn CLE-215P  ->  xc7a200tfbg484-3
# Link  : PCIe x1 Gen2
# Top   : RC_direct_opensource
#
# Pokretanje (iz ovog foldera):
#   vivado -mode batch -source RC-direct.opensource.tcl
#
# ili iz Vivado Tcl konzole, bilo odakle:
#   source <putanja>/RC-direct.opensource.tcl
#
# Opcije preko Tcl varijabli (postavi ih PRIJE source):
#   set ::origin_dir_loc    <putanja>   ;# korijen projekta (default: folder skripte)
#   set ::user_project_name <ime>       ;# ime .xpr (default: RC_direct_opensource)
#
# Nakon toga otvori  proj/RC_direct_opensource.xpr  u Vivado GUI pa:
#   Run Synthesis -> Run Implementation -> Generate Bitstream
#
# PAZNJA: proj/ je potpuno regenerisan folder -- skripta ga pravi s -force,
# tj. svako ponovno pokretanje ga brise i gradi iz nule. Ne cuvaj nista svoje
# unutra. Izvor istine su samo  src/ ,  xdc/  i ova skripta.
#*****************************************************************************

# ---- Korijen projekta = folder u kojem je ova skripta ----------------------
# ([info script] radi i kad se skripta source-a izvana, za razliku od "." )
set origin_dir [file dirname [file normalize [info script]]]
if { [info exists ::origin_dir_loc] } {
  set origin_dir [file normalize $::origin_dir_loc]
}

set proj_name "Vivado-v2024.2"
if { [info exists ::user_project_name] } {
  set proj_name $::user_project_name
}
set proj_dir "$origin_dir/xbuild.Vivado-v2024.2"

# ---- Putanje ---------------------------------------------------------------
set src_dir  "$origin_dir/src"
set pcie_dir "$origin_dir/src/pcie"
set xdc_file "$origin_dir/xdc/RC-direct.sv.x1g2.AcornCLE-215P.xdc"

set top_sv "$src_dir/RC_direct_opensource.sv"
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

# firmware.hex se NE drzi u ovom repou -- proizvod je sw_build faze:
#   <openPCIE>/4.build/sw_build/firmware.hex
# Relativno odavde (2.rtl/2.RC-direct.opensource) to je ../../4.build/sw_build/
set hex_file [file normalize "$origin_dir/../../4.build/sw_build/firmware.hex"]

# ---- Provjeri da sve postoji prije nego se uopste startuje Vivado ----------
set missing {}
foreach f [concat [list $top_sv $soc_sv $cpu_v $xdc_file $hex_file] $csr_files] {
  if { ![file isfile $f] } { lappend missing $f }
}
if { ![file isdirectory $pcie_dir] } { lappend missing "$pcie_dir (folder)" }

if { [llength $missing] } {
  puts "=============================================================="
  puts " GRESKA -- nedostaje:"
  foreach f $missing { puts "   $f" }
  puts ""
  puts " Ako fali firmware.hex: pokreni sw_build fazu u 4.build/ prije"
  puts " kreiranja RTL projekta."
  puts "=============================================================="
  return -code error "Nedostaju izvorni fajlovi -- projekat nije kreiran."
}

# ---- Kreiraj projekat ------------------------------------------------------
create_project $proj_name $proj_dir -part xc7a200tfbg484-3 -force

set obj [current_project]
set_property -name "target_language"    -value "Verilog" -objects $obj
set_property -name "simulator_language" -value "Mixed"   -objects $obj
set_property -name "default_lib"        -value "xil_defaultlib" -objects $obj

# host_bridge.sv instancira xpm_cdc_single (2x). Za sintezu Vivado XPM nalazi
# sam, ali za simulaciju/elaboraciju biblioteka mora biti eksplicitno ukljucena.
set_property -name "xpm_libraries" -value "XPM_CDC" -objects $obj

# ---- Izvorni fajlovi -------------------------------------------------------
# glob je NAMJERNO ne-rekurzivan: src/pcie/_catB_backup/ drzi originalne Xilinx
# fajlove kao *.sv.orig (referenca za rewrite) i oni ne smiju u sintezu.
set svfiles [lsort [glob -nocomplain $pcie_dir/*.sv]]

# Eventualni preostali .v u pcie/ (trenutno ih nema -- sve je prevedeno u .sv)
set vfiles [lsort [glob -nocomplain $pcie_dir/*.v]]

if { ![llength $svfiles] } {
  return -code error "Nijedan .sv fajl nije nadjen u $pcie_dir"
}

add_files -norecurse [concat $svfiles $vfiles $csr_files [list $cpu_v $soc_sv $top_sv]]

# Eksplicitno oznaci SystemVerilog. Bitno jer je u src/pcie/ i SV paket
# (link_pkg.sv) i dva SV interfejsa (stream_if.sv, phy_lanes_if.sv) --
# ako ih Vivado tretira kao obicni Verilog, elaboracija puca.
foreach f [concat $svfiles $csr_files [list $soc_sv $top_sv]] {
  set_property file_type "SystemVerilog" [get_files [file normalize $f]]
}

# ---- firmware.hex kao Memory Initialization File ---------------------------
# riscv_pcie_soc.sv radi  $readmemh("firmware.hex", ram)  s golim imenom, pa
# Vivado mora znati gdje da ga trazi. Tip "Memory Initialization Files"
# ubacuje njegov direktorij u search path sinteze.
add_files -norecurse $hex_file
set_property file_type {Memory Initialization Files} [get_files [file normalize $hex_file]]

# ---- Constraints -----------------------------------------------------------
add_files -fileset constrs_1 -norecurse $xdc_file
set_property file_type "XDC" [get_files [file normalize $xdc_file]]

# ---- Top modul + redoslijed kompilacije ------------------------------------
set_property top RC_direct_opensource [current_fileset]
set_property top_auto_set 0 [current_fileset]

# The legacy CSR sits behind `ifdef SOC_CSR_LEGACY in riscv_pcie_soc.sv
if { $use_legacy_csr } {
  set_property verilog_define {SOC_CSR_LEGACY} [current_fileset]
}
update_compile_order -fileset sources_1

# ---- Sazetak ---------------------------------------------------------------
puts ""
puts "=============================================================="
puts " PROJEKAT KREIRAN"
puts "--------------------------------------------------------------"
puts "  xpr       : $proj_dir/$proj_name.xpr"
puts "  part      : xc7a200tfbg484-3   (Acorn CLE-215P)"
puts "  top       : RC_direct_opensource"
puts "  src/pcie  : [llength $svfiles] .sv  +  [llength $vfiles] .v"
puts "  src/      : picorv32.v, riscv_pcie_soc.sv, RC_direct_opensource.sv"
puts "  csr       : [expr {$use_legacy_csr ? {hand-written (SOC_CSR_LEGACY)} : {PeakRDL -- csr_pkg.sv, csr.sv, soc_csr.sv}}]"
puts "  xdc       : [file tail $xdc_file]"
puts "  firmware  : $hex_file"
puts "--------------------------------------------------------------"
puts " Otvori .xpr u Vivado GUI, pa:"
puts "   Run Synthesis -> Run Implementation -> Generate Bitstream"
puts "=============================================================="
puts ""
