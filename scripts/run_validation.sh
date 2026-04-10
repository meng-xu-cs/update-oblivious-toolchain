#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"
./scripts/compile_benches.sh
cargo test
cargo run -q -p mplus-probe -- --out-dir results
