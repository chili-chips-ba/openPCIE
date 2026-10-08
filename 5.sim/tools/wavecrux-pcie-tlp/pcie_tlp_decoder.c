// SPDX-FileCopyrightText: 2026 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// openPCIE * NLnet-sponsored open-source implementation
//--------------------------------------------------------------------------
// Description:
//   PCIe TLP decoder plugin for the WaveCrux waveform viewer.
//
//   WaveCrux loads protocol decoders from native shared libraries through
//   the C ABI in wavecrux_decoder.h (Apache-2.0, Ferrite Engineering), which
//   is part of its free Open Core. This plugin decodes Transaction Layer
//   Packets carried one DW per clock -- the shape 5.sim/models/tlp_dw_monitor.sv
//   produces from the SOC's 64-bit AXI-Stream:
//
//     clk        rising edge samples the stream
//     tlp_data   one TLP DW, byte 0 (Fmt/Type) in bits [31:24]
//     tlp_sop    first DW of a TLP
//     tlp_eop    last DW of a TLP
//     tlp_valid  tlp_data carries a DW this cycle
//
//   It understands Memory, I/O, Configuration, Completion and Message TLPs,
//   names the Type 0 configuration registers, and flags framing errors and
//   length mismatches.
//
//   The optional peer_* signals take the OTHER direction of the same link.
//   Nothing is emitted for them; the decoder only remembers the requests seen
//   there, by tag, so that each Completion on the main stream can say what it
//   answers ("CplD BAR0 = 0xFFFFF008" rather than a bare payload).
//
//   Time units. Samples arrive and transactions leave in femtoseconds, as
//   wavecrux_decoder.h says. That needs WaveCrux 1.0.1 or later: 0.2.x drew
//   plugin results in waveform ticks, so the rows stay empty there.
//
//   Payload byte order. On the wire, byte 0 of a payload DW is bits [31:24].
//   Configuration registers are little-endian, so a configuration payload is
//   shown byte-swapped -- as the register value the spec prints. Memory
//   payloads are shown as the DW itself.
//==========================================================================

#include "wavecrux_decoder.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// -------------------------------------------------------------------------
// Manifest
// -------------------------------------------------------------------------
static const char kManifestJson[] =
    "{"
    "\"signals\":["
      "{\"name\":\"clk\",\"bit_width\":1,"
       "\"description\":\"Stream clock; the rising edge samples it\"},"
      "{\"name\":\"tlp_data\",\"bit_width\":32,"
       "\"description\":\"One TLP DW per beat, byte 0 (Fmt/Type) in bits [31:24]\"},"
      "{\"name\":\"tlp_sop\",\"bit_width\":1,"
       "\"description\":\"First DW of a TLP\"},"
      "{\"name\":\"tlp_eop\",\"bit_width\":1,"
       "\"description\":\"Last DW of a TLP\"},"
      "{\"name\":\"tlp_valid\",\"bit_width\":1,"
       "\"description\":\"tlp_data carries a DW this cycle\"}"
    "],"
    "\"optional_signals\":["
      "{\"name\":\"peer_data\",\"bit_width\":32,"
       "\"description\":\"Opposite link direction: DW (used to name Completions)\"},"
      "{\"name\":\"peer_sop\",\"bit_width\":1,"
       "\"description\":\"Opposite link direction: first DW\"},"
      "{\"name\":\"peer_eop\",\"bit_width\":1,"
       "\"description\":\"Opposite link direction: last DW\"},"
      "{\"name\":\"peer_valid\",\"bit_width\":1,"
       "\"description\":\"Opposite link direction: DW valid\"}"
    "],"
    "\"parameters\":["
      "{\"name\":\"labels\",\"kind\":\"enum\",\"default\":\"compact\","
       "\"enum_values\":[\"compact\",\"full\"],"
       "\"enum_labels\":{\"compact\":\"Compact\","
                        "\"full\":\"Full (bus/device, tag, status)\"},"
       "\"display_name\":\"Labels\","
       "\"description\":\"Compact leaves out what a single-device link does not "
       "need -- bus/device/function 01:00.0, the tag, a Successful status -- so "
       "the label fits its box. Everything stays in the transaction's fields.\"},"
      "{\"name\":\"span\",\"kind\":\"enum\",\"default\":\"packet\","
       "\"enum_values\":[\"packet\",\"until_next\"],"
       "\"enum_labels\":{\"packet\":\"Packet duration\","
                        "\"until_next\":\"Stretch to next TLP (overview)\"},"
       "\"display_name\":\"Box width\","
       "\"description\":\"Packet duration draws each TLP as long as it really is on "
       "the stream. Stretch to next TLP widens each box up to the next TLP, so the "
       "labels stay readable when zoomed out over a whole enumeration.\"}"
    "],"
    "\"description\":\"PCI Express Transaction Layer Packets, one 32-bit DW "
    "per clock with SOP/EOP framing (openPCIE). Memory, I/O, Configuration, "
    "Completion and Message TLPs. Bind the opposite direction to peer_* to "
    "label each Completion with the request it answers.\","
    "\"category\":\"userPlugin\""
    "}";

// -------------------------------------------------------------------------
// Instance state
// -------------------------------------------------------------------------
#define MAX_TLP_DW   (4 + 1024)  // longest header + max payload
#define MAX_PENDING  8
#define LABEL_MAX    160
#define FIELDS_MAX   768

// One TLP being collected from a stream
typedef struct {
    int      active;
    uint64_t start_fs;
    uint32_t n;
    uint32_t dw[MAX_TLP_DW];
} Collector;

// What a request asked for, remembered by tag until its Completion
typedef struct {
    int      valid;
    int      is_cfg;
    int      is_read;
    uint32_t reg;        // config register offset
    uint32_t addr;       // memory address (low 32 bits)
} ReqInfo;

typedef struct {
    uint64_t start_fs;
    uint64_t end_fs;
    int      is_error;
    char     label[LABEL_MAX];
    char     fields[FIELDS_MAX];
} Pending;

// Signal positions in the packed sample (declaration order, bound only)
typedef struct {
    int off_clk, off_data, off_sop, off_eop, off_valid;
    int off_pdata, off_psop, off_peop, off_pvalid;   // -1 when unbound
} Layout;

typedef struct {
    Layout    lay;
    int       last_clk;
    uint64_t  last_edge_fs;
    uint64_t  period_fs;
    uint64_t  last_ts;
    int       have_ts;

    Collector main;
    Collector peer;
    ReqInfo   req[256];

    Pending   pending[MAX_PENDING];
    int       n_pending;

    int       stretch;    // span = until_next
    int       full_labels; // labels = full
    Pending   held;       // last TLP, waiting for the next one to end it
    int       has_held;

    // Strings handed to the host stay valid until the next call
    char      out_label[MAX_PENDING][LABEL_MAX];
    char      out_fields[MAX_PENDING][FIELDS_MAX];
} State;

// -------------------------------------------------------------------------
// Sample access -- 2 buffer bits per signal bit: level, unknown
// -------------------------------------------------------------------------
static int get_bit(const uint8_t* b, int sig_bit, int* unknown) {
    int pos = sig_bit * 2;
    int lvl = (b[pos >> 3] >> (pos & 7)) & 1;
    int unk = (b[(pos + 1) >> 3] >> ((pos + 1) & 7)) & 1;
    if (unk && unknown) *unknown = 1;
    return lvl;
}

static uint32_t get_field(const uint8_t* b, int off, int width, int* unknown) {
    uint32_t v = 0;
    for (int i = 0; i < width; i++) {
        v |= (uint32_t)get_bit(b, off + i, unknown) << i;
    }
    return v;
}

// -------------------------------------------------------------------------
// Binding layout: the host packs only the bound signals, in manifest order,
// so the offsets depend on which optional peer_* signals are bound.
// -------------------------------------------------------------------------
static int json_has_binding(const char* json, const char* name) {
    const char* sb = json ? strstr(json, "\"signal_bindings\"") : NULL;
    if (!sb) return 0;
    const char* end = strchr(sb, '}');
    char key[48];
    snprintf(key, sizeof key, "\"%s\"", name);
    const char* hit = strstr(sb, key);
    return hit && (!end || hit < end);
}

static void build_layout(Layout* l, const char* cfg) {
    int off = 0;
    l->off_clk   = off; off += 1;
    l->off_data  = off; off += 32;
    l->off_sop   = off; off += 1;
    l->off_eop   = off; off += 1;
    l->off_valid = off; off += 1;
    l->off_pdata  = json_has_binding(cfg, "peer_data")  ? (off += 32) - 32 : -1;
    l->off_psop   = json_has_binding(cfg, "peer_sop")   ? (off += 1) - 1 : -1;
    l->off_peop   = json_has_binding(cfg, "peer_eop")   ? (off += 1) - 1 : -1;
    l->off_pvalid = json_has_binding(cfg, "peer_valid") ? (off += 1) - 1 : -1;
}

// -------------------------------------------------------------------------
// TLP field helpers
// -------------------------------------------------------------------------
static uint32_t bswap32(uint32_t v) {
    return (v << 24) | ((v & 0xFF00u) << 8) | ((v >> 8) & 0xFF00u) | (v >> 24);
}

static const char* cpl_status_name(uint32_t s) {
    switch (s) {
        case 0: return "SC";
        case 1: return "UR";
        case 2: return "CRS";
        case 4: return "CA";
        default: return "rsvd";
    }
}

// Type 0 configuration header register names
static const char* cfg_reg_name(uint32_t reg) {
    switch (reg) {
        case 0x00: return "ID";
        case 0x04: return "Command";
        case 0x08: return "Class/Rev";
        case 0x0C: return "Hdr/Lat/CLS";
        case 0x10: return "BAR0";
        case 0x14: return "BAR1";
        case 0x18: return "BAR2";
        case 0x1C: return "BAR3";
        case 0x20: return "BAR4";
        case 0x24: return "BAR5";
        case 0x28: return "CardBus";
        case 0x2C: return "Subsystem";
        case 0x30: return "ExpROM";
        case 0x34: return "CapPtr";
        case 0x3C: return "Int";
        default:   return NULL;
    }
}

static void reg_text(char* out, size_t n, uint32_t reg) {
    const char* name = cfg_reg_name(reg);
    if (name) snprintf(out, n, "%s", name);
    else      snprintf(out, n, "reg 0x%03X", reg);
}

// Number of DWs a TLP should have, from its header; 0 when unknown
static uint32_t expected_dw(uint32_t dw0) {
    uint32_t fmt = (dw0 >> 29) & 0x7;
    uint32_t len = dw0 & 0x3FF;
    if (fmt & 0x4) return 0;                       // TLP prefix: not checked
    uint32_t hdr  = (fmt & 0x1) ? 4 : 3;
    uint32_t data = (fmt & 0x2) ? (len ? len : 1024) : 0;
    return hdr + data;
}

// -------------------------------------------------------------------------
// Pending transaction queue
// -------------------------------------------------------------------------
static void push_pending(State* st, const Pending* p) {
    if (st->n_pending >= MAX_PENDING) return;
    st->pending[st->n_pending++] = *p;
}

// Hand a finished transaction to the host. With span = until_next the
// previous one is held back until this one starts, and ends there.
static void commit(State* st, const Pending* p) {
    if (!st->stretch) {
        push_pending(st, p);
        return;
    }
    if (st->has_held) {
        if (p->start_fs > st->held.end_fs) st->held.end_fs = p->start_fs;
        push_pending(st, &st->held);
    }
    st->held     = *p;
    st->has_held = 1;
}

static void emit_error(State* st, uint64_t t0, uint64_t t1, const char* what) {
    Pending tmp;
    Pending* p = &tmp;
    memset(p, 0, sizeof *p);
    p->start_fs = t0;
    p->end_fs   = t1 > t0 ? t1 : t0 + 1;
    p->is_error = 1;
    snprintf(p->label, LABEL_MAX, "TLP error: %s", what);
    snprintf(p->fields, FIELDS_MAX, "{\"error\":\"%s\"}", what);
    commit(st, p);
}

// -------------------------------------------------------------------------
// Remember a request seen on the peer stream, by tag
// -------------------------------------------------------------------------
static void note_request(State* st, const Collector* c) {
    if (c->n < 3) return;
    uint32_t dw0  = c->dw[0];
    uint32_t type = (dw0 >> 24) & 0x1F;
    uint32_t fmt  = (dw0 >> 29) & 0x7;
    uint32_t tag  = (c->dw[1] >> 8) & 0xFF;
    ReqInfo* r = &st->req[tag];

    if (type == 0x04 || type == 0x05) {               // CfgRd/CfgWr 0/1
        r->valid   = 1;
        r->is_cfg  = 1;
        r->is_read = !(fmt & 0x2);
        r->reg     = (c->dw[2] & 0xFFC);
    } else if (type == 0x00 || type == 0x01) {        // MRd / MRdLk
        if (fmt & 0x2) return;                        // MWr: posted, no Cpl
        r->valid   = 1;
        r->is_cfg  = 0;
        r->is_read = 1;
        r->addr    = (fmt & 0x1) ? (c->dw[3] & ~3u) : (c->dw[2] & ~3u);
    } else if (type == 0x02) {                        // IO
        r->valid   = 1;
        r->is_cfg  = 0;
        r->is_read = !(fmt & 0x2);
        r->addr    = c->dw[2] & ~3u;
    }
}

// -------------------------------------------------------------------------
// Decode one complete TLP from the main stream
// -------------------------------------------------------------------------
static void decode_tlp(State* st, const Collector* c, uint64_t end_fs) {
    Pending tmp;
    Pending* p = &tmp;
    memset(p, 0, sizeof *p);
    p->start_fs = c->start_fs;
    p->end_fs   = end_fs > c->start_fs ? end_fs : c->start_fs + 1;

    if (c->n < 3) {
        p->is_error = 1;
        snprintf(p->label, LABEL_MAX, "TLP error: %u DW, shorter than a header", c->n);
        snprintf(p->fields, FIELDS_MAX, "{\"error\":\"short TLP\",\"dw\":\"%u\"}", c->n);
        commit(st, p);
        return;
    }

    uint32_t dw0  = c->dw[0];
    uint32_t fmt  = (dw0 >> 29) & 0x7;
    uint32_t type = (dw0 >> 24) & 0x1F;
    uint32_t len  = dw0 & 0x3FF;
    uint32_t hdr  = (fmt & 0x1) ? 4 : 3;
    int has_data  = (fmt & 0x2) != 0;
    uint32_t data = (has_data && c->n > hdr) ? c->dw[hdr] : 0;

    uint32_t exp = expected_dw(dw0);
    int len_err  = exp && exp != c->n;

    char head[96] = "";
    char body[LABEL_MAX - 96] = "";
    char compact[LABEL_MAX] = "";   // short label; empty = use the full one
    char extra[FIELDS_MAX / 2] = "";

    if (type == 0x04 || type == 0x05) {
        // ---------------- Configuration request ----------------
        uint32_t tag  = (c->dw[1] >> 8) & 0xFF;
        uint32_t bus  = (c->dw[2] >> 24) & 0xFF;
        uint32_t dev  = (c->dw[2] >> 19) & 0x1F;
        uint32_t fn   = (c->dw[2] >> 16) & 0x7;
        uint32_t reg  = c->dw[2] & 0xFFC;
        char rname[24];
        reg_text(rname, sizeof rname, reg);
        snprintf(head, sizeof head, "Cfg%s%u %02X:%02X.%u",
                 has_data ? "Wr" : "Rd", type & 1, bus, dev, fn);
        if (has_data) {
            snprintf(body, sizeof body, " %s = 0x%08X  tag %02X",
                     rname, bswap32(data), tag);
        } else {
            snprintf(body, sizeof body, " %s  tag %02X", rname, tag);
        }
        // Compact: the BDF only when it is not the lone endpoint at 01:00.0
        char bdf[24] = "";
        if (bus != 1 || dev != 0 || fn != 0 || (type & 1)) {
            snprintf(bdf, sizeof bdf, " %02X:%02X.%u", bus, dev, fn);
        }
        if (has_data) {
            snprintf(compact, sizeof compact, "CfgWr%s%s %s = 0x%08X",
                     (type & 1) ? "1" : "", bdf, rname, bswap32(data));
        } else {
            snprintf(compact, sizeof compact, "CfgRd%s%s %s",
                     (type & 1) ? "1" : "", bdf, rname);
        }
        snprintf(extra, sizeof extra,
                 ",\"bus\":\"%02X\",\"device\":\"%02X\",\"function\":\"%u\","
                 "\"register\":\"0x%03X\",\"register_name\":\"%s\","
                 "\"requester\":\"%04X\",\"tag\":\"%02X\","
                 "\"first_be\":\"%X\"",
                 bus, dev, fn, reg, rname, c->dw[1] >> 16, tag,
                 c->dw[1] & 0xF);
        if (has_data) {
            size_t k = strlen(extra);
            snprintf(extra + k, sizeof extra - k,
                     ",\"value\":\"0x%08X\",\"payload_dw\":\"0x%08X\"",
                     bswap32(data), data);
        }
    } else if (type == 0x00 || type == 0x01 || type == 0x02) {
        // ---------------- Memory / IO request ----------------
        uint32_t tag  = (c->dw[1] >> 8) & 0xFF;
        uint32_t ahi  = (fmt & 0x1) ? c->dw[2] : 0;
        uint32_t alo  = ((fmt & 0x1) ? c->dw[3] : c->dw[2]) & ~3u;
        const char* kind = (type == 0x02) ? "IO" : "M";
        snprintf(head, sizeof head, "%s%s%s%s", kind,
                 has_data ? "Wr" : "Rd", (type == 0x01) ? "Lk" : "",
                 (type == 0x02) ? "" : ((fmt & 0x1) ? "64" : "32"));
        if (ahi) {
            snprintf(body, sizeof body, " 0x%08X_%08X", ahi, alo);
        } else {
            snprintf(body, sizeof body, " 0x%08X", alo);
        }
        size_t k = strlen(body);
        if (has_data) {
            if (len > 1) snprintf(body + k, sizeof body - k, " = 0x%08X +%u DW", data, len - 1);
            else         snprintf(body + k, sizeof body - k, " = 0x%08X", data);
        } else {
            snprintf(body + k, sizeof body - k, "  %u DW  tag %02X", len ? len : 1024, tag);
        }
        if (ahi) {
            snprintf(compact, sizeof compact, "%s 0x%08X_%08X", head, ahi, alo);
        } else {
            snprintf(compact, sizeof compact, "%s 0x%08X", head, alo);
        }
        size_t ck = strlen(compact);
        if (has_data) {
            snprintf(compact + ck, sizeof compact - ck, " = 0x%08X%s", data,
                     len > 1 ? " ..." : "");
        } else if (len != 1) {
            snprintf(compact + ck, sizeof compact - ck, " x%u DW", len ? len : 1024);
        }
        snprintf(extra, sizeof extra,
                 ",\"address\":\"0x%08X%08X\",\"length_dw\":\"%u\","
                 "\"requester\":\"%04X\",\"tag\":\"%02X\","
                 "\"first_be\":\"%X\",\"last_be\":\"%X\"",
                 ahi, alo, len ? len : 1024, c->dw[1] >> 16, tag,
                 c->dw[1] & 0xF, (c->dw[1] >> 4) & 0xF);
        if (has_data) {
            size_t e = strlen(extra);
            snprintf(extra + e, sizeof extra - e, ",\"data0\":\"0x%08X\"", data);
        }
    } else if (type == 0x0A || type == 0x0B) {
        // ---------------- Completion ----------------
        uint32_t cid    = c->dw[1] >> 16;
        uint32_t status = (c->dw[1] >> 13) & 0x7;
        uint32_t bc     = c->dw[1] & 0xFFF;
        uint32_t rid    = c->dw[2] >> 16;
        uint32_t tag    = (c->dw[2] >> 8) & 0xFF;
        uint32_t la     = c->dw[2] & 0x7F;
        ReqInfo* r      = &st->req[tag];
        char what[40]   = "";

        if (r->valid && r->is_cfg) {
            char rname[24];
            reg_text(rname, sizeof rname, r->reg);
            snprintf(what, sizeof what, " %s%s", r->is_read ? "" : "for write ", rname);
        } else if (r->valid) {
            snprintf(what, sizeof what, " MRd 0x%08X", r->addr);
        }

        snprintf(head, sizeof head, "Cpl%s%s %s", has_data ? "D" : "",
                 (type == 0x0B) ? "Lk" : "", cpl_status_name(status));
        if (has_data) {
            // A config read returns a little-endian register value
            uint32_t shown = (r->valid && r->is_cfg) ? bswap32(data) : data;
            snprintf(body, sizeof body, "%s = 0x%08X  tag %02X", what, shown, tag);
        } else {
            snprintf(body, sizeof body, "%s  tag %02X", what, tag);
        }
        snprintf(extra, sizeof extra,
                 ",\"status\":\"%s\",\"completer\":\"%04X\",\"requester\":\"%04X\","
                 "\"tag\":\"%02X\",\"byte_count\":\"%u\",\"lower_address\":\"0x%02X\"",
                 cpl_status_name(status), cid, rid, tag, bc, la);
        if (has_data) {
            size_t e = strlen(extra);
            snprintf(extra + e, sizeof extra - e,
                     ",\"payload_dw\":\"0x%08X\",\"as_register\":\"0x%08X\"",
                     data, bswap32(data));
        }
        if (r->valid) {
            size_t e = strlen(extra);
            snprintf(extra + e, sizeof extra - e, ",\"answers\":\"%s\"", what + 1);
        }
        {
            // Compact: what it answers, and the status only when not SC
            char cwhat[32] = "";
            if (r->valid && r->is_cfg) {
                reg_text(cwhat, sizeof cwhat, r->reg);
            } else if (r->valid) {
                snprintf(cwhat, sizeof cwhat, "0x%08X", r->addr);
            }
            char cst[8] = "";
            if (status != 0) snprintf(cst, sizeof cst, " %s", cpl_status_name(status));
            if (has_data) {
                uint32_t shown = (r->valid && r->is_cfg) ? bswap32(data) : data;
                snprintf(compact, sizeof compact, "CplD%s%s%s = 0x%08X",
                         cst, cwhat[0] ? " " : "", cwhat, shown);
            } else {
                snprintf(compact, sizeof compact, "Cpl%s%s%s",
                         cst, cwhat[0] ? " " : "", cwhat);
            }
        }
        r->valid = 0;
        if (status != 0 && status != 2) p->is_error = 1;   // UR / CA
    } else if ((type & 0x18) == 0x10) {
        // ---------------- Message ----------------
        uint32_t code = c->dw[1] & 0xFF;
        snprintf(head, sizeof head, "Msg%s", has_data ? "D" : "");
        snprintf(body, sizeof body, " code 0x%02X  route %u", code, type & 0x7);
        snprintf(extra, sizeof extra, ",\"message_code\":\"0x%02X\",\"routing\":\"%u\"",
                 code, type & 0x7);
    } else {
        snprintf(head, sizeof head, "TLP");
        snprintf(body, sizeof body, " Fmt %u Type 0x%02X", fmt, type);
    }

    if (len_err) {
        size_t k = strlen(body);
        snprintf(body + k, sizeof body - k, "  [%u DW, expected %u]", c->n, exp);
        p->is_error = 1;
    }

    if (!st->full_labels && compact[0]) {
        if (len_err) {
            size_t k = strlen(compact);
            snprintf(compact + k, sizeof compact - k, "  [%u DW, expected %u]", c->n, exp);
        }
        snprintf(p->label, LABEL_MAX, "%s", compact);
    } else {
        snprintf(p->label, LABEL_MAX, "%s%s", head, body);
    }
    snprintf(p->fields, FIELDS_MAX,
             "{\"type\":\"%s\",\"fmt\":\"%u\",\"type_code\":\"0x%02X\","
             "\"length\":\"%u\",\"dw_count\":\"%u\","
             "\"header\":\"%08X %08X %08X\"%s}",
             head, fmt, type, len, c->n,
             c->dw[0], c->dw[1], c->dw[2], extra);
    commit(st, p);
}

// -------------------------------------------------------------------------
// One beat on a stream. Returns 1 when a TLP completed (c holds it).
// -------------------------------------------------------------------------
static int stream_beat(State* st, Collector* c, uint64_t t, int emit_errors,
                       uint32_t data, int sop, int eop, int unknown) {
    if (unknown) {
        if (emit_errors) emit_error(st, t, t + st->period_fs, "x/z on the TLP stream");
        c->active = 0;
        return 0;
    }
    if (sop) {
        if (c->active && emit_errors) {
            emit_error(st, c->start_fs, t, "SOP before EOP, TLP truncated");
        }
        c->active   = 1;
        c->start_fs = t;
        c->n        = 0;
    } else if (!c->active) {
        if (emit_errors) emit_error(st, t, t + st->period_fs, "data beat without SOP");
        return 0;
    }
    if (c->n < MAX_TLP_DW) c->dw[c->n++] = data;
    if (eop) {
        c->active = 0;
        return 1;
    }
    return 0;
}

// -------------------------------------------------------------------------
// Lifecycle
// -------------------------------------------------------------------------
static WcDecoderHandle tlp_create(const char* config_json) {
    State* st = (State*)calloc(1, sizeof(State));
    if (!st) return NULL;
    build_layout(&st->lay, config_json);
    st->stretch = config_json && strstr(config_json, "\"until_next\"") != NULL;
    const char* lb = config_json ? strstr(config_json, "\"labels\"") : NULL;
    if (lb && (lb = strchr(lb + 8, ':')) != NULL) {
        while (*++lb == ' ') {}
        st->full_labels = strncmp(lb, "\"full\"", 6) == 0;
    }
    st->last_clk = -1;
    return st;
}

static int32_t drain(State* st, WcTransaction* out, size_t* inout_count) {
    size_t cap = *inout_count;
    size_t n = 0;
    while (n < cap && n < (size_t)st->n_pending) {
        Pending* p = &st->pending[n];
        memcpy(st->out_label[n],  p->label,  LABEL_MAX);
        memcpy(st->out_fields[n], p->fields, FIELDS_MAX);
        out[n].start_fs    = p->start_fs;
        out[n].end_fs      = p->end_fs > p->start_fs ? p->end_fs : p->start_fs + 1;
        out[n].label       = st->out_label[n];
        out[n].fields_json = st->out_fields[n];
        out[n].is_error    = (uint32_t)p->is_error;
        out[n]._reserved0  = 0;
        n++;
    }
    if (n > 0 && (size_t)st->n_pending > n) {
        memmove(&st->pending[0], &st->pending[n],
                (st->n_pending - n) * sizeof(Pending));
    }
    st->n_pending -= (int)n;
    *inout_count = n;
    if (st->n_pending > 0) {
        *inout_count = n ? n : (size_t)st->n_pending;
        return n ? WC_DECODER_OK : WC_DECODER_NEED_MORE_SLOTS;
    }
    return WC_DECODER_OK;
}

static int32_t tlp_feed(WcDecoderHandle handle, const WcSample* s,
                        WcTransaction* out, size_t* inout_count) {
    if (!handle || !s || !inout_count) {
        if (inout_count) *inout_count = 0;
        return WC_DECODER_ERR;
    }
    State* st = (State*)handle;

    // The host may call again with the same sample after growing its
    // buffer; decode each timestamp only once.
    if (!(st->have_ts && s->timestamp_fs == st->last_ts) && s->bits_ptr) {
        st->have_ts = 1;
        st->last_ts = s->timestamp_fs;

        const Layout* l = &st->lay;
        const uint8_t* b = s->bits_ptr;
        int clk_unk = 0;
        int clk = get_bit(b, l->off_clk, &clk_unk);

        if (!clk_unk && st->last_clk == 0 && clk == 1) {
            uint64_t t = s->timestamp_fs;
            if (st->last_edge_fs && t > st->last_edge_fs) {
                st->period_fs = t - st->last_edge_fs;
            }
            st->last_edge_fs = t;

            // Peer first: a request must be known before its Completion
            if (l->off_pdata >= 0 && l->off_psop >= 0 &&
                l->off_peop >= 0 && l->off_pvalid >= 0) {
                int unk = 0;
                if (get_bit(b, l->off_pvalid, &unk) && !unk) {
                    uint32_t d = get_field(b, l->off_pdata, 32, &unk);
                    int so = get_bit(b, l->off_psop, &unk);
                    int eo = get_bit(b, l->off_peop, &unk);
                    if (stream_beat(st, &st->peer, t, 0, d, so, eo, unk)) {
                        note_request(st, &st->peer);
                    }
                }
            }

            int unk = 0;
            int valid = get_bit(b, l->off_valid, &unk);
            if (valid && !unk) {
                uint32_t d = get_field(b, l->off_data, 32, &unk);
                int so = get_bit(b, l->off_sop, &unk);
                int eo = get_bit(b, l->off_eop, &unk);
                if (stream_beat(st, &st->main, t, 1, d, so, eo, unk)) {
                    // A request on the main stream is remembered too, so a
                    // single decoder over a merged stream still pairs tags.
                    note_request(st, &st->main);
                    decode_tlp(st, &st->main, t + st->period_fs);
                }
            }
        }
        if (!clk_unk) st->last_clk = clk;
    }
    return drain(st, out, inout_count);
}

static int32_t tlp_flush(WcDecoderHandle handle, WcTransaction* out,
                         size_t* inout_count) {
    if (!handle || !inout_count) {
        if (inout_count) *inout_count = 0;
        return WC_DECODER_ERR;
    }
    State* st = (State*)handle;
    if (st->main.active) {
        emit_error(st, st->main.start_fs, st->last_edge_fs + st->period_fs,
                   "missing EOP at end of capture");
        st->main.active = 0;
    }
    if (st->has_held) {
        push_pending(st, &st->held);
        st->has_held = 0;
    }
    return drain(st, out, inout_count);
}

static void tlp_destroy(WcDecoderHandle handle) {
    free(handle);
}

// -------------------------------------------------------------------------
// ABI entry points
// -------------------------------------------------------------------------
uint32_t wavecrux_decoder_abi_version(void) {
    return WAVECRUX_DECODER_ABI_VERSION;
}

// The same decoder is registered twice, once per link direction, so the two
// rows read "TLP Downstream" and "TLP Upstream" in WaveCrux instead of two
// identical names (a decoder row is labelled with its display name and cannot
// be renamed). Bind Downstream to the tx_ set of tb.tlp_view, Upstream to rx_.
static const struct {
    const char* id;
    const char* display_name;
} kDecoders[] = {
    { "openpcie.pcie_tlp_down", "TLP Downstream" },   // RC -> EP
    { "openpcie.pcie_tlp_up",   "TLP Upstream"   },   // EP -> RC
};
#define NUM_DECODERS (sizeof kDecoders / sizeof kDecoders[0])

int32_t wavecrux_decoder_register(WcDecoderDef* out_defs, size_t* inout_count) {
    if (!inout_count) return WC_DECODER_ERR;
    if (!out_defs || *inout_count < NUM_DECODERS) {
        *inout_count = NUM_DECODERS;
        return WC_DECODER_NEED_MORE_SLOTS;
    }
    for (size_t i = 0; i < NUM_DECODERS; i++) {
        memset(&out_defs[i], 0, sizeof out_defs[i]);
        out_defs[i].id            = kDecoders[i].id;
        out_defs[i].display_name  = kDecoders[i].display_name;
        out_defs[i].manifest_json = kManifestJson;
        out_defs[i].create        = tlp_create;
        out_defs[i].feed          = tlp_feed;
        out_defs[i].flush         = tlp_flush;
        out_defs[i].destroy       = tlp_destroy;
    }
    *inout_count = NUM_DECODERS;
    return WC_DECODER_OK;
}

const char* wavecrux_decoder_plugin_name(void) {
    return "openPCIE PCIe TLP decoder";
}

const char* wavecrux_decoder_plugin_description(void) {
    return "BSD-3-Clause, Chili.CHIPS -- github.com/chili-chips-ba/openpcie";
}

//--------------------------------------------------------------------------
// Revision history:
//  2026/10/06 - initial creation
//--------------------------------------------------------------------------
