set_property PACKAGE_PIN F6 [get_ports sys_clk_p]
set_property PACKAGE_PIN E6 [get_ports sys_clk_n]
create_clock -period 10.000 -name sys_clk_pin [get_ports sys_clk_p]

set_property PACKAGE_PIN J1 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PULLTYPE PULLUP [get_ports sys_rst_n]

#LANE0
#set_property PACKAGE_PIN B10 [get_ports {pci_exp_rxn[0]}]
#set_property PACKAGE_PIN A10 [get_ports {pci_exp_rxp[0]}]
#set_property PACKAGE_PIN B6 [get_ports {pci_exp_txn[0]}]
#set_property PACKAGE_PIN A6 [get_ports {pci_exp_txp[0]}]
#set_property LOC GTPE2_CHANNEL_X0Y6 [get_cells {pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]

#LANE1
#set_property PACKAGE_PIN B8 [get_ports {pci_exp_rxn[0]}]
#set_property PACKAGE_PIN A8 [get_ports {pci_exp_rxp[0]}]
#set_property PACKAGE_PIN B4 [get_ports {pci_exp_txn[0]}]
#set_property PACKAGE_PIN A4 [get_ports {pci_exp_txp[0]}]
#set_property LOC GTPE2_CHANNEL_X0Y4 [get_cells {pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]

#LANE2
set_property PACKAGE_PIN D11 [get_ports {pci_exp_rxn[0]}]
set_property PACKAGE_PIN C11 [get_ports {pci_exp_rxp[0]}]
set_property PACKAGE_PIN D5 [get_ports {pci_exp_txn[0]}]
set_property PACKAGE_PIN C5 [get_ports {pci_exp_txp[0]}]
set_property LOC GTPE2_CHANNEL_X0Y5 [get_cells {pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]

#LANE3
#set_property PACKAGE_PIN D9 [get_ports {pci_exp_rxn[0]}]
#set_property PACKAGE_PIN C9 [get_ports {pci_exp_rxp[0]}]
#set_property PACKAGE_PIN D7 [get_ports {pci_exp_txn[0]}]
#set_property PACKAGE_PIN C7 [get_ports {pci_exp_txp[0]}]
#set_property LOC GTPE2_CHANNEL_X0Y7 [get_cells {pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]

set_property PACKAGE_PIN G3 [get_ports {led_debug_out[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_debug_out[0]}]

set_property PACKAGE_PIN H3 [get_ports {led_debug_out[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_debug_out[1]}]

set_property PACKAGE_PIN G4 [get_ports {led_debug_out[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_debug_out[2]}]

set_property PACKAGE_PIN H4 [get_ports {led_debug_out[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_debug_out[3]}]

set_property PACKAGE_PIN G1 [get_ports clk_req]
set_property IOSTANDARD LVCMOS33 [get_ports clk_req]

#set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
#set_property CONFIG_MODE SPIx4 [current_design]

set_false_path -from [get_ports sys_rst_n]

set_false_path -to [get_pins pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0]
set_false_path -to [get_pins pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S1]
set_case_analysis 1 [get_pins pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0]
set_case_analysis 0 [get_pins pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S1]
set_property DONT_TOUCH true [get_cells -of [get_nets -of [get_pins pcie_7x_0_support_i/pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0]]]

#set_property LOC GTPE2_CHANNEL_X0Y6 [get_cells {pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]
