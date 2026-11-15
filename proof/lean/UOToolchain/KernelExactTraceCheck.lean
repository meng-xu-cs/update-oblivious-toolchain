import Lean.Data.Json
import UOToolchain.KernelAdmission
import UOToolchain.RuntimeRefinementJson
import UOToolchain.RuntimeStoreCodecSemantics
import UOToolchain.RuntimeValueOpsSemantics

/-!
# A runtime trace against the exact store's encoding

The exact route's theorem (`admittedKernel_exactUO`) is about the physical
trace that the exact store's encoding gives a kernel program
(`exactEncodeRun` in `UOToolchain/KernelExactTrace.lean`): one scan of every
object a statement accesses, in object-id order, when the call loads it, and
at commit one rewrite of every object a statement writes. This file checks a
runtime trace against it. From a call's artifact it decodes the entrypoint's
kernel program and the layout of each object the program touches (its name,
its kind, its slots, and the length of its sealed record), and it compares
the trace's physical reads and writes, as the trace importer names the
events of their scans and rewrites, with `exactEncodeRun` of the program
over that layout (`exactTraceMatches`, sound by `exactTraceMatches_sound`).

That the runtime writes the trace it does is the runtime's part: this check
reads the trace, it does not run the runtime.
-/

namespace UOToolchain.IR

/-- The canonical length of a value of a type, as `Type::canonical_len` in
`crates/uo-core/src/types.rs` computes it: a scalar's width, and for a
struct or an array each part behind a length prefix. -/
def ScalarType.canonicalLen : ScalarType → Nat
  | .bool => 1
  | .uint _ => 32
  | .bytes32 => 32
  | .address => 20

mutual
def Ty.canonicalLen : Ty → Nat
  | .scalar s => s.canonicalLen
  | .structTy fields => Ty.fieldsCanonicalLen fields
  | .array elem size =>
      size * (RuntimeValueOpsSemantics.canonicalLengthPrefixBytes + elem.canonicalLen)

def Ty.fieldsCanonicalLen : List (String × Ty) → Nat
  | [] => 0
  | (name, ty) :: rest =>
      RuntimeValueOpsSemantics.canonicalLengthPrefixBytes + name.utf8ByteSize +
        RuntimeValueOpsSemantics.canonicalLengthPrefixBytes + ty.canonicalLen +
        Ty.fieldsCanonicalLen rest
end

instance : Inhabited ExactObjectLayout :=
  ⟨{ name := "", kind := .cell, slots := 0, recordLen := 0 }⟩

/-- The layout of an object on an exact (full-scan) backend: a cell has one
slot, an array and a map their capacity, and a slot holds the sealed record
of a value, or for a map of a present flag, a key and a value. `none` for an
object on another backend. -/
def StateObject.exactLayout? (object : StateObject) : Option ExactObjectLayout :=
  match object.backend with
  | .fullScan =>
      let valueLen := object.valueType.canonicalLen
      match object.kind with
      | .cell =>
          some { name := object.name, kind := .cell, slots := 1
                 recordLen := RuntimeStoreCodecSemantics.sealedEncodedLen valueLen }
      | .arrayKind =>
          object.capacity.map fun capacity =>
            { name := object.name, kind := .arrayKind, slots := capacity
              recordLen := RuntimeStoreCodecSemantics.sealedEncodedLen valueLen }
      | .mapKind => do
          let keyType ← object.keyType
          let capacity ← object.capacity
          pure { name := object.name, kind := .mapKind, slots := capacity
                 recordLen :=
                   RuntimeStoreCodecSemantics.sealedEncodedLen
                     (1 + keyType.canonicalLen + valueLen) }
  | _ => none

/-- The layout of every object of a contract, by id: an object that is not on
an exact backend, or not declared, has the empty layout, which the check
rejects before it uses it. -/
def exactLayoutOf (state : List StateObject) (objectId : Nat) : ExactObjectLayout :=
  ((stateObjectOf? state objectId).bind StateObject.exactLayout?).getD default

/-- Whether a trace's physical reads and writes are the exact store's
encoding of a program over a contract's layout: every object the program
touches is on an exact backend, and the reads and writes are those of
`exactEncodeRun`, one for one and in order. -/
def exactTraceMatches (state : List StateObject) (kp : KernelProgram) (trace : Trace) : Bool :=
  (touchedObjects (kp.body.flatMap KernelStatement.accesses)).all
      (fun objectId => ((stateObjectOf? state objectId).bind StateObject.exactLayout?).isSome) &&
    trace.physicalReads == (exactEncodeRun (exactLayoutOf state) kp.body).physicalReads &&
    trace.physicalWrites == (exactEncodeRun (exactLayoutOf state) kp.body).physicalWrites

/-- **A trace that passes the check is the exact store's encoding.** Its
reads and writes are those `exactEncodeRun` gives the program over the
contract's layout, so what `exactEncodeRun` is proved to be (each touched
object read once, only written objects rewritten, every write an `Update`)
holds of the trace. -/
theorem exactTraceMatches_sound {state : List StateObject} {kp : KernelProgram}
    {trace : Trace} (h : exactTraceMatches state kp trace = true) :
    trace.physicalReads = (exactEncodeRun (exactLayoutOf state) kp.body).physicalReads ∧
      trace.physicalWrites = (exactEncodeRun (exactLayoutOf state) kp.body).physicalWrites := by
  simp only [exactTraceMatches, Bool.and_eq_true, beq_iff_eq] at h
  exact ⟨h.1.2, h.2⟩

/-- Every write of a trace that passes the check is an `Update`. -/
theorem exactTraceMatches_writes_update {state : List StateObject} {kp : KernelProgram}
    {trace : Trace} (h : exactTraceMatches state kp trace = true) :
    ∀ w ∈ trace.physicalWrites, w.writeClass = "Update" := by
  rw [(exactTraceMatches_sound h).2]
  exact exactEncodeRun_writes_update _ _

end UOToolchain.IR

namespace UOToolchain.ExactTraceJson

open Lean
open UOToolchain.IR
open UOToolchain.IR.ArtifactJson

/-- The schema tag of the probe's input. -/
def schema : String := "uo-exact-trace-check-v1"

/-- What a check of one call found: its name, the counts of its reads and
writes, and the error if the trace is not the exact store's encoding. -/
structure CaseVerdict where
  name : String
  reads : Nat
  writes : Nat
  error : Option String

/-- The kernel program of `entrypoint` in an artifact's manifest. -/
def entrypointProgram (artifact : Json) (entrypoint : String) : Decode KernelProgram := do
  let contract ← field artifact "contract"
  let manifest ← field contract "manifest"
  let entry ← field (← field manifest "entrypoints") entrypoint
  match optField entry "confidential_program" with
  | some programJson => program programJson
  | none => throw s!"{entrypoint} has no kernel program"

/-- Check one call: its entrypoint's program over the artifact's layout
against the reads and writes of its trace. -/
def checkCase (artifact : Json) (state : List StateObject) (case : Json) : CaseVerdict :=
  let name := (strField case "name").toOption.getD "?"
  let result : Except String (Nat × Nat) := do
    let entrypoint ← strField case "entrypoint"
    let kp ← entrypointProgram artifact entrypoint
    let trace : ImportedRefinementTrace ← fromJson? (← field case "trace")
    let trace := trace.toTrace
    unless exactTraceMatches state kp trace do
      throw s!"the trace of {entrypoint} is not the exact store's encoding of its program"
    pure (trace.physicalReads.length, trace.physicalWrites.length)
  match result with
  | .ok (reads, writes) => { name := name, reads := reads, writes := writes, error := none }
  | .error message => { name := name, reads := 0, writes := 0, error := some message }

def checkInput (input : Json) : Decode (List CaseVerdict) := do
  unless (← strField input "schema") == schema do
    throw s!"exact trace check schema is not {schema}"
  let artifact ← field input "artifact"
  let state ← (← arrField (← field artifact "contract") "state").mapM stateObject
  let cases ← arrField input "cases"
  if cases.isEmpty then throw "the input has no call to check"
  pure (cases.map (checkCase artifact state))

end UOToolchain.ExactTraceJson
