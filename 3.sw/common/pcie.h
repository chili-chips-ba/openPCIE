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
//   PCIe request layer shared by the RC-direct and RC-switched firmware:
//   CSR access, TLP send / Completion wait with status, CRS retry,
//   configuration helpers and BAR sizing. Each main.c adds only its own
//   topology walk.
//==========================================================================

#ifndef OPENPCIE_PCIE_H
#define OPENPCIE_PCIE_H

#include <stdint.h>

// -------------------------------------------------------------------------
// CSR access: register offsets and field positions come from the headers
// PeakRDL generates out of 4.build/csr_build/csr.rdl, so hardware and
// software cannot drift apart.
// -------------------------------------------------------------------------
#include "csr_regs.h"

#define PCIE_TX_HEADER0      CSR_REG32(tx.header0)
#define PCIE_TX_HEADER1      CSR_REG32(tx.header1)
#define PCIE_TX_HEADER2      CSR_REG32(tx.header2)
#define PCIE_TX_DATA         CSR_REG32(tx.data)

#define PCIE_RX_STATUS       CSR_REG32(rx.status)
#define PCIE_RX_DATA         CSR_REG32(rx.data)
#define PCIE_RX_HEADER_INFO  CSR_REG32(rx.header_info)
#define PCIE_ERR_STATUS      CSR_REG32(status.err)
#define PCIE_PHY_STATUS      CSR_REG32(status.phy)
#define PCIE_RESULT          CSR_REG32(status.result)

// Field masks and positions come from the generated csr.h, via RDL_FIELD()
#define TX_STATE_MASK        CSR__STATUS__PHY__TX_STATE_bm
#define TX_BUF_MASK          CSR__STATUS__PHY__TX_BUF_AVAIL_bm

#define RX_REQUESTER_ID(hdr) RDL_FIELD(hdr, CSR__RX__HEADER_INFO__REQUESTER_ID)
#define RX_TAG(hdr)          RDL_FIELD(hdr, CSR__RX__HEADER_INFO__TAG)


#define MY_REQUESTER_ID  0x10EE

#define TLP_CFG_WR0 0x44000000
#define TLP_CFG_RD0 0x04000000
#define TLP_MEM_WR  0x40000000
#define TLP_MEM_RD  0x00000000

#define CPL_STAT_SC  0 // Successful
#define CPL_STAT_UR  1 // Unsupported Request
#define CPL_STAT_CRS 2 // Configuration Retry Status (Busy)
#define CPL_STAT_CA  4 // Completer Abort
#define CPL_TIMEOUT  8 // not a PCIe status: no Completion arrived in time

// Polls of rx.header_info before giving up. The simulation builds shorten it,
// so a lost Completion ends as 0xBAD00002 within the run, not as a time-out.
#ifndef CPL_POLL_LIMIT
#define CPL_POLL_LIMIT 2000000
#endif
#define CRS_RETRIES    100     // re-issues of a request answered with CRS

// Configuration space offsets
#define CFG_ID           0x00 // Device ID / Vendor ID
#define CFG_COMMAND      0x04
#define CFG_BAR0         0x10
#define CFG_BUS_NUMBERS  0x18 // primary / secondary / subordinate
#define CFG_MEM_LIMITS   0x20 // memory base and limit of the bridge window
#define NUM_BARS         6

#define CMD_MEM_BUS_MASTER 0x00000006 // Memory Space Enable + Bus Master Enable

// Stops the firmware: any status other than SC on a checked config access
#define RESULT_CFG_FAILED  0xBAD00002

// Cycles to idle at start-up, waiting for the PCIe link to finish training.
// On hardware that wait is unavoidable. In co-simulation the link is already up
// by the time the SOC leaves reset, and this loop -- compiled without
// optimisation -- costs about 37 ms of simulated time on eduBOS5, so the simulation build
// shortens it:  make SIM=1  in 4.build/sw_build.
#ifndef STARTUP_DELAY
#define STARTUP_DELAY 100000
#endif

extern uint8_t tx_tag;

void wait_cycles(int n);
__attribute__((noreturn)) void halt(uint32_t marker);
void send_tlp(uint32_t h0, uint32_t h1, uint32_t h2, uint32_t data);
uint32_t wait_for_completion(uint8_t tag, uint32_t *data);
uint32_t pcie_request(uint32_t type, uint32_t addr_or_id, uint32_t wdata, uint32_t *rdata);
uint32_t pcie_cfg_write(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg, uint32_t val);
uint32_t pcie_cfg_read(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg, uint32_t *val);
void pcie_mem_write(uint32_t addr, uint32_t val);
uint32_t pcie_mem_read(uint32_t addr, uint32_t *val);
uint32_t bswap32(uint32_t v);
void cfg_write32(uint32_t bus, uint32_t dev, uint32_t reg, uint32_t val);
uint32_t cfg_read32(uint32_t bus, uint32_t dev, uint32_t reg, uint32_t *val);
uint32_t cfg_read32_checked(uint32_t bus, uint32_t dev, uint32_t reg);
uint32_t assign_bars(uint32_t bus, uint32_t dev, uint32_t win_base, uint32_t win_size);

#endif // OPENPCIE_PCIE_H

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
