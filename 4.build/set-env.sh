#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Build environment for openPCIE on Linux / WSL. Finds every tool the Makefiles
# and scripts call, checks its version, and exports one variable per tool --
# the names the Makefiles use (YOSYS, SV2V, PEAKRDL, RISCV_PREFIX, ...).
#
# usage:  source 4.build/set-env.sh        bash, zsh
#         source 4.build/set-env.csh       tcsh, csh
#         bash 4.build/set-env.sh          report only, exports nothing
#
# A variable already set in the environment is kept, so a tool can be pinned:
#   export YOSYS=/opt/oss-cad-suite/bin/yosys
# The searches start from these, when set: OPENXC7_ROOT (openXC7 prefix),
# XILINX_VIVADO (Vivado install), RISCV_ROOT (folder of riscv-none-elf-gcc).
#
# The minimum versions are the ones the build was validated with (README.md,
# "Tool versions"). A tool that is missing or older is reported together with
# what to install. The steps that do not need it still work.

_se_csh=0
[ "${1:-}" = "--csh" ] && _se_csh=1
# sourced from bash/zsh, or run (report only / csh front end)
_se_src=0
[ -n "${BASH_SOURCE:-}" ] && [ "${BASH_SOURCE[0]}" != "$0" ] && _se_src=1
[ -n "${ZSH_VERSION:-}" ] && case $ZSH_EVAL_CONTEXT in *:file) _se_src=1 ;; esac

_se_path0=$PATH
_se_bad=0
_se_todo=""

_se_msg() { printf '%s\n' "$*" >&2; }

# set one variable: exported when sourced, printed as setenv for set-env.csh
_se_set() {
    export "$1=$2"
    if [ $_se_csh = 1 ]; then printf 'setenv %s "%s";\n' "$1" "$2"; fi
}

_se_need() {
    _se_bad=$((_se_bad + 1))
    case "$_se_todo" in *"$1"*) ;; *) _se_todo="$_se_todo
  - $1" ;; esac
}

# first dotted number in the input, e.g. "Yosys 0.69 (git ...)" -> 0.69
_se_num() { grep -oE '[0-9]+(\.[0-9]+)+' | head -1; }

# $1 >= $2, as versions
_se_ge() { [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" = "$2" ]; }

# newest existing path among the arguments (glob results), by version order
_se_newest() { for p in "$@"; do [ -e "$p" ] && echo "$p"; done | sort -V | tail -1; }

# _se_tool VAR default-command min-version version-command install-hint
#   version-command is evaluated with $T set to the tool, e.g. '$T --version'
_se_tool() {
    local var=$1 def=$2 min=$3 vcmd=$4 hint=$5 cur p real ver
    eval "cur=\${$var:-}"
    p=$(command -v "${cur:-$def}" 2>/dev/null)
    if [ -z "$p" ]; then
        printf '  %-18s %-12s %s\n' "$var" "MISSING" "${cur:-$def}" >&2
        _se_need "$hint"
        return 1
    fi
    real=$(readlink -f "$p")
    case "$real" in
        *.exe|*.bat|*.cmd)
            printf '  %-18s %-12s %s -> Windows program, needs the Linux build\n' "$var" "WINDOWS" "$p" >&2
            _se_need "$hint"
            return 1 ;;
    esac
    ver=""
    [ -n "$vcmd" ] && ver=$(T=$p; eval "$vcmd" 2>&1 </dev/null | _se_num)
    if [ -n "$min" ] && ! _se_ge "${ver:-0}" "$min"; then
        printf '  %-18s %-12s %s -- TOO OLD, need %s or later\n' "$var" "${ver:-?}" "$p" "$min" >&2
        _se_need "$hint"
    else
        printf '  %-18s %-12s %s\n' "$var" "${ver:-ok}" "$p" >&2
    fi
    _se_set "$var" "$p"
}

_se_msg "openPCIE build environment"

# ---- openXC7 v1.0.0 (Yosys, nextpnr-himbaechel, fpga-as, prjxray-db) -------
_se_msg "openXC7:"
_se_x7=""
for d in "${OPENXC7_ROOT:-}" "${NEXTPNR_XILINX_DIR:-}" "$HOME/opt/openxc7" /opt/openxc7; do
    [ -n "$d" ] && [ -x "$d/bin/nextpnr-himbaechel" ] && { _se_x7=$d; break; }
done
_se_hint_x7="openXC7 v1.0.0: toolchain-sources-builder.sh from github.com/openXC7/toolchain-installer, into ~/opt/openxc7 or /opt/openxc7 (or set OPENXC7_ROOT)"
if [ -n "$_se_x7" ]; then
    _se_msg "  OPENXC7_ROOT       $_se_x7"
    _se_set OPENXC7_ROOT              "$_se_x7"
    _se_set NEXTPNR_XILINX_DIR        "$_se_x7"
    _se_set NEXTPNR_XILINX_PYTHON_DIR "$_se_x7/lib/python"
    _se_set PRJXRAY_DB_DIR            "$_se_x7/share/nextpnr/prjxray-db"
    case ":$PATH:" in *":$_se_x7/bin:"*) ;; *) PATH="$_se_x7/venv/bin:$_se_x7/bin:$PATH" ;; esac
    [ -x "$_se_x7/venv/bin/python3" ] && OPENXC7_PYTHON=${OPENXC7_PYTHON:-$_se_x7/venv/bin/python3}
else
    _se_msg "  OPENXC7_ROOT       MISSING"
    _se_need "$_se_hint_x7"
fi
_se_tool YOSYS              yosys              0.67  '$T -V'        "$_se_hint_x7"
_se_tool YOSYS_CONFIG       yosys-config       ""    ''             "$_se_hint_x7"
_se_tool NEXTPNR_HIMBAECHEL nextpnr-himbaechel ""    '$T --version' "$_se_hint_x7"
_se_tool NEXTPNR_XILINX     nextpnr-xilinx     ""    ''             "$_se_hint_x7"
_se_tool BBASM              bbasm              ""    ''             "$_se_hint_x7"
_se_tool FPGA_AS            fpga-as            ""    ''             "$_se_hint_x7"
# the default assembler (ASSEMBLER=prjxray): fasm2frames lives in the openXC7 venv
_se_tool FASM2FRAMES        "${_se_x7:+$_se_x7/venv/bin/}fasm2frames" "" '' "$_se_hint_x7"
_se_tool XC7FRAMES2BIT      xc7frames2bit      ""    ''             "$_se_hint_x7"
_se_tool OPENXC7_PYTHON     python3            3.10  '$T --version' "$_se_hint_x7"
_se_tool SV2V               sv2v               0.0.13 '$T --numeric-version' \
    "sv2v v0.0.13+: sv2v-Linux.zip from github.com/zachjs/sv2v/releases, into ~/.local/bin"

# ---- firmware: xPack RISC-V GCC -------------------------------------------
_se_msg "firmware:"
_se_hint_rv="xPack riscv-none-elf-gcc 15.2.0-1, linux-x64 tarball from github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases, unpacked into ~/opt (or set RISCV_ROOT)"
_se_rv=${RISCV_ROOT:-}
if [ -z "$_se_rv" ]; then
    # on PATH, unless that is a link to the Windows .exe; else the newest xPack
    _se_rv=$(command -v riscv-none-elf-gcc 2>/dev/null)
    case "$(readlink -f "${_se_rv:-/}")" in *.exe|/) _se_rv="" ;; esac
    if [ -n "$_se_rv" ]; then
        _se_rv=$(dirname "$_se_rv")
    else
        _se_rv=$(_se_newest "$HOME"/opt/xpack-riscv-none-elf-gcc-*/bin \
                            /opt/xpack-riscv-none-elf-gcc-*/bin \
                            "$HOME"/.local/xPacks/@xpack-dev-tools/riscv-none-elf-gcc/*/.content/bin)
    fi
fi
RISCV_GCC=${RISCV_PREFIX:+${RISCV_PREFIX}gcc}
RISCV_GCC=${RISCV_GCC:-${_se_rv:+$_se_rv/}riscv-none-elf-gcc}
if _se_tool RISCV_GCC riscv-none-elf-gcc 15.2 '$T -dumpfullversion' "$_se_hint_rv"; then
    _se_set RISCV_PREFIX "${RISCV_GCC%gcc}"
fi
unset RISCV_GCC

# ---- CSR generation: PeakRDL, and the Python that has systemrdl-compiler ---
_se_msg "CSR:"
_se_hint_rdl="PeakRDL 1.5.0: pip install --user peakrdl peakrdl-regblock peakrdl-cheader peakrdl-html peakrdl-markdown systemrdl-compiler"
if _se_tool PEAKRDL peakrdl 1.5.0 '$T --version' "$_se_hint_rdl"; then
    # sysrdl_cosim.py must run on peakrdl's own interpreter -- take it from its #!
    _se_py=$(head -1 "$PEAKRDL" | sed -n 's|^#! *||p' | sed 's|^/usr/bin/env  *||')
    [ -n "${PYTHON:-}" ] || PYTHON=$_se_py
fi
# otherwise the first python3 on the PATH as it was before openXC7 went in front
[ -n "${PYTHON:-}" ] || PYTHON=$(PATH=$_se_path0 command -v python3)
_se_tool PYTHON python3 3.10 '$T --version' "$_se_hint_rdl" && \
    { "$PYTHON" -c "import systemrdl" 2>/dev/null || {
        _se_msg "  PYTHON             $PYTHON has no systemrdl-compiler"
        _se_need "$_se_hint_rdl"; }; }

# ---- lint, format ---------------------------------------------------------
_se_msg "lint:"
_se_tool VERILATOR verilator 5.052 '$T --version' \
    "Verilator 5.052+: build from source (verilator.org/guide/latest/install.html); Ubuntu's apt package is older"
# Verible numbers its releases v0.0-<build>; read as 0.0.<build> to compare
_se_tool VERIBLE   verible-verilog-lint 0.0.4296 '$T --version | grep -oE "0\.0-[0-9]+" | sed "s/0\.0-/0.0./"' \
    "Verible v0.0-4296+: linux-static-x86_64 tarball from github.com/chipsalliance/verible/releases, into ~/.local/bin"
[ -n "${VERIBLE:-}" ] && _se_vb=$(dirname "$VERIBLE") && {
    _se_set VERIBLE_FORMAT "$_se_vb/verible-verilog-format"
    _se_set VERIBLE_SYNTAX "$_se_vb/verible-verilog-syntax"
    _se_set VERIBLE_LINT   "$VERIBLE"; }

# ---- programming: openFPGALoader, and on WSL usbipd-win for the cable ------
_se_msg "programming:"
_se_tool OPENFPGALOADER openFPGALoader 1.1.1 '$T --Version' \
    "openFPGALoader v1.1.1+: build from source (github.com/trabucayre/openFPGALoader, needs libftdi1-dev libhidapi-dev libudev-dev libusb-1.0-0-dev); Ubuntu's apt package is older"
_se_tool LSUSB lsusb "" '' "lsusb: sudo apt install usbutils"
if grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL sees a USB JTAG cable only once usbipd-win attaches it
    _se_ui=$(command -v usbipd.exe 2>/dev/null)
    [ -z "$_se_ui" ] && [ -x "/mnt/c/Program Files/usbipd-win/usbipd.exe" ] && _se_ui="/mnt/c/Program Files/usbipd-win/usbipd.exe"
    if [ -n "$_se_ui" ]; then
        printf '  %-18s %-12s %s\n' USBIPD "$("$_se_ui" --version 2>/dev/null | _se_num)" "$_se_ui" >&2
    else
        printf '  %-18s %-12s %s\n' USBIPD MISSING "(WSL needs it to reach the JTAG cable)" >&2
        _se_need "usbipd-win (Windows): winget install usbipd -- see hw_build.openXC7/README.md, Programming the board from WSL"
    fi
fi

# ---- co-simulation: host compiler, Vivado xsim ----------------------------
_se_msg "co-simulation:"
_se_hint_cc="GCC 10+ (C++20) and binutils: sudo apt install build-essential"
_se_tool HOST_CC  gcc 10 '$T -dumpfullversion' "$_se_hint_cc"
_se_tool HOST_CXX g++ 10 '$T -dumpfullversion' "$_se_hint_cc"
_se_tool HOST_AR  ar  "" ''                    "$_se_hint_cc"
_se_tool VCD2FST  vcd2fst "" ''                "vcd2fst (tb.vcd -> tb.fst): sudo apt install gtkwave"

_se_hint_viv="AMD Vivado 2026.1+ for Linux, e.g. /tools/Xilinx/2026.1/Vivado (or set XILINX_VIVADO). Windows xsim cannot load the Linux-built co-sim models."
_se_vv=${XILINX_VIVADO:-}
[ -z "$_se_vv" ] && command -v vivado >/dev/null 2>&1 && _se_vv=$(dirname "$(dirname "$(command -v vivado)")")
[ -z "$_se_vv" ] && _se_vv=$(_se_newest /tools/Xilinx/20*/Vivado /tools/Xilinx/Vivado/20* \
                                        /opt/Xilinx/20*/Vivado /opt/Xilinx/Vivado/20* \
                                        "$HOME"/Xilinx/20*/Vivado "$HOME"/Xilinx/Vivado/20*)
if [ -n "$_se_vv" ] && [ -x "$_se_vv/bin/vivado" ]; then
    _se_vver=$(echo "$_se_vv" | grep -oE '20[0-9]{2}\.[0-9]' | tail -1)
    if _se_ge "${_se_vver:-0}" 2026.1; then
        printf '  %-18s %-12s %s\n' XILINX_VIVADO "${_se_vver:-?}" "$_se_vv" >&2
    else
        printf '  %-18s %-12s %s -- TOO OLD, need 2026.1 or later\n' XILINX_VIVADO "${_se_vver:-?}" "$_se_vv" >&2
        _se_need "$_se_hint_viv"
    fi
    _se_set XILINX_VIVADO "$_se_vv"
    _se_set VIVADO        "$_se_vv/bin/vivado"
    _se_set XVLOG         "$_se_vv/bin/xvlog"
    _se_set XELAB         "$_se_vv/bin/xelab"
    _se_set SIMEXE        "$_se_vv/bin/xsim"
else
    printf '  %-18s %-12s %s\n' XILINX_VIVADO MISSING "(co-simulation and the lint cdc phase need it)" >&2
    _se_need "$_se_hint_viv"
fi

# ---- summary --------------------------------------------------------------
[ "$PATH" != "$_se_path0" ] && { export PATH; [ $_se_csh = 1 ] && printf 'setenv PATH "%s";\n' "$PATH"; }
if [ $_se_bad -gt 0 ]; then
    _se_msg ""
    _se_msg "WARNING: $_se_bad tool(s) missing or too old. To install:$_se_todo"
    _se_msg "The build steps that do not need them still work."
else
    _se_msg "OK -- all tools found"
fi
[ $_se_src = 0 ] && [ $_se_csh = 0 ] && \
    _se_msg "(report only -- 'source' this file to set the variables)"

unset _se_csh _se_src _se_path0 _se_bad _se_todo _se_x7 _se_hint_x7 _se_rv _se_hint_rv \
      _se_hint_rdl _se_py _se_vb _se_hint_cc _se_hint_viv _se_vv _se_vver _se_ui
unset -f _se_msg _se_set _se_need _se_num _se_ge _se_newest _se_tool

# -----------------------------------------------------------------------------
# Project:     openPCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        May 24, 2024
# -----------------------------------------------------------------------------
