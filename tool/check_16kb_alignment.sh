#!/usr/bin/env bash
# Verifies that an APK is compatible with Android devices that use 16 KB
# memory pages (required by Google Play for apps targeting Android 15+).
#
#   tool/check_16kb_alignment.sh path/to/app.apk
#
# Two checks, mirroring Google's check_elf_alignment.sh and
# https://developer.android.com/guide/practices/page-sizes:
#   1. Every 64-bit native library (arm64-v8a, x86_64) has ELF LOAD segments
#      aligned to at least 16 KB (2**14).
#   2. The APK itself is zip-aligned so uncompressed .so entries start on a
#      16 KB boundary (zipalign -c -P 16).
#
# usb_serial itself ships no native code; this guards the example app as a
# whole (Flutter engine + plugins) and proves nothing non-compliant is added.
#
# Tool discovery: $READELF, then readelf / llvm-readelf on PATH, then the
# newest NDK's llvm-readelf. zipalign comes from $ZIPALIGN or the newest
# build-tools in $ANDROID_HOME / $ANDROID_SDK_ROOT (~/Library/Android/sdk
# on macOS). Exits non-zero on any failure.

set -euo pipefail

apk="${1:-}"
if [[ -z "$apk" || ! -f "$apk" ]]; then
  echo "usage: $0 <app.apk>" >&2
  exit 2
fi

sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"

# Prints the highest-versioned existing path among the (glob-expanded) args.
newest() {
  local p
  for p in "$@"; do
    if [[ -e "$p" ]]; then printf '%s\n' "$p"; fi
  done | sort -V | tail -n 1
}

readelf_bin="${READELF:-}"
if [[ -z "$readelf_bin" ]]; then
  readelf_bin="$(command -v readelf || command -v llvm-readelf || true)"
fi
if [[ -z "$readelf_bin" ]]; then
  readelf_bin="$(newest "$sdk"/ndk/*/toolchains/llvm/prebuilt/*/bin/llvm-readelf)"
fi
if [[ -z "$readelf_bin" || ! -x "$readelf_bin" ]]; then
  echo "error: readelf not found (set READELF, install binutils, or install an NDK)" >&2
  exit 2
fi

zipalign_bin="${ZIPALIGN:-}"
if [[ -z "$zipalign_bin" ]]; then
  zipalign_bin="$(newest "$sdk"/build-tools/*/zipalign)"
fi
if [[ -z "$zipalign_bin" || ! -x "$zipalign_bin" ]]; then
  echo "error: zipalign not found (set ZIPALIGN or ANDROID_HOME)" >&2
  exit 2
fi

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
unzip -q "$apk" 'lib/*' -d "$workdir" 2>/dev/null || true

failed=0
checked=0

echo "== ELF LOAD segment alignment (64-bit ABIs) =="
while IFS= read -r -d '' so; do
  rel="${so#"$workdir"/}"
  # The last column of each LOAD program header is its alignment, e.g. 0x4000.
  min_align=""
  while read -r align; do
    value=$((align))
    if [[ -z "$min_align" || $value -lt $min_align ]]; then
      min_align=$value
    fi
  done < <("$readelf_bin" -lW "$so" | awk '$1 == "LOAD" { print $NF }')

  checked=$((checked + 1))
  if [[ -z "$min_align" ]]; then
    printf 'FAIL  %-45s no LOAD segments found\n' "$rel"
    failed=1
  elif ((min_align >= 16384)); then
    printf 'OK    %-45s align=%d KB\n' "$rel" $((min_align / 1024))
  else
    printf 'FAIL  %-45s align=%d bytes (< 16 KB)\n' "$rel" "$min_align"
    failed=1
  fi
done < <(find "$workdir/lib/arm64-v8a" "$workdir/lib/x86_64" -name '*.so' -print0 2>/dev/null | sort -z)

if ((checked == 0)); then
  echo "no 64-bit native libraries in APK; nothing to check"
fi

echo
echo "== APK zip alignment (zipalign -c -P 16) =="
if "$zipalign_bin" -c -P 16 -v 4 "$apk" >"$workdir/zipalign.log" 2>&1; then
  echo "OK    $(basename "$apk") is 16 KB zip-aligned"
else
  grep -E 'BAD|lib/.*\.so' "$workdir/zipalign.log" | grep -v '(OK' || cat "$workdir/zipalign.log"
  echo "FAIL  $(basename "$apk") is not 16 KB zip-aligned"
  failed=1
fi

echo
if ((failed)); then
  echo "RESULT: NOT compatible with 16 KB page sizes"
  exit 1
fi
echo "RESULT: compatible with 16 KB page sizes"
