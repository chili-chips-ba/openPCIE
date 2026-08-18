//==========================================================================
// Copyright (c) 2025 Chili.CHIPS*ba
//--------------------------------------------------------------------------
//                      PROPRIETARY INFORMATION
//
// The information contained in this file is the property of CHILI CHIPS LLC.
// Except as specifically authorized in writing by CHILI CHIPS LLC, the holder
// of this file: (1) shall keep all information contained herein confidential;
// and (2) shall protect the same in whole or in part from disclosure and
// dissemination to all third parties; and (3) shall use the same for operation
// and maintenance purposes only.
//--------------------------------------------------------------------------
// Description:
//   - User sanity test program for soc_cpu.VPROC at node 0
//==========================================================================

//=============================================================
// VUserMain0.cpp
//=============================================================

#include <stdio.h>
#include <stdint.h>

#include "VProcClass.h"

extern "C" {
#include "mem.h"
}

// ----------------------------------------------------------------------------
// VProc node 0 main entry point
// ----------------------------------------------------------------------------

extern "C" void VUserMain0(int node)
{
    VPrint("VProc soc_cpu entered VUserMain%d()\n\n", node);
    
    // Create VProc access object for this node
    VProc* vp0 = new VProc(node);
    
    // Wait a bit
    vp0->tick(100);
    
    uint32_t addr  = 0x10001000;
    uint32_t wdata = 0x900dc0de;
    
    vp0->write(addr, wdata);
    VPrint("Written   0x%08x  to  addr 0x%08x\n", wdata, addr);
    
    vp0->tick(3);
    
    uint32_t rdata;
    vp0->read(addr, &rdata);
    
    if (rdata == wdata)
    {
        VPrint("Read back 0x%08x from addr 0x%08x\n", rdata, addr);
    }
    else
    {   
        VPrint("***ERROR: data mis-match at addr = 0x%08x. Got 0x%08x, expected 0x%08x\n", addr, rdata, wdata);
    }

    // Sleep forever (and allow simulation to continue)
    while(true)
        vp0->tick(GO_TO_SLEEP);
}