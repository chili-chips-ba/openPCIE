<!-- Generated text version of `1.pcb/0.doc/openPCIE-BlockDiagram.drawio` (draw.io text labels) so the website assistant can read it. Do not edit by hand; regenerate from the source. -->

# openPCIE backplane block diagram (text labels)

The diagram itself is graphical; these are its text labels, page by page.

## PCIE-topology

- General PCIE topology
- PCIEx1 pinout

## openPCIE2

- --- openPCIE backplane ---
- July 27, 2025
- RC44-lane RC connector with mechanical option: / - M.2 (PCIE)
- 4-lane "Direct" island / RC4 => EP4
- EP44-lane EP connector with mechanical option: / - Slot
- 4 lanes
- The "RC Connectors" are for the plug-in cards that are natively EP.
- 1-lane "Switched" islandRC1=>SW=>SW_EP0/1/2/3
- RC11-lane RC connector with mechanical option: - Slot
- The backplane job is to swap the connector pins so that the Tx diff.pair on one side of the link is connected to the Rx diff.pair on the other side, and vice-versa. This allows the same FPGA plug-in card, which is always pined-out to serve as an EP, to be used in both EP and RC roles.
- 1 lane
- SWitch / PCIE2.1 / 1-lane / 1-to-4
- 4 x / 1 lane
- 1-lane EPconnector / - Slot
- 1-lane EPconnector / - M.2 (PCIE)
- SW_EP0
- SW_EP1
- SW_EP2
- SW_EP3
- cca 10W per slot70W total
- differential REFCLK_P/N
- 6-pin PCIE Power connector(3x12V, 3xGND)
- DC/DC Buck and LDOs for power distribution
- ...
- Reset Generator / - PowerOn reset (3V3) / - manual push-button / - distribution buffers
- PERST#
- 100MHz PCIE-class REFCLK Generator / - 25MHz oscillator / - PLL / - series-terminated / distribution buffers
- CLKREQ#

## openPCIE3-AsMedia

Note: discovery-stage option for a follow-up Gen3 board. A 20-lane ASMedia-based design was considered, but a 24-lane Diodes Incorporated PCIe Gen3 switch was found more suitable and was selected for the planned openPCIE Gen3 extension card (four Gen3 x4 downlinks, two Gen3 x4 OCuLink ports).

- --- openPCIE3 backplane ---
- cca 10W per slot70W total
- differential REFCLK_P/N
- 6-pin PCIE Power connector(3x12V, 3xGND)
- DC/DC Buck and LDOs for power distribution
- ...
- Reset Generator / - PowerOn reset (3V3) / - manual push-button / - distribution buffers
- PERST#
- 100MHz PCIE-class REFCLK Generator / - 25MHz oscillator / - PLL / - series-terminated / distribution buffers
- CLKREQ#
- Dec.22, 2025
- - x4 / 42P -
- RC1
- 4-lane
- SWitch / PCIE3.1 / 24-lane / 12-port
- 4 x 4-lane
- 4-lane EPconnector / - Slot
- 4-lane EPconnector / - M.2 (PCIE)
- SW_EP0
- SW_EP1
- SW_EP2
- SW_EP3
- RC2
- OCuLink SFF-8612 (female/board side) / - x8 / 80Pin -

## openPCIE3-Diodes

- --- openPCIE3 backplane ---
- Feb.27, 2026
- - x4 / 42P -
- PC1-EPEP pinout / Oculink provides REFCLK and RESET
- 4-lane
- SWitch / PCIE3.1 / 24-lane / 12-port
- 4 x 4-lane
- 4-lane EPconnector / - Slot
- 4-lane EPconnector / - M.2 (PCIE)
- SW_EP0
- SW_EP1
- SW_EP2
- SW_EP3
- PC2-EPEP pinout / Oculink provides REFCLK and RESET
- OCuLink SFF-8612 (female/board side) / - x8 / 80Pin -
- PI7C9X3G / 1224GPB
- cca 10W per slot70W total
- 6-pin PCIE Power connector(3x12V, 3xGND)
- DC/DC Buck and LDOs for power distribution
- ...
