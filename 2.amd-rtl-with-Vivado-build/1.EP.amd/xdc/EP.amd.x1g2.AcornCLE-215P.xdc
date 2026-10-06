set_property PACKAGE_PIN F6 [get_ports sys_clk_p]
set_property PACKAGE_PIN E6 [get_ports sys_clk_n]
create_clock -period 10.000 -name sys_clk_pin [get_ports sys_clk_p]

set_property PACKAGE_PIN J1 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PULLTYPE PULLUP [get_ports sys_rst_n]

#LANE0
# pads MGTP*2_216: RXP B10, RXN A10, TXP B6, TXN A6 - fixed by the GTPE2_CHANNEL LOC below
#set_property LOC GTPE2_CHANNEL_X0Y6 [get_cells {pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]

#LANE1
# pads MGTP*0_216: RXP B8, RXN A8, TXP B4, TXN A4 - fixed by the GTPE2_CHANNEL LOC below
#set_property LOC GTPE2_CHANNEL_X0Y4 [get_cells {pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]

#LANE2
# pads MGTP*1_216: RXP D11, RXN C11, TXP D5, TXN C5 - fixed by the GTPE2_CHANNEL LOC below
set_property LOC GTPE2_CHANNEL_X0Y5 [get_cells {pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]

#LANE3
# pads MGTP*3_216: RXP D9, RXN C9, TXP D7, TXN C7 - fixed by the GTPE2_CHANNEL LOC below
#set_property LOC GTPE2_CHANNEL_X0Y7 [get_cells {pcie_7x_0_support_i/pcie_7x_0_i/inst/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i}]

set_property PACKAGE_PIN G3 [get_ports {led_data_payload[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_data_payload[0]}]

set_property PACKAGE_PIN H3 [get_ports {led_data_payload[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_data_payload[1]}]

set_property PACKAGE_PIN G4 [get_ports {led_data_payload[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_data_payload[2]}]

set_property PACKAGE_PIN H4 [get_ports {led_data_payload[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led_data_payload[3]}]

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
