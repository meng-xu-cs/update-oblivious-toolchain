#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export UO_ARTIFACT_MODE=heavy
export UO_RESULTS_DIR="${UO_RESULTS_DIR:-results-heavy}"
export UO_HEAVY_ARTIFACT_BUDGET_BYTES="${UO_HEAVY_ARTIFACT_BUDGET_BYTES:-21474836480}"

cd "$ROOT"
./scripts/run_validation.sh
