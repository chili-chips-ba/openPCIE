# RC-switched: GT lane position of the x1 link -- GTPE2_CHANNEL_X0Y6, pins B10/A10/B6/A6.
# Everything else is shared by both root complexes:
#   2.rtl/0.common.opensource/xdc/RC.sv.x1g2.AcornCLE-215P.xdc

set_property LOC GTPE2_CHANNEL_X0Y6 [get_cells {pcie_inst/serdes_front_i/serdes_ctrl_i/lane_gen[0].xcvr_i/hm_chan.gtpe2_channel_i}]
