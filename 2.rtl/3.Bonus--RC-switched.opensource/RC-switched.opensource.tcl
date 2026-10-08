#*****************************************************************************
# RC-switched.opensource.tcl -- creates the Vivado project (.xpr) for
# RC-switched, the open-source root complex behind the ASM1184e switch
#
# Run (from this folder):
#   vivado -mode batch -source RC-switched.opensource.tcl
#
# or from the Vivado Tcl console, from anywhere:
#   source <path>/RC-switched.opensource.tcl
#
# The project lands in xbuild.Vivado-v2024.2/ here. Everything else -- the RTL,
# the shared constraints, the options -- is in the common script:
#   2.rtl/0.common.opensource/RC.opensource.tcl
# This folder adds only xdc/, the GT lane position of this root complex.
#*****************************************************************************

set ::rc_variant switched
source [file join [file dirname [file normalize [info script]]] .. 0.common.opensource RC.opensource.tcl]
