#!/bin/sh
# Builds lib/libzstd.a and installs the public zstd headers into include/.
# Runs inside a private copy of vendor/ with CC, AR, CFLAGS, and DOOF_JOBS
# supplied by the Doof compiler.
set -eu

# The x86-64 assembly decoder is not built; use the portable C decoder.
defines="-DZSTD_DISABLE_ASM"
includes="-Izstd/lib -Izstd/lib/common"
jobs=${DOOF_JOBS:-1}

mkdir -p include lib obj
cp zstd/lib/zstd.h zstd/lib/zstd_errors.h include/

pids=''
active=0
status=0
objects=''
for source in zstd/lib/common/*.c zstd/lib/compress/*.c zstd/lib/decompress/*.c; do
  object="obj/$(echo "$source" | sed 's|^zstd/lib/||; s|/|_|g; s|\.c$|.o|')"
  objects="$objects $object"
  # shellcheck disable=SC2086
  $CC $CFLAGS $defines $includes -c "$source" -o "$object" &
  pids="$pids $!"
  active=$((active + 1))
  if [ "$active" -ge "$jobs" ]; then
    for pid in $pids; do wait "$pid" || status=1; done
    pids=''
    active=0
  fi
done
for pid in $pids; do wait "$pid" || status=1; done
[ "$status" -eq 0 ]

rm -f lib/libzstd.a
# shellcheck disable=SC2086
$AR rcs lib/libzstd.a $objects
