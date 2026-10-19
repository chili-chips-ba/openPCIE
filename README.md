[![NLnet:Funded](https://badgen.net/badge/NLnet/Funded/08C)](https://nlnet.nl/)
[![Stars](https://badgen.net/github/stars/chili-chips-ba/openPCIE?label=Stars)](https://github.com/chili-chips-ba/openPCIE/stargazers)
[![License:BSD-3/CC-BY-SA](https://badgen.net/badge/License/BSD-3%2FCC-BY-SA/blue)](LICENSES)
[![KiBot:Pass](https://badgen.net/badge/KiBot/Pass/green)](1.pcb/openpci2-backplane/openpci2-backplane.kibot.yaml)
[![eduBOS5:Pass](https://badgen.net/badge/eduBOS5/Pass/green)](2.rtl/0.common.opensource/src/CPU.eduBOS5/README.md#riscv-formal-every-instruction-against-the-isa)
[![Lint](https://badgen.net/github/checks/chili-chips-ba/openPCIE/main/run-lint?label=Lint)](https://github.com/chili-chips-ba/openPCIE/actions/workflows/lint.yml)
[![Verible](https://badgen.net/github/checks/chili-chips-ba/openPCIE/main/verible?label=Verible)](https://github.com/chili-chips-ba/openPCIE/actions/workflows/verible.yml)
[![Sim:Pass](https://badgen.net/badge/Sim/Pass/green)](5.sim)
[![openXC7:Pass](https://badgen.net/badge/openXC7/Pass/green)](4.build/hw_build.openXC7)
[![PCIE:Pass](https://badgen.net/badge/PCIE/Pass/green)](https://github.com/chili-chips-ba/openPCIE#bench-validation-results)

Computing is about communicating. Some would also say about networking. Digital independence tags along on the wave of _"Recommendations and Roadmap for European Sovereignty in open source HW, SW and RISC-V Technologies (2021)"_, calling for the development of critical open source IP blocks, such as **`PCIE Root Complex (RC)`**. This is the first step in that direction. And, if you are looking for an opensource, soft PCIE EndPoint (EP) core, please check our [other](https://github.com/chili-chips-ba/openCologne-PCIE) repo.


<p align="center" width="100%">
  <img alt="openPCIE Root Complex project logo" width="25%" src="0.doc/artwork/pcie2rootc.hex.png">
</p>

This project opens Artix7 PCIE Gen2 RC IP blocks for use outside of proprietary tool flows. While still reliant on Xilinx Series7 Hard Macros (HMs), it surrounds them with open-source soft logic for PIO accesses — The **`RTL`** and, even more importantly, the layered **`software Driver with Demo App`**. 

All that with **`full HW/SW opensource co-sim`**. Augmented with a rock-solid **`openBackplane`** in the basement of our hardware solution, the geek community thus gets all it takes for building their own, end-to-end _openCompute_ systems.

> The project‘s immediate goal, now accomplished, was to empower the makers with ability to drive PCIE-based peripherals from their own soft RISC-V SOCs.

Given that the PCIE End-Point (EP) with DMA is already available in opensource, the opensource PCIE peripherals do exist for Artix7. Except that they are always, without exception, controlled by the proprietary RC on the motherboard side, typically in the form of RaspberryPi ASIC, or x86 PC. This project changes that status quo.

Our long-term goal is to set the stage for the development of full opensource PCIE stack, gradually phasing out Xilinx HMs from the solution. That’s a long, ambitious track, esp. when it comes to mixed-signal SerDes and high-quality PLLs. We therefore anticipate a series of follow on projects that would build on the foundations hereby set.

This first phase implemented an open source PCIE Root Complex (RC) for Artix7 FPGA, utilizing Xilinx Series7 PCIE HM and GTP IP blocks, along with their low-jitter PLL.

#### References
- [PCIE Primer](http://www.anita-simulators.org.uk/wyvernsemi/articles/pci_express.pdf) by Simon Southwell ✔

--------------------

# HW Architecture

The project relies on a modular hardware ecosystem that combines our custom-designed openPCIE Backplane with SQRL Acorn CLE-215+ FPGA modules and various PCIE adapters to create a flexible testing platform.

<p align="center">
 <img alt="openPCIE hardware ecosystem" src="0.doc/pictures/openPCIE-hardware-ecosystem.jpg" width="60%">
</p>

--------------------
### openBackplane PCB

<p align="center" width="100%">
    <a href="https://www.canva.com/design/DAHXSTcjxEc/odZj_VbgU20EEeZ1zuJlJA/watch?utm_content=DAHXSTcjxEc&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=h8306e0024f" target="_blank" rel="noopener"><img alt="openPCIE backplane intro video (click to watch)" width="50%" src="0.doc/artwork/openPCIE-backplane.png"></a>
    <img alt="openPCIE backplane block diagram" width="50%" src="1.pcb/0.doc/openPCIE-BlockDiagram.jpg">
</p>

Please, refer to [1.pcb](1.pcb) for additional detail, and to [1.pcb/KiCad-library](1.pcb/KiCad-library/README.md) for the self-contained KiCad library. Plain-text versions of the PDF and slide documents are in [0.doc/1.pcb](0.doc/1.pcb/README.md).

### FPGA Carrier

The hardware platform for this project is the **SQRL Acorn CLE-215+**, a versatile FPGA development board. Although originally designed as a crypto-accelerator, its powerful Artix-7 FPGA and modular design make it an excellent choice for general-purpose PCIE development.

The system consists of two main components:

*  **M.2 FPGA Module (Acorn CLE-215+):** This is the core of the system, a compact board in an M.2 form factor. It houses the **Xilinx Artix-7 XC7A200T FPGA** and is designed to be plugged into a standard M.2 M-key slot.

<table align="center" style="border: none; border-collapse: collapse;">
  <tr style="border: none;">
    <td align="center" style="border: none;">
      <img alt="M.2 FPGA module, top view" src="0.doc/pictures/M.2 FPGA Module (Top View).png" width="60%">
    </td>
    <td align="center" style="border: none;">
      <img alt="M.2 FPGA module, bottom view" src="0.doc/pictures/M.2 FPGA Module (Bottom View).png" width="60%">
    </td>
  </tr>
  <tr style="border: none;">
    <td align="center" style="border: none;"><b>M.2 FPGA Module (Top View)</b></td>
    <td align="center" style="border: none;"><b>M.2 FPGA Module (Bottom View)</b></td>
  </tr>
</table>

*  **PCIE Adapter Board (Acorn Baseboard Mini):** A carrier board that holds the M.2 FPGA module. Its primary function is to adapt the M.2 interface to a standard **PCIE x4 edge connector**, allowing the entire assembly to be installed and tested in a regular PC motherboard slot.

<table align="center" style="border: none; border-collapse: collapse;">
  <tr style="border: none;">
    <td align="center" style="border: none;">
      <img alt="PCIE adapter board, top view" src= "0.doc/pictures/PCIe Adapter Board (Top View).png" width="60%">
    </td>
    <td align="center" style="border: none;">
      <img alt="PCIE adapter board, bottom view" src="0.doc/pictures/PCIe Adapter Board (Bottom View).png" width="60%">
    </td>
  </tr>
  <tr style="border: none;">
    <td align="center" style="border: none;"><b>PCIE Adapter Board (Top View)</b></td>
    <td align="center" style="border: none;"><b>PCIE Adapter Board (Bottom View)</b></td>
  </tr>
</table>


<p align="center">
  <img alt="Fully assembled Acorn CLE-215+" src="0.doc/pictures/The fully assembled Acorn CLE-215+.png" width="60%">
  <br>
  <b>The fully assembled Acorn CLE-215+ development board, ready for use in a PCIE slot.</b>
</p>

It is important to note that the Acorn CLE-215+ is functionally identical to the more widely known NiteFury board, with the primary difference being the amount of onboard memory. The Acorn model features 1 GB of DDR3 RAM, while the standard NiteFury has 512 MB. Therefore, the [NiteFury schematic](https://github.com/chili-chips-ba/openPCIE/blob/main/0.doc/Reference-SCH/Schematic.FPGA-NiteFury.pdf) serves as a direct and accurate reference for the board's hardware layout.

The central component of the SQRL Acorn CLE-215+ system is the **Xilinx Artix-7 XC7A200T-FBG484** chip. This FPGA is crucial for implementing the PCIE Root Complex - and, on the other card, the Endpoint - possessing a range of features that make it highly suitable for this purpose.

The key specifications are summarized below:

<div align="center">
<table>
<thead>
<tr>
<th>Specification</th>
<th>Value</th>
</tr>
</thead>
<tbody>
<tr>
<td>Family</td>
<td>Xilinx Artix-7</td>
</tr>
<tr>
<td>Speed Grade</td>
<td>-3</td>
</tr>
<tr>
<td>Logic Cells (LUT4-Equivalent)¹</td>
<td>215,360</td>
</tr>
<tr>
<td>LUT6</td>
<td>134,600</td>
</tr>
<tr>
<td>Flip-Flops</td>
<td>269,200</td>
</tr>
<tr>
<td>Block RAM</td>
<td>13 Mbit</td>
</tr>
<tr>
<td>DSP Slices</td>
<td>740</td>
</tr>
<tr>
<td>GTP Transceivers</td>
<td>4 (up to 6.6 Gbit/s)</td>
</tr>
<tr>
<td>DDR3 SDRAM (Board)</td>
<td>1 GB, 16-bit</td>
</tr>
<tr>
<td>QSPI Flash (Board)</td>
<td>32 MB</td>
</tr>
<tr>
<td>User LEDs</td>
<td>4</td>
</tr>
<tr>
<td>General Purpose IOs</td>
<td>4</td>
</tr>
<tr>
<td>LVDS Pairs</td>
<td>4</td>
</tr>
</tbody>
</table>
<p><small>¹ The 'Logic Cells' count is a Xilinx metric derived from the physical 6-input LUTs to provide an estimated equivalent in simpler 4-input LUTs for comparison purposes. The number of physical LUTs and other resources are the exact counts for the XC7A200T chip.</small></p>
</div>

#### References:
- [Acorn-CLE215+ QuickStart](https://github.com/SMB784/SQRL_quickstart)
- [NiteFury](https://github.com/RHSResearchLLC/NiteFury-and-LiteFury/tree/master)
- [fpgas.online-test-designs](https://github.com/fpgas-online/fpgas.online-test-designs/tree/main/designs/pcie-enumeration) PCIE ENUMERATION by RPI, for Acorn-CLE215+ EP
  
--------------------

# RTL Architecture

The opensource Root Complex RTL is a chain of blocks joined by SystemVerilog interfaces: the RISC-V SoC hands TLPs over AXI-Stream to the PCIE stack, which converts them for the `PCIE_2_1` hard block and drives the GTP transceiver over PIPE.

<p align="center">
 <img alt="RTL blocks of the opensource Root Complex and the SystemVerilog interfaces between them" src="0.doc/2.rtl/block-diagram.drawio.png" width="100%">
</p>

Details are in the [RTL README](2.rtl/README.md#systemverilog-interfaces). Per design: [common RTL](2.rtl/0.common.opensource/README.md), [EP](2.rtl/1.EP.opensource/README.md), [RC-direct](2.rtl/2.RC-direct.opensource/README.md), [RC-switched](2.rtl/3.Bonus--RC-switched.opensource/README.md). The AMD/Vivado-IP reference designs are in [2.amd-rtl-with-Vivado-build](2.amd-rtl-with-Vivado-build/README.md) ([EP](2.amd-rtl-with-Vivado-build/1.EP.amd/README.md), [RC-direct](2.amd-rtl-with-Vivado-build/2.RC-direct.amd/README.md), [RC-switched](2.amd-rtl-with-Vivado-build/3.Bonus--RC-switched.amd/README.md)).

#### References:
- [Basic PCIE EP for LiteFury](https://github.com/hdlguy/litefury_pcie)
- [Regymm PCIE](https://github.com/regymm/pcie_7x)
- [LiteX PCIE EP](https://github.com/enjoy-digital/litepcie)
- [PCIE EP DMA - Wupper](https://gitlab.nikhef.nl/franss/wupper)
- [Xilinx UG477 - 7Series Integrated Block PCIe](https://docs.xilinx.com/v/u/en-US/ug477_7Series_IntBlock_PCIe)
- [Xilinx DS821 - 7series_PCIE Datasheet](https://docs.xilinx.com/v/u/en-US/ds821_7series_pcie)
- [Xapp1052 - BusMaster DMA for EP](https://docs.xilinx.com/v/u/en-US/xapp1052)
  
--------------------

# SW Architecture

The software stack is designed to run **bare-metal** on the soft RISC-V SoC embedded within the FPGA. In a standard PC, the Operating System (Linux/Windows) manages PCIE enumeration automatically in the background, hiding the complexity from the developer. In this project, our **baremetal open-source driver** takes full control, manually performing every step of the enumeration process to act as the PCIE Host.

<p align="center">
 <img alt="Firmware layers: application, PCIE driver, HAL, register map and startup, talking to the CSR block over the CPU memory bus, then through pcie_top to a direct endpoint or a switch with up to 4 endpoints" src="0.doc/3.sw/sw-structure.drawio.png" width="100%">
</p>

The architecture adopts a clean, well-defined, layered approach:

1.  **Application Layer (The "User" Logic)**: 
    - The final stage of the program that executes the high-level task.
    - It performs **Memory Write** operations to send a data payload to the Endpoint and uses **Memory Read** to verify the integrity of the data path.

2.  **PCIE Driver (Enumeration & Setup)**:
    - Responsible for the **initialization sequence** required to perform enumeration and establish a functional connection (link).
    - It manually performs device discovery, sizes the BARs by readback, assigns aligned memory addresses, checks the completion status of every request, and configures the **Command Register** to enable the device for communication.
      
3.  **HAL (Hardware Abstraction Layer)**:
    - Low-level helper functions that interact with the hardware by reading and writing data to **specific memory addresses**.

> **Note:** This structure allows developers to treat PCIE devices just like any other local peripheral, abstracting away the complexities of the physical link.

Details are in the [SW README](3.sw/README.md).

--------------------

# Simulation Architecture

### Sim Test Bench

The [openPCIE test bench](5.sim/README.md) aims to have a flexible approach to simulation which allows a common test environment to be used whilst selecting between alternative CPU components, one of which uses the [_VProc_ virtual processor](https://github.com/wyvernSemi/vproc) co-simulation element. This allows simulations to be fully HDL, with the RISC-V RTL core that goes into the bitstream (eduBOS5 by default, or PicoRV32), or to co-simulate software using the virtual processor, with a significant speed up in simulation times.

<p align="center">
<img alt="openPCIE Root Complex test bench structure" src="0.doc/5.sim/tb-structure.drawio.png" width="100%">
</p>

The test bench has the following features:

* A [_VProc_](https://github.com/wyvernSemi/vproc) virtual processor based [`soc_cpu.VPROC.picorv32`](5.sim/models/README.md#soc_cpuvprocpicorv32) component
  * [Selectable](5.sim/README.md#the-three-cpu-options) between this or the RTL core (eduBOS5 by default, or PicoRV32), with `make CPU=rtl|vproc|iss`
  * Can run natively compiled test code
  * Can run the application compiled natively with the [auto-generated co-sim HAL](4.build/README.md#csr-hal-compilation)
  * Can run RISC-V compiled code using the [rv32 RISC-V ISS model](5.sim/models/rv32/README.md)
  * All three have been [built and measured](5.sim/README.md#what-they-cost); each reaches the same result over the same PCIE link
* The [_pcieVHost VIP_](https://github.com/wyvernSemi/pcievhost) is used to drive the logic's PCIE link
* Uses a C [sparse memory model](https://github.com/wyvernSemi/mem_model)
  * An [HDL component](5.sim/models/cosim/README.md) instantiated in logic gives logic access to this memory
  * An API is provided to _VProc_ running code for direct access from the _pcieVHost_ software, which implements this sparse memory C model.

More details on the architecture and usage of the openPCIE test bench can be found in the [README.md](5.sim/README.md) in the `5.sim` directory.

The co-simulation can also be followed at TLP level in the [WaveCrux](https://wavecrux.app) waveform viewer, with an [open-source PCIE TLP decoder plugin](5.sim/tools/wavecrux-pcie-tlp/README.md) and a ready-made session -- here the firmware sizing BAR0 by readback and placing it at `0x80000000` ([more](5.sim/README.md#viewing-the-tlps-in-wavecrux)):

<p align="center">
<img alt="WaveCrux TLP view: firmware sizing BAR0" src="5.sim/images/wavecrux-tlp-bar-sizing.png" width="75%">
</p>

One level down, Ferrite's [PCIe PIPE and Data Link Layer decoders](https://github.com/Ferrite-Engineering/wavecrux-decoders) show the same link on the wire: link training, flow-control credits, and every TLP with its sequence number and Ack ([more](5.sim/README.md#viewing-the-pipe-in-wavecrux)). With all three layers in one view, you can also see how long a TLP spends inside the hard macro: about 0.4 µs each way ([more](5.sim/README.md#how-long-a-tlp-spends-in-the-hard-macro)).

### Co-sim HAL

The openPCIE control and status register hardware abstraction layer (HAL) software is [auto-generated](4.build/README.md#csr-hal-compilation), as is the CSR RTL, using [`peakrdl`](https://peakrdl-cheader.readthedocs.io/en/latest/). A single SystemRDL specification, [`4.build/csr_build/csr.rdl`](4.build/csr_build/csr.rdl), describes the TLP transmit/receive window the RISC-V firmware drives, and everything else is derived from it: the register block RTL (`csr.sv`, `csr_pkg.sv`), which [`soc_csr.sv`](2.rtl/0.common.opensource/src/soc_csr.sv) bridges to the picorv32 memory bus, and the software header. For co-simulation purposes an additional layer is auto-generated from the same SystemRDL specification using [`systemrdl-compiler`](https://systemrdl-compiler.readthedocs.io/en/stable/) that accompanies the `peakrdl` tools. This produces two header files that define a common API to the application layer for both the RISC-V platform and the *VProc* based co-simulation verification environment. The details of the HAL generation can be found in the [README.md](./4.build/README.md#csr-hal-compilation) in the `4.build/` directory.

More details of the test bench, the _pcievhost_ component and its usage can be found in the [5.sim/README.md](5.sim/README.md) file. See also the [pcievhost model](5.sim/models/pcievhost/README.md), its [LTSSM support code](5.sim/models/pcievhost/ltssm/README.md), and the superseded [DUT stubs](5.sim/stubs/README.md).
  
#### References
- [pcieVHost](https://github.com/wyvernSemi/pcievhost/blob/master/doc/pcieVHost.pdf)
- [WaveCrux](https://wavecrux.app) waveform viewer, [decoder plugin interface](https://github.com/Ferrite-Engineering/wavecrux/blob/main/include/wavecrux_decoder.h)
- [wavecrux-decoders](https://github.com/Ferrite-Engineering/wavecrux-decoders): Ferrite's open-source PCIE PIPE and Data Link Layer decoders for WaveCrux

--------------------

# Implementation Workflow

The openPCIE implementation workflow is organized into several stages, covering the complete process from setting up the development environment to verifying the design on physical hardware.

<p align="center">
 <img alt="Build flow: CSR generation, firmware, bitstream through Vivado or openXC7, co-simulation, lint and formal equivalence" src="0.doc/4.build/build-flow.drawio.png" width="100%">
</p>

## Prerequisites

Before building the project, install and configure the required development tools. These include an FPGA toolchain such as **AMD Vivado** or **openXC7**, a bare-metal **RISC-V cross-compilation toolchain**, Python, and the project-specific dependencies listed in the corresponding directories.

### HW/SW Co-Sim

Before deploying the design to physical hardware, run the available simulation environment to verify the interaction between the PCIE hardware design and the software components.

The co-simulation flow is used to test essential operations such as device initialization, register access, PCIE link behavior, and data exchange between the Root Complex (RC) and Endpoint (EP). This stage helps identify hardware and software integration issues before synthesis and hardware deployment.

### SW Build

Compile the bare-metal RISC-V driver and test application using the configured cross-compilation toolchain, see [4.build/sw_build](4.build/sw_build/README.md).

The software is responsible for initializing the required hardware components, configuring the PCIE communication flow, and transferring test payloads between the RC and EP. The generated executable can be used during simulation or deployed together with the FPGA design for hardware verification.

### HW Synth and Bitstream Generation

The FPGA design can be synthesized and implemented using either the commercial **AMD Vivado** toolchain or the open-source **openXC7** toolchain. Depending on the selected flow, the process includes design elaboration, synthesis, placement, routing, timing analysis, and final bitstream generation.

The resulting `.bit` file contains the complete hardware configuration for the selected FPGA board. The appropriate board-specific constraints, build configuration, and target design must be selected depending on whether the board operates as the Root Complex (RC) or Endpoint (EP).

Detailed build instructions for both the Vivado and openXC7 flows are provided in the corresponding project directories.

### Flashing and Deployment

Program the RC and EP FPGA boards with their corresponding bitstreams. After both designs have been loaded, start the software application and allow the boards to initialize the PCIE connection.

The deployed system can then be verified by checking the PCIE link-status indicators and comparing the transmitted payload with the data displayed or received on the Endpoint.

Detailed commands, configuration options, supported boards, and stage-specific instructions are provided in the corresponding project directories.

---
<a name="functional-verification"></a>

# Bringup, Debug, Bench Testing and Demo

### FPGA Board Setup

Properly programming and operating the Artix-7 FPGA on the SQRL board requires some soldering and work on open desktop motherboard.

#### 1. Custom JTAG Cable

The JTAG connector on the Acorn CLE-215+ is non-standard and not directly compatible with the standard 14-pin connector on the Xilinx Platform Cable. A custom adapter cable is therefore required.

<table align="center" style="border: none; border-collapse: collapse; width="60%">
  <tr style="border: none;">
    <td align="center" style="border: none;" width="60%">
      <img alt="FPGA JTAG connection" src="0.doc/pictures/FPGA-JTAG.jpg" width="60%">
    </td>
    <td align="center" style="border: none;" width="30%">
      <img alt="JTAG connector pinout on the board" src="0.doc/pictures/JTAG Connector Pinout on the Board.png" width="50%">
    </td>
  </tr>
  <tr style="border: none;">
    <td align="center" style="border: none;"><b>Custom JTAG Cable connecting the Xilinx Programmer to the board</b></td>
    <td align="center" style="border: none;"><b>JTAG Connector Pinout on the Board</b></td>
  </tr>
</table>

The connector on the board is a **Molex Pico-Lock 1.50mm pitch male header**. This is not a standard 2.54mm or 2.00mm header, so standard DuPont-style cables will not fit.

To simplify making the cable, we highly recommend purchasing a pre-assembled cable with the correct female connector.

*   **Recommended Part:** **[Molex 0369200603 on Digi-Key](https://www.digikey.com/en/products/detail/molex/0369200603/10233020)**

This cable has the correct female connector on both ends. The easiest method is to **cut the cable in half**, which gives you two connector cables with open ends. You can then splice one of these cable ends onto the wires of your Xilinx programmer cable, matching the signals according to the following wiring diagram.

<p align="center">
  <img alt="Acorn JTAG wiring diagram" src="0.doc/pictures/acorn-jtag-wiring-diagram.PNG" width="60%">
  <br><em>JTAG Connection Guide: Physical Pinout and Wiring Diagram.</em>
</p>

#### 2. External 12V Power Supply

The board cannot be programmed or operated solely from the PCIE/M.2 slot power. It requires an external 12V supply to function correctly, especially when complex designs and high-speed transceivers are active. Power is provided via a standard 6-pin PCIE power connector from an ATX power supply.

<p align="center">
  <img alt="External 12 V power connection" src="0.doc/pictures/External 12V power connection.jpg" width="40%">
  <br><em>External 12V power connection.</em>
</p>

#### 3. Final Assembly

The complete system, including the custom cabling, is mounted in a test PC chassis for verification.

<p align="center">
  <img alt="Complete FPGA system mounted in a PCIE slot" src="0.doc/pictures/The complete FPGA system mounted in a PCIe slot.jpg" width="50%">
  <br><em>The complete FPGA system mounted in a PCIE slot.</em>
</p>

#### 4. JTAG Connectivity Test

After the hardware was prepared, the connection was verified using the **Vivado Hardware Manager**. As shown below, the tool successfully detected the JTAG programmer and identified the `xc7a200t_0` FPGA chip. This confirms that the physical connections are correct and the board is ready for programming.

<p align="center">
  <img alt="Successful device detection in Vivado Hardware Manager" src="0.doc/pictures/Successful device detection in Vivado Hardware Manager.png" width="50%">
  <br><em>Successful device detection in Vivado Hardware Manager.</em>
</p>

### Test Jig
- **PCB:** **openPCIE Backplane** (see [1.pcb](1.pcb/))  which provides slots for the RC, EP, and the Switch.
- **FPGA Boards:** Two **SQRL Acorn CLE-215+** (Artix-7) boards.
- **JTAG Programmers:** Two **Xilinx Platform Cable USB** units are used, each equipped with a **custom adapter cable**.

Before interacting over PCIE, here is the complete bench validation setup used for the Direct (Point-to-Point) connection scenario. It features the **openPCIE Backplane** powered by an external 12V supply, populated with two **Acorn CLE-215+** FPGA modules (one configured as RC, the other as EP).

Dual **Xilinx Platform Cable USB** units are connected via custom adapters to allow simultaneous debugging and bitstream loading from two separate host workstations.

<p align="center">
  <img alt="Validation environment for the direct connection" src="0.doc/pictures/openPCIE-direct-connection-validation-environment.jpg" width="60%">
  <br>
  <em>The complete hardware validation environment for the Direct connection test.</em>
</p>

#### The "Dual-PC" JTAG Approach 
We used a two-PC setup to streamline development:
-  **PC 1:** Connected to the **Root Complex (RC)** FPGA via JTAG.
-  **PC 2:** Connected to the **EndPoint (EP)** FPGA via JTAG.
   
**Why this setup?**
- **Speed and Efficiency:** This setup avoids the repetitive task of manually swapping the JTAG cable between boards and eliminates the time-consuming process of flashing onboard memory for every test iteration.
- **Simultaneous Debugging:** This allows us to run two instances of **Vivado Hardware Manager** (ILA - Integrated Logic Analyzer) at the same time. We can trigger on the RC and EP simultaneously to view the transaction from both sides of the link.
  
### Test Procedure

To bring up the system and verify the PCIE link, follow these steps:

*   **Hardware Assembly:** Insert the FPGA cards into their designated slots on the **openPCIE Backplane** (RC and EP) and connect the external **12V power supply**.
*   **Bitstream Programming:** Program both FPGAs using Vivado Hardware Manager. **PC 1** is used to program the Root Complex, while **PC 2** programs the EndPoint.
*   **Manual Reset:** Once both devices are programmed, press the **manual reset button** on the backplane.
*   **Enumeration:** Upon releasing the reset button, the Root Complex initiates the **enumeration process** and establishes the link with the EndPoint.
*   **Re-Initialization:** Every subsequent press of the reset button triggers a full re-initialization of the PCIE connection, allowing for repeated testing and debugging without the need to re-program the FPGAs.

#### Objectives
The goal of this test is to verify that the Root Complex can successfully enumerate the link and perform both **Memory Write** and **Memory Read** transactions.
1. **Write:** The RC sends a data payload to the EP.
2. **Transfer:** The EP receives the TLP and writes it into its internal Block RAM (BRAM).
3. **Read:** The RC requests to read the data back from the EP memory.

### Bench Validation Steps

**1. Visual Verification (LEDs)**
Visual feedback is provided via the **4 user LEDs** on both FPGA boards:
- **RC Board:** The LEDs indicate the **Link Status**, confirming that the physical connection is established and the devices are ready to communicate.
- **EP Board:** The LEDs display the data received by the EP.

**2. Internal Signal Monitoring (ILA)**
Using the Vivado Integrated Logic Analyzer (ILA) on both PCs enables detailed monitoring of internal signals to see exactly what data was sent and received, its precise timing, and the low-level transaction details.

### Bench Validation Results

The implementation was verified on physical hardware by checking both PCIE link establishment and successful payload transfer between the Root Complex (RC) and Endpoint (EP).

On the RC board, LED **A3** indicates the PCIE link status. When this LED is illuminated, the PCIE link has been successfully established. We can see that the LED A3 is active, confirming that the link between the RC and EP is up.

On the EP board, the LEDs display the received data payload. The RC transmitted the decimal value **6**, represented in binary as **`0110`**. The LED pattern on the EP matches this value, confirming that the payload was transferred and received correctly.

These results confirm that PCIE link initialization and RC-to-EP data transfer operate successfully on physical hardware.

<table align="center" style="border: none; border-collapse: collapse;">
  <tr style="border: none;">
    <td align="center" style="border: none;">
       <img alt="LEDs showing link up" src="0.doc/pictures/led_link_up.jpg" width="60%">
    </td>
    <td align="center" style="border: none;">
       <img alt="LEDs showing the data payload" src="0.doc/pictures/led_data_payload.jpg" width="60%">
    </td>
  </tr>
  <tr style="border: none;">
    <td align="center" style="border: none;"><b>RC-LED-Link-Up</b></td>
    <td align="center" style="border: none;"><b>EP-LED-Data-Payload</b></td>
  </tr>
</table>

#### Primary References
- [PCIE Utils](https://mj.ucw.cz/sw/pciutils)
- [Debug PCIE issues using 'lspci' and 'setpci'](https://adaptivesupport.amd.com/s/article/1148199?language=en_US)
- Using [busybox (devmem)](0.doc/using-busybox-devmem-for-reg-access.txt) for register access 

#### Secondary References
PCIE Protocol Analyzers
- [PCIE Sniffing](https://ctf.re/pcie/experiment/linux/keysight/protocol-analyzer/2024/03/26/pcie-experiment-1)
- [Stark 75T Card](https://www.ebay.com/itm/396313189094?var=664969332633)
- [ngscopeclient](http://www.ngscopeclient.org/protocol-analysis)
- [PCI Leech](https://github.com/ufrisk/pcileech)
- [PCI Leech/ZDMA](https://github.com/ufrisk/pcileech-fpga/tree/master/ZDMA)
- [LiteX PCIE Screamer](https://github.com/enjoy-digital/pcie_screamer)
- [LiteX PCIE Analyzer](https://github.com/enjoy-digital/pcie_analyzer)
- [Wireshark PCIe Dissector](https://github.com/antmicro/wireshark-pcie-dissector)
- [PCIe Tool Hunt](https://scolton.blogspot.com/2023/05/pcie-deep-dive-part-1-tool-hunt.html)
- [PCIe network simulator](https://github.com/antmicro/warp-pipe)
- [An interesting PCIE tidbit: Peer-to-Peer communication](https://xilinx.github.io/XRT/2025.1/html/p2p.html). Also see [this](https://xillybus.com/tutorials/pci-express-tlp-pcie-primer-tutorial-guide-1)
- [NetTLP - An invasive method for intercepting PCIE TLPs](https://haeena.dev/nettlp)
- [PCIe on STM32MP257 with ngscopeclient](https://www.youtube.com/watch?v=qxdK3mjHNBM)
- [opensource PCIE Controller](https://www.mdpi.com/2076-3417/16/7/3409)

--------------------

# Project Status

#### `PART 1. Mini PCIE Backplane PCB`

Almost all consumer PCIE installations have the RC chip soldered down on the motherboard, typically embodied in the CPU or "North Bridge" ASIC, where PCIE connectors are used solely for the EP cards. Similarly, all FPGA boards on the market are designed for EP applications. As such, they expect clock, reset and a few other signals from the infrastructure. It is only the professional and military-grade electronics that may have both RC and EP functions on add-on cards, with a backplane or mid-plane connecting them (see VPX chassis, or VITA 46.4).

This dev activity is about creating the minimal PCIE infrastructure necessary for using a plethora of ready-made FPGA EP cards as a Root Complex. This infrastructure takes the physical form of a mini backplane that provides the necessary PCIE context similarly to what a typical motherboard would give, but without a soldered-down RC chip that would be conflicting with our own FPGA RC node.

Such approach is less work and less risk than to design our own PCIE motherboard, with a large FPGA on it. But, it is also a task that we did not appreciate from the get-go. In a bit of a surprise, half-way through planning, we've realized that a suitable, ready-made backplane was not available on the market. This initial disappointment then turned into excitement knowing that this new outcome would make the project even more attractive / more valuable for the community... esp. when **[Envox.eu](https://www.envox.eu)** has agreed to step in and help. They will take on the PCIE backplane PCB development activity.

 - ✅ Create requirements document.
 - ✅ Select components. Schematic and PCB layout design.
 - ✅ Review and iterate design to ensure robust operation at 5 GT/s (PCIE Gen2), using openEMS for simulation of high-speed traces.
 - ✅ Manufacture prototype. Debug and bringup, using AMD-proprietary on-chip IBERT IP core to assess Signal Integrity.
 - ✅ Produce second batch that includes all improvements. Distribute it, and release design files with full documentation.

#### `PART 2. Project setup and preparatory activities`
 - ✅ Procure FPGA development boards and PCIE accessories.
 - ✅ Put together a prototype system. Bring it up using proprietary RTL IP, proprietary SW Driver, TestApp and Vivado toolchain.
 
#### `PART 3. Initial HW/SW implementation`
 - ✅ HW development of opensource RTL that mimics the functionality of PCIE RC proprietary solution.
 - ✅ SW development of opensource driver for the PCIE RC HW function. It runs bare-metal on the RISC-V SOC, without Linux - see [SW Architecture](#sw-architecture).
 - ✅ Design SOC based on RISC-V CPU with PCIE RC as its main peripheral.

#### `PART 4. HW/SW co-simulation using full PCIE EP model`

This dev activity is significantly beefed up compared to our original plan, which was to use a much simpler PCIE EP BFM, and non-SOC sim framework. While that would have reduced the time and effort spent on the sim, prompted by NLnet astute questions, we're happy to announce that **[wyvernSemi](https://github.com/wyvernSemi/pcievhost)** is now also onboard!

Their VProc can be used not only to faithfully model the RISC-V CPU and SW interactions with HW, but it also comes with an implementation of the PCIE model. The PCIE model has some EP capabilities with a configurable configuration space, which can be paired in sim with our RC RTL design. Moreover, the existence of both RC and EP models paves the way for future plug-and-play, pick-and-choose opensource sims of the entire PCIE subsystem.

With the full end-to-end simulation thus in place, we hope that the need for hardware debugging, using ChipScope, expensive test equipment and PCIE protocol analyzers would be alleviated.

 - ✅ Extension of the existing PCIE RC model for some additional configurability of the EP capabilities.
 - ✅ Testbench development and build up. Execution and debug of sim testcases.
 - ✅ Documentation of EP model, TB and sim environment, with objectives to make it all simple enough to pickup, adapt and deploy in other projects.
 
#### `PART 5. Integration, testing and iterative design refinements`
 - ✅ One-by-one replace proprietary design elements of the PART 2 prototype system with our opensource versions (except for Vivado and TestApp). Test it along the way, fixing problems as they occur.
 
#### `PART 6. Prepare Demo and port it to openXC7`

 - ✅ Develop our opensource PIO TestApp software and representative Demo.
 - ✅ Build design with _openXC7_, reporting issues and working with developers to fix them, possibly also trying _ScalePNR_ flow.

Given that PCIE is an advanced, high-speed design, in the light of _nextpnr-xilinx_ and openXC7 shortcomings when it comes to timing constraints and timing closure, we expect to run into showstoppers, and have therefore planned to experiment with WIP _ScalePNR_. In turned out that, with some corrections, the _nextpnr-xilinx_ was good enough -- The bitstream built with it brings the link up at **Gen2** speeds on hardware, the same as Vivado does. Getting there took six fixes - one latent bug in our RTL and five workarounds for openXC7 defects - all documented in [4.build/hw_build.openXC7](4.build/hw_build.openXC7/README.md), along with the issues we filed against openXC7.

The design has also been ported to, and tested with [_openXC7_ 1.0.0 edition](https://lnkd.in/p/gsDArjSt), which was a major step forward and essentially what _"ScalePNR"_ idea eventually evolved into. It brought to the forefront _Yosys0.69_ with integrated _**Slang**_, _**nextpnr-himbaechel**_ (instead of _nextpnr-xilinx_) and _**fpga-as**_. With that, the earlier SV2V standalone prep step for our SystemVerilog design sources proved to be unnecessary, which simplified the build process. The SV2V option is however still retained for cross-tool checking.

--------------------

### Academia Outreach
openPCIE has served as the basis for a number of Master's theses at the Faculty of Electrical Engineering, University of Sarajevo (ETF Sarajevo). Among them are the theses of Anes Vrce and [Aladin Brdar](https://www.linkedin.com/posts/abrdar1_proud-to-share-that-i-have-successfully-share-7512945056492904448-Ugtq/), the latter shown here presenting his work on the openPCIE platform, tapping into its hardware, software and simulation facets.

<p align="center">
 <img alt="Aladin Brdar presenting his work on the openPCIE platform at ETF Sarajevo" src="0.doc/pictures/Aladin-Brdar-Master-Thesis-Oct2026.png" width="80%">
</p>

--------------------

### Acknowledgements
We are grateful to **NLnet Foundation** for their sponsorship of this development activity.

<p align="center">
   <a href="https://nlnet.nl/project/openPCIe2-RootComplex"><img width="30%" alt="NLnet logo" src="0.doc/artwork/NLnet-logo.png"></a>
   <a href="https://nlnet.nl/core"><img width="15%" alt="NGI Zero, Next Gen Internet" src="0.doc/artwork/NGI0-logo.png"></a>
</p>

This project was funded through the NGI0 Core Fund, a fund established by NLnet with financial support from the European Commission's Next Generation Internet programme, under the aegis of DG Communications Networks, Content and Technology under grant agreement No 101092990.


The **wyvernSemi**'s wisdom and contribution made a great deal of difference -- Thank you, we are honored to have you on the project.

<p align="center">
 <a href="https://github.com/wyvernSemi"><img width="15%" alt="wyvernSemi-Logo" src="0.doc/artwork/wyvernSemi-logo-rounded.png"></a>
</p>

The **Envox**, our next-door buddy, is responsible for the birth of our backplane, which we like to call BB (not to be mistaken for their gorgeous blue beauty [BB3](https://www.envox.eu/eez-bb3))

<p align="center">
  <a href="https://www.envox.eu"><img alt="EEZ / Envox logo" width="25%" src="0.doc/artwork/EEZ-web-logo.png"></a>
</p>

<p align="center">
  <a href="https://github.com/chili-chips-ba/openCologne-PCIE"><img alt="openCologne-PCIE logo" width="15%" src="0.doc/artwork/openCologne-PCIE.hex.png"></a>
</p>

**KiCad** turns electrical idea into a manufacturable board. **openXC7**, with **Yosys** at its core, turns RTL into a loadable FPGA bitfile. **PeakRDL** turns our SystemRDL file into CSR RTL+headers+RegMap docs. **WaveCrux** greatly facilitates waveform decoding and viewing. But, that's not everything that made this project possible -- Thank you all for these wonderful opensource tools :sparkles:.

<p align="center">
  <a href="https://www.kicad.org"><img alt="KiCad logo" width="25%" src="0.doc/artwork/kicad_logo.png"></a>
  <a href="https://www.openems.de"><img alt="openEMS logo" width="15%" src="0.doc/artwork/openEMS.logo.short.noBG.png"></a>
</p>

<p align="center">
  <a href="https://github.com/openXC7"><img alt="openXC7 logo" width="80%" src="0.doc/artwork/openXC7.logo.png"></a>
  <a href="https://www.yosyshq.com"><img alt="YosysHQ logo" width="25%" src="0.doc/artwork/YosysHQ.logo.png"></a>
  <a href="https://peakrdl.readthedocs.io"><img alt="PeakRDL logo" width="14%" src="0.doc/artwork/PeakRDL.logo.png"></a>
  <a href="https://wavecrux.app"><img alt="WaveCrux logo" width="35%" src="0.doc/artwork/WaveCrux.logo.png"></a>
</p>

<p align="center">
  <a href="https://www.symbioticeda.com"><img alt="Symbiotic EDA logo" width="25%" src="0.doc/artwork/symbioticeda.logo.png"></a>
</p>   

<p align="center">
  <a href="https://verilator.org"><img alt="Verilator logo" width="25%" src="0.doc/artwork/Verilator.logo.png"></a>
  <a href="https://www.drawio.com"><img alt="draw.io logo" width="25%" src="0.doc/artwork/drawio.logo.png"></a>
  <a href="https://github.com/MikePopoloski/slang"><img alt="MikePopoloski slang logo" width="25%" src="0.doc/artwork/slang.logo.png"></a>
  <a href="https://www.chipsalliance.org/projects"><img alt="Chips Alliance SV Tools logo" width="15%" src="0.doc/artwork/ChipsAlliance-SV-Tools.logo.png"></a>
  <a href="https://github.com/chipsalliance/verible"><img alt="Verible logo" width="25%" src="0.doc/artwork/Verible.logo.png"></a>
  <a href="https://github.com/trabucayre/openFPGALoader"><img alt="openFPGALoader logo" width="20%" src="0.doc/artwork/openFPGAloader.logo.png"></a>
  <a href="https://github.com/tarik-ibrahimovic/eduBOS5"><img alt="eduBOS5 logo" width="17%" src="0.doc/artwork/eduBOS5.logo.png"></a>
  <a href="https://github.com/YosysHQ/picorv32"><img alt="PicoRV32 logo" width="20%" src="0.doc/artwork/picoRV32.logo.png"></a>
  <a href="https://riscv.org"><img alt="RISC-V logo" width="12%" src="0.doc/artwork/RISC-V-logo.svg"></a>
  <a href="https://www.cprover.org/ebmc/"><img alt="EBMC logo" width="20%" src="0.doc/artwork/EBMC.logo.png"></a>
</p>


### Crowd Supply Campaign
 - [Info Page](https://www.chili-chips.xyz/openpcie-backplane-put-your-fpga-in-control), [Intro Video](https://www.canva.com/design/DAHXSTcjxEc/odZj_VbgU20EEeZ1zuJlJA/watch?utm_content=DAHXSTcjxEc&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=h8306e0024f)
 - [Hackster](https://www.hackster.io/chili-chips-ba/openpcie-backplane-76fdb0)
 - [Elecrow](https://www.hackster.io/ElecrowOfficial/projects)

<p align="center">
  <a href="https://www.crowdsupply.com"><img alt="Crowd Supply logo" width="50%" src="0.doc/artwork/CrowdSupply.logo.png"></a>
  <a href="https://www.oshwa.org"><img alt="Open Source Hardware logo" width="20%" src="0.doc/artwork/oshw-logo-filled-black.png"></a>
</p>  

<p align="center">
  <a href="https://www.hackster.io/chili-chips-ba/openpcie-backplane-76fdb0"><img alt="Hackster logo" width="25%" src="0.doc/artwork/Hackster-logo.png"></a>
  <a href="https://www.elecrow.com"><img alt="Elecrow logo" width="25%" src="0.doc/artwork/Elecrow-logo.png"></a>
  <a href="https://www.kickstarter.com"><img alt="Kickstarter logo" width="25%" src="0.doc/artwork/kickstarter.logo.png"></a>
</p> 


### Community Outreach:
- [2026-10-10](https://www.linkedin.com/feed/update/urn:li:activity:7509048253993242624?commentUrn=urn%3Ali%3Acomment%3A%28activity%3A7509048253993242624%2C7514858764861104128%29&dashCommentUrn=urn%3Ali%3Afsd_comment%3A%287514858764861104128%2Curn%3Ali%3Aactivity%3A7509048253993242624%29)
- [2026-10-05](https://lnkd.in/p/gVDkcKni)
- [2026-09-15](https://www.linkedin.com/posts/chili-chips_opensource-pcie-activity-7505034443674251264-eed-?utm_source=share&utm_medium=member_desktop&rcm=ACoAAAJv-TcBSi_5ff0VNMrInrT-xg44YF3jnyU)
- [2026-06-23](https://www.linkedin.com/posts/andrew-e-wilson_its-fun-bringing-all-the-fpga-vendors-together-share-7475267075234607104-j50-)
- [2026-01-26](https://www.linkedin.com/posts/chili-chips_fpga-pcie-riscv-activity-7421756737285734400-Lzlv?utm_source=share&utm_medium=member_desktop&rcm=ACoAAAJv-TcBSi_5ff0VNMrInrT-xg44YF3jnyU)
- [2025-12-19](https://www.linkedin.com/posts/chili-chips_opensource-fpga-gatemate-activity-7407180369269223424-laCE?utm_source=share&utm_medium=member_desktop&rcm=ACoAAAJv-TcBSi_5ff0VNMrInrT-xg44YF3jnyU)
- [2025-08-17](https://www.linkedin.com/pulse/pcie-model-c-simon-southwell-m2fve/?trackingId=CA4nW3if5DVRR%2BXN%2FIkQoQ%3D%3D)
- [2025-07-22](https://www.linkedin.com/posts/simon-southwell-7684482_pcie-vhdl-nvc-activity-7354160318052220929-K0Ku?utm_source=share&utm_medium=member_desktop&rcm=ACoAAAJv-TcBSi_5ff0VNMrInrT-xg44YF3jnyU)
- [2025-04-03](https://www.linkedin.com/feed/update/urn:li:activity:7313386031125303296?commentUrn=urn%3Ali%3Acomment%3A%28activity%3A7313386031125303296%2C7313594045216223236%29&dashCommentUrn=urn%3Ali%3Afsd_comment%3A%287313594045216223236%2Curn%3Ali%3Aactivity%3A7313386031125303296%29)

### Community Involvement

Feel like helping opensource PCIE community grow better and larger?! See [Contributions](CONTRIBUTING.md).

Don't feel shy to reach out and ask for help ===> [![issues](https://badgen.net/github/open-issues/chili-chips-ba/openPCIE?label=issues)](https://github.com/chili-chips-ba/openPCIE/issues).

--------------------

### Future outlook

Our next step is **openPCIE3**, a 24-lane Gen3 backplane with Optical Copper Link (OCuLink). It is built around the Diodes PI7C9X3G1224GP switch (PCIE 3.1, 24 lanes, 12 ports), and links one or two PCs, each over an x4 OCuLink cable, to four x4 EP connectors (two slots, two M.2).

Its main use is as a PC I/O extender, adding compute, storage or I/O cards, e.g. for opensource AI servers. The PC drives REFCLK and reset over the cable, so the board needs no local clock or reset generator. Design input is welcome in [#9](https://github.com/chili-chips-ba/openPCIE/issues/9) and [#13](https://github.com/chili-chips-ba/openPCIE/issues/13).

--------------------

### GenAI

Our repo may contain elements of work facilitated by the modern GenAI tools <img alt="Claude" height="16" src="https://cdn.simpleicons.org/claude/D97757">, used under strict guidance and tight supervision of the blood-and-flesh developers, and solely as suggestions.

In the end, it is us, the human devs, who are fully responsible for any shortfalls you may uncover while tapping into repo resources.

--------------------
#### End-of-Document
