<!-- Generated text version of `1.pcb/0.doc/PCBA_Functional_Test_Procedure_RevB.pdf` (converted from its LaTeX source, `PCBA_Functional_Test_Procedure_RevB_LaTeX_Source.zip`; figures omitted) so the website assistant can read it. Do not edit by hand; regenerate from the source. -->

# PCBA Functional Test Procedure (openpci2-backplane)

Prepared for Elecrow. Revision B.

## Introduction

This document outlines the mandatory functional test procedures for the openpci2-backplane PCBA after assembly. The purpose of this test is to verify the soldering quality, power supply stability, and basic signal integrity before the units are shipped.

Please follow the steps sequentially. If any step fails, the board should be marked as "Failed" and separated for inspection.

## Power Supply Verification

- **Step 1.1:** Connect the main power supply (**standard 6-pin PCIe power connector (3 × +12V, 3 × GND), up to 70W total**) to the board input connector. 

- **Step 1.2:** Using a Digital Multimeter, measure the voltages at the specific test points indicated in **the figure** below. Reference all measurements to the board Ground (GND).

Verify the following voltage rails are present and stable:

- **12V** (Main Input)
- **3V3** (Output from DC/DC Buck Converter)
- **1V8**
- **1V2**

[Figure: Voltage Measurement Points]

## Reset Circuit Verification

The objective of this section is to verify that the manual reset signal is correctly distributed to all destination points on the backplane.

- **Step 2.1:** Ensure the board is powered (12V applied).

- **Step 2.2:** Locate the **RESET Button** and the **7 specific Reset Test Points** indicated in **the figure**.

- **Step 2.3:** **Idle State Check:** Without pressing the button, measure the voltage at **all 7 test points**.

- Verify that **all 7 points** are at a **High Logic Level (~ 3V3)**.

- **Step 2.4:** **Active State Check:** Press and **hold** the RESET Button. While holding the button, measure the voltage at **all 7 test points** again.

- Verify that **all 7 points** drop to a **Low Logic Level (~ 0V / GND)**.

- **Step 2.5:** Release the button and confirm that **all 7 test points** return to a **High Logic Level (~ 3V3)**.

[Figure: Location of Reset Button and the 7 Verification Points]

## Reference Clock Verification

The objective of this section is to verify the clock generator chip functionality. This is done in two parts: first by checking the primary reference output, and second by verifying the individual PCIe clocks.

### Part 1: Primary Reference Check (25 MHz)

**Objective:** Verify that the clock generator is active and the crystal is oscillating.

- **Step 3.1:** Ensure the board is powered (12V).
- **Step 3.2:** Locate **Resistor R22** (Series resistor for the SMA connector J4). See **the figure**.
- **Step 3.3:** Probe the signal on **R22**.
- **Step 3.4:** Verify the signal parameters:

- **Frequency:** **25 MHz**
- **Waveform:** Clean square/sine-like wave.
- **Amplitude:** Logic High (V_OH) should be **>1.35V** (typically ~ 1.8V). Logic Low (V_OL) should be **<0.45V** (typically ~ 0V).

- **Decision:** If this signal is **ABSENT**, the clock chip is not running. **STOP the test**. If present, proceed to Part 2.

[Figure: Location of Resistor R22 (25MHz Check)]

### Part 2: PCIe Output Verification (100 MHz)

**Objective:** Verify the presence of the 100 MHz PCIe reference clock outputs, confirm that the clock generator correctly drives the PCIe Switch, and verify that the Switch distributes the clock to downstream endpoints.

**Test Strategy:**
The CLKREQ# signal of the main upstream slot (**SWRC1**) is tied to GND by default on the board. Therefore, as soon as the board is powered, the clock generator output that feeds both the SWRC1 slot and the PCIe Switch input is enabled automatically. **No jumper wire or any other external connection is required.** Once the Switch receives the reference clock, it should automatically distribute it to the downstream x1 slot (**SW_EP1**).

- **Step 3.5: Measure Input Clock (at SWRC1)**

- Locate the PCIe x4 slot labeled **SWRC1**.
- With the board powered, probe the clock pins (A13/A14) on the **SWRC1** slot (at the connector entrance). **Refer to the figure.**
- **Verify:** 100 MHz clock is present.

[Figure: Measurement points on SWRC1]

- **Step 3.6: Measure Downstream Clock (at SW_EP1)**

- Locate the PCIe x1 slot labeled **SW_EP1**.
- Probe the clock pins (A13/A14) on **SW_EP1**. **Refer to the figure.**
- **Verify:** 100 MHz clock is present.
- *Note: If the clock is present here, it confirms the PCIe Switch is functioning.*

[Figure: Measurement points on SW_EP1]

- **Step 3.7: Signal Parameters Verification**

- **Frequency:** **100 MHz**
- **Waveform:** Clean square/sine-like wave (HCSL).
- **Amplitude:** Logic High (V_OH) approx. **0.7V - 0.8V**. Logic Low (V_OL) approx. **0V**.

- **Step 3.8: Thermal Check of the PCIe Switch**

- With the board powered for at least 1–2 minutes, briefly touch the **PCIe Switch chip** and the area around it with a finger.
- **Verify:** The chip and the surrounding area must **not be hot**. Slightly warm is acceptable.
- *Note: If the chip is too hot to keep a finger on it, mark the board as "Failed".*

**End of Test Procedure** 
If all steps passed, mark the board as **"PASSED"**.
