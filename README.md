Computing is about communicating. Some would say networking. Sovereignty tag along -- “Recommendations and Roadmap for European Sovereignty in open source HW, SW and RISC-V Technologies” from 2021 calls for the development of critical open source IP blocks within 2-5 years. PCIe Root Complex (RC) was listed as one of them. This project is the first step in that direction.

<p align="center">
  <img width=380 src="0.doc/artwork/PCIE2-RootC.logo.png">
</p>

It aims to open Artix7 PCIe Gen2 RC for use outside of proprietary tool flows. While still reliant on Xilinx Series7 Hard Macros (HMs), it will surround them with open-source Soft IP for PIO accesses — The RTL and, even more importantly, the layered sofware Driver with Demo App. All that with full HW/SW co-sim the kind of is unheard of in proprietary settings. And with an openBackplane that allows building your openCompute systems on top of.

The project‘s immediate goal is to empower the makers with ability to host PCIe-based peripherals on their RISC-V SOCs. Since End-Point (EP) with DMA is already available, open-source PCIe peripherals do exist for Artix7. Except that they are always, without exception, controlled by the proprietary RC on the motherboard side, typically in the form of RaspberryPi ASIC, or x86 PC. This project intends to change that status quo.

The long-term goal is to set the stage for the development of full open-source PCIe stack, and gradually phase out Xilinx HMs from the solution. That’s a long, ambitious path, esp. when it comes to mixed-signal SerDes and high-quality PLLs. We therefore anticipate a series of follow on projects that would build on the foundations we hereby set.

This first phase is about implementing an open source PCIE Root Complex (RC) for Artix7 FPGA, utilizing Xilinx Series7 PCIE HM and GTP.


#### References
- TODO


--------------------

## Hardware platform
- TODO


--------------------

# Project Status

#### 1. Mini PCIE Backplane PCB

Almost all consumer PCIE installations have the RC chip soldered down on the motherboard, typically embodied in the CPU or "North Bridge" ASIC, where PCIE connectors are used solely for the EP cards. Similarly, all FPGA boards on the market are meant for EP applications. As such, they expect clock, reset and a few other signals from the infrastructure. It is only the professional and military-grade electronics that may have both RC and EP functions on add-on cards, with a backplane connecting them (see VPX chassis, or VITA 46.4).

This task is about creating the minimal PCIE infrastructure necessary for using ready-made FPGA EP cards in the RC function. This infrastructure takes the physical form of a mini backplane that provides the necessary PCIE context similarly to what a typical motherboard would give, but without a soldered-down RC chip that's conflicting our FPGA RC chip.

This mini backplane approach is less work and less risk than the design of our own PCIE motherboard , with large FPGA on it, would entail. But, it is also a task that we originally did not anticipate. In a bit of a surprise, it turned out that a suitable, ready-made backplane was not available on the market.

On the other hand, while more work, we believe that this new PCB outcome makes the project even more attractive and valuable for the community.

We are happy to announce that [Envox.eu](https://www.envox.eu) has agreed to participate on the project and will carry the bulk of the PCIE backplane PCB development activity.

 - [x] Create requirements document.
 - [x] Select components. Schematic and PCB layout design.
 - [ ] Review and iterate design to ensure robust operation at 5GHz, possibly using openEMS for simulation of high-speed traces.
 - [ ] Manufacure prototype. Debug and bringup, using AMD-proprietary on-chip IBERT IP core to assess Signal Integrity
 - [ ] Produce second batch that includes all improvements. Distribute it, and release design files with full documentation.

#### 2. Project setup and preparatory activities
 - [x] Procure FPGA development boards and PCIE accessories.
 - [ ] Analyze and fully understand the existing proprietary codebase and design setup. Take the entire team to the sufficient level of understanding of the existing PCIE ecosystem, both proprietary and open-source. 
 - [ ] Prepare project repo and documentation blueprint for both hardware and software elements of the overall solution.
 - [ ] Put together a prototype system. Bring it up using proprietary RTL IP, Vivado toolchain, proprietary SW Driver and TestApp. 
 
#### 3. Initial HW/SW implementation
 - [ ] HW development of open-source RTL that mimics the functionality of PCIE RC proprietary solution.
 - [ ] SW development of open-source driver for the PCIE RC HW function. This may, or may not be done within Linux framework. 
 - [ ] Design SOC based on RISC-V CPU with PCIE RC as its main peripheral.

#### 4. HW/SW co-simulation using full PCIE EP model

This development task is significantly beefed up compared to our original plan, which was to use a much simpler PCIE EP BFM, and non-SOC framework. While that would have reduced time and effort spent on the sim, prompted by NLnet astute questions, we're happy to announce that Simon Southwell is now also onboard!

Simon's VProc can be used not only to model RISC-V CPU and SW interactions with RTL HW, but it also comes with an implementation of the PCIE RC model. Our plan is to first convert it to the comprehensive PCIE EP model, then pair it up in sim with our RC RTL. Moreover, the existence of both RC and EP models paves the way for future plug-and-play open-source sims of the entire PCIE sub-system.

With full simulation in place, we hope that the need for hardware debugging, using ChipScope, expensive test equipment, and/or PCIE protocol analyzers would be alleviated.

 - [ ] Conversion of the existing PCIE RC model to EP model.
 - [ ] Testbench development and build up. Execution and debug of sim testcases.
 - [ ] Documentation of EP model, TB and sim environment, with objectives to make it easy for anyone to use and understand.
 
#### 5. Integration, testing and iterative design refinements
 - [ ] One by one replace proprietary design elements from task (2.d) with our open-source versions (except for Vivado and TestApp), testing it along the way, and fixing problems as they occur.
 
#### 6.Prepare Demo and port it to openXC7

It is expected that, due to nextpnr-xilinx limitations, we might run into showstoppers on the timing closure front. Provided that ScalePNR is ready for real-life testing, even though PCIE is an advanced and high-speed design, we are here to support ScalePNR developers.

 - [ ] Develop our open-source PIO TestApp software and representative Demo.
 - [ ] Build design with openXC7, reporting issues and working with developers to fix them, possibly also trying ScalePNR flow.


--------------------

# PCIE Backplane
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