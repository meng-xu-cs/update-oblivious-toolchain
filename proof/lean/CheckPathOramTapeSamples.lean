import UOToolchain.ProofGrade
import UOToolchain.PathOramTapeWitness

open UOToolchain
open UOToolchain.PathOramTapeWitness
open Lean

/-- One call: its representative run, and runs of the same call on the same
contents that were deployed with other seeds, so that they hold other leaves
and draw other coins. -/
structure ImportedTapeSampleCase where
  name : String
  representative : ImportedRuntimeRefinementWitness
  samples : List ImportedRuntimeRefinementWitness
deriving FromJson

structure ImportedTapeSampleCases where
  schema : String
  cases : List ImportedTapeSampleCase
deriving FromJson

/-- The schema tag of the probe's tape-substitution samples. -/
def tapeSamplesSchema : String := "uo-tape-substitution-samples-v1"

/-- Check that every sampled runtime run is its case's representative run with
the sample's own tape substituted (`sampleCheck`), after the representative has
passed the tape-family checks (`tapeWitnessCheck`). This tests, and does not
prove, that the runtime's run on a tape is the substituted run. -/
def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
    let raw ← IO.FS.readFile path
    let parsed : Except String ImportedTapeSampleCases := Json.parse raw >>= fromJson?
    match parsed with
    | .error err =>
      IO.eprintln s!"failed to parse tape samples: {err}"
      pure 2
    | .ok input =>
      if input.schema != tapeSamplesSchema then
        IO.eprintln s!"tape samples schema {input.schema}, expected {tapeSamplesSchema}"
        return 2
      if input.cases.isEmpty then
        IO.eprintln "the tape samples have no case"
        return 2
      let mut runs := 0
      let mut otherTapes := 0
      let mut otherStarts := 0
      for c in input.cases do
        let w := c.representative.toRuntimeWitness
        if tapeWitnessCheck w != true then
          IO.eprintln s!"{c.name}: the representative run fails the tape-family checks"
          return 1
        let samples := c.samples.map ImportedRuntimeRefinementWitness.toRuntimeWitness
        if samples.all (sampleCheck w) != true then
          IO.eprintln s!"{c.name}: a runtime run is not the representative run with its tape's leaves"
          return 1
        let present := (runPresent w).length
        runs := runs + samples.length
        otherTapes := otherTapes +
          (samples.filter fun run => sampleTape w run != sampleTape w w).length
        otherStarts := otherStarts +
          (samples.filter fun run =>
            (sampleTape w run).take present != (sampleTape w w).take present).length
      IO.println s!"cases={input.cases.length} runs={runs} other_tapes={otherTapes} other_starts={otherStarts}"
      pure 0
  | _ =>
    IO.eprintln "usage: checkPathOramTapeSamples <tape-samples.json>"
    pure 2
