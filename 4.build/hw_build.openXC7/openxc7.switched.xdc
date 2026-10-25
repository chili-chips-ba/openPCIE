set_property PACKAGE_PIN F6 [get_ports refclk_p]
set_property PACKAGE_PIN E6 [get_ports refclk_n]
create_clock -period 10.000 -name refclk [get_ports refclk_p]

set_property PACKAGE_PIN J1 [get_ports perst_n]
set_property IOSTANDARD LVCMOS33 [get_ports perst_n]
set_property PULLTYPE PULLUP [get_ports perst_n]

set_property PACKAGE_PIN A6  [get_ports txn]
set_property PACKAGE_PIN B6  [get_ports txp]
set_property PACKAGE_PIN A10 [get_ports rxn]
set_property PACKAGE_PIN B10 [get_ports rxp]

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

create_clock -period 10.000 -name txoutclk [get_nets u_pcie.u_phy_top.u_gtp_wrapper.gt_txoutclk]

create_clock -period  8.000 -name clk_125mhz [get_nets u_pcie.u_clk_rst_gen.clk_125mhz]
create_clock -period  4.000 -name clk_250mhz [get_nets u_pcie.u_clk_rst_gen.clk_250mhz]
create_clock -period  4.000 -name pipe_clk [get_nets u_pcie.pipe_clk]
create_clock -period  8.000 -name clk125 [get_nets u_pcie.clk125]
# user_clk: no create_clock; nextpnr derives it from the MMCM's CLKOUT2
# (62.5 / 125 / 250 MHz, set by pcie_pkg.sv USER_CLK_FREQ)
