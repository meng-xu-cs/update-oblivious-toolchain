#!/usr/bin/env bash
# Fail if tracked files embed machine-specific absolute home paths.
#
# Tests, scripts, and generated artifacts must not depend on where the
# repository is checked out: resolve repository files from
# `env!("CARGO_MANIFEST_DIR")` (Rust) or the script's own location (shell). A
# literal /home/<user>/ or /Users/<user>/ path in a tracked file means the file
# only works, or only regenerates byte-for-byte, on the machine that wrote it.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if matches="$(git grep -nIE '/(home|Users)/[A-Za-z0-9._-]+/' -- . ':!scripts/check_portable_paths.sh')"; then
  printf 'machine-specific absolute paths found in tracked files:\n%s\n' "$matches" >&2
  exit 1
fi
printf 'no machine-specific absolute home paths in tracked files\n'
