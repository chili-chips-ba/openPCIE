## Design Outline
**WIP:**
@AnesVrce to elaborate

<p align="center" width="100%">
    <img width="50%" src="0.doc/openPCIE-BlockDiagram.jpg">
</p>

Designed with **KiCad 9.0.5**, from schematic entry to layout. For the full schematic PDF, click [here](openpci2-backplane/openpci2-backplane.pdf).

## Use-case-1: Direct FPGA_RC to FPGA_EP (Gen1, x1)
@AnesVrce to add illustration.

This scenario is the bread-and-butter, the meat of this project. That's what it is about. We intend to test our Artix-7 RootComplex in both "Slot" and M.2 form-factors. The backplane design leaves the path open for future exploration of **x4** and **Gen2** implementations and scenarios.

This same scenario is also envisioned for testing the interoperability of our [openCologne-PCIE](https://github.com/chili-chips-ba/openCologne-PCIE) EndPoint with Xilinx Artix-7 RootComplex.

## Use-case-2: Switched FPGA_RC to FPGA_EP (Gen1, x1)
@AnesVrce to add illustration. 

We intend to try testing the Root Complex interactions with End-Points through a PCIE Switch. This is "best effort", i.e. a  bonus if we manage to make it work. The backplane also leaves the path open for **Gen2** testing.

## Use-case-3: Switched RPi5_RC to FPGA_EP (Gen1, x1)
This scenario is for our [openCologne-PCIE](https://github.com/chili-chips-ba/openCologne-PCIE) EndPoint design, to test its interoperability with RPi5. The backplane design allows trying both "Slot" and M.2 form-factor of GateMate PCIE cards.

<p align="center" width="100%">
    <img width="50%" src="0.doc/images/PCIE-synergy-with-RPI5.png">
</p>

Our backplane is designed for RPi5 Standard FPC cable, which is with contacts on the **opposite sides**.
<p align="center" width="100%">
    <img width="50%" src="0.doc/images/RPI5-PCIE-FFC.jpg">
</p>

Such cable is also known as **"B Type"**, see [this](https://www.amazon.com/iUniker-Contacts-Opposite-Raspberry-Peripheral/dp/B0F7HJL2QG/ref=pd_ci_mcx_di_int_sccai_cn_d_sccl_2_2/143-7699313-0639204?pd_rd_w=UVwz6&content-id=amzn1.sym.751acc83-5c05-42d0-a15e-303622651e1e&pf_rd_p=751acc83-5c05-42d0-a15e-303622651e1e&pf_rd_r=SSMC3DSGA2A09FFQH4YH&pd_rd_wg=RZodX&pd_rd_r=fb584b31-62bd-44e0-af8e-5133406dd983&pd_rd_i=B0F7HJL2QG&psc=1). Interestingly, many RPi5 HATs use the same-side contact, that is "A Type" cable, despite RaspberryPi explicit requirement not to do so. It is imperative to ensure you are using the correct orientation FPC before connecting up and powering up the system. [Here](https://www.jeffgeerling.com/blog/2023/testing-pcie-on-raspberry-pi-5) is another interesting read on the RPi5 PCIE connectivity.

## Use-case-4: PCIE Expansion or Extension
By using our _"PCIE Jumper Cable"_, the backplane can be connected to a standard PC serving as a Root Complex, such as for the expansion of its I/O Slot capacity, or for the extension of its physical reach. We also intend to use it for [openCologne-PCIE](https://github.com/chili-chips-ba/openCologne-PCIE) EndPoint validation, specificaly to assess and compare the strength of GateMate SerDes to others, specifically Xilinx Artix-7 and off-the-shelf ASICs.

<p align="center" width="100%">
    <img width="60%" src="0.doc/images/PCIE-Jumper-Cable-Male2Male.jpg">
</p>

## PCIE Layout Consideration

The characteristic impedance of the differential pairs on our backplane is **100ohm+/-10% for both data and clock signals**. They are all routed as **microstrips**, i.e. with reference to ground or power plane from only one side and no more than **5 mils** P-to-N skew, and with minimal number of vias on the path. 

<p align="center" width="100%">
    <img width="50%" src="PCIE-Trace-Impedance.jpg">
</p>

We don't use the "striplines", which is when high-speed traces are sandwiched between ground or power planes, as that requires more layers and necessitates the use of vias. Our stackup is 4-layer:
- Microstrip (Top)
- GND (L2)
- 3V3 (L3)
- Microstrip (Bottom)

The backplane does not use blind, burried or partial vias. Via size is 0.3mm. Please, see [this](0.doc/PCIE-Layout-Guidelined.TI-slaae45.pdf) for more routing guidelines.

## Signal Integrity (SI) Sims
@prasimix @AnesVrce TODO.

The following four wiring topologies are to be examined in simulations:
> 1) **one-to-one** (point-to-point) 100MHz clock diff pair
> 2) **two-to-two** 5Gbps PCIE diff pair (one of the RC4=>EP4 pairs)
> 3) **three-to-one** 5Gbps PCIE diff pairs (RC1 => SW)
> 4) **one-to-two** 5Gbps PCEI diff pairs (SW => the logest SW_EP0/1/2/3)
   
## SI Test Results
TODO

-----

### References:
**[1] [PCIE Card Electro-Mechanical Specification, Rev4.0](0.doc/PCIE-card-ElectroMech-Spec.Rev4-0.pdf)**

**[2] RPi5 PCIE Connector Enigma**
- [Reverse Engineering RPi5 PCIE](https://github.com/m1geo/Pi5_PCIe)
- [4-port PCIE/Gen3 Hub for RPi5. Based on ASM2806. FPC must be rotated](https://github.com/will127534/PCIe3_Hub)

**[3] PCIE Extenders**
- [PCIE "Slot" to 4-port "Slot" with ASM1184e, by Waveshare](https://www.waveshare.com/pcie-packet-switch-4p.htm)
- [RPi5 PCIe FPC to "Slot", by 52Pi](https://52pi.com/collections/all-products/products/p02-pcie-slot-for-rpi5)
- [RPi5 4-port FPC HAT with ASM1184e, by 52Pi](https://wiki.52pi.com/index.php?title=EP-0233)
- [RPi5 4-port FPC HAT with ASM1184e, by Waveshare](https://www.waveshare.com/pcie-to-4-ch-pcie-hat.htm)

**[4] ASMedia ASM1184e 1-to-4 single-lane PCIE/Gen2 Switch**
- [Product Brief](https://www.asmedia.com.tw/product/556yQ9dSX7gP9Tuf/b7FyQBCxz2URbzg0)
- [Technical Notes](https://crimier.github.io/posts/ASM118x)
- [Design Example: CM4 M2 (NVME) NAS](https://github.com/will127534/CM4-Nvme-NAS)

**[5] [Component datasheets](1.datasheets)**

**[6] [PCB Layout Guidelines](0.doc/PCIE-Layout-Guidelined.TI-slaae45.pdf)**

**[7] Open-source SI Sim tools**
- [openEMS](https://docs.openems.de)
- [AntMicro EMS Sim](https://antmicro.com/blog/2025/07/recent-improvements-to-antmicros-signal-integrity-simulation-flow)

-------
#### End of Document
