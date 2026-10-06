// SPDX-FileCopyrightText: 2024 Chili.CHIPS
//
// SPDX-License-Identifier: BSD-3-Clause

//==========================================================================
// Copyright (C) 2024 Chili.CHIPS
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
//   Header for the VProc main program to instantiate and run the rv32 RISC-V
//   instruction set simulator
//
//==========================================================================

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

#ifndef _VUSERMAIN0_H_
#define _VUSERMAIN0_H_

#if !defined _WIN32 && !defined _WIN64
#include <unistd.h>
#include <termios.h>
#include <sys/time.h>

#define STRDUP strdup
#else
# undef   UNICODE
# define  WIN32_LEAN_AND_MEAN

# include <windows.h>
# include <winsock2.h>
# include <ws2tcpip.h>

#define STRDUP _strdup

extern "C" {

    extern int   getopt(int nargc, char** nargv, const char* ostr);
    extern char* optarg;
}
#endif

#include "rv32_cache.h"
#include "mem_vproc_api.h"
#include "rv32.h"
#include "rv32_cpu_gdb.h"
#include "rv32_timing_config.h"
#include "rv32_cache.h"
#include "uart.h"

extern "C" {

#include "VUser.h"
}

#define CFGFILENAME                        "vusermain.cfg"
#define MAXARGS                            100
#define MEM_SIZE                           (1024*1024)
#define MEM_OFFSET                         0

#ifndef EXT_ACCESS_BASE
#define EXT_ACCESS_BASE                    0xFFFFFFFF
#endif

#ifndef EXT_ACCESS_TOP
#define EXT_ACCESS_TOP                     0xFFFFFFFF
#endif

// Define a sleep forever macro
#define SLEEP_FOREVER {while(1)            VTick(0x7fffffff, node);}

typedef struct vusermain_cfg_s {
    uint32_t    ext_access_base_addr;
    uint32_t    ext_access_top_addr;
    bool        enable_icache;

    unsigned    icache_line_bytes;
    unsigned    icache_ways;
    unsigned    icache_sets;
    unsigned    icache_base_addr;
    unsigned    icache_top_addr;
    
    unsigned    penalty_slow_mem;
    
    bool        load_binary;
    uint32_t    bin_load_addr;
    
    rv32_timing_config::risc_v_core_e riscv_core;

    vusermain_cfg_s()
    {
        ext_access_base_addr = EXT_ACCESS_BASE;
        ext_access_top_addr  = EXT_ACCESS_TOP;
        enable_icache        = false;

        icache_line_bytes    = RV32_CACHE_DEFAULT_LINE;
        icache_ways          = RV32_CACHE_DEFAULT_WAYS;
        icache_sets          = RV32_CACHE_DEFAULT_SETS;
        icache_base_addr     = RV32_CACHE_DEFAULT_BASE;
        icache_top_addr      = RV32_CACHE_DEFAULT_ILIMIT;
        
        penalty_slow_mem     = RV32_SLOW_MEM_PENALTY;
        
        load_binary          = false;
        bin_load_addr        = 0;
        
        riscv_core           = rv32_timing_config::risc_v_core_e::DEFAULT;
    }

} vusermain_cfg_t;

#endif