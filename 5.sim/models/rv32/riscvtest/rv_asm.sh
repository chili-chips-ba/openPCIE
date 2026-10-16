#!/usr/bin/bash

if [ "$FNAME" != "" ]
then
  FNAME=$1
else
  FNAME="main.s"
fi

ONAME=main
STARTADDR=0
DATAADDR=1000
TESTDIR=.

# full prefix from 4.build/set-env.sh, else riscv-none-elf- on the PATH
PREFIX=${RISCV_PREFIX:-riscv-none-elf-}

${PREFIX}as -fpic -march=rv32imafdc -aghlms=$TESTDIR/$ONAME.list -o $TESTDIR/$ONAME.o $TESTDIR/$FNAME
${PREFIX}ld $TESTDIR/$ONAME.o -Ttext $STARTADDR -Tdata $DATAADDR -melf32lriscv -o $ONAME.bin
