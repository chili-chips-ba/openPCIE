// SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   Native C++ CPU model for VProc node 0 -- the "CPU=vproc" build.
//
//   This is the same bring-up sequence as the picorv32 firmware in
//   3.sw/RC-direct/main.c, but compiled for the host and executed directly by
//   VProc instead of being compiled for RISC-V and executed by an RTL core.
//   The DUT does not know the difference: the accesses arrive on the same
//   memory interface, at the same CSR addresses.
//
//   Register access goes through csr_cosim.h, which PeakRDL generates from
//   4.build/csr_build/csr.rdl -- the very same source of truth that produces
//   the register RTL and the firmware's csr.h. So this model cannot drift
//   away from the hardware either.
//
//   The result is reported the same way the firmware reports it, by writing a
//   marker to tx.data, which tb.sv watches for:
//
//     0x0000FACE  memory write/readback through PCIe succeeded
//     0x0000DEAD  readback mismatch
//     0xBAD00000  the endpoint never answered a config read
//==========================================================================

#include <stdio.h>
#include <stdint.h>

extern "C" {
#include "VUser.h"
}

#include "csr_cosim.h"

// -------------------------------------------------------------------------
// Same constants as the firmware
// -------------------------------------------------------------------------
#define MY_REQUESTER_ID  0x10EE

#define TLP_CFG_WR0      0x44000000
#define TLP_CFG_RD0      0x04000000
#define TLP_MEM_WR       0x40000000
#define TLP_MEM_RD       0x00000000

#define CPL_STAT_SC      0   // Successful
#define CPL_STAT_UR      1   // Unsupported Request
#define CPL_STAT_CRS     2   // Configuration Retry Status (Busy)
#define CPL_STAT_CA      4   // Completer Abort

// Poll budget, in CSR reads rather than in CPU cycles. The firmware counts
// instructions because that is all it can do; here one iteration is one real
// bus read, so a far smaller number covers the same wall of time.
#define POLL_LIMIT       20000
#define CRS_RETRIES      100

#define RDL_GET(val, FLD)  (((val) & FLD##_bm) >> FLD##_bp)

static csr_vp_t* csr;
static uint8_t   tx_tag;

// -------------------------------------------------------------------------
// TLP transmit -- wait for the TX path to go idle and for the hard macro to
// have buffer credit, then write the three header dwords and the payload.
// Writing tx.data is what launches the packet (swmod in csr.rdl).
// -------------------------------------------------------------------------
static void send_tlp(uint32_t h0, uint32_t h1, uint32_t h2, uint32_t data)
{
    while (true)
    {
        uint32_t phy = csr->status->phy->full();

        if (RDL_GET(phy, CSR__STATUS__PHY__TX_STATE)  == 0 &&
            RDL_GET(phy, CSR__STATUS__PHY__TX_BUF_AV) != 0)
        {
            break;
        }
    }

    csr->tx->header0->full(h0);
    csr->tx->header1->full(h1);
    csr->tx->header2->full(h2);
    csr->tx->data->full(data);
}

// -------------------------------------------------------------------------
// Completion wait, with Configuration Retry handling, mirroring pcie_read()
// -------------------------------------------------------------------------
static uint32_t pcie_read(uint32_t type, uint32_t addr_or_id)
{
    for (int retry = 0; retry <= CRS_RETRIES; retry++)
    {
        uint8_t current_tag = tx_tag++;

        send_tlp(type | 0x01,
                 (MY_REQUESTER_ID << 16) | (current_tag << 8) | 0x0F,
                 addr_or_id & 0xFFFFFFFC,
                 0);

        int crs_received = 0;
        int timeout      = POLL_LIMIT;

        while (timeout > 0)
        {
            uint32_t raw_header = csr->rx->header_info->full();

            if (RDL_GET(raw_header, CSR__RX__HEADER_INFO__REQUESTER_ID) == MY_REQUESTER_ID &&
                RDL_GET(raw_header, CSR__RX__HEADER_INFO__TAG)          == current_tag)
            {
                uint32_t rx_status = csr->rx->status->cpl_status();

                if (rx_status == CPL_STAT_SC)
                {
                    return csr->rx->data->full();
                }

                if (rx_status == CPL_STAT_CRS)
                {
                    VTick(1000, SOC_CPU_VPNODE);
                    crs_received = 1;
                    break;
                }

                return 0xFFFFFFFF;
            }
            timeout--;
        }

        if (!crs_received && timeout <= 0)
        {
            return 0xFFFFFFFF;
        }
    }

    return 0xFFFFFFFF;
}

static void pcie_cfg_write(uint32_t bus, uint32_t dev, uint32_t func,
                           uint32_t reg, uint32_t val)
{
    uint8_t  tag = tx_tag++;
    uint32_t id  = (bus << 24) | (dev << 19) | (func << 16) | (reg & 0xFC);

    send_tlp(TLP_CFG_WR0 | 0x01,
             (MY_REQUESTER_ID << 16) | (tag << 8) | 0x0F,
             id, val);

    // Drain the completion the write generates, so it cannot be mistaken for
    // the answer to the next read.
    int timeout = POLL_LIMIT;
    while (timeout-- > 0)
    {
        uint32_t raw_header = csr->rx->header_info->full();

        if (RDL_GET(raw_header, CSR__RX__HEADER_INFO__REQUESTER_ID) == MY_REQUESTER_ID &&
            RDL_GET(raw_header, CSR__RX__HEADER_INFO__TAG)          == tag)
        {
            break;
        }
    }
}

static void pcie_mem_write(uint32_t addr, uint32_t val)
{
    uint8_t tag = tx_tag++;

    // Posted -- no completion to wait for
    send_tlp(TLP_MEM_WR | 0x01,
             (MY_REQUESTER_ID << 16) | (tag << 8) | 0x0F,
             addr & 0xFFFFFFFC,
             val);
}

static uint32_t pcie_cfg_read(uint32_t bus, uint32_t dev, uint32_t func, uint32_t reg)
{
    uint32_t id = (bus << 24) | (dev << 19) | (func << 16) | (reg & 0xFC);
    return pcie_read(TLP_CFG_RD0, id);
}

static uint32_t pcie_mem_read(uint32_t addr)
{
    return pcie_read(TLP_MEM_RD, addr);
}

// -------------------------------------------------------------------------
// VProc node 0 entry point -- the CPU
// -------------------------------------------------------------------------
extern "C" void VUserMain0(int node)
{
    VPrint("\n[CPU=vproc] native C++ CPU model entered on VProc node %d\n", node);

    csr    = new csr_vp_t((uint32_t*)0x30000000);
    tx_tag = 0;

    // No start-up delay. The firmware needs one because it cannot tell when
    // the link is up; here send_tlp() blocks on tx_buf_av, which stays zero
    // until the hard macro has trained, so the wait happens by itself.

    uint32_t dev_id = pcie_cfg_read(1, 0, 0, 0x00);
    VPrint("[CPU=vproc] config read bus 1 dev 0 reg 0x00 -> 0x%08x\n", dev_id);

    if (dev_id == 0xFFFFFFFF)
    {
        VPrint("[CPU=vproc] no endpoint responded\n");
        csr->tx->data->full(0xBAD00000);
        while (true) VTick(10000, SOC_CPU_VPNODE);
    }

    // BAR sizing, then place BAR0 at 0x80000000 (written byte-swapped, as the
    // configuration payload travels big-endian)
    pcie_cfg_write(1, 0, 0, 0x10, 0xFFFFFFFF);
    pcie_cfg_write(1, 0, 0, 0x14, 0xFFFFFFFF);

    pcie_cfg_write(1, 0, 0, 0x10, 0x00000080);
    pcie_cfg_write(1, 0, 0, 0x14, 0x00000000);

    // Memory Space Enable + Bus Master Enable
    pcie_cfg_write(1, 0, 0, 0x04, 0x06000000);

    uint32_t test_addr = 0x80000000;
    uint32_t test_data = 0x00000006;

    pcie_mem_write(test_addr, test_data);

    uint32_t readback = pcie_mem_read(test_addr);
    VPrint("[CPU=vproc] memory readback from 0x%08x -> 0x%08x (expected 0x%08x)\n",
           test_addr, readback, test_data);

    if (readback == test_data)
    {
        csr->tx->data->full(0x0000FACE);
    }
    else
    {
        csr->tx->data->full(0x0000DEAD);
    }

    // Keep the node alive so the simulation carries on to its own end
    while (true) VTick(10000, SOC_CPU_VPNODE);
}

/*
-----------------------------------------------------------------------------
Version History:
-----------------------------------------------------------------------------
 2026/08/16 AV: initial creation -- native C++ equivalent of 3.sw/RC-direct/main.c
                (the previous node-0 sanity test is kept in stubs/)
*/
