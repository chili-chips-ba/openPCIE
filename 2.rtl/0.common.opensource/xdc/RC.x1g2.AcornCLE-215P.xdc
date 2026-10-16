
set_property PACKAGE_PIN F6 [get_ports refclk_p]
set_property PACKAGE_PIN E6 [get_ports refclk_n]
create_clock -period 10.000 -name refclk [get_ports refclk_p]

set_property PACKAGE_PIN J1 [get_ports perst_n]
set_property IOSTANDARD LVCMOS33 [get_ports perst_n]
set_property PULLTYPE PULLUP [get_ports perst_n]
set_false_path -from [get_ports perst_n]

create_clock -name txoutclk_x0y0 -period 10 [get_pins {u_pcie/u_phy_top/u_gtp_wrapper/g_lane[0].u_xcvr/u_gtpe2_channel/TXOUTCLK}]

# The GT channel LOCs -- which of the four lane positions the link uses -- are
# what differs between the root complexes and link widths, so they live in each
# variant's own xdc/, one file per width, which Vivado reads together with this
# file (RC.opensource.tcl picks the one for PCIE_LANES):
#   2.RC-direct.opensource/xdc/RC-direct.x4g2.AcornCLE-215P.xdc       (default)
#   2.RC-direct.opensource/xdc/RC-direct.x1g2.AcornCLE-215P.xdc
#   3.Bonus--RC-switched.opensource/xdc/RC-switched.x1g2.AcornCLE-215P.xdc

set_property LOC GTPE2_COMMON_X0Y1 [get_cells {u_pcie/u_phy_top/u_gtp_wrapper/u_gtpe2_common}]
set_property LOC PCIE_X0Y0 [get_cells u_pcie/u_core/u_pcie_block]

set_property LOC RAMB36_X2Y46 [get_cells {u_pcie/u_core/rx_buf_bank/g_tile[3].ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y47 [get_cells {u_pcie/u_core/rx_buf_bank/g_tile[2].ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y46 [get_cells {u_pcie/u_core/rx_buf_bank/g_tile[1].ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y45 [get_cells {u_pcie/u_core/rx_buf_bank/g_tile[0].ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y44 [get_cells {u_pcie/u_core/tx_buf_bank/g_tile[0].ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y43 [get_cells {u_pcie/u_core/tx_buf_bank/g_tile[1].ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y42 [get_cells {u_pcie/u_core/tx_buf_bank/g_tile[2].ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y41 [get_cells {u_pcie/u_core/tx_buf_bank/g_tile[3].ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]

set_property PACKAGE_PIN G3 [get_ports {led_link_up[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_link_up[0]}]
set_property PACKAGE_PIN H3 [get_ports {led_link_up[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_link_up[1]}]
set_property PACKAGE_PIN G4 [get_ports {led_link_up[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_link_up[2]}]
set_property PACKAGE_PIN H4 [get_ports {led_link_up[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_link_up[3]}]
set_property PACKAGE_PIN G1 [get_ports clk_req]
set_property IOSTANDARD LVCMOS33 [get_ports clk_req]

create_generated_clock -name clk_125mhz_x0y0 [get_pins u_pcie/u_clk_rst_gen/u_mmcm/CLKOUT0]
create_generated_clock -name clk_250mhz_x0y0 [get_pins u_pcie/u_clk_rst_gen/u_mmcm/CLKOUT1]

set_false_path -to [get_pins u_pcie/u_clk_rst_gen/u_pipe_clk/S0]
set_false_path -to [get_pins u_pcie/u_clk_rst_gen/u_pipe_clk/S1]

create_generated_clock -name clk_125mhz_mux_x0y0 -source [get_pins u_pcie/u_clk_rst_gen/u_pipe_clk/I0] -divide_by 1 [get_pins u_pcie/u_clk_rst_gen/u_pipe_clk/O]
create_generated_clock -name clk_250mhz_mux_x0y0 -source [get_pins u_pcie/u_clk_rst_gen/u_pipe_clk/I1] -divide_by 1 -add -master_clock [get_clocks -of [get_pins u_pcie/u_clk_rst_gen/u_pipe_clk/I1]] [get_pins u_pcie/u_clk_rst_gen/u_pipe_clk/O]

set_clock_groups -name pcieclkmux -physically_exclusive -group clk_125mhz_mux_x0y0 -group clk_250mhz_mux_x0y0

set_false_path -through [get_pins -filter {REF_PIN_NAME=~PLPHYLNKUPN} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ * }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~PLRECEIVEDHOTRST} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ * }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~RXELECIDLE} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~TXPHINITDONE} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~TXPHALIGNDONE} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~TXDLYSRESETDONE} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~RXDLYSRESETDONE} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~RXPHALIGNDONE} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~RXCDRLOCK} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~CFGMSGRECEIVEDPMETO} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ * }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~PLL0LOCK} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~RXPMARESETDONE} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~RXSYNCDONE} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
set_false_path -through [get_pins -filter {REF_PIN_NAME=~TXSYNCDONE} -of_objects [get_cells -hierarchical -filter { PRIMITIVE_TYPE =~ IO.gt.* }]]
