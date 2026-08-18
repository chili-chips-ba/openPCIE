// SPDX-FileCopyrightText: 2026 Chili.CHIPS*ba
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// Description:
//   openPCIE software top level CSR definition header
//==========================================================================

#ifndef _OPENPCIE_REGS_H_
#define _OPENPCIE_REGS_H_

// Select appropriate auto-generated HAL header for the build type.
// To build these headers, use "make -f MakefileCSR" in the 4.build/ directory.
//
// csr_hw.h and csr_cosim.h are C++ (a class per register), so they suit the
// co-simulation and any C++ application. The bare-metal picorv32 firmware in
// 3.sw/ is plain C -- it includes "csr.h" straight away and reaches the same
// register structs through the CSR_REGS() pointer below.
# ifdef VPROC
#  include "csr_cosim.h"
# else
#  ifdef __cplusplus
#   include "csr_hw.h"
#  else
#   include "csr.h"
#  endif
# endif

// Base address of the CSR block inside the SOC address map, straight out of
// csr.rdl ("csr csr @ 0x3000_0000" in the openpcie addrmap).
#define OPENPCIE_CSR_BASE  0x30000000u

// Plain-C accessors.
//
// CSR_REG32() is the one to use for a whole register:
//
//     CSR_REG32(tx.header0) = h0;
//     uint32_t s = CSR_REG32(status.phy);
//
// It takes the register's offset out of the generated struct with offsetof()
// and then performs one aligned 32-bit access at that address.
//
// Do NOT dereference through the struct itself. "peakrdl c-header" marks every
// struct __attribute__((packed)), which tells the compiler the members may be
// unaligned. On a target without unaligned load/store -- rv32i, for one -- that
// turns a single register access into four byte accesses:
//
//     lbu a4,12(a5)  /  sb a4,12(a5)  /  lbu a4,13(a5)  ...
//
// which is wrong for a CSR: it writes a register in four steps, and on this
// design the write strobe of tx.data starts a TLP transfer, so the packet goes
// out after the first byte with the other three not yet written. The compiler
// only folds the byte accesses back into a word at -O2 and above, and the
// firmware is built without optimisation.
//
// offsetof() on a packed struct is still a plain compile-time constant, so this
// keeps the generated header as the single source of truth for the layout.
#ifndef __cplusplus
# include <stddef.h>
# include <stdint.h>

# define CSR_REGS()       ((volatile csr_t*)OPENPCIE_CSR_BASE)

# define CSR_REG32(member)     (*(volatile uint32_t *)((uintptr_t)OPENPCIE_CSR_BASE + offsetof(csr_t, member)))
#endif

// Extract a field out of a register value that has already been read, using
// the bit mask and bit position "peakrdl c-header" emits for that field:
//
//    uint32_t hdr = CSR_REG32(rx.header_info);       // one bus read
//    uint8_t  tag = RDL_FIELD(hdr, CSR__RX__HEADER_INFO__TAG);
//
// Reading the register once and picking the fields out of the copy matters
// here -- a completion arriving between two reads would otherwise mix the
// tag of one TLP with the requester ID of the next.
#define RDL_FIELD(val, FLD)  (((val) & FLD##_bm) >> FLD##_bp)

#endif
