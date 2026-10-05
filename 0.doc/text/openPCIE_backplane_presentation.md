<!-- Generated text version of `1.pcb/0.doc/OpenPCIE backplane presentation.pptx` (slide text; images omitted) so the website assistant can read it. Do not edit by hand; regenerate from the source. -->

# openPCIE backplane presentation

Prototype bring-up story: topology, layout, manufacturing, factory tests, the CLKREQ# problem, the switch overheating fix and next steps.

## Slide 1
- Openpcie
- backplane

## Slide 2
- Functionality and   Topology
- Two Logical Islands:
- 4-lane "Direct" connection
- 1-lane "Switched" connection
- Supports standard PCIe Slots and M.2 connectors
- Single 6-pin PCIe power connector
- Integrated 100 MHz clock and reset distribution
- Same FPGA plug-in card can act as EndPoint (EP) or Root Complex (RC)

## Slide 3
- KiCad PCB Layout
- Designed in KiCad
- 4-Layer Stackup:
- Top: Microstrip for diff pairs
- L2: Ground plane
- L3: 3.3V Power plane
- Bottom: Microstrip for diff pairs
- Careful routing to minimize stubs and skew

## Slide 4
- 3D View
- 3D visualization of the openPCIE backplane

## Slide 5
- Manufacturing and Testing Preparation
- PCB manufacturing by Elecrow (5 prototypes)
- Created a PCBA Functional Test Procedure
- Testing basic power, reset, and clock generation

## Slide 6
- Factory Test Results
- Factory tests passed successfully
- Clock (25MHz, 100MHz ) and voltages (1.8V, 12V, 3.3V, 1.2V) verified

## Slide 7
- Boards Arrival
- Prototypes arrived in Sarajevo
- Ready for hardware validation

## Slide 8
- Starting the Tests (Direct Connection)
- Phase 1: Testing the Direct Connection (RC to EP)
- Inserting the FPGA cards

## Slide 9
- The CLKREQ Problem
- The Problem: CLKREQ# signal
- Clock generator requires CLKREQ to be pulled to GND
- Assumption: most M.2 to PCIe adapters route this signal to the M.2 connector, allowing the FPGA to pull it to Ground.

## Slide 10
- History of CLKREQ
- CLKREQ# was introduced in Revision 4 of the PCIe electromechanical specification in late 2018
- Previously, pin B12 was marked as "Reserved"
- Older adapters do not connect this pin

## Slide 11
- Temporary Fix
- First Attempt: put a simple wire between CLKREQ and Ground.
- Issue: Created an inductive loop/antenna near tx0
- Resulted in an unstable link on Lane 0

## Slide 12
- Better Solution: Solder bridge between CLKREQ and GND
- Clock is only active when needed
- Pin layout is perfect for a simple solder bridge:
- The Ground pin is right next to the CLKREQ pin
- The CLKREQ is the last pin on the left side of the connector
- The Permanent Fix

## Slide 13
- Verification Environment
- Dual-PC Setup:
- PC 1: Connected to RC FPGA via JTAG
- PC 2: Connected to EP FPGA via JTAG
- Speed and Efficiency: No manual swapping of JTAG cables and no time-consuming flashing
- Simultaneous Debugging: Run two Vivado Logic Analyzers at the same time

## Slide 14
- Test Objective and Results
- Objective: Verify Link Enumeration, Memory Write, and Memory Read
- Write: RC sends a data payload (Decimal 6) to EP
- Transfer: EP writes it into internal Block RAM
- Read: RC reads the data back
- Result: Successful link (LED is ON) and data matches (0110 binary)

## Slide 15
- Switch Testing
- Moving from Direct connection to the PCIe Switch
- Inserting boards into the 1-to-4 Switch topology

## Slide 16
- The Switch Overheating Problem
- New Problem: One area of the board board was getting extremely hot.
- Switch was too hot to touch; link was highly unstable
- Temporary fix: Added a heatsink and fan
- Investigation: Thermal camera revealed the real issue (1.2V LDO)

## Slide 17
- Thermal Camera Analysis
- Thermal camera shows LDO at 90°C
- Switch pulls up to 2 Watts
- LDO cannot handle this power dissipation, so it was overheating.

## Slide 18
- Ordered a DC-DC Step-Down Power Module
- Input: 2.5-6V | Output: 1.2V Voltage Regulator
- Manual installation for testing
- Testing the Buck Converter

## Slide 19
- Manual Board Modification
- Lifted the LDO leg to disconnect it
- Wired the new DC-DC Buck converter to the board

## Slide 20
- Temperature Results
- Temperature dropped to ~45°C
- Stable communication restored
- Second batch: LDO will be replaced by a Buck converter

## Slide 21
- Fully Populated Switch
- Fully populated PCIe switch setup

## Slide 22
- Improvements for the Second Batch
- Updates for the next PCB revision:
- Open-end PCIe slots (allows x4 cards in x1 slots)
- Add power switch for the main 12V supply line
- Replace LDO with DC-DC Buck converter
- Add CLKREQ shunt on the backplane
- Other minor improvements

## Slide 23
- Thank you for your attention!
