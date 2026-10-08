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
//==========================================================================

#include "pcie.h"

// Memory window the endpoint BARs are placed in: the upper 2 GB of the 32-bit
// space. BAR0 lands at its base, so the self-test address stays 0x80000000.
#define WINDOW_BASE      0x80000000
#define WINDOW_SIZE      0x80000000

// Result markers written to PCIE_TX_DATA
#define RESULT_PASS        0x0000FACE // data 0x6 was written and read back
#define RESULT_FAIL        0x0000DEAD // the readback did not match, or failed
#define RESULT_NO_DEVICE   0xBAD00000 // no endpoint answered the first config read
// RESULT_CFG_FAILED  0xBAD00002    a config request to the endpoint failed (pcie.h)
#define RESULT_BAR0_FAILED 0xBAD00003 // BAR0 is missing, I/O, or does not fit

int main() {

	tx_tag = 0;

	wait_cycles(STARTUP_DELAY);

    uint32_t dev_id;

    if (cfg_read32(1, 0, CFG_ID, &dev_id) != CPL_STAT_SC || dev_id == 0xFFFFFFFF) {
        halt(RESULT_NO_DEVICE);
    }

    uint32_t test_addr = assign_bars(1, 0, WINDOW_BASE, WINDOW_SIZE);

    if (test_addr == 0) {
        halt(RESULT_BAR0_FAILED);
    }

    cfg_write32(1, 0, CFG_COMMAND, CMD_MEM_BUS_MASTER);

	uint32_t test_data = 0x00000006;
    uint32_t readback;

    pcie_mem_write(test_addr, test_data);

    if (pcie_mem_read(test_addr, &readback) == CPL_STAT_SC && readback == test_data) {
        halt(RESULT_PASS);
    } else {
        halt(RESULT_FAIL);
    }
}

//--------------------------------------------------------------------------
// Revision history:
//  2026/02/01 AV - initial creation
//  2026/02/20 AV - updates based on test results on hardware
//  2026/10/06    - Completion Status checked on every request (CRS retry on
//                  config writes too), real BAR sizing, explicit byte swap
//--------------------------------------------------------------------------
