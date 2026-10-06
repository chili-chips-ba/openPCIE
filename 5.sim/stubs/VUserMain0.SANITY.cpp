// SPDX-FileCopyrightText: 2025 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// Copyright (c) 2025 Chili.CHIPS
//--------------------------------------------------------------------------
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