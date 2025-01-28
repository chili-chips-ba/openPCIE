Computing is about communicating. Some would also say networking. The digital sovereignty tags along with them -- _"The Recommendations and Roadmap for European Sovereignty in open source HW, SW and RISC-V Technologies (2021)"_ calls for the development of critical open source IP blocks, such as **`PCIe Root Complex (RC)`**. This project is the first step in that direction.

<p align="center">
  <img width=350 src="0.doc/artwork/PCIE2-RootC.logo.png">
</p>

It aims to open Artix7 PCIe Gen2 RC IP blocks for use outside of proprietary tool flows. While still reliant on Xilinx Series7 Hard Macros (HMs), it will surround them with open-source soft logic for PIO accesses — This **`RTL`** and, even more importantly, the layered **`sofware Driver with Demo App`**. 

All that with **`full HW/SW co-sim`** the kind of is yet to be seen in the proprietary settings. Augmented with a rock-solid **`openBackplane`** in the basement, the geek community will thus get all it takes for building their own _openCompute_ systems.

> The project‘s immediate goal is to empower the makers with ability to host PCIe-based peripherals on their soft RISC-V SOCs.

Given that the PCIE End-Point (EP) with DMA is already available in opensource, the opensource PCIe peripherals do exist for Artix7. Except that they are always, without exception, controlled by the proprietary RC on the motherboard side, typically in the form of RaspberryPi ASIC, or x86 PC. This project intends to change that status quo.

Our long-term goal is to set the stage for the development of full opensource PCIe stack, gradually phasing out Xilinx HMs from the solution. That’s a long, ambitious track, esp. when it comes to mixed-signal SerDes and high-quality PLLs. We therefore anticipate a series of follow on projects that would build on the foundations we hereby set.

This first phase is about implementing an open source PCIE Root Complex (RC) for Artix7 FPGA, utilizing Xilinx Series7 PCIE HM and GTP IP blocks, along with their low-jitter PLL.

--------------------

#### References
- TODO

--------------------

## Hardware platform
- TODO

--------------------

# Project Status

#### `PART 1. Mini PCIE Backplane PCB`

Almost all consumer PCIE installations have the RC chip soldered down on the motherboard, typically embodied in the CPU or "North Bridge" ASIC, where PCIE connectors are used solely for the EP cards. Similarly, all FPGA boards on the market are meant for EP applications. As such, they expect clock, reset and a few other signals from the infrastructure. It is only the professional and military-grade electronics that may have both RC and EP functions on add-on cards, with a backplane connecting them (see VPX chassis, or VITA 46.4).

This activity is about creating the minimal PCIE infrastructure necessary for using ready-made FPGA EP cards in the RC function. This infrastructure takes the physical form of a mini backplane that provides the necessary PCIE context similarly to what a typical motherboard would give, but without a soldered-down RC chip that would be conflicting with our FPGA RC chip.

This mini backplane approach is less work and less risk than the design of our own PCIE motherboard, with large FPGA on it, would entail. But, it is also a task that we did not appreciate from the get-go and, in a bit of a surprise, realized later on that a suitable, ready-made backplane was not available on the market. On the other hand, while more work, we believe that this new PCB outcome makes the project even more attractive and valuable for the community.

We are therefore happy to announce that [Envox.eu](https://www.envox.eu) has agreed to participate on the project. They will carry the bulk of the PCIE backplane PCB development activity.

 - [x] Create requirements document.
 - [x] Select components. Schematic and PCB layout design.
 - [ ] Review and iterate design to ensure robust operation at 5GHz, possibly using openEMS for simulation of high-speed traces.
 - [ ] Manufacure prototype. Debug and bringup, using AMD-proprietary on-chip IBERT IP core to assess Signal Integrity
 - [ ] Produce second batch that includes all improvements. Distribute it, and release design files with full documentation.

#### `PART 2. Project setup and preparatory activities`
 - [x] Procure FPGA development boards and PCIE accessories.
 - [ ] Analyze and fully understand the existing proprietary codebase and design setup. Take the entire team to the sufficient level of understanding of the existing PCIE ecosystem, both proprietary and open-source. 
 - [ ] Prepare project repo and documentation blueprint for both hardware and software elements of the overall solution.
 - [ ] Put together a prototype system. Bring it up using proprietary RTL IP, Vivado toolchain, proprietary SW Driver and TestApp. 
 
#### `PART 3. Initial HW/SW implementation`
 - [ ] HW development of opensource RTL that mimics the functionality of PCIE RC proprietary solution.
 - [ ] SW development of opensource driver for the PCIE RC HW function. This may, or may not be done within Linux framework. 
 - [ ] Design SOC based on RISC-V CPU with PCIE RC as its main peripheral.

#### `PART 4. HW/SW co-simulation using full PCIE EP model`

This development activity is significantly beefed up compared to our original plan, which was to use a much simpler PCIE EP BFM, and non-SOC sim framework. While that would have reduced the time and effort spent on the sim, prompted by NLnet astute questions, we're happy to announce that [wyvernSemi](https://github.com/wyvernSemi/pcievhost) is now also onboard!

Their VProc can be used not only to model the RISC-V CPU and SW interactions with HW, but it also comes with an implementation of the PCIE RC model. Our plan is to first convert it to the comprehensive PCIE EP model, then pair it up in sim with our RC RTL design. Moreover, the existence of both RC and EP models paves the way for future plug-and-play open-source sims of the entire PCIE sub-system.

With the full end-to-end simulation in place, we hope that the need for hardware debugging, using ChipScope, expensive test equipment, and/or PCIE protocol analyzers would be alleviated.

 - [ ] Conversion of the existing PCIE RC model to EP model.
 - [ ] Testbench development and build up. Execution and debug of sim testcases.
 - [ ] Documentation of EP model, TB and sim environment, with objectives to make it easy for anyone to use and understand.
 
#### `PART 5. Integration, testing and iterative design refinements`
 - [ ] One-by-one replace proprietary design elements from PART2.d with our opensource versions (except for Vivado and TestApp), testing it along the way, and fixing problems as they occur.
 
#### `PART 6. Prepare Demo and port it to openXC7`

It is expected that, due to _nextpnr-xilinx_ and openXC7 limitations, we might run into showstoppers on the timing closure front. Provided that _ScalePNR_ flow is ready for real-life testing, even though PCIE is an advanced and high-speed design, we are here to support _ScalePNR_ developers.

 - [ ] Develop our opensource PIO TestApp software and representative Demo.
 - [ ] Build design with _openXC7_, reporting issues and working with developers to fix them, possibly also trying _ScalePNR_ flow.

--------------------

# Backplane PCB Design
- WIP

--------------------

# HW Architecture
- WIP
  
--------------------

# TB/Sim Architecture
- WIP
  
--------------------

# SW Architecture
- WIP

--------------------

### Acknowledgements
We are grateful to **NLnet Foundation** for their sponsorship of this development activity.

<p align="center">
   <img src="https://github.com/chili-chips-ba/openeye/assets/67533663/18e7db5c-8c52-406b-a58e-8860caa327c2">
   <img width="115" alt="NGI-Entrust-Logo" src="https://github.com/chili-chips-ba/openeye-CamSI/assets/67533663/013684f5-d530-42ab-807d-b4afd34c1522">
</p>

The **wyvernSemi**'s wisdom and contribution made a great deal of difference -- Thank you, we are honored to have you on the project.

<p align="center">
 <img width="115" alt="wyvernSemi-Logo" src="https://github.com/user-attachments/assets/94858fce-081a-43b4-a593-d7d79ef38e13">
</p>

The **Envox**, our next-door buddy, is responsible for the Birth of our Backplane. We like to call it BB, not to be mixed with their gorgeous [BB3](https://www.envox.eu/eez-bb3) beauty.

<p align="center">
  <img width=250 src="0.doc/artwork/EEZ-web-logo.png">
</p>

### Public posts:
- Soon to come

--------------------
#### End of Document
