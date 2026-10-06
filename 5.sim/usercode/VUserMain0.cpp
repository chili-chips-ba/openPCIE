// SPDX-FileCopyrightText: 2026 Chili.CHIPS
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
//     0x0000DEAD  readback mismatch, or the read was not completed with SC
//     0xBAD00000  the endpoint never answered a config read
//     0xBAD00002  a config request to the endpoint failed (UR/CA/timeout)
//     0xBAD00003  BAR0 is not implemented, is I/O, or does not fit
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
#define CPL_TIMEOUT      8   // not a PCIe status: no Completion arrived in time

// Poll budget, in CSR reads rather than in CPU cycles. The firmware counts
// instructions because that is all it can do; here one iteration is one real
// bus read, so a far smaller number covers the same wall of time.
#define POLL_LIMIT       20000
#define CRS_RETRIES      100

#define CFG_ID           0x00
#define CFG_COMMAND      0x04
#define CFG_BAR0         0x10
#define NUM_BARS         6

#define CMD_MEM_BUS_MASTER 0x00000006

#define WINDOW_BASE      0x80000000
#define WINDOW_SIZE      0x80000000

#define RESULT_PASS        0x0000FACE
#define RESULT_FAIL        0x0000DEAD
#define RESULT_NO_DEVICE   0xBAD00000
#define RESULT_CFG_FAILED  0xBAD00002
#define RESULT_BAR0_FAILED 0xBAD00003

#define RDL_GET(val, FLD)  (((val) & FLD##_bm) >> FLD##_bp)

static csr_vp_t* csr;
static uint8_t   tx_tag;

// -------------------------------------------------------------------------
// Report a result marker and park the node, so the simulation carries on to
// its own end
// -------------------------------------------------------------------------
[[noreturn]] static void halt(uint32_t marker)
{
    VPrint("[CPU=vproc] result marker 0x%08x\n", marker);
    csr->tx->data->full(marker);
    while (true) VTick(10000, SOC_CPU_VPNODE);
}

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
// Completion wait: returns the Completion Status, or CPL_TIMEOUT. The payload
// is stored only on SC.
// -------------------------------------------------------------------------
static uint32_t wait_for_completion(uint8_t tag, uint32_t* data)
{
    for (int timeout = POLL_LIMIT; timeout > 0; timeout--)
    {
        uint32_t raw_header = csr->rx->header_info->full();

        if (RDL_GET(raw_header, CSR__RX__HEADER_INFO__REQUESTER_ID) == MY_REQUESTER_ID &&
            RDL_GET(raw_header, CSR__RX__HEADER_INFO__TAG)          == tag)
        {
            uint32_t rx_status = csr->rx->status->cpl_status();

            if (rx_status == CPL_STAT_SC && data)
            {
                *data = csr->rx->data->full();
            }
            return rx_status;
        }
    }
    return CPL_TIMEOUT;
}

// -------------------------------------------------------------------------
// One non-posted request, re-issued with a fresh tag while it is answered
// with CRS -- mirroring pcie_request() in the firmware
// -------------------------------------------------------------------------
static uint32_t pcie_request(uint32_t type, uint32_t addr_or_id,
                             uint32_t wdata, uint32_t* rdata)
{
    uint32_t status = CPL_TIMEOUT;

    for (int retry = 0; retry <= CRS_RETRIES; retry++)
    {
        uint8_t current_tag = tx_tag++;

        send_tlp(type | 0x01,
                 (MY_REQUESTER_ID << 16) | (current_tag << 8) | 0x0F,
                 addr_or_id & 0xFFFFFFFC,
                 wdata);

        status = wait_for_completion(current_tag, rdata);

        if (status != CPL_STAT_CRS)
        {
            break;
        }
        VTick(1000, SOC_CPU_VPNODE);
    }
    return status;
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

static uint32_t pcie_mem_read(uint32_t addr, uint32_t* val)
{
    return pcie_request(TLP_MEM_RD, addr, 0, val);
}

// -------------------------------------------------------------------------
// Configuration access on bus 1, device 0. The payload travels big-endian,
// so it is byte-swapped on the way in and out; values here read the way the
// spec prints them. cfg_write32() and cfg_read32_checked() stop with
// RESULT_CFG_FAILED on anything but SC.
// -------------------------------------------------------------------------
static uint32_t bswap32(uint32_t v)
{
    return ((v & 0x000000FFu) << 24) | ((v & 0x0000FF00u) << 8) |
           ((v & 0x00FF0000u) >>  8) | ((v & 0xFF000000u) >> 24);
}

static uint32_t cfg_id(uint32_t reg)
{
    return (1u << 24) | (reg & 0xFC);
}

static uint32_t cfg_read32(uint32_t reg, uint32_t* val)
{
    uint32_t raw;
    uint32_t status = pcie_request(TLP_CFG_RD0, cfg_id(reg), 0, &raw);

    if (status == CPL_STAT_SC)
    {
        *val = bswap32(raw);
    }
    return status;
}

static uint32_t cfg_read32_checked(uint32_t reg)
{
    uint32_t val;

    if (cfg_read32(reg, &val) != CPL_STAT_SC)
    {
        halt(RESULT_CFG_FAILED);
    }
    return val;
}

static void cfg_write32(uint32_t reg, uint32_t val)
{
    if (pcie_request(TLP_CFG_WR0, cfg_id(reg), bswap32(val), nullptr) != CPL_STAT_SC)
    {
        halt(RESULT_CFG_FAILED);
    }
}

// -------------------------------------------------------------------------
// BAR sizing and assignment, as assign_bars() in the firmware: size each BAR
// by reading it back after writing all ones, pack the memory BARs into the
// window in order, each aligned to its size, and park any that do not fit
// (64-bit: above 4 GB, 32-bit: at 0). Returns the BAR0 address, 0 if none.
// -------------------------------------------------------------------------
static uint32_t assign_bars(uint32_t win_base, uint32_t win_size)
{
    uint32_t next = 0;
    uint32_t bar0 = 0;

    cfg_write32(CFG_COMMAND, 0);

    for (int i = 0; i < NUM_BARS; i++)
    {
        uint32_t reg = CFG_BAR0 + 4 * i;

        cfg_write32(reg, 0xFFFFFFFF);
        uint32_t lo = cfg_read32_checked(reg);

        if (lo == 0)
        {
            continue;
        }
        if (lo & 0x1)
        {
            cfg_write32(reg, 0);
            continue;
        }

        bool     is64 = (((lo >> 1) & 0x3) == 0x2) && (i < NUM_BARS - 1);
        uint32_t hi   = 0xFFFFFFFF;

        if (is64)
        {
            cfg_write32(reg + 4, 0xFFFFFFFF);
            hi = cfg_read32_checked(reg + 4);
        }

        uint32_t size = ~(lo & 0xFFFFFFF0) + 1;
        bool     fits = false;
        uint32_t base = 0;

        if (hi == 0xFFFFFFFF && size != 0 && size <= win_size)
        {
            base = (next + size - 1) & ~(size - 1);
            fits = (base <= win_size - size);
        }

        VPrint("[CPU=vproc] BAR%d: readback 0x%08x_%08x -> %s 0x%08x\n", i, hi, lo,
               fits ? "placed at" : "does not fit, size", fits ? win_base + base : size);

        if (fits)
        {
            cfg_write32(reg, win_base + base);
            if (is64)
            {
                cfg_write32(reg + 4, 0);
            }
            next = base + size;
            if (i == 0)
            {
                bar0 = win_base + base;
            }
        }
        else if (is64)
        {
            cfg_write32(reg, 0);
            cfg_write32(reg + 4, (hi == 0xFFFFFFFF) ? 1 : ~hi + 1);
        }
        else
        {
            cfg_write32(reg, 0);
        }

        if (is64)
        {
            i++;
        }
    }
    return bar0;
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

    uint32_t dev_id;

    if (cfg_read32(CFG_ID, &dev_id) != CPL_STAT_SC || dev_id == 0xFFFFFFFF)
    {
        VPrint("[CPU=vproc] no endpoint responded\n");
        halt(RESULT_NO_DEVICE);
    }
    VPrint("[CPU=vproc] config read bus 1 dev 0 reg 0x00 -> 0x%08x\n", dev_id);

    uint32_t test_addr = assign_bars(WINDOW_BASE, WINDOW_SIZE);

    if (test_addr == 0)
    {
        halt(RESULT_BAR0_FAILED);
    }

    // Memory Space Enable + Bus Master Enable
    cfg_write32(CFG_COMMAND, CMD_MEM_BUS_MASTER);

    uint32_t test_data = 0x00000006;
    uint32_t readback  = 0;

    pcie_mem_write(test_addr, test_data);

    uint32_t status = pcie_mem_read(test_addr, &readback);
    VPrint("[CPU=vproc] memory readback from 0x%08x -> status %u, 0x%08x (expected 0x%08x)\n",
           test_addr, status, readback, test_data);

    halt((status == CPL_STAT_SC && readback == test_data) ? RESULT_PASS : RESULT_FAIL);
}

/*
-----------------------------------------------------------------------------
Version History:
-----------------------------------------------------------------------------
 2026/08/16 AV: initial creation -- native C++ equivalent of 3.sw/RC-direct/main.c
                (the previous node-0 sanity test is kept in stubs/)
 2026/10/06   : follows the firmware -- Completion Status checks, CRS retry on
                config writes, BAR sizing by readback
*/
