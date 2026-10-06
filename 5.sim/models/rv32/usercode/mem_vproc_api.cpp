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
//   Memory access API, selecting between HDL transaction or memory model
//   direct access.
//
//==========================================================================

#include <cstdio>
#include <cstdlib>
#include <cstdint>

#include "mem_vproc_api.h"

void write_word(uint32_t byte_addr, uint32_t data, bool access_sim)
{
    //printf("write_word: addr=0x%08x data=0x%08x sim=%d\n", byte_addr, data, access_sim);
    if (access_sim)
        VWriteBE(byte_addr & ~0x3UL, data, 0xf, NORMAL_UPDATE, node);
    else
        WriteRamWord(byte_addr, data, ENDIAN, node);
}

void write_hword(uint32_t byte_addr, uint32_t data, bool access_sim)
{
    if (access_sim)
        VWriteBE(byte_addr & ~0x3UL, data << ((byte_addr & 0x2) * 8), 0x3 << (byte_addr & 0x2), NORMAL_UPDATE, node);
    else
        WriteRamHWord(byte_addr, data, ENDIAN, node);
}

void write_byte(uint32_t byte_addr, uint32_t data, bool access_sim)
{
    if (access_sim)
        VWriteBE (byte_addr & ~0x3UL, data << ((byte_addr & 0x3) * 8), 0x1 << (byte_addr & 0x3), NORMAL_UPDATE, node);
    else
        WriteRamByte(byte_addr, data, node);
}

uint32_t read_word(uint32_t byte_addr, bool access_sim)
{
    uint32_t word;
    
    //printf("read_word: addr=0x%08x sim=%d\n", byte_addr, access_sim);

    if (access_sim)
        VRead(byte_addr & ~0x3, &word, NORMAL_UPDATE, node);
    else
        word = ReadRamWord(byte_addr, ENDIAN, node);

    return word;
}

uint32_t read_hword(uint32_t byte_addr, bool access_sim)
{
    uint32_t word;

    if (access_sim)
        VRead(byte_addr & ~0x3UL, &word, NORMAL_UPDATE, node);
    else
        word = ReadRamWord(byte_addr & ~0x3, ENDIAN, node);

    return (word >> ((byte_addr & 0x2UL) * 8)) & 0xffff;
}

uint32_t read_byte(uint32_t byte_addr, bool access_sim)
{
    uint32_t word;

    if (access_sim)
        VRead(byte_addr & ~0x3UL, &word, NORMAL_UPDATE, node);
    else
        word = ReadRamWord(byte_addr & ~0x03, ENDIAN, node);

    return (word >> ((byte_addr & 0x3UL) * 8)) & 0xff;
}

uint32_t read_instr(uint32_t byte_addr, bool access_sim)
{
    uint32_t word;

    word = read_word(byte_addr, access_sim);

    return word;
}