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
//   PCIe request layer shared by the RC-direct and RC-switched firmware.
//   See pcie.h.
//==========================================================================

#include "pcie.h"

uint8_t tx_tag;

void wait_cycles(int n) {
    for (int i = 0; i < n; i++) __asm__("nop");
}

__attribute__((noreturn)) void halt(uint32_t marker) {
    PCIE_TX_DATA = marker;
    while (1) {}
}

void send_tlp(uint32_t h0, uint32_t h1, uint32_t h2, uint32_t data) {
    while (((PCIE_PHY_STATUS & TX_STATE_MASK) != 0) ||
           ((PCIE_PHY_STATUS & TX_BUF_MASK) == 0));

    PCIE_TX_HEADER0 = h0;
    PCIE_TX_HEADER1 = h1;
    PCIE_TX_HEADER2 = h2;
    PCIE_TX_DATA = data;
}

// Waits for the Completion carrying `tag` and returns its Completion Status
// (CPL_STAT_*), or CPL_TIMEOUT. The payload is stored to *data only on SC, so
// a genuine 0xFFFFFFFF read can no longer be mistaken for an error.
uint32_t wait_for_completion(uint8_t tag, uint32_t *data) {
    volatile int timeout = CPL_POLL_LIMIT;

    while (timeout > 0) {
        uint32_t raw_header = PCIE_RX_HEADER_INFO;
        uint16_t rx_req_id = RX_REQUESTER_ID(raw_header);
        uint8_t  rx_tag    = RX_TAG(raw_header);

        if (rx_req_id == MY_REQUESTER_ID && rx_tag == tag) {
            uint32_t rx_status = PCIE_RX_STATUS;

            if (rx_status == CPL_STAT_SC && data) {
                *data = PCIE_RX_DATA;
            }
            return rx_status;
        }
        timeout--;
    }
    return CPL_TIMEOUT;
}

// Sends one non-posted request and waits for its Completion. A device that is
// still initialising may answer a Configuration Request -- read or write --
// with CRS; the request is then re-issued, with a fresh tag, up to CRS_RETRIES
// times. Returns the final Completion Status.
uint32_t pcie_request(uint32_t type, uint32_t addr_or_id, uint32_t wdata, uint32_t *rdata) {
    uint32_t status = CPL_TIMEOUT;

    for (int retry_count = 0; retry_count <= CRS_RETRIES; retry_count++) {

        uint8_t current_tag = tx_tag++;

        send_tlp(type | 0x01,
                 (MY_REQUESTER_ID << 16) | (current_tag << 8) | 0x0F,
                 addr_or_id & 0xFFFFFFFC,
                 wdata);

        status = wait_for_completion(current_tag, rdata);

        if (status != CPL_STAT_CRS) {
            break;
        }
        wait_cycles(1000);
    }
    return status;
}

uint32_t pcie_cfg_write(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg, uint32_t val) {
    uint32_t id = (bus << 24) | (dev << 19) | (func << 16) | (reg & 0xFC);
    return pcie_request(TLP_CFG_WR0, id, val, 0);
}

uint32_t pcie_cfg_read(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg, uint32_t *val) {
    uint32_t id = (bus << 24) | (dev << 19) | (func << 16) | (reg & 0xFC);
    return pcie_request(TLP_CFG_RD0, id, 0, val);
}

void pcie_mem_write(uint32_t addr, uint32_t val) {
	uint8_t tag = tx_tag++;

    // Posted -- no Completion to wait for
    send_tlp(TLP_MEM_WR | 0x01,
             (MY_REQUESTER_ID << 16) | (tag << 8) | 0x0F,
             addr & 0xFFFFFFFC,
             val);
}

uint32_t pcie_mem_read(uint32_t addr, uint32_t *val) {
    return pcie_request(TLP_MEM_RD, addr, 0, val);
}

//--------------------------------------------------------------------------
// Configuration space payloads travel big-endian: byte 0 of the register ends
// up in bits [31:24] of the data dword. The two helpers below swap on the way
// in and out, so every value in the firmware is written the way the spec prints
// it (BAR 0x80000000, not 0x00000080).
//
// cfg_write32() is the checked write: any status other than SC stops the
// firmware with RESULT_CFG_FAILED.
//--------------------------------------------------------------------------
uint32_t bswap32(uint32_t v) {
    return ((v & 0x000000FFu) << 24) |
           ((v & 0x0000FF00u) <<  8) |
           ((v & 0x00FF0000u) >>  8) |
           ((v & 0xFF000000u) >> 24);
}

void cfg_write32(uint32_t bus, uint32_t dev, uint32_t reg, uint32_t val) {
    if (pcie_cfg_write(bus, dev, 0, reg, bswap32(val)) != CPL_STAT_SC) {
        halt(RESULT_CFG_FAILED);
    }
}

uint32_t cfg_read32(uint32_t bus, uint32_t dev, uint32_t reg, uint32_t *val) {
    uint32_t raw;
    uint32_t status = pcie_cfg_read(bus, dev, 0, reg, &raw);

    if (status == CPL_STAT_SC) {
        *val = bswap32(raw);
    }
    return status;
}

// The checked read, for a device already known to be there
uint32_t cfg_read32_checked(uint32_t bus, uint32_t dev, uint32_t reg) {
    uint32_t val;

    if (cfg_read32(bus, dev, reg, &val) != CPL_STAT_SC) {
        halt(RESULT_CFG_FAILED);
    }
    return val;
}

//--------------------------------------------------------------------------
// BAR sizing and assignment. For each of the six BARs:
//   - write all ones, read back; 0 means the BAR is not implemented
//   - bit 0 set: I/O BAR. This RC has no I/O space -- left unassigned
//   - bits [2:1] = 10: 64-bit BAR, the next BAR holds the upper half
//   - size = ~(readback & ~0xF) + 1, the base is aligned to it
// BARs are packed into [win_base, win_base + win_size) in order. One that does
// not fit is not squeezed in but parked out of the way: a 64-bit BAR above
// 4 GB (out of reach of the 3-DW requests this RC sends), a 32-bit one at 0,
// below every window. Only BAR0 is used by the self-test.
//
// Memory decoding is switched off while the BARs move.
// Returns the address given to BAR0, or 0 when BAR0 could not be placed.
//--------------------------------------------------------------------------
uint32_t assign_bars(uint32_t bus, uint32_t dev,
                            uint32_t win_base, uint32_t win_size) {
    uint32_t next     = 0; // first free offset inside the window
    uint32_t bar0     = 0;

    cfg_write32(bus, dev, CFG_COMMAND, 0);

    for (int i = 0; i < NUM_BARS; i++) {
        uint32_t reg = CFG_BAR0 + 4 * i;

        cfg_write32(bus, dev, reg, 0xFFFFFFFF);
        uint32_t lo = cfg_read32_checked(bus, dev, reg);

        if (lo == 0) {
            continue;                             // not implemented
        }
        if (lo & 0x1) {
            cfg_write32(bus, dev, reg, 0);        // I/O -- left unassigned
            continue;
        }

        int      is64 = (((lo >> 1) & 0x3) == 0x2) && (i < NUM_BARS - 1);
        uint32_t hi   = 0xFFFFFFFF;               // upper half of the size mask

        if (is64) {
            cfg_write32(bus, dev, reg + 4, 0xFFFFFFFF);
            hi = cfg_read32_checked(bus, dev, reg + 4);
        }

        uint32_t size = ~(lo & 0xFFFFFFF0) + 1;   // 0 when 4 GB or more
        int      fits = 0;
        uint32_t base = 0;

        if (hi == 0xFFFFFFFF && size != 0 && size <= win_size) {
            base = (next + size - 1) & ~(size - 1);
            fits = (base <= win_size - size);
        }

        if (fits) {
            cfg_write32(bus, dev, reg, win_base + base);
            if (is64) {
                cfg_write32(bus, dev, reg + 4, 0);
            }
            next = base + size;
            if (i == 0) {
                bar0 = win_base + base;
            }
        } else if (is64) {
            // Base = size (aligned to itself), but never below 4 GB
            uint32_t park_hi = (hi == 0xFFFFFFFF) ? 1 : ~hi + 1;
            cfg_write32(bus, dev, reg, 0);
            cfg_write32(bus, dev, reg + 4, park_hi);
        } else {
            cfg_write32(bus, dev, reg, 0);
        }

        if (is64) {
            i++;                                  // upper half done
        }
    }
    return bar0;
}
