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
//   - User test program for pcievhost endpoint at node 1
//==========================================================================

//=============================================================
// VUserMain1.cpp
//=============================================================

#include <stdio.h>
#include <stdlib.h>

#include "VProcClass.h"
#include "pcieModelClass.h"

extern "C" {
#include "ltssm.h"
}

#define RST_DEASSERT_INT 4

static unsigned int Interrupt = 0;

//-------------------------------------------------------------
// ResetDeasserted()
//
// ISR for reset de-assertion. Clears interrupts state.
//
//-------------------------------------------------------------

static int ResetDeasserted(int irq)
{
    Interrupt |= irq & RST_DEASSERT_INT;

    return 0;
}

//-------------------------------------------------------------
// VUserInput_1()
//
// Consumes the unhandled input Packets
//-------------------------------------------------------------

static void VUserInput_1(pPkt_t pkt, int status, void* usrptr)
{
    int idx;

    if (pkt->seq == DLLP_SEQ_ID)
    {
        DebugVPrint("---> VUserInput_1 received DLLP\n");
    }
    else
    {
        DebugVPrint("---> VUserInput_1 received TLP sequence %d of %d bytes at %d\n", pkt->seq, GET_TLP_LENGTH(pkt->data), pkt->TimeStamp);
    }

    // Once packet is finished with, the allocated space *must* be freed.
    // All input packets have their own memory space to avoid overwrites
    // which shared buffers.
    DISCARD_PACKET(pkt);
}

//-------------------------------------------------------------
// ConfigureType0PcieCfg()
//
// Configure the configuartion space buffer for an endpoint
// (type 0) PCIe configuration space with PCI compatible header,
// PCIe capabilities, MSI capabilities and Power managment
// capabilities, along with some default values.
//
//-------------------------------------------------------------

static void ConfigureType0PcieCfg (pcieModelClass *pcie)
{
    unsigned        next_cap_ptr = 0;

    // -------------------------------------
    // PPCI compatible header
    // -------------------------------------

    cfg_spc_type0_t     type0;
    cfg_spc_type0_t     type0_mask;
    cfg_spc_pcie_caps_t pcie_caps;
    cfg_spc_pcie_caps_t pcie_caps_mask;
    cfg_spc_msi_caps_t  msi_caps;
    cfg_spc_msi_caps_t  msi_caps_mask;
    pwr_mgmnt_caps_t    pwr_mgmnt_caps;
    pwr_mgmnt_caps_t    pwr_mgmnt_caps_mask;

    // Default to all zeros and read-only
    for (int idx = 0; idx < (CFG_PCI_HDR_SIZE_BYTES/4); idx++)
    {
        type0.words[idx]      = 0x00000000;
        type0_mask.words[idx] = 0xffffffff;
    }

    next_cap_ptr += CFG_PCI_HDR_SIZE_BYTES;

    // Construct PCI compatible structure value, and set writable bits where appropriate
    type0.type0_struct.vendor_id               = 0x14fc;
    type0.type0_struct.device_id               = 0x0002;
    type0.type0_struct.command                 = 0x0006;     type0_mask.type0_struct.command = 0xfab8;
    type0.type0_struct.status                  = 0x0010;
    type0.type0_struct.revision_id             = 0x01;
    type0.type0_struct.prog_if                 = 0x00;       // don't care
    type0.type0_struct.subclass                = 0x80;       // other
    type0.type0_struct.class_code              = 0x02;       // network controller
    type0.type0_struct.cache_line_size         = 0x00;       type0_mask.type0_struct.cache_line_size         = 0x00;
    type0.type0_struct.bar[0]                  = 0x00000008; type0_mask.type0_struct.bar[0]                  = 0x00000fff; // 32-bit, prefetchable, 4K
    type0.type0_struct.bar[1]                  = 0x00000008; type0_mask.type0_struct.bar[1]                  = 0x000003ff; // 32-bit, prefetchable, 1K
    type0.type0_struct.bar[2]                  = 0x0000000c; type0_mask.type0_struct.bar[2]                  = 0xffffffff; // 64-bit, prefetchable
    type0.type0_struct.bar[3]                  = 0x00000000; type0_mask.type0_struct.bar[3]                  = 0x00000001; // 8G
    type0.type0_struct.bar[4]                  = 0x00000000; type0_mask.type0_struct.bar[4]                  = 0xffffffff; // Disabled
    type0.type0_struct.bar[5]                  = 0x00000000; type0_mask.type0_struct.bar[5]                  = 0xffffffff; // Disabled
    type0.type0_struct.expansion_rom_base_addr = 0x00000000; type0_mask.type0_struct.expansion_rom_base_addr = 0x000007fe;
    type0.type0_struct.capabilities_ptr        = next_cap_ptr;

    // Update config space and mask with values
    for (int idx = 0; idx < (CFG_PCI_HDR_SIZE_BYTES/4); idx++)
    {
        pcie->writeConfigSpace     (next_cap_ptr - CFG_PCI_HDR_SIZE_BYTES + idx*4, type0.words[idx]);
        pcie->writeConfigSpaceMask (next_cap_ptr - CFG_PCI_HDR_SIZE_BYTES + idx*4, type0_mask.words[idx]);
    }

    // -------------------------------------
    // PCIe capability
    // -------------------------------------

    // Default to all zeros and read-only
    for (int idx = 0; idx < (CFG_PCIE_CAPS_SIZE_BYTES/4); idx++)
    {
        pcie_caps.words[idx]      = 0x00000000;
        pcie_caps_mask.words[idx] = 0xffffffff;
    }

    next_cap_ptr += CFG_PCIE_CAPS_SIZE_BYTES;

    pcie_caps.pcie_caps_struct.cap_id         = 0x10;
    pcie_caps.pcie_caps_struct.next_cap_ptr   = next_cap_ptr;
    pcie_caps.pcie_caps_struct.device_caps    = 0x00000001;   // max payload = 256 bytes
    pcie_caps.pcie_caps_struct.device_control = 0x2810;       pcie_caps_mask.pcie_caps_struct.device_control = 0x0000;
    pcie_caps.pcie_caps_struct.link_caps      = 0x0003fc12;
    pcie_caps.pcie_caps_struct.link_control   = 0x0000;       pcie_caps_mask.pcie_caps_struct.link_control   = 0xf004;
    pcie_caps.pcie_caps_struct.link_status    = 0x0091;
    pcie_caps.pcie_caps_struct.link_control2  = 0x0002;       pcie_caps_mask.pcie_caps_struct.link_control2  = 0xe06f;

    for (int idx = 0; idx < (CFG_PCIE_CAPS_SIZE_BYTES/4); idx++)
    {
        pcie->writeConfigSpace     (next_cap_ptr - CFG_PCIE_CAPS_SIZE_BYTES + idx*4, pcie_caps.words[idx]);
        pcie->writeConfigSpaceMask (next_cap_ptr - CFG_PCIE_CAPS_SIZE_BYTES + idx*4, pcie_caps_mask.words[idx]);
    }

    // -------------------------------------
    // MSI capability
    // -------------------------------------

    // Default to all zeros and read-only
    for (int idx = 0; idx < (CFG_MSI_CAPS_SIZE_BYTES/4); idx++)
    {
        msi_caps.words[idx]      = 0x00000000;
        msi_caps_mask.words[idx] = 0xffffffff;
    }

    next_cap_ptr += CFG_MSI_CAPS_SIZE_BYTES;

    msi_caps.msi_caps_struct.cap_id           = 0x05;
    msi_caps.msi_caps_struct.next_cap_ptr     = next_cap_ptr;
    msi_caps.msi_caps_struct.mess_control     = 0x0080;     msi_caps_mask.msi_caps_struct.mess_control = 0xff8e;
    msi_caps.msi_caps_struct.mess_addr_lo     = 0x00000000; msi_caps_mask.msi_caps_struct.mess_addr_lo = 0x00000003;
    msi_caps.msi_caps_struct.mess_addr_hi     = 0x00000000; msi_caps_mask.msi_caps_struct.mess_addr_hi = 0x00000000;
    msi_caps.msi_caps_struct.mess_data        = 0x0000;     msi_caps_mask.msi_caps_struct.mess_data    = 0x0000;
    msi_caps.msi_caps_struct.mask             = 0x00000000; msi_caps_mask.msi_caps_struct.mask         = 0x00000000;
    msi_caps.msi_caps_struct.pending          = 0x00000000;

    for (int idx = 0; idx < (CFG_MSI_CAPS_SIZE_BYTES/4); idx++)
    {
        pcie->writeConfigSpace     (next_cap_ptr - CFG_MSI_CAPS_SIZE_BYTES + idx*4, msi_caps.words[idx]);
        pcie->writeConfigSpaceMask (next_cap_ptr - CFG_MSI_CAPS_SIZE_BYTES + idx*4, msi_caps_mask.words[idx]);
    }

    // -------------------------------------
    // Power managment capability
    // -------------------------------------

    // Default to all zeros and read-only
    for (int idx = 0; idx < (CFG_PWR_MGMT_CAPS_SIZE_BYTES/4); idx++)
    {
        pwr_mgmnt_caps.words[idx]      = 0x00000000;
        pwr_mgmnt_caps_mask.words[idx] = 0xffffffff;
    }

    next_cap_ptr += CFG_PWR_MGMT_CAPS_SIZE_BYTES;

    pwr_mgmnt_caps.pwr_mgmnt_caps_struct.cap_id                   = 0x01;
    pwr_mgmnt_caps.pwr_mgmnt_caps_struct.next_cap_ptr             = 0x00; // last capability
    pwr_mgmnt_caps.pwr_mgmnt_caps_struct.pwr_mgmnt_caps           = 0x0003;
    pwr_mgmnt_caps.pwr_mgmnt_caps_struct.pwr_mgmnt_control_status = 0x0008;  pwr_mgmnt_caps_mask.pwr_mgmnt_caps_struct.pwr_mgmnt_control_status = 0xe0fc;

    for (int idx = 0; idx < (CFG_PWR_MGMT_CAPS_SIZE_BYTES/4); idx++)
    {
        pcie->writeConfigSpace     (next_cap_ptr - CFG_PWR_MGMT_CAPS_SIZE_BYTES + idx*4, pwr_mgmnt_caps.words[idx]);
        pcie->writeConfigSpaceMask (next_cap_ptr - CFG_PWR_MGMT_CAPS_SIZE_BYTES + idx*4, pwr_mgmnt_caps_mask.words[idx]);
    }
}

//-------------------------------------------------------------
// VUserMain1()
//
// Endpoint program Initialises link and FC
// before sending idles indefinitely.
//
//-------------------------------------------------------------

extern "C" void VUserMain1(int node)
{
    // Create VProc API object for this node
    VProc* vp1 = new VProc(node);
    
    // Create pcievhost API object for this node
    pcieModelClass *pcie = new pcieModelClass(node);

    // Initialise PCIe VHost, with input callback function and no user pointer.
    pcie->initialisePcie(VUserInput_1, NULL);

    // Make sure the link is out of electrical idle
    vp1->write(LINK_STATE, 0);
    
    // Configure for a pipe
    pcie->configurePcie(CONFIG_DISABLE_SCRAMBLING);
    pcie->configurePcie(CONFIG_DISABLE_8B10B);
    
    //Marke DUT as node 2
    pcie->configurePcie(CONFIG_DISP_BCK_NODE_NUM, 2);

    DebugVPrint("VUserMain: in node %d\n", node);

    vp1->regIrq(ResetDeasserted);

    // Use node number as seed
    pcie->pcieSeed(node);

    // Construct an endpoint PCIe configuration space
    ConfigureType0PcieCfg(pcie);

    // Send out idles until we recieve an interrupt
    do
    {
        pcie->sendOs(IDL);
    }
    while (!Interrupt);

    Interrupt &= ~RST_DEASSERT_INT;

    // Initialise the link for 1 lane
    InitLink(1, node);

    // Initialise DLLP flow control
    pcie->initFc();

    // Send out idels forever
    while (true)
    {
        pcie->sendIdle(100);
    }
}

