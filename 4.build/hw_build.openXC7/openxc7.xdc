set_property PACKAGE_PIN F6 [get_ports sys_clk_p]
set_property PACKAGE_PIN E6 [get_ports sys_clk_n]
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

set_property PACKAGE_PIN J1 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PULLTYPE PULLUP [get_ports sys_rst_n]

set_property PACKAGE_PIN C5  [get_ports TXN]
set_property PACKAGE_PIN D5  [get_ports TXP]
set_property PACKAGE_PIN C11 [get_ports RXN]
set_property PACKAGE_PIN D11 [get_ports RXP]

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

create_clock -period 10.000 -name txoutclk [get_nets pcie_inst.serdes_front_i.serdes_ctrl_i.gt_txoutclk]

create_clock -period  8.000 -name clk_125mhz [get_nets pcie_inst.clk_synth_i.clk_125mhz]
create_clock -period  4.000 -name clk_250mhz [get_nets pcie_inst.clk_synth_i.clk_250mhz]
create_clock -period  4.000 -name pclk [get_nets pcie_inst.clk_oobclk]
create_clock -period  8.000 -name dclk   [get_nets pcie_inst.clk_dclk]
create_clock -period 16.000 -name usrclk [get_nets pcie_inst.clk_userclk2]
