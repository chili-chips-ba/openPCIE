# openBackplane PCB

The board is designed for flexible PCIe system development and testing, featuring two distinct logical *islands*:  
- **(1-to-1) 4-lane Direct connection**
- **(1-to-4) 1-lane Switched connection**.

<p align="center" width="100%">
    <img width="50%" src="0.doc/openPCIE-BlockDiagram.jpg">
</p>

####  Key Features

- Modular Design:
  - Two independent “islands” for different PCIe topologies.  
- Flexible Connectivity:
  - Supports standard PCIe Slots and M.2 (M-key, PCIe) connectors.  
- Power, Clock and Reser generation:
  - Single 6-pin PCIe power connector supplies the entire board (up to 70 W total).  
  - Integrated 100 MHz REFCLK generator and reset (PERST#) distribution circuits.  
- Innovative RC Connector Design:
  - Allows natively EndPoint cards to function as a RootComplex without hardware modification.

Designed with **KiCad 9.0.5**, from schematic entry to layout. For the full schematic PDF, click [here](openpci2-backplane/openpci2-backplane.pdf).

### Common Resources

#### Power Delivery
- Powered by a standard **6-pin PCIe power connector** (3 × **+12V**, 3 × **GND**).  
- On-board **DC-DC** and **LDO** converters provide the required **+3.3V** and **+12V** rails for all slots.  
- Total power budget: **~70W**, with a guideline of **10W per slot**.

#### Clock Distribution
- On-board **100MHz PCIe-approved REFCLK Generator** provides the reference clock.
- The clock is distributed to all slots via differential buffers (**REFCLK+ / REFCLK-**).
- The **REFCLK** is only distributed to a slot (both RC and EP) after a device has been inserted and asserts the **CLKREQ#** signal (by driving it to logic low). This feature ensures that clocks are only active when and where needed, thus reducing the power and EMI.

#### Reset Logic
The system-wide PERST# reset signal is distributed to all slots and can be triggered by two sources:

- **Automatic**: Triggers a reset whenever a supply voltage is outside its specified range.
- **Manual**: A push-button for user-initiated resets.

##  Functional Blocks

### 4-lane “Direct” Island (RC4 ⇔ EP4)

Provides a direct, point-to-point, 4-lane PCIe link between two connectors.

**RC4 (Root Complex)**  
- 4-lane connector intended for a card acting as the Root Complex.  
- Mechanical option: *M.2 (M-key, PCIe)*.

**EP4 (Endpoint)**  
- 4-lane connector for a standard Endpoint card.  
- Mechanical option: *Standard PCIe slot*.

---
### 1-lane “Switched” Island (RC1 ⇔ SW ⇔ SW_EP0/1/2/3)

Uses a PCIe switch to branch a single upstream lane into four downstream lanes.

**RC1 (Root Complex)**  
- 1-lane connector for the upstream Root Complex card.  
- Mechanical option: *Standard PCIe Slot*.

**PCIe Switch**  
- Device: **Asmedia ASM1184e** (PCIe 2.0 switch).  
- Configuration: **1 × Upstream → 4 × Downstream** (1-to-4).

**SW_EP0 – SW_EP3 (Endpoints)**  
- Four 1-lane connectors for downstream Endpoint cards.  
- Mechanical options: *Standard PCIe Slot* or *M.2 (M-key, PCIe)*.

#### Note on “RC Connectors”

A key design feature of this backplane is the implementation of the **RC (Root Complex)** connectors.

Most FPGA development boards or other plug-in cards are natively designed with an **Endpoint (EP) pinout**.  
The backplane swaps the connector pins on the RC slots so that:

- The **Transmit (Tx)** differential pairs from the plug-in card connect to the **Receive (Rx)** pairs on the opposite side, and  
- The **Receive (Rx)** pairs connect to the **Transmit (Tx)** pairs on the other side.

This pin-swapping allows the same physical FPGA plug-in card—always pinned as an Endpoint—to operate in either **EP** or **RC** role.

---
## PCB Views

<p align="center" width="100%">
    <img width="70%" src="0.doc/images/PCIe_mini_Backplane_3D_viewer_left.JPG">
</p>

<p align="center" width="100%">
    <img width="70%" src="0.doc/images/PCIe_mini_Backplane_3D_viewer_right.JPG">
</p>

<p align="center" width="100%">
    <img width="70%" src="0.doc/images/openPCIE-Bare-PCB.png">
</p>


Impedance-controlled traces:

<p align="center" width="100%">
    <img width="70%" src="0.doc/images/Impedance-controlled-traces.png">
</p>


---
## Usage scenarios

### Usecase 1: Direct FPGA_RC to FPGA_EP (Gen1 x1)

<p align="center" width="100%">
    <img width="70%" src="0.doc/images/Direct FPGA_RC to FPGA_EP 1.JPG">
</p>

<p align="center" width="100%">
    <img width="70%" src="0.doc/images/Direct FPGA_RC to FPGA_EP 2.JPG">
</p>

This scenario is the bread-and-butter, the meat of this project. That's what it is about. We intend to test our Artix-7 RootComplex in the Standard PCIe slot. The backplane design leaves the path open for future exploration of **x4** and **Gen2** implementations.

This same scenario is also envisioned for testing the interoperability of our [openCologne-PCIE](https://github.com/chili-chips-ba/openCologne-PCIE) EndPoint with Xilinx Artix-7 RootComplex.

### Usecase 2: Switched FPGA_RC to FPGA_EP (Gen1 x1)

We intend to try testing the RootComplex interactions with EndPoints through a PCIE Switch. This is "best effort", i.e. a  bonus if we manage to make it work. The backplane also leaves the door open for the **Gen2** testing.

### Usecase 3: PCIE Expansion or Extension
By using our _"PCIE Jumper Cable"_, the backplane can be connected to a standard PC serving as a RootComplex, such as for the expansion of its I/O Slot capacity, or for the extension of its physical reach. We also intend to use it for [openCologne-PCIE](https://github.com/chili-chips-ba/openCologne-PCIE) EndPoint validation, specificaly to assess and compare the strength of GateMate SerDes to others, Xilinx Artix-7 and off-the-shelf ASICs in particular.

<p align="center" width="100%">
    <img width="60%" src="0.doc/images/PCIE-Jumper-Cable-Male2Male.jpg">
</p>

## PCIE Layout Considerations

The _characteristic impedance_ of the differential pairs on our backplane is `100ohm+/-10% for both data and clock signals`. They are all routed as `microstrips`, i.e. with reference to Ground/Power plane from only one side. The P-to-N skew is matched to no more than **5 mils**.

The number of vias or other impedance discontinuities on the path of `5Gbps signal wires` and `100MHz reference clocks` is minimized. We use Through-Hole (TH) slot connectors for mechanical stability and better routability. The M.2 and RPi connectors are Surface-Mount Devices (SMD). All components are on the top side of the board. We did not use the _'striplines'_, which is when the high-speed traces are sandwiched between two reference planes (ground or power), as they require vias and are typically used in setups with 6 or more layers. We used the _'microstrips'_, as they allowed getting away without any vias. 

The size of our vias is the standard **0.3mm**. The blind, burried, partial or any other advanced via technologies are not used. That makes for a less expensive PCB and final product, but it also stresses the need to be cautious about placing vias on the diff pairs. Such vias go through all layers, they are longer. They are also not with the smallest possible diameter, therefore overall bulkier and more of a disturbance.

<p align="center" width="100%">
    <img width="65%" src="0.doc/images/PCIE-Trace-Impedance.jpg">
</p>

Our stackup is **4-layer**:

- `Top` - Microstrip for diff pairs and ordinary lines 
- `L2` - Ground plane
- `L3` - 3.3V Power plane
- `Bottom` - Microstrip for diff pairs and ordinary lines 

<p align="center" width="100%">
    <img width="65%" src="0.doc/images/PCIE-stackup.jpg">
    <img width="65%" src="0.doc/images/PCIE-trace-geometry.jpg">
    <img width="65%" src="0.doc/images/PCIE-symmetry.jpg">
    <img width="65%" src="0.doc/images/PCIE-ref-plane.jpg">
    <img width="65%" src="0.doc/images/PCIE-no-stubs.jpg">
</p>

Check [this](0.doc/PCIE-Layout-Guidelines.SIG.pdf) link for additional physical and routing considerations.

Since we have a unique feature with multiple connectors on the same line, special care is given to minimize the "stubs" at both the start and end of the transmission line. Here is an example of what not to do.

<p align="center" width="100%">
    <img width="65%" src="0.doc/images/PCB-Stubs-MustAvoid.png">
</p>


## The P and N Swaps

While the PCIE requirements stipulate that, in order to simplify the PCB layout, the electronics should be capable of internally swapping the P and N leads of differential pairs, we did not want to take chances, and have taken extra steps not to depend on the plug-in electronics -- All Ps are routed to the Ps, and all Ns to the Ns, even if that called for a via. 

<p align="center" width="100%">
    <img width="65%" src="0.doc/images/PCIE-P-and-N-swaps.png">
</p>

## PCIe Connection Model: Generators → Transport → Consumers

All signal generators should be placed as close as possible to each other. Likewise, all signal consumers should be grouped very close together. The goal is to minimize the stubs, both at the beginning of the transmission path (on the generator side) and at the end (on the consumer side).

In the example above, when the M.2 connector acts as the signal generator and the Slot is the consumer, very long stubs appear on both ends. Since the active signal also propagates into these unterminated stubs, part of it gets reflected back with a noticeable delay proportional to the stub length. This reflected wave interferes with the original signal at the Slot receiver when that signal should be stable. Similarly, the reflection from the M.2 stub disturbs the transmitter at the M.2 side, which then shows up again at the Slot and superimposes with the first and second waves.

The key is to eliminate or minimize the second, third, and subsequent `reflected waves`, keeping only the primary, `incident wave` that carries the valid data.

## Signal Integrity (SI) Sims
The following videos demonstrate signal reflections on a transmission line in two different cases:

- **Transmission line with stub** – see video below

https://github.com/user-attachments/assets/f051aea8-5269-4e07-8074-357f93c2e468

- **Transmission line without stub** – see video below

https://github.com/user-attachments/assets/b43a36d0-c9cd-4929-85f8-a3717680f151
  
The following five wiring topologies are examined in Electro-Magnetic Simulations (EMS):
- `Bad` **Long stubs**. For understanding of _Incident_ and _Reflected_ waves
- `One-2-One` **Point-to-Point**. This is the standard and simplest, i.e. the baseline case
- `One-2-Two` **Point-to-Multipoint**. Unique for high-speed
- `Three-2-One` **Multipoint-to-Point**. Unique for high-speed

Since we feature multiple mechanical connectors ("Slot", M.2, RPi5 FPC) on the same diff lines, we have very unusal, probably **unique topologies** to deal with. All representative combinations are analyzed and presented.

### EMS topology 0: Bad (just for learning, not for using)
- long stubs on both sides. We can use the analysis of the Rx and Tx SMA connectors for this case to show why it is better to place them at the end of their line, close to the Rx input termination.
  
### EMS topology 1: One-2-One (standard)
- SWRC3_CLK_P/N 100MHz clock diff pair
  
### EMS topology 2: One-2-Two (unique)
- Pick the longest 5Gbps diff pairs from the SW => SW_EP0/1/2/3 set
    
### EMS topology 3: Three-2-One (unique)
- Pick one of the RC1 => SW 5Gbps diff pairs. We have RPi5 FFC, Slot and M.2 here.

  
## SI Lab Measurements
TODO

<p align="center" width="100%">
    <img width="65%" src="0.doc/images/PCIE-Eye-Measurements.jpg">
</p>


## 30 Amp DC/DC Buck Layout Considerations

The layout of the PCIE backplane is not only about the 5Gbps differential pairs. The backplane also hosts a powerfull 12V-to-3.3V DC/DC. Given its 30 Amps(!) current capacity, the buck layout calls for special attention. While we have followed the TI recommendations to the letter, the question was also raised about the stability of the `long Remote Sense` wires:
   1) Will they incentivize the buck to oscillate?
   2) Is the far-off Remote Sense really needed?

The argument is that the digital logic can tolerate +/-10% voltage inaccuracy. Remote Sense, while allowing fine voltage tracking at the very load point, creates a long loop that opens the Pandora box of potential closed-loop instability. The digital logic is more sensitive to transients than to the absolute voltage levels. The argument goes that the design should therefore focus on providing fast dynamic response rather than the static accuracy. 

<p align="center" width="100%">
    <img width="65%" src="0.doc/images/Buck-Remote-Sense.0.JPG">
    <img width="65%" src="0.doc/images/Buck-Remote-Sense.1.JPG">
    <img width="65%" src="0.doc/images/Buck-Remote-Sense.2.png">
</p>

Check [here](https://e2e.ti.com/support/power-management-group/power-management/f/power-management-forum/1588097/tps54kc23-tps54kc23-remote-sense-stability-or-not) to see what the TI experts had to say on this question.

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

**[6] [PCB Layout Guidelines](0.doc/PCIE-Layout-Guidelines.SIG.pdf)**

**[7] Open-source SI Sim tools**
- [openEMS](https://docs.openems.de)
- [AntMicro EMS Sim](https://antmicro.com/blog/2025/07/recent-improvements-to-antmicros-signal-integrity-simulation-flow)

**[8] [Saturn PCB Tools](https://saturnpcb.com/saturn-pcb-toolkit)**

**[9] [JLC DFM Tool](https://jlcdfm.com)**

**[10] [JLC Impedance Calculator Tool](https://jlcpcb.com/pcb-impedance-calculator)**

**[11] [PMOD Interface Spec](PMOD-interface-spec.V1_2_0.pdf)**

-------
#### End of Document
