
set_property PACKAGE_PIN F6 [get_ports sys_clk_p]
set_property PACKAGE_PIN E6 [get_ports sys_clk_n]
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

set_property PACKAGE_PIN J1 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]
set_property PULLTYPE PULLUP [get_ports sys_rst_n]
set_false_path -from [get_ports sys_rst_n]

create_clock -name txoutclk_x0y0 -period 10 [get_pins {pcie_inst/serdes_front_i/serdes_ctrl_i/lane_gen[0].xcvr_i/hm_chan.gtpe2_channel_i/TXOUTCLK}]

set_property LOC GTPE2_CHANNEL_X0Y5 [get_cells {pcie_inst/serdes_front_i/serdes_ctrl_i/lane_gen[0].xcvr_i/hm_chan.gtpe2_channel_i}]

set_property LOC GTPE2_COMMON_X0Y1 [get_cells {pcie_inst/serdes_front_i/serdes_ctrl_i/lane_gen[0].quad_gen.pll_bank_i/hm_cmn.gtpe2_common_i}]
set_property LOC PCIE_X0Y0 [get_cells pcie_inst/txn_engine_i/silicon_core_i/pcie_block_i]

set_property LOC RAMB36_X2Y46 [get_cells {pcie_inst/txn_engine_i/silicon_core_i/rx_buf_bank/tiles[3].tile/use_tdp.ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y47 [get_cells {pcie_inst/txn_engine_i/silicon_core_i/rx_buf_bank/tiles[2].tile/use_tdp.ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y46 [get_cells {pcie_inst/txn_engine_i/silicon_core_i/rx_buf_bank/tiles[1].tile/use_tdp.ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y45 [get_cells {pcie_inst/txn_engine_i/silicon_core_i/rx_buf_bank/tiles[0].tile/use_tdp.ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y44 [get_cells {pcie_inst/txn_engine_i/silicon_core_i/tx_buf_bank/tiles[0].tile/use_tdp.ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y43 [get_cells {pcie_inst/txn_engine_i/silicon_core_i/tx_buf_bank/tiles[1].tile/use_tdp.ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y42 [get_cells {pcie_inst/txn_engine_i/silicon_core_i/tx_buf_bank/tiles[2].tile/use_tdp.ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]
set_property LOC RAMB36_X1Y41 [get_cells {pcie_inst/txn_engine_i/silicon_core_i/tx_buf_bank/tiles[3].tile/use_tdp.ramb36/genblk*.bram36_tdp_bl.bram36_tdp_bl}]

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

create_generated_clock -name clk_125mhz_x0y0 [get_pins pcie_inst/clk_synth_i/mmcm_i/CLKOUT0]
create_generated_clock -name clk_250mhz_x0y0 [get_pins pcie_inst/clk_synth_i/mmcm_i/CLKOUT1]

set_false_path -to [get_pins pcie_inst/clk_synth_i/pclk_i1/S0]
set_false_path -to [get_pins pcie_inst/clk_synth_i/pclk_i1/S1]

create_generated_clock -name clk_125mhz_mux_x0y0 -source [get_pins pcie_inst/clk_synth_i/pclk_i1/I0] -divide_by 1 [get_pins pcie_inst/clk_synth_i/pclk_i1/O]
create_generated_clock -name clk_250mhz_mux_x0y0 -source [get_pins pcie_inst/clk_synth_i/pclk_i1/I1] -divide_by 1 -add -master_clock [get_clocks -of [get_pins pcie_inst/clk_synth_i/pclk_i1/I1]] [get_pins pcie_inst/clk_synth_i/pclk_i1/O]

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
