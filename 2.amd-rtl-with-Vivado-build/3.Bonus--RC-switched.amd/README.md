# Root Complex (Switched Connection) - AMD IP Implementation

This is a bonus deliverable, above and beyond our original plan. 

[Here](https://github.com/chili-chips-ba/openPCIE/tree/main/1.pcb#usecase-2-switched-fpga_rc-to-fpga_ep-gen1-x1) is the corresponding hardware setup. 

In order to make it work, we had to get to the root of what looked like ASM1184e overheating problem, see slide 17 of [presentation](https://github.com/chili-chips-ba/openPCIE/blob/main/1.pcb/0.doc/OpenPCIE%20backplane%20presentation.pptx). This turned out to be an undersized LDO (which is to be replaced with a DC/DC buck on the RevB openPCIE backplane).

Once that was taken out of the way, the test procedure was very similar to what was done to validate the [direct](../2.RC-direct.amd) topology.

----

## Key RTL Differences (Direct vs. Switched Topology)

There are two major modifications that need to be made to handle the Switched topology:

### 1. Dynamic Bus and Device Routing
In a direct connection, the Endpoint is always located at a fixed address (typically Bus 1, Device 0). Therefore, in previous AMD implementation, this target address was hardcoded.

In a switched environment, the switch introduces multiple virtual PCI-to-PCI bridges. To communicate with devices behind the switch, the Root Port must dynamically route packets. To support this, the following signals were introduced to the Packet Generator:
* `wire [7:0] pkt_bus_num;`
* `wire [4:0] pkt_dev_num;`

Instead of assuming the target is always Bus 1, the Controller now extracts the exact Bus and Device number for every single transaction directly from the configuration ROM and passes it to the Packet Generator. This also allows the hardware to automatically differentiate between **Type 0** (local) and **Type 1** (cross-bridge) Configuration TLPs.

### 2. Configuration ROM Updates (`cgator_cfg_rom.data`)
Because the routing is now dynamic, the binary format of the configuration ROM had to be updated. The upper bits of the header line (previously unused) now strictly define the `[Bus 8-bit]` and `[Device 5-bit]` target for that specific transaction.

Furthermore, the initialization sequence itself is vastly different. Instead of just configuring one Endpoint, the ROM file now executes a 3-step bring-up process:

* **STEP 1: Switch Upstream Port (Bus 1, Dev 0)** 
  Configures the primary entry point of the switch, assigning the overall memory limits and subordinate bus ranges.
* **STEP 2: Switch Downstream Ports (Internal Bus 2)** 
  Iterates through the internal downstream ports of the switch (e.g., Dev 1, 3, 5, 7). Each port acts as a virtual bridge and is assigned a dedicated Secondary Bus number (Buses 3, 4, 5, and 6) and a specific Memory Base/Limit window.
* **STEP 3: Endpoint Configuration (Buses 3-6)** 
  Finally, the actual Endpoints (cards plugged into the slots) are addressed using their newly assigned bus numbers. Their BARs are configured to fit exactly within the memory windows defined in Step 2.

------

#### End-of-Document
