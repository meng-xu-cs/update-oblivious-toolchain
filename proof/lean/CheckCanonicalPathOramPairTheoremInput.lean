import UOToolchain.ProofGrade
import UOToolchain.PathOramTapeWitness

open UOToolchain
open UOToolchain.PathOramTapeWitness
open Lean

def usage : String :=
  "usage: checkCanonicalPathOramPairTheoremInput <theorem-input.json> <page-model> <exit-model> <shared-resource-model> [<tape-samples.json>]"

def checkerAssumptions : PathOramLocalPosmapV1SecurityAssumptions :=
  { bucketEncryptionINDCPA := True
  , metadataEncryptionINDCPA := True
  , stashOverflowBounded := True
  }

/-- Runtime runs of each side's call on other tapes (other deployment seeds,
so other leaves for the keys present before the call, and other coins). -/
structure ImportedTapeFamilySamples where
  lhs_samples : List ImportedRuntimeRefinementWitness
  rhs_samples : List ImportedRuntimeRefinementWitness
deriving FromJson, ToJson

def checkSamples (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
    (samplesPath : String) : IO UInt32 := do
  let raw ← IO.FS.readFile samplesPath
  let parsed : Except String ImportedTapeFamilySamples := Json.parse raw >>= fromJson?
  let samples : ImportedTapeFamilySamples ←
    match parsed with
    | .ok samples => pure samples
    | .error err => throw <| IO.userError s!"failed to parse tape-family samples: {err}"
  let lhs := input.lhs_input.runtimeRepresentativeWitness
  let rhs := input.rhs_input.runtimeRepresentativeWitness
  let lhsSamples := lhs :: samples.lhs_samples.map ImportedRuntimeRefinementWitness.toRuntimeWitness
  let rhsSamples := rhs :: samples.rhs_samples.map ImportedRuntimeRefinementWitness.toRuntimeWitness
  if hLhs : lhsSamples.all (sampleCheck lhs) = true then
    if hRhs : rhsSamples.all (sampleCheck rhs) = true then
      -- Every checked run, the representative's included, is its side's
      -- representative run on the run's own tape.
      have _ := samplesCheck_sound hLhs
      have _ := samplesCheck_sound hRhs
      let otherTapes := fun (w : RuntimeRefinementWitness) (runs : List RuntimeRefinementWitness) =>
        (runs.filter fun run => sampleTape w run != sampleTape w w).length
      let otherStarts := fun (w : RuntimeRefinementWitness) (runs : List RuntimeRefinementWitness) =>
        (runs.filter fun run =>
          (sampleTape w run).take (runPresent w).length != (sampleTape w w).take (runPresent w).length).length
      let lhsRuns := lhsSamples.drop 1
      let rhsRuns := rhsSamples.drop 1
      IO.println
        s!"checked {lhsRuns.length} lhs and {rhsRuns.length} rhs runtime runs against the tape families for {input.runtimePublicOutcome.entrypointId}: {otherTapes lhs lhsRuns} and {otherTapes rhs rhsRuns} on other tapes, {otherStarts lhs lhsRuns} and {otherStarts rhs rhsRuns} with other leaves for the {(runPresent lhs).length} and {(runPresent rhs).length} keys present before the call"
      pure 0
    else
      IO.eprintln "an rhs runtime run is not the rhs run with its tape's leaves"
      pure 1
  else
    IO.eprintln "an lhs runtime run is not the lhs run with its tape's leaves"
    pure 1

def main (args : List String) : IO UInt32 := do
  match args with
  | path :: pageModel :: exitModel :: sharedResourceModel :: rest =>
      if rest.length > 1 then
        IO.eprintln usage
        return 1
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let theoremInput ←
        loadAndCheckImportedProofGradeCanonicalFreshCoinRuntimePathOramPairTheoremInput
          path
          modelTags
      IO.println
        s!"validated proof-grade canonical fresh-coin path-ORAM pair theorem input for {theoremInput.runtimePublicOutcome.entrypointId}"
      if hProofGrade : theoremInput.checkProofGrade modelTags = true then
        have hValid : theoremInput.Valid modelTags :=
          importedCanonicalFreshCoinRuntimePathOramPairTheoremInput_proofGradeValid_implies_valid
            ((importedCanonicalFreshCoinRuntimePathOramPairTheoremInput_checkProofGrade_eq_true_iff
              theoremInput modelTags).mp hProofGrade)
        if hLhs : tapeWitnessCheck theoremInput.lhs_input.runtimeRepresentativeWitness = true then
          if hRhs : tapeWitnessCheck theoremInput.rhs_input.runtimeRepresentativeWitness = true then
            -- Each side's runs on every tape are its representative run with
            -- the tape's leaves; the paper-main relation holds between the sides.
            have _ :=
              (tapePairOfTheoremInput theoremInput hValid hLhs hRhs).sgxViewRelation_sides
                checkerAssumptions
            IO.println
              s!"derived the Path ORAM tape-family theorem for {theoremInput.runtimePublicOutcome.entrypointId}: each side's run on every tape is its representative run with the tape's leaves, and the two sides are related"
            match rest with
            | [samplesPath] => checkSamples theoremInput samplesPath
            | _ => pure 0
          else
            IO.eprintln "rhs representative run fails the tape-family checks"
            pure 1
        else
          IO.eprintln "lhs representative run fails the tape-family checks"
          pure 1
      else
        IO.eprintln "pair theorem input failed Lean proof-grade validity checks"
        pure 1
  | _ =>
      IO.eprintln usage
      pure 1
