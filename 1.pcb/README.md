## Design Outline
***WIP:** @AnesVrce to elaborate

<p align="center" width="100%">
    <img width="50%" src="0.doc/openPCIE-BlockDiagram.jpg">
</p>

Designed with **KiCad 9.0.5**, from schematic entry to layout. For the full schematic PDF, click [here](openpci2-backplane/openpci2-backplane.pdf).

## Signal Integrity (SI) Sims
@prasimix @AnesVrce TODO

## SI Test Results

TODO

-----
### References:
**[1] ASMedia ASM1184e 1-to-4 single-lane PCIE/Gen2 Switch**
- [Product Brief](https://www.asmedia.com.tw/product/556yQ9dSX7gP9Tuf/b7FyQBCxz2URbzg0)
- [Technical Notes](https://crimier.github.io/posts/ASM118x)
- [Design Example: CM4 M2 (NVME) NAS](https://github.com/will127534/CM4-Nvme-NAS)

**[2] RPi5 PCIE Connector Enigma**
- [Reverse Engineering RPi5 PCIE](https://github.com/m1geo/Pi5_PCIe)
- [4-port PCIE/Gen3 Hub for RPi5. Based on ASM2806. FPC must be rotated](https://github.com/will127534/PCIe3_Hub)

**[3] PCIE Extenders**
- [PCIE "Slot" to 4-port "Slot" with ASM1184e, by Waveshare](https://www.waveshare.com/pcie-packet-switch-4p.htm)
- [RPi5 PCIe FPC to "Slot", by 52Pi](https://52pi.com/collections/all-products/products/p02-pcie-slot-for-rpi5)
- [RPi5 4-port FPC HAT with ASM1184e, by 52Pi](https://wiki.52pi.com/index.php?title=EP-0233)
- [RPi5 4-port FPC HAT with ASM1184e, by Waveshare](https://www.waveshare.com/pcie-to-4-ch-pcie-hat.htm)

**[4] Component datasheets**
- Click [here](1.datasheets)
  
**[5] open-source SI Sim tools**
- [openEMS](https://docs.openems.de)
- [AntMicro EMS Sim](https://antmicro.com/blog/2025/07/recent-improvements-to-antmicros-signal-integrity-simulation-flow)


-------
#### End of Document
