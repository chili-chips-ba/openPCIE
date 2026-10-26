// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   VProc node 0 for the "CPU=vproc" build: runs the real firmware natively.
//
//   The Makefile compiles 3.sw/common/pcie.c and 3.sw/RC-<VARIANT>/main.c for
//   the host, as C++, with main() renamed fw_main(). Their register accesses
//   (CSR_REG32 in csr_regs.h) become VProc bus cycles on the SOC's CPU
//   memory interface, at the same CSR addresses the RISC-V cores use. So
//   CPU=rtl, iss and vproc all run one firmware source; only the way it
//   executes differs.
//
//   No start-up delay is needed: send_tlp() waits for tx_buf_avail, which
//   stays zero until the hard macro has trained the link. The result marker
//   goes to status.result, which tb.sv watches, as on the RISC-V cores.
//==========================================================================

extern "C" {
#include "VUser.h"
}

int fw_main();

extern "C" void VUserMain0(int node)
{
    VPrint("\n[CPU=vproc] native firmware entered on VProc node %d\n", node);
    fw_main();
}

/*
-----------------------------------------------------------------------------
Version History:
-----------------------------------------------------------------------------
 2026/08/16 AV: initial creation -- native C++ equivalent of 3.sw/RC-direct/main.c
                (the previous node-0 sanity test is kept in stubs/)
 2026/10/06   : follows the firmware -- Completion Status checks, CRS retry on
                config writes, BAR sizing by readback
 2026/10/26   : runs the 3.sw firmware itself (RC-direct or RC-switched)
                instead of a hand-written copy of it
*/

// -----------------------------------------------------------------------------
// Project:     openPCIE
// Description: NLnet-sponsored open-source implementation
// Version:     1.0
// Date:        May 24, 2024
// -----------------------------------------------------------------------------
