// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
//                   Copyright (C) 2026 Chili.CHIPS
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
// contributors may be used to endorse or promote products derived
// from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
// IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//              https://opensource.org/license/bsd-3-clause
//--------------------------------------------------------------------------
// Description:
//   opensource openPCIE software FSM that replaces AMD-proprietary RTL FSM
//   Switched topology: ASM1184e PCIe switch with up to 4 endpoints behind it
//
//   Bus map produced by this firmware (same as the AMD cgator_cfg_rom.data):
//
//     bus 0 .............. Root Complex
//      |
//     bus 1  dev 0 ....... ASM1184e upstream port      (pri 1, sec 2, sub 6)
//      |
//     bus 2  dev 1 ....... downstream port 1 --> bus 3, window 0x10000000
//            dev 3 ....... downstream port 2 --> bus 4, window 0x10100000
//            dev 5 ....... downstream port 3 --> bus 5, window 0x10200000
//            dev 7 ....... downstream port 4 --> bus 6, window 0x10300000
//      |
//     bus 3..6  dev 0 .... the endpoint cards, BAR0 at the window base
//
//   Everything on bus 1 is reached with Type 0 Configuration TLPs, everything
//   deeper with Type 1. That selection is NOT made here -- riscv_pcie_soc.sv
//   derives it from the bus number in TX_HEADER2. The RTL is the same as for
//   RC-direct, whose requests all go to bus 1.
//==========================================================================

#include "pcie.h"

// Topology, exactly as laid out in the AMD configuration ROM
#define SWITCH_BUS        1
#define SWITCH_INTERNAL   2
#define SWITCH_SUBORD     6
#define NUM_PORTS         4

#define WINDOW_BASE       0x10000000
#define WINDOW_SIZE       0x00100000

// Result markers written to PCIE_TX_DATA
#define RESULT_PASS        0x0000FACE // every endpoint that was found passed
#define RESULT_FAIL        0x0000DEAD // an endpoint failed its memory readback
#define RESULT_NO_SWITCH   0xBAD00000 // the switch upstream port did not answer
#define RESULT_NO_DEVICE   0xBAD00001 // switch is up but no endpoint was found
// RESULT_CFG_FAILED  0xBAD00002    a config request to a found device failed (pcie.h)
#define RESULT_BAR0_FAILED 0xBAD00003 // an endpoint BAR0 is missing, I/O, or
                                      // larger than its 1 MB port window

// Downstream port device numbers and the bus number handed to each of them
static const uint8_t port_dev[NUM_PORTS] = { 1, 3, 5, 7 };
static const uint8_t port_bus[NUM_PORTS] = { 3, 4, 5, 6 };

// A device is there when it answers the ID read with SC. Behind a switch an
// empty slot is answered with UR by the downstream port.
static int device_present(uint32_t bus, uint32_t dev) {
    uint32_t id;

    if (cfg_read32(bus, dev, CFG_ID, &id) != CPL_STAT_SC) {
        return 0;
    }
    return (id != 0xFFFFFFFF) && (id != 0x00000000);
}

//--------------------------------------------------------------------------
// Bridge (Type 1) header helpers
//--------------------------------------------------------------------------

// Register 0x18: byte 0 = primary, byte 1 = secondary, byte 2 = subordinate
static void bridge_set_buses(uint32_t bus, uint32_t dev,
                             uint8_t primary, uint8_t secondary, uint8_t subordinate) {
    cfg_write32(bus, dev, CFG_BUS_NUMBERS,
                ((uint32_t)subordinate << 16) |
                ((uint32_t)secondary   <<  8) |
                ((uint32_t)primary));
}

// Register 0x20: [15:0] memory base, [31:16] memory limit. In both halves it is
// bits [15:4] that carry address bits [31:20], so the window granularity is
// 1 MB and the low nibble is read-only. The limit is inclusive -- it names the
// last megabyte still inside the window, not the first one outside it.
static void bridge_set_window(uint32_t bus, uint32_t dev,
                              uint32_t base, uint32_t size) {
    uint32_t base_field  = (base >> 16) & 0xFFF0;
    uint32_t limit_field = ((base + size - 1) >> 16) & 0xFFF0;

    cfg_write32(bus, dev, CFG_MEM_LIMITS, (limit_field << 16) | base_field);
}

int main() {

    tx_tag = 0;

    wait_cycles(STARTUP_DELAY);

    //----------------------------------------------------------------------
    // STEP 1: switch upstream port -- bus 1, device 0
    // Reached with Type 0 requests; it captures bus number 1 from them.
    //----------------------------------------------------------------------
    if (!device_present(SWITCH_BUS, 0)) {
        halt(RESULT_NO_SWITCH);
    }

    // Primary 1 (link towards the RC), secondary 2 (internal bus),
    // subordinate 6 (highest bus number behind this port)
    bridge_set_buses(SWITCH_BUS, 0, SWITCH_BUS, SWITCH_INTERNAL, SWITCH_SUBORD);

    // One window covering all four downstream windows: 0x10000000 - 0x103FFFFF
    bridge_set_window(SWITCH_BUS, 0, WINDOW_BASE, NUM_PORTS * WINDOW_SIZE);

    cfg_write32(SWITCH_BUS, 0, CFG_COMMAND, CMD_MEM_BUS_MASTER);

    //----------------------------------------------------------------------
    // STEP 2: the four downstream ports on the internal bus 2
    // Each is a virtual PCI-to-PCI bridge and gets its own secondary bus and
    // its own 1 MB memory window carved out of the upstream window.
    //----------------------------------------------------------------------
    for (int p = 0; p < NUM_PORTS; p++) {
        uint32_t base = WINDOW_BASE + (uint32_t)p * WINDOW_SIZE;

        bridge_set_buses(SWITCH_INTERNAL, port_dev[p],
                         SWITCH_INTERNAL, port_bus[p], port_bus[p]);

        bridge_set_window(SWITCH_INTERNAL, port_dev[p], base, WINDOW_SIZE);

        cfg_write32(SWITCH_INTERNAL, port_dev[p], CFG_COMMAND, CMD_MEM_BUS_MASTER);
    }

    //----------------------------------------------------------------------
    // STEP 3: the endpoint cards, one per downstream port, always device 0 on
    // the secondary bus of that port. Slots may be empty, so each one is
    // probed first and silently skipped when there is no answer.
    //----------------------------------------------------------------------
    uint32_t ep_bar0[NUM_PORTS]; // 0 = slot empty
    int      found = 0;

    for (int p = 0; p < NUM_PORTS; p++) {
        uint32_t base = WINDOW_BASE + (uint32_t)p * WINDOW_SIZE;

        ep_bar0[p] = 0;
        if (!device_present(port_bus[p], 0)) {
            continue;
        }

        // The BARs have to land inside the window the port forwards, otherwise
        // the downstream port drops every memory request aimed at them.
        ep_bar0[p] = assign_bars(port_bus[p], 0, base, WINDOW_SIZE);
        if (ep_bar0[p] == 0) {
            halt(RESULT_BAR0_FAILED);
        }

        cfg_write32(port_bus[p], 0, CFG_COMMAND, CMD_MEM_BUS_MASTER);

        found++;
    }

    if (found == 0) {
        halt(RESULT_NO_DEVICE);
    }

    //----------------------------------------------------------------------
    // STEP 4: memory write / readback through the switch, one endpoint at a
    // time. This is the same self-test the direct build runs, repeated for
    // every populated slot.
    //----------------------------------------------------------------------
    uint32_t test_data = 0x00000006;
    int      failures  = 0;

    for (int p = 0; p < NUM_PORTS; p++) {
        uint32_t readback;

        if (ep_bar0[p] == 0) {
            continue;
        }

        pcie_mem_write(ep_bar0[p], test_data);

        if (pcie_mem_read(ep_bar0[p], &readback) != CPL_STAT_SC ||
            readback != test_data) {
            failures++;
        }
    }

    if (failures == 0) {
        halt(RESULT_PASS);
    } else {
        halt(RESULT_FAIL);
    }
}

//--------------------------------------------------------------------------
// Revision history:
//  2026/07/31 AV - initial creation, derived from the RC-direct firmware
//  2026/10/06    - Completion Status checked on every request (CRS retry on
//                  config writes too), real BAR sizing inside the port window
//--------------------------------------------------------------------------
