<!--
SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba

SPDX-License-Identifier: BSD-3-Clause
-->

<!---
Markdown description for SystemRDL register map.

Don't override. Generated from: openpcie
  - csr_build/csr.rdl
-->

## openpcie address map

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x30000024

|  Offset  |Identifier|Name|
|----------|----------|----|
|0x00000000|   imem   |imem|
|0x30000000|    csr   | csr|

## imem memory

- Absolute Address: 0x0
- Base Offset: 0x0
- Size: 0x2000

<p>CPU Program/Data Memory</p>

No supported members.


## csr address map

- Absolute Address: 0x30000000
- Base Offset: 0x30000000
- Size: 0x24

<p>openPCIE Root Complex CSR</p>

|Offset|Identifier|   Name   |
|------|----------|----------|
| 0x00 |    tx    |  csr.tx  |
| 0x10 |    rx    |  csr.rx  |
| 0x1C |  status  |csr.status|

## tx register file

- Absolute Address: 0x30000000
- Base Offset: 0x0
- Size: 0x10

<p>TLP Transmit CSR (CPU --&gt; PCIe link)</p>

|Offset|Identifier|     Name     |
|------|----------|--------------|
|  0x0 |  header0 |csr.tx.header0|
|  0x4 |  header1 |csr.tx.header1|
|  0x8 |  header2 |csr.tx.header2|
|  0xC |   data   |  csr.tx.data |

### header0 register

- Absolute Address: 0x30000000
- Base Offset: 0x0
- Size: 0x4

<p>TLP Header DW0 -- Fmt/Type, TC, attributes and Length</p>

|Bits|Identifier|Access|Reset|          Name          |
|----|----------|------|-----|------------------------|
|31:0|    hdr   |  rw  | 0x0 |csr.tx.header0.hdr[31:0]|

#### hdr field

<p>1st header DWORD of the outgoing TLP</p>

### header1 register

- Absolute Address: 0x30000004
- Base Offset: 0x4
- Size: 0x4

<p>TLP Header DW1 -- Requester ID, Tag and byte enables</p>

|Bits|Identifier|Access|Reset|          Name          |
|----|----------|------|-----|------------------------|
|31:0|    hdr   |  rw  | 0x0 |csr.tx.header1.hdr[31:0]|

#### hdr field

<p>2nd header DWORD of the outgoing TLP</p>

### header2 register

- Absolute Address: 0x30000008
- Base Offset: 0x8
- Size: 0x4

<p>TLP Header DW2 -- address, or Bus/Device/Function and register</p>

|Bits|Identifier|Access|Reset|          Name          |
|----|----------|------|-----|------------------------|
|31:0|    hdr   |  rw  | 0x0 |csr.tx.header2.hdr[31:0]|

#### hdr field

<p>3rd header DWORD of the outgoing TLP</p>

### data register

- Absolute Address: 0x3000000C
- Base Offset: 0xC
- Size: 0x4

<p>TLP Payload DWORD -- writing this register STARTS the transfer</p>

|Bits|Identifier|Access|Reset|           Name          |
|----|----------|------|-----|-------------------------|
|31:0|  payload |  rw  | 0x0 |csr.tx.data.payload[31:0]|

#### payload field

<p>Payload DWORD of the outgoing TLP. A software write to this
register is what launches the Tx FSM, so it must be written
LAST, after the three header registers. The write strobe is
exported to logic as the 'swmod' output of this field.</p>

## rx register file

- Absolute Address: 0x30000010
- Base Offset: 0x10
- Size: 0xC

<p>TLP Receive CSR (PCIe link --&gt; CPU)</p>

|Offset| Identifier|       Name       |
|------|-----------|------------------|
|  0x0 |   status  |   csr.rx.status  |
|  0x4 |    data   |    csr.rx.data   |
|  0x8 |header_info|csr.rx.header_info|

### status register

- Absolute Address: 0x30000010
- Base Offset: 0x0
- Size: 0x4

<p>Completion Status Register</p>

|Bits|Identifier|Access|Reset|             Name            |
|----|----------|------|-----|-----------------------------|
| 2:0|cpl_status|   r  | 0x0 |csr.rx.status.cpl_status[2:0]|

#### cpl_status field

<p>Completion Status of the last received Completion TLP:
0 = SC (Successful Completion), 1 = UR (Unsupported
Request), 2 = CRS (Configuration Retry Status),
4 = CA (Completer Abort)</p>

### data register

- Absolute Address: 0x30000014
- Base Offset: 0x4
- Size: 0x4

<p>Completion Payload Register</p>

|Bits|Identifier|Access|Reset|           Name          |
|----|----------|------|-----|-------------------------|
|31:0|  payload |   r  | 0x0 |csr.rx.data.payload[31:0]|

#### payload field

<p>Payload DWORD of the last received Completion TLP</p>

### header_info register

- Absolute Address: 0x30000018
- Base Offset: 0x8
- Size: 0x4

<p>Completion Header Register -- 3rd DWORD of the Completion TLP</p>

| Bits| Identifier |Access|Reset|                 Name                |
|-----|------------|------|-----|-------------------------------------|
| 6:0 | lower_addr |   r  | 0x0 |  csr.rx.header_info.lower_addr[6:0] |
| 15:8|     tag    |   r  | 0x0 |     csr.rx.header_info.tag[7:0]     |
|31:16|requester_id|   r  | 0x0 |csr.rx.header_info.requester_id[15:0]|

#### lower_addr field

<p>Lower Address field of the Completion header</p>

#### tag field

<p>Tag of the request this Completion belongs to</p>

#### requester_id field

<p>Requester ID the Completion is addressed to. Software
compares it against its own ID to filter foreign traffic.</p>

## status register file

- Absolute Address: 0x3000001C
- Base Offset: 0x1C
- Size: 0x8

<p>PCIe Link Status CSR</p>

|Offset|Identifier|     Name     |
|------|----------|--------------|
|  0x0 |    err   |csr.status.err|
|  0x4 |    phy   |csr.status.phy|

### err register

- Absolute Address: 0x3000001C
- Base Offset: 0x0
- Size: 0x4

<p>PCIe Error Status Register</p>

|Bits|  Identifier |Access|Reset|              Name             |
|----|-------------|------|-----|-------------------------------|
|15:0|  cfg_status |   r  | 0x0 |csr.status.err.cfg_status[15:0]|
| 16 |msg_err_fatal|   r  | 0x0 |  csr.status.err.msg_err_fatal |

#### cfg_status field

<p>Configuration Space Status Register of the PCIe hard macro
(cfg_status)</p>

#### msg_err_fatal field

<p>A fatal-error Message TLP has been received
(cfg_msg_received_err_fatal)</p>

### phy register

- Absolute Address: 0x30000020
- Base Offset: 0x4
- Size: 0x4

<p>PCIe PHY / Tx FSM Status Register</p>

|Bits|Identifier|Access|Reset|             Name            |
|----|----------|------|-----|-----------------------------|
| 5:0| tx_buf_av|   r  | 0x0 |csr.status.phy.tx_buf_av[5:0]|
| 7:6| tx_state |   r  | 0x0 | csr.status.phy.tx_state[1:0]|

#### tx_buf_av field

<p>Number of free transmit buffers in the PCIe hard macro
(tx_buf_av). Software waits for a non-zero value.</p>

#### tx_state field

<p>State of the Tx FSM: 0 = IDLE, 1 = SEND_CYCLE_1,
2 = SEND_CYCLE_2. Software polls for 0 before it starts
loading the next TLP.</p>
