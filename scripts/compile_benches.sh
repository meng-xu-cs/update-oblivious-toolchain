#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT/benches/uo"

mkdir -p "$OUT_DIR"

compile() {
  local source="$1"
  local meta="$2"
  local mode="$3"
  local out="$4"
  cargo run -q -p uo-solc -- \
    --source "$ROOT/$source" \
    --metadata "$ROOT/$meta" \
    --mode "$mode" \
    --out "$ROOT/$out"
}

compile benches/raw/FixedSlotClassifier.sol benches/raw/FixedSlotClassifier.uo.yaml uo benches/uo/FixedSlotClassifier.uo.json
compile benches/raw/AuthScan.sol benches/raw/AuthScan.uo.yaml uo benches/uo/AuthScan.uo.json
compile benches/raw/ConfidentialMixer.sol benches/raw/ConfidentialMixer.uo.yaml uo benches/uo/ConfidentialMixer.fullscan.json
compile benches/raw/ConfidentialMixer.sol benches/raw/ConfidentialMixer.fullscan64.yaml uo benches/uo/ConfidentialMixer.fullscan64.json
compile benches/raw/ConfidentialMixer.sol benches/raw/ConfidentialMixer.oram.yaml uo benches/uo/ConfidentialMixer.oram.json
compile benches/raw/ConfidentialMixer.sol benches/raw/ConfidentialMixer.private-posmap.yaml uo benches/uo/ConfidentialMixer.private-posmap.json
compile benches/raw/ERC20Lite.sol benches/raw/ERC20Lite.uo.yaml uo benches/uo/ERC20Lite.fullscan.json
compile benches/raw/ERC20Lite.sol benches/raw/ERC20Lite.oram.yaml uo benches/uo/ERC20Lite.oram.json
compile benches/raw/ERC20Lite.sol benches/raw/ERC20Lite.private-posmap.yaml uo benches/uo/ERC20Lite.private-posmap.json
compile benches/raw/RegistryCRUD.sol benches/raw/RegistryCRUD.uo.yaml uo benches/uo/RegistryCRUD.uo.json
