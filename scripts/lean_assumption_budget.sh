#!/usr/bin/env bash
# Lean assumption and axiom budget (Issue 15).
#
# Scans proof/lean for `axiom`/`sorry` declarations and grounds every explicit
# proof-grade assumption in the Lean source, then emits
# results/lean_assumption_budget.json. Fails closed (exit 1) when an axiom or
# `sorry` appears outside the documented allowlist, or when a documented
# proof-grade assumption or its consumer is missing from the Lean source, so CI
# rejects new unexpected assumptions.
set -eu

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEAN="$ROOT/proof/lean"
OUT="$ROOT/results/lean_assumption_budget.json"
PROOF_GRADE_ROOT="$LEAN/UOToolchain/ProofGradeRoot.lean"

# Allowlisted legacy axioms: demonstration-only declarations that live in modules
# intentionally excluded from UOToolchain.ProofGradeRoot.
declare -A LEGACY_AXIOM_MODULE=(
  [legacyOramLocalTheorem]="UOToolchain.OramGame"
  [legacySgxMicroLocalTheorem]="UOToolchain.SgxMicroGame"
)

# Active proof-grade assumptions: "id|role|consumer-anchor" grounded in Lean.
ACTIVE_ASSUMPTIONS=(
  "bucketEncryptionINDCPA|hides Path ORAM bucket/path ciphertext contents|PathOramLocalPosmapV1SecurityAssumptions"
  "metadataEncryptionINDCPA|hides encrypted position-map metadata pages|PathOramLocalPosmapV1SecurityAssumptions"
  "stashOverflowBounded|bounds Path ORAM stash overflow at deployed parameters|PathOramLocalPosmapV1SecurityAssumptions"
  "SgxDeploymentAssumptions|TEE confidentiality/integrity/attestation/rollback/freshness|DeploymentAcceptance"
)

# --- scan all axiom declarations ---
# Only line-start `axiom name` declarations, not prose mentions of "axiom" in
# comments/docstrings.
mapfile -t AXIOMS < <(grep -rhoE '^[[:space:]]*axiom[[:space:]]+[A-Za-z0-9_]+' "$LEAN" --include='*.lean' 2>/dev/null \
  | grep -oE 'axiom[[:space:]]+[A-Za-z0-9_]+' | awk '{print $2}' | sort -u)
SORRY_COUNT=$(grep -rnE '(^|[^A-Za-z0-9_])sorry([^A-Za-z0-9_]|$)' "$LEAN" --include='*.lean' 2>/dev/null | grep -vE '\-\-|/-' | wc -l | tr -d ' ')

# --- unexpected axioms (declared but not allowlisted as legacy) ---
UNEXPECTED=()
for ax in "${AXIOMS[@]:-}"; do
  [[ -z "$ax" ]] && continue
  [[ -n "${LEGACY_AXIOM_MODULE[$ax]:-}" ]] || UNEXPECTED+=("$ax")
done

# --- ProofGradeRoot must not import the legacy axiom modules ---
EXCLUDES_LEGACY=true
for mod in "${LEGACY_AXIOM_MODULE[@]}"; do
  grep -qE "^import[[:space:]]+$mod([[:space:]]|$)" "$PROOF_GRADE_ROOT" 2>/dev/null && EXCLUDES_LEGACY=false
done

# --- legacy axioms JSON + presence grounding ---
LEGACY_JSON="[]"
for ax in $(printf '%s\n' "${!LEGACY_AXIOM_MODULE[@]}" | sort); do
  present=false
  grep -rqE "axiom[[:space:]]+$ax([[:space:]]|$)" "$LEAN" --include='*.lean' 2>/dev/null && present=true
  excluded=true
  grep -qE "^import[[:space:]]+${LEGACY_AXIOM_MODULE[$ax]}([[:space:]]|$)" "$PROOF_GRADE_ROOT" 2>/dev/null && excluded=false
  LEGACY_JSON=$(jq --arg id "$ax" --arg mod "${LEGACY_AXIOM_MODULE[$ax]}" \
    --argjson present "$present" --argjson excluded "$excluded" \
    '. + [{id:$id, module:$mod, declared_present:$present, excluded_from_proof_grade_root:$excluded}]' <<<"$LEGACY_JSON")
done

# --- active assumptions JSON + presence grounding ---
ACTIVE_JSON="[]"
ALL_ACTIVE_PRESENT=true
for entry in "${ACTIVE_ASSUMPTIONS[@]}"; do
  IFS='|' read -r id role consumer <<<"$entry"
  id_present=false
  grep -rqE "[^A-Za-z0-9_]$id([^A-Za-z0-9_]|$)" "$LEAN" --include='*.lean' 2>/dev/null && id_present=true
  consumer_present=false
  grep -rqE "[^A-Za-z0-9_]$consumer([^A-Za-z0-9_]|$)" "$LEAN" --include='*.lean' 2>/dev/null && consumer_present=true
  [[ "$id_present" == true && "$consumer_present" == true ]] || ALL_ACTIVE_PRESENT=false
  ACTIVE_JSON=$(jq --arg id "$id" --arg role "$role" --arg consumer "$consumer" \
    --argjson idp "$id_present" --argjson cp "$consumer_present" \
    '. + [{id:$id, role:$role, consumer:$consumer, declared_present:$idp, consumer_present:$cp}]' <<<"$ACTIVE_JSON")
done

UNEXPECTED_JSON=$(printf '%s\n' "${UNEXPECTED[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')
ACCEPTED=true
[[ "${#UNEXPECTED[@]}" -eq 0 && "$SORRY_COUNT" -eq 0 && "$EXCLUDES_LEGACY" == true && "$ALL_ACTIVE_PRESENT" == true ]] || ACCEPTED=false

jq -n \
  --argjson active "$ACTIVE_JSON" \
  --argjson legacy "$LEGACY_JSON" \
  --argjson unexpected "$UNEXPECTED_JSON" \
  --argjson sorry_count "$SORRY_COUNT" \
  --argjson axiom_count "${#AXIOMS[@]}" \
  --argjson excludes_legacy "$EXCLUDES_LEGACY" \
  --argjson all_active_present "$ALL_ACTIVE_PRESENT" \
  --argjson accepted "$ACCEPTED" \
  '{
     schema: "uo.lean_assumption_budget.v1",
     proof_grade_root: "UOToolchain.ProofGradeRoot",
     active_assumptions: $active,
     legacy_axioms: $legacy,
     scanned: {axiom_declaration_count: $axiom_count, sorry_count: $sorry_count},
     unexpected_axioms_outside_allowlist: $unexpected,
     proof_grade_root_excludes_legacy_axiom_modules: $excludes_legacy,
     all_active_assumptions_grounded_in_lean: $all_active_present,
     accepted: $accepted
   }' >"$OUT"

if [[ "$ACCEPTED" != true ]]; then
  echo "lean_assumption_budget: FAILED (unexpected axioms: ${UNEXPECTED[*]:-none}; sorry_count: $SORRY_COUNT; excludes_legacy: $EXCLUDES_LEGACY; active_grounded: $ALL_ACTIVE_PRESENT)" >&2
  exit 1
fi
echo "lean_assumption_budget: accepted (${#ACTIVE_ASSUMPTIONS[@]} active assumptions, ${#LEGACY_AXIOM_MODULE[@]} legacy axioms, 0 unexpected) -> $OUT"
