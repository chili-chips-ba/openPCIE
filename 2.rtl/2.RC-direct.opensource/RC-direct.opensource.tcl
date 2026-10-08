#*****************************************************************************
# RC-direct.opensource.tcl -- creates the Vivado project (.xpr) for
# RC-direct, the open-source root complex on a direct link
#
# Run (from this folder):
#   vivado -mode batch -source RC-direct.opensource.tcl
#
# or from the Vivado Tcl console, from anywhere:
#   source <path>/RC-direct.opensource.tcl
#
# The project lands in xbuild.Vivado-v2024.2/ here. Everything else -- the RTL,
# the shared constraints, the options -- is in the common script:
#   2.rtl/0.common.opensource/RC.opensource.tcl
# This folder adds only xdc/, the GT lane position of this root complex.
#*****************************************************************************

set ::rc_variant direct
source [file join [file dirname [file normalize [info script]]] .. 0.common.opensource RC.opensource.tcl]
