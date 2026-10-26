//==========================================================================
// Copyright (C) 2026 Chili.CHIPS
//--------------------------------------------------------------------------
// SPDX-License-Identifier: BSD-3-Clause
//--------------------------------------------------------------------------
// Description:
//   pcie_switch: a PCIe switch with endpoints behind it, at the TLP level,
//   for the RC-switched co-simulation (make VARIANT=switched). See
//   pcie_switch.cpp.
//==========================================================================

#ifndef _PCIE_SWITCH_H_
#define _PCIE_SWITCH_H_

#include "pcieModelClass.h"

// Builds the configuration spaces. Call before the link comes up.
void SwitchInit(void);

// pcieVHost input callback; usrptr is the node's pcieModelClass. Needs
// CONFIG_DISABLE_MEM, so that every request reaches it.
void SwitchInput(pPkt_t pkt, int status, void* usrptr);

#endif
