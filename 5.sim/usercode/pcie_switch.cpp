//==========================================================================
// Copyright (C) 2026 Chili.CHIPS
//--------------------------------------------------------------------------
// SPDX-License-Identifier: BSD-3-Clause
//--------------------------------------------------------------------------
// Description:
//   pcie_switch: the far end of the link for the RC-switched co-simulation
//   (make VARIANT=switched). pcieVHost stays the link partner; this code,
//   its input callback, answers every request the way a switch with
//   endpoints behind it would:
//
//     upstream port ........ reached with Type 0; its bus number is the one
//      |                     in the request (the RC firmware uses 1)
//     internal bus ......... the upstream port's secondary bus
//      |  dev 1, 3, 5, 7 ... four downstream ports, as on the ASM1184e
//      |
//     each port's secondary bus, dev 0 ... an endpoint (ports 1 and 3)
//                                          or an empty slot (ports 2 and 4)
//
//   Routing uses what the firmware programs, as in hardware: Type 1 by the
//   secondary/subordinate bus numbers, memory by the memory base/limit
//   windows and the Memory Space Enable bits, endpoint memory by BAR0 and
//   BAR1. Anything else is answered with Unsupported Request (reads) or
//   dropped (writes), as a switch does. Each endpoint has its own memory, so
//   a write that goes to the wrong slot fails the readback.
//
//   The endpoints have the IDs, class and BARs of the RC-direct endpoint
//   (VUserMain1.cpp): BAR0 4 KB, BAR1 1 KB, BAR2/3 64-bit 8 GB.
//==========================================================================

#include <stdint.h>
#include <string.h>
#include <map>

#include "pcie_switch.h"

// GET_TLP_FBE/LBE need it; pcie_utils.h, which has it, does not compile as C++
#ifndef LO_NIBBLE_MASK
#define LO_NIBBLE_MASK 0x0f
#endif

#define NUM_PORTS 4
#define CFG_BYTES 256  // the PCI-compatible space; extended space reads 0

static const int  port_dev[NUM_PORTS]    = {1, 3, 5, 7};
static const bool port_has_ep[NUM_PORTS] = {true, false, true, false};

struct cfg_t {
    uint8_t val[CFG_BYTES];
    uint8_t wmask[CFG_BYTES];  // 1: the bit is writable
};

struct ep_t {
    cfg_t                       cfg;
    std::map<uint32_t, uint8_t> mem;
};

static cfg_t us;              // upstream port
static int   us_bus;          // its bus number, taken from Type 0 requests
static cfg_t ds[NUM_PORTS];   // downstream ports
static ep_t  ep[NUM_PORTS];   // the endpoint behind each downstream port

static void put32(cfg_t &c, int reg, uint32_t val, uint32_t wmask)
{
    for (int b = 0; b < 4; b++) {
        c.val[reg + b]   = (val   >> (8 * b)) & 0xff;
        c.wmask[reg + b] = (wmask >> (8 * b)) & 0xff;
    }
}

static uint32_t get32(const cfg_t &c, int reg)
{
    return c.val[reg] | (c.val[reg + 1] << 8) | (c.val[reg + 2] << 16) | ((uint32_t)c.val[reg + 3] << 24);
}

static int sec_bus(const cfg_t &c) { return c.val[0x19]; }
static int sub_bus(const cfg_t &c) { return c.val[0x1a]; }
static bool mem_enabled(const cfg_t &c) { return c.val[0x04] & 0x2; }

// Type 1 header of a switch port. port_type: 5 upstream, 6 downstream
static void bridge_init(cfg_t &c, int port_type)
{
    memset(&c, 0, sizeof c);
    put32(c, 0x00, 0x11841b21, 0x00000000);  // ASMedia ASM1184e
    put32(c, 0x04, 0x00100000, 0x00000547);  // status: capability list; command
    put32(c, 0x08, 0x06040001, 0x00000000);  // PCI-to-PCI bridge, revision 1
    put32(c, 0x0c, 0x00010000, 0x00000000);  // header type 1
    put32(c, 0x18, 0x00000000, 0x00ffffff);  // primary, secondary, subordinate bus
    put32(c, 0x20, 0x00000000, 0xfff0fff0);  // memory base, memory limit
    put32(c, 0x34, 0x00000040, 0x00000000);  // capabilities pointer
    put32(c, 0x3c, 0x00000000, 0x000000ff);  // interrupt line
    put32(c, 0x40, (uint32_t)(0x0002 | (port_type << 4)) << 16 | 0x10, 0);  // PCIe capability, the last
}

// Type 0 header, as the RC-direct endpoint's (VUserMain1.cpp)
static void ep_init(cfg_t &c)
{
    memset(&c, 0, sizeof c);
    put32(c, 0x00, 0x000214fc, 0x00000000);  // vendor 0x14fc, device 0x0002
    put32(c, 0x04, 0x00100000, 0x00000547);  // status: capability list; command
    put32(c, 0x08, 0x02800001, 0x00000000);  // network controller, other; revision 1
    put32(c, 0x10, 0x00000008, 0xfffff000);  // BAR0: 32-bit, prefetchable, 4 KB
    put32(c, 0x14, 0x00000008, 0xfffffc00);  // BAR1: 32-bit, prefetchable, 1 KB
    put32(c, 0x18, 0x0000000c, 0x00000000);  // BAR2/3: 64-bit, prefetchable, 8 GB
    put32(c, 0x1c, 0x00000000, 0xfffffffe);
    put32(c, 0x34, 0x00000040, 0x00000000);  // capabilities pointer
    put32(c, 0x3c, 0x00000000, 0x000000ff);  // interrupt line
    put32(c, 0x40, 0x00020010, 0x00000000);  // PCIe capability: endpoint, the last
}

void SwitchInit(void)
{
    bridge_init(us, 5);
    for (int p = 0; p < NUM_PORTS; p++) {
        bridge_init(ds[p], 6);
        ep_init(ep[p].cfg);
        ep[p].mem.clear();
    }
    us_bus = 0;
}

// The function a configuration request addresses, or NULL for Unsupported
// Request. cid: completer ID of the function that answers, in both cases.
static cfg_t* cfg_target(bool type1, int bus, int dev, int fn, uint16_t &cid)
{
    cid = us_bus << 8;

    if (!type1) {                                   // ends at the upstream port
        // A real port captures its bus number from Type 0 writes only; this
        // model takes it from any Type 0 request, so even the first read is
        // completed with bus 1 in the completer ID
        us_bus = bus;
        cid    = us_bus << 8;
        return (dev == 0 && fn == 0) ? &us : NULL;
    }

    if (bus == sec_bus(us)) {                       // the internal bus
        for (int p = 0; p < NUM_PORTS; p++) {
            if (dev == port_dev[p] && fn == 0) {
                cid = (bus << 8) | (dev << 3);
                return &ds[p];
            }
        }
        return NULL;
    }

    if (bus > sec_bus(us) && bus <= sub_bus(us)) {
        for (int p = 0; p < NUM_PORTS; p++) {
            if (bus >= sec_bus(ds[p]) && bus <= sub_bus(ds[p]) && sec_bus(ds[p]) != 0) {
                cid = (sec_bus(us) << 8) | (port_dev[p] << 3);
                if (bus == sec_bus(ds[p]) && dev == 0 && fn == 0 && port_has_ep[p]) {
                    cid = bus << 8;
                    return &ep[p].cfg;
                }
                return NULL;                        // empty slot, or deeper
            }
        }
    }
    return NULL;
}

static bool in_window(const cfg_t &c, uint32_t addr)
{
    uint32_t base  = (uint32_t)(get32(c, 0x20) & 0x0000fff0) << 16;
    uint32_t limit = (get32(c, 0x20) & 0xfff00000) | 0x000fffff;

    return mem_enabled(c) && addr >= base && addr <= limit;
}

static bool in_bar(const cfg_t &c, int reg, uint32_t size, uint32_t addr)
{
    uint32_t base = get32(c, reg) & ~(size - 1);

    return addr >= base && addr - base < size;
}

// The endpoint a memory request goes to, or NULL
static ep_t* mem_target(uint64_t addr)
{
    if (addr >> 32 || !in_window(us, (uint32_t)addr)) {
        return NULL;
    }
    for (int p = 0; p < NUM_PORTS; p++) {
        if (in_window(ds[p], (uint32_t)addr)) {
            ep_t *e = &ep[p];
            if (port_has_ep[p] && mem_enabled(e->cfg) &&
                (in_bar(e->cfg, 0x10, 0x1000, addr) || in_bar(e->cfg, 0x14, 0x400, addr))) {
                return e;
            }
            return NULL;
        }
    }
    return NULL;
}

void SwitchInput(pPkt_t pkt, int status, void* usrptr)
{
    pcieModelClass *pcie = (pcieModelClass *)usrptr;
    PktData_t      *d    = pkt->data;
    static PktData_t buff[4096];

    if (pkt->seq == DLLP_SEQ_ID) {
        DISCARD_PACKET(pkt);
        return;
    }

    int type = GET_TLP_TYPE(d);
    int rid  = GET_TLP_RID(d);
    int tag  = GET_TLP_TAG(d);
    int fbe  = GET_TLP_FBE(d);
    int lbe  = GET_TLP_LBE(d);
    int len  = GET_TLP_LENGTH(d);

    if (type == TL_CFGRD0 || type == TL_CFGWR0 || type == TL_CFGRD1 || type == TL_CFGWR1) {
        int      bus   = d[TLP_ADDR_OFFSET] & 0xff;
        int      dev   = (d[TLP_ADDR_OFFSET + 1] >> 3) & 0x1f;
        int      fn    = d[TLP_ADDR_OFFSET + 1] & 0x7;
        int      reg   = ((d[TLP_ADDR_OFFSET + 2] & 0xf) << 8) | (d[TLP_ADDR_OFFSET + 3] & 0xfc);
        bool     type1 = (type == TL_CFGRD1 || type == TL_CFGWR1);
        bool     write = (type == TL_CFGWR0 || type == TL_CFGWR1);
        uint16_t cid;
        cfg_t   *c     = cfg_target(type1, bus, dev, fn, cid);

        if (c == NULL) {
            VPrint("pcie_switch: Cfg%s%d bus %d dev %d reg 0x%03x: Unsupported Request\n",
                   write ? "Wr" : "Rd", type1, bus, dev, reg);
            pcie->partCompletionDelay(0, NULL, CPL_UNSUPPORTED, 0, 0, 0, 0, tag, cid, rid, false, false, true);
        }
        else if (write) {
            for (int b = 0; b < 4; b++) {
                if ((fbe >> b) & 1 && reg + b < CFG_BYTES) {
                    uint8_t m = c->wmask[reg + b];
                    c->val[reg + b] = (c->val[reg + b] & ~m) | (d[TLP_DATA_OFFSET32 + b] & m);
                }
            }
            pcie->partCompletionDelay(0, buff, CPL_SUCCESS, 0xf, 0, 0, 0, tag, cid, rid, false, false, true);
        }
        else {
            for (int b = 0; b < 4; b++) {
                buff[b] = (reg + b < CFG_BYTES) ? c->val[reg + b] : 0;
            }
            pcie->partCompletionDelay(0, buff, CPL_SUCCESS, 0xf, 0, 1, 1, tag, cid, rid, false, false, true);
        }
    }
    else if (type == TL_MWR32 || type == TL_MWR64 || type == TL_MRD32 || type == TL_MRD64) {
        bool      is64  = (type == TL_MWR64 || type == TL_MRD64);
        bool      write = (type == TL_MWR32 || type == TL_MWR64);
        uint64_t  addr  = is64 ? GET_TLP_4DW_ADDRESS(d) : GET_TLP_3DW_ADDRESS(d);
        ep_t     *e     = mem_target(addr);
        int       slot  = e ? (int)(e - ep) + 1 : 0;

        if (write) {
            PktData_t *wd = &d[is64 ? TLP_DATA_OFFSET64 : TLP_DATA_OFFSET32];
            if (e == NULL) {
                VPrint("pcie_switch: MWr 0x%08llx: no target, dropped\n", (unsigned long long)addr);
            }
            else {
                for (int i = 0; i < len * 4; i++) {
                    int be = (i < 4) ? fbe : (i >= (len - 1) * 4) ? lbe : 0xf;
                    if ((be >> (i & 3)) & 1) {
                        e->mem[(uint32_t)addr + i] = wd[i] & 0xff;
                    }
                }
                VPrint("pcie_switch: MWr 0x%08llx -> endpoint on port %d\n", (unsigned long long)addr, slot);
            }
        }
        else if (e == NULL) {
            VPrint("pcie_switch: MRd 0x%08llx: Unsupported Request\n", (unsigned long long)addr);
            pcie->partCompletionDelay(0, NULL, CPL_UNSUPPORTED, 0, 0, 0, 0, tag, us_bus << 8, rid, false, false, true);
        }
        else {
            for (int i = 0; i < len * 4; i++) {
                auto it = e->mem.find((uint32_t)addr + i);
                buff[i] = (it != e->mem.end()) ? it->second : 0;
            }
            VPrint("pcie_switch: MRd 0x%08llx <- endpoint on port %d\n", (unsigned long long)addr, slot);
            pcie->partCompletionDelay(addr, buff, CPL_SUCCESS, fbe, lbe, len, len, tag,
                                      sec_bus(ds[slot - 1]) << 8, rid, false, false, true);
        }
    }
    else if (type == TL_IORD || type == TL_IOWR || type == TL_MRDLCK32 || type == TL_MRDLCK64) {
        // Non-posted, so they need an answer; the switch and the endpoints
        // have no I/O space and support no locked access
        VPrint("pcie_switch: TLP type 0x%02x: Unsupported Request\n", type);
        pcie->partCompletionDelay(0, NULL, CPL_UNSUPPORTED, 0, 0, 0, 0, tag, us_bus << 8, rid, false, false, true);
    }
    // Messages need no answer

    DISCARD_PACKET(pkt);
}
