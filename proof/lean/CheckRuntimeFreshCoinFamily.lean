import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkRuntimeFreshCoinFamily <family.json> <page-model> <exit-model> <shared-resource-model>"

def familyEntrypoint
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily) : String :=
  match family.witnesses.head? with
  | some witness => witness.public_outcome.entrypoint_id
  | none => "<empty>"

def witnessFailureReason
  (seed : Nat)
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (witness : ImportedRuntimeRefinementWitness)
  (modelTags : SGXModelTags) : Option String :=
  if !witness.checkValid modelTags then
    let parts := [
      if !witness.toRuntimeWitness.checkValid modelTags then
        some "toRuntimeWitness.checkValid = false"
      else
        none,
      if !witness.checkKernelWitness then
        some "checkKernelWitness = false"
      else
        none,
      if !witness.checkRuntimeKernelRefinementWitness then
        some "checkRuntimeKernelRefinementWitness = false"
      else
        none
    ]
    some s!"seed {seed}: witness.checkValid = false ({String.intercalate ", " <| parts.filterMap id})"
  else if decide
      (witness.toRuntimeWitness.oramLeafPublicScaffold =
        family.runtimePublicLeafScaffold) = false then
    some s!"seed {seed}: oramLeafPublicScaffold does not match family public_leaf_scaffold"
  else if decide
      (witness.toRuntimeWitness.pathOramFreshCoinScaffold? =
        some family.projectedPublicFreshCoinScaffold) = false then
    some s!"seed {seed}: pathOramFreshCoinScaffold? does not match family public_fresh_coin_scaffold"
  else if decide
      (witness.toRuntimeWitness.pathOramFreshCoinValues? =
        some (pathOramLeafValueTraceOfSeed family.projectedPublicFreshCoinScaffold seed)) = false then
    some s!"seed {seed}: pathOramFreshCoinValues? does not match canonical seed-derived fresh-coin values"
  else
    none

def familyFailureReason?
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Option String :=
  if _hLen : family.witnesses.length ≠ family.seed_count then
    some s!"witness count {family.witnesses.length} does not match seed_count {family.seed_count}"
  else
    let expectedSeedCount :=
      pathOramLeafValueSeedSpaceSize family.projectedPublicFreshCoinScaffold
    if _hSeed : family.seed_count ≠ expectedSeedCount then
      some s!"seed_count {family.seed_count} does not match projected scaffold seed count {expectedSeedCount}"
    else
      let rec go : List Nat → Option String
      | [] => none
      | seed :: rest =>
          match family.witnessAt? seed with
          | none => some s!"seed {seed}: witnessAt? returned none"
          | some witness =>
              match witnessFailureReason seed family witness modelTags with
              | some reason => some reason
              | none => go rest
      go (List.range family.seed_count)

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let family ← loadImportedCanonicalFreshCoinRuntimePathOramWitnessFamily path
      if family.checkValid modelTags then
        IO.println
          s!"validated canonical fresh-coin path-ORAM runtime witness family for {familyEntrypoint family} with {family.seed_count} seeds"
        pure 0
      else
        let reason := (familyFailureReason? family modelTags).getD "unknown family validity failure"
        throw <| IO.userError
          s!"failed to validate canonical fresh-coin path-ORAM runtime witness family: {reason}"
  | _ =>
      IO.eprintln usage
      pure 1
