# RC-direct: GT lane position of the x1 link -- GTPE2_CHANNEL_X0Y5, pins D11/C11/D5/C5.
# Everything else is shared by both root complexes:
#   2.rtl/0.common.opensource/xdc/RC.sv.x1g2.AcornCLE-215P.xdc

set_property LOC GTPE2_CHANNEL_X0Y5 [get_cells {u_pcie/u_phy_top/u_gtp_wrapper/lane_gen[0].u_xcvr/u_gtpe2_channel}]
