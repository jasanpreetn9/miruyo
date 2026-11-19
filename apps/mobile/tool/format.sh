#!/bin/sh
# dart format for everything except generated code: build_runner writes
# *.g.dart at its own width, and CI checks they match what it writes.
# Flags pass through to dart format (e.g. --output=none --set-exit-if-changed);
# paths narrow it (default: lib and test), still skipping *.g.dart.
cd "$(dirname "$0")/.." || exit 1
paths=""
flags=""
for arg in "$@"; do
  case "$arg" in
    -*) flags="$flags $arg" ;;
    *) paths="$paths $arg" ;;
  esac
done
[ -z "$paths" ] && paths="lib test"
# shellcheck disable=SC2086 # word splitting is the point
find $paths -name '*.dart' ! -name '*.g.dart' -print0 | xargs -0 dart format $flags
