#!/bin/bash
# SPDX-FileCopyrightText: 2026 Chili.CHIPS
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Lint of the opensource RTL (2.rtl/0.common.opensource/src): syntax and
# limited semantic checks with a set of opensource tools, run in this order:
#
#   tags       every /*LINT:OK*/ sits on an output port (no tool needed)
#   verilator  Verilator --lint-only -Wall: unused/undriven signals, widths,
#              implicit nets, multiple drivers, blocking vs non-blocking, case
#   yosys      Yosys check on the read_slang netlist: combinational loops,
#              conflicting drivers, used-but-undriven wires, latches
#   slang      read_slang -Wextra: strict IEEE parse, second opinion (read_slang
#              has no --lint-only, that needs standalone slang)
#   verible    Verible style rules (run-lint.verible): our case rule -- signals
#              and ports lower case, constants UPPER case -- and Verible's defaults
#   cdc        Vivado report_cdc: clock-domain crossings and their
#              synchronizers (there is no mature opensource CDC checker)
#
# usage:  bash run-lint.sh [phase ...]      default: all phases
#         LANES=1 bash run-lint.sh            lint the x1 link (default x4)
#         CPU=picorv32 bash run-lint.sh       lint the PicoRV32 build (default edubos5;
#                                             edubos5_3stg: 3-stage pipeline)
#
# A phase whose tool is not found is skipped. Source ../set-env.sh first; the
# cdc phase needs Vivado. The tool commands can be overridden: VERILATOR, YOSYS
# (+ YOSYS_ARGS), YOSYS_CONFIG, PYTHON, VERIBLE, VIVADO. The tags and Verilator phases
# need the Xilinx primitive stubs that gen_xilinx_bb.py builds from the Yosys
# library: from yosys-config, or pass XILINX_BB=<stubs.sv> from a run that had
# Yosys.
#
# Sources are copied into a work directory (LINT_WORK, default mktemp -d) and
# every tool gets relative paths, since Windows tools cannot read UNC or WSL
# paths. Logs stay there: <phase>.log is the tool output, <phase>.findings the
# findings left after the waivers.
#
# Accepted findings are waived in two ways, each one reviewed:
#   - inline, on an unused output of an instance:  .PIN (/*LINT:OK*/)
#     waives the findings about that pin, from any phase; the tags phase flags
#     a /*LINT:OK*/ on an input, so it cannot hide a floating input
#   - run-lint-waivers.txt (or LINT_WAIVERS=<file>), for findings without a
#     source line of ours (generated code, Vivado reports, ...)
# Exit status is non-zero when any phase has findings that are not waived.
#
# TODO: Verilator lints the SYN_YOSYS_BUG variant of the RTL, as the stubs have
#       no real parameters.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
SRC=$HERE/../../2.rtl/0.common.opensource
CSR=$HERE/../csr_build/generated-files
TOP=RC_opensource
PART=xc7a200tfbg484-3

VERILATOR=${VERILATOR:-verilator}
YOSYS=${YOSYS:-yosys}
YOSYS_CONFIG=${YOSYS_CONFIG:-yosys-config}
PYTHON=${PYTHON:-python3}
YOSYS_ARGS=${YOSYS_ARGS:-}   # e.g. "-m slang" where read_slang is a plugin (OSS CAD Suite)
VERIBLE=${VERIBLE:-verible-verilog-lint}
VIVADO=${VIVADO:-vivado}
LANES=${LANES:-4}
CPU=${CPU:-edubos5}
PICORV32_SV="src/picorv32.CHILI.sv"
EDUBOS5_SV=$(for f in pkg rf alu; do echo src/CPU.eduBOS5/edubos5_$f.sv; done; echo src/CPU.eduBOS5/edubos5.sv)
case $CPU in
  picorv32) CPU_SV=$PICORV32_SV; OTHER_CPU_SV=$EDUBOS5_SV; CPU_DEF=SOC_CPU_PICORV32 ;;
  edubos5)  CPU_SV=$EDUBOS5_SV; OTHER_CPU_SV=$PICORV32_SV; CPU_DEF="" ;;
  edubos5_3stg) CPU_SV=$EDUBOS5_SV; OTHER_CPU_SV=$PICORV32_SV; CPU_DEF=SOC_EDUBOS5_3STG ;;
  *) echo "CPU must be picorv32, edubos5 or edubos5_3stg, got \"$CPU\""; exit 1 ;;
esac
VL_DEFS=""; SL_DEFS=""; VIV_DEFS=""
for d in $CPU_DEF; do
  VL_DEFS="$VL_DEFS -D$d"; SL_DEFS="$SL_DEFS -D $d"; VIV_DEFS="$VIV_DEFS -verilog_define $d"
done
WAIVERS=${LINT_WAIVERS:-$HERE/run-lint-waivers.txt}

PHASES=${*:-tags verilator yosys slang verible cdc}
W=${LINT_WORK:-$(mktemp -d)}
mkdir -p "$W"

# ---- work copy, in the same order as SV_ORDERED in the Makefile ---------------
cp -r "$SRC/src" "$SRC/xdc" "$W/"
cp "$CSR/csr_pkg.sv" "$CSR/csr.sv" "$HERE/unimacro_shim.v" "$W/"
cp "$HERE/../sw_build/firmware.hex" "$W/"
cp "$SRC/../2.RC-direct.opensource/xdc/RC-direct.x${LANES}g2.AcornCLE-215P.xdc" "$W/xdc/"
cd "$W"

P=src/pcie
SV_IF=$(for i in axis_if trn_if cfg_if mem_if mim_if gtp_if pipe_if; do echo $P/$i.sv; done)
SV_REST=$(ls $P/*.sv | grep -v -e '_if\.sv$' -e '_pkg\.sv$')
SV=$(echo $P/link_pkg.sv $P/pcie_pkg.sv csr_pkg.sv $SV_IF $SV_REST csr.sv src/soc_csr.sv \
          $CPU_SV src/riscv_pcie_soc.sv src/$TOP.sv)
SHIMS="unimacro_shim.v"
PRIMS="PCIE_2_1 GTPE2_CHANNEL GTPE2_COMMON MMCME2_ADV IBUFDS_GTE2 BUFG BUFGCTRL FDCE RAMB36E1"

have() { command -v "$1" >/dev/null 2>&1; }
declare -A RESULT
skip() { RESULT[$1]="skipped ($2)"; echo "-- $1: skipped, $2"; }

# waiver regexes of one phase: the lines "<phase> <regex>" of the waivers file
waivers() {
  [ -f "$WAIVERS" ] || return 0
  awk -v ph="$1" '{ sub(/\r$/, "") } $1 == ph { sub(/^[ \t]*[^ \t]+[ \t]+/, ""); print }' "$WAIVERS"
}

# inline waivers .PIN (/*LINT:OK*/), as file:line:PIN (the first line keeps
# awk's NR==FNR test working when there is none)
{ echo "#"
  grep -n -o -E '\.[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([[:space:]]*/\*LINT:OK\*/[[:space:]]*\)' $SV |
    sed -E 's/^([^:]*:[0-9]+):\.([A-Za-z0-9_]*).*/\1:\2/'
} > lint_ok.txt

found() {  # $1 phase; one finding per line on stdin (not a pipe: RESULT must stay in this shell)
  cat > $1.all
  # drop findings about a pin waived inline: file:line plus the 'PIN' the tools
  # quote (Windows tools print \ in paths)
  awk 'NR == FNR { ok[$0] = 1; next }
       { l = $0; gsub(/\\/, "/", l)
         if (match(l, /[A-Za-z0-9_.\/-]+\.s?v:[0-9]+/)) {
           k = substr(l, RSTART, RLENGTH)
           if (match(l, /\047[A-Za-z_][A-Za-z0-9_]*\047/) && (k ":" substr(l, RSTART + 1, RLENGTH - 2)) in ok) next
         }
         print }' lint_ok.txt $1.all > $1.inline
  grep -E -v -f <(waivers $1) $1.inline > $1.findings
  local n=$(wc -l < $1.findings) t=$(wc -l < $1.all) i=$(wc -l < $1.inline)
  RESULT[$1]="$n finding(s), $((t - n)) waived ($((t - i)) inline), see $W/$1.findings"
  echo "-- $1: $n finding(s), $((t - n)) waived ($((t - i)) inline)"
}

# Xilinx primitive stubs, for the tags, Verilator, Yosys and slang phases
bb() {
  [ -s bb.sv ] && return 0
  if [ -n "${XILINX_BB:-}" ]; then cp "$XILINX_BB" bb.sv
  elif have "$YOSYS_CONFIG"; then
    "$PYTHON" "$HERE/gen_xilinx_bb.py" "$("$YOSYS_CONFIG" --datdir)/xilinx" bb.sv $PRIMS >/dev/null
  else return 1; fi
}

# /*LINT:OK*/ on anything but an output port; the port directions come from the
# module headers of the design, the shims and the primitive stubs, plus the
# other CPU core: riscv_pcie_soc.sv instantiates both, behind `ifdef
run_tags() {
  bb || { skip tags "no Xilinx stubs (yosys-config or XILINX_BB)"; return; }
  "$PYTHON" - $OTHER_CPU_SV -- bb.sv $SHIMS $SV > tags.log <<'EOF'
import re, sys
ports_only = sys.argv[1:sys.argv.index('--')]
files = sys.argv[sys.argv.index('--') + 1:]
text = {f: open(f).read() for f in ports_only + files}
types = {'logic', 'wire', 'reg', 'signed', 'unsigned', 'var', 'bit', 'integer', 'tri'}
dirs = {}
for t in text.values():
    t = re.sub(r'//[^\n]*|/\*.*?\*/', '', t, flags=re.S)
    for m in re.finditer(r'\bmodule\s+(\w+)(.*?)\bendmodule', t, flags=re.S):
        d = dirs.setdefault(m.group(1), {})
        for p in re.finditer(r'\b(input|output|inout)\b(.*?)(?=\b(?:input|output|inout)\b|[;()]|$)',
                             m.group(2), flags=re.S):
            for part in re.sub(r'\[[^\]]*\]', ' ', p.group(2)).split(','):
                w = [x for x in re.findall(r'[A-Za-z_]\w*', part) if x not in types]
                if w:
                    d.setdefault(w[-1], p.group(1))
tag  = re.compile(r'\.(\w+)\s*\(\s*/\*LINT:OK\*/\s*\)')
inst = re.compile(r'\s*([A-Za-z_]\w*)\s*(#|\s\w+\s*\()')
kw   = {'if', 'else', 'for', 'begin', 'end', 'case', 'assign', 'module', 'always', 'always_ff',
        'always_comb', 'initial', 'function', 'task', 'return', 'generate'}
for f in files:
    lines = text[f].split('\n')
    for n, line in enumerate(lines, 1):
        for m in tag.finditer(line):
            typ = next((t.group(1) for i in range(n - 1, -1, -1)
                        for t in [inst.match(lines[i])] if t and t.group(1) not in kw), None)
            d = dirs.get(typ, {}).get(m.group(1))
            if d != 'output':
                print(f'{f}:{n}: LINT:OK on {d or "unknown"} port {typ}.{m.group(1)}')
EOF
  found tags < tags.log
}

run_verilator() {
  have "$VERILATOR" || { skip verilator "$VERILATOR not found"; return; }
  bb || { skip verilator "no Xilinx stubs (yosys-config or XILINX_BB)"; return; }
  cat > waive.vlt <<'EOF'
`verilator_config
lint_off -file "*bb.sv"
lint_off -file "*_shim.v"
EOF
  "$VERILATOR" --lint-only -Wall -Wno-fatal --top-module $TOP -DSYN_YOSYS_BUG -DPCIE_LANES=$LANES $VL_DEFS \
    -Isrc -I$P waive.vlt bb.sv $SV $SHIMS > verilator.log 2>&1
  found verilator < <(grep -E '^%(Warning|Error)' verilator.log)
}

run_yosys() {
  have "$YOSYS" || { skip yosys "$YOSYS not found"; return; }
  bb || { skip yosys "no Xilinx stubs"; return; }
  "$YOSYS" $YOSYS_ARGS -q -l yosys.log -p "read_slang -D SYN_YOSYS_BUG -D PCIE_LANES=$LANES $SL_DEFS --top $TOP -I $P -I src \
      bb.sv $SV $SHIMS; hierarchy -check -top $TOP; proc; check -nolatches -initdrv" \
      >/dev/null 2>&1
  # read_slang's own warnings are the slang phase's business; take check's
  found yosys < <(awk '/Executing CHECK pass/ { c = 1 } c && /^Warning:/' yosys.log)
}

run_slang() {
  have "$YOSYS" || { skip slang "$YOSYS not found"; return; }
  bb || { skip slang "no Xilinx stubs"; return; }
  "$YOSYS" $YOSYS_ARGS -q -l slang.log -p "read_slang -D SYN_YOSYS_BUG -D PCIE_LANES=$LANES $SL_DEFS --top $TOP -I $P -I src \
      -Wextra bb.sv $SV $SHIMS" >/dev/null 2>&1
  # Yosys' built-in read_slang prints "file:line:col: warning:", the yosys-slang
  # plugin (OSS CAD Suite, CI) prints "file:line: Warning:"; bring both to the
  # first form so the waivers match either
  found slang < <(sed -E 's/^([^ :]+:[0-9]+): Warning:/\1:0: warning:/; s/^([^ :]+:[0-9]+): Error:/\1:0: error:/' slang.log |
                  grep -E 'warning:|error:')
}

run_verible() {
  have "$VERIBLE" || { skip verible "$VERIBLE not found"; return; }
  cp "$HERE/run-lint.verible" .
  "$VERIBLE" --rules_config=run-lint.verible $SV > verible.log 2>&1
  found verible < <(grep -E ':[0-9]+:[0-9]+' verible.log)
}

run_cdc() {
  have "$VIVADO" || { skip cdc "$VIVADO not found"; return; }
  # Vivado has its own XPM and UNIMACRO libraries, so no shims here
  cat > cdc.tcl <<EOF
read_verilog -sv {$SV}
read_xdc [glob xdc/*.xdc]
synth_design -top $TOP -part $PART -flatten_hierarchy rebuilt -verilog_define PCIE_LANES=$LANES$VIV_DEFS
report_cdc -details -file cdc.rpt
report_clock_interaction -file clock_interaction.rpt
EOF
  "$VIVADO" -mode batch -nojournal -log cdc.log -source cdc.tcl >/dev/null 2>&1
  # detail rows: <row> CDC-<n> <severity> <description> ... <from> <to>
  found cdc < <(grep -s -E '^ +[0-9]+ +CDC-[0-9]+ +(Critical|Warning) ' cdc.rpt)
}

for ph in $PHASES; do
  case $ph in
    tags|verilator|yosys|slang|verible|cdc) echo "== $ph"; run_$ph ;;
    *) echo "unknown phase: $ph (tags verilator yosys slang verible cdc)"; exit 2 ;;
  esac
done

echo; echo "== summary  (x$LANES, $W)"
FAIL=0
for ph in $PHASES; do
  printf '  %-10s %s\n' "$ph" "${RESULT[$ph]}"
  case ${RESULT[$ph]} in skipped*|"0 finding"*) ;; *) FAIL=1 ;; esac
done
exit $FAIL

# -----------------------------------------------------------------------------
# Project:     openPCIE
# Description: NLnet-sponsored open-source implementation
# Version:     1.0
# Date:        May 24, 2024
# -----------------------------------------------------------------------------
