# RC-direct: GT lane positions of the x4 link (build with PCIE_LANES=4).
# Board lane -> GT channel, pins RXP/RXN TXP/TXN (0.doc/xilinx/xc7a200t-fbg484-package.txt):
#   lane 0  GTPE2_CHANNEL_X0Y6  B10/A10 B6/A6
#   lane 1  GTPE2_CHANNEL_X0Y4  B8/A8   B4/A4
#   lane 2  GTPE2_CHANNEL_X0Y5  D11/C11 D5/C5
#   lane 3  GTPE2_CHANNEL_X0Y7  D9/C9   D7/C7
# Everything else is shared by both root complexes:
#   2.rtl/0.common.opensource/xdc/RC.common.xdc

set_property LOC GTPE2_CHANNEL_X0Y6 [get_cells {u_pcie/u_phy_top/u_gtp_wrapper/g_lane[0].u_xcvr/u_gtpe2_channel}]
set_property LOC GTPE2_CHANNEL_X0Y4 [get_cells {u_pcie/u_phy_top/u_gtp_wrapper/g_lane[1].u_xcvr/u_gtpe2_channel}]
set_property LOC GTPE2_CHANNEL_X0Y5 [get_cells {u_pcie/u_phy_top/u_gtp_wrapper/g_lane[2].u_xcvr/u_gtpe2_channel}]
set_property LOC GTPE2_CHANNEL_X0Y7 [get_cells {u_pcie/u_phy_top/u_gtp_wrapper/g_lane[3].u_xcvr/u_gtpe2_channel}]
