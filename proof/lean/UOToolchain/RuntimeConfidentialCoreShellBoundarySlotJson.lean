import Lean.Data.Json
import UOToolchain.RuntimeConfidentialCoreAssuranceJson
import UOToolchain.RuntimeShellBoundarySlotJson

open Lean

namespace UOToolchain

def importedRuntimeConfidentialCoreShellBoundarySlotBundleFieldNames : List String :=
  ["runtime_witness", "shell_boundary_bundle", "confidential_slot_program"]

structure ImportedRuntimeConfidentialCoreShellBoundarySlotBundle where
  runtime_witness : ImportedRuntimeRefinementWitness
  shell_boundary_bundle : ImportedRuntimeShellBoundaryBundle
  confidential_slot_program : ImportedConfidentialKernelSlotProgram
deriving FromJson

def ImportedRuntimeConfidentialCoreShellBoundarySlotBundle.confidentialCoreSlotBundle
  (bundle : ImportedRuntimeConfidentialCoreShellBoundarySlotBundle) :
  ImportedRuntimeConfidentialCoreSlotBundle :=
  { runtime_witness := bundle.runtime_witness
  , confidential_slot_program := bundle.confidential_slot_program
  }

def ImportedRuntimeConfidentialCoreShellBoundarySlotBundle.shellBoundarySlotBundle
  (bundle : ImportedRuntimeConfidentialCoreShellBoundarySlotBundle) :
  ImportedRuntimeShellBoundarySlotBundle :=
  { shell_boundary_bundle := bundle.shell_boundary_bundle
  , confidential_slot_program := bundle.confidential_slot_program
  }

def ImportedRuntimeConfidentialCoreShellBoundarySlotBundle.Valid
  (bundle : ImportedRuntimeConfidentialCoreShellBoundarySlotBundle)
  (modelTags : SGXModelTags) : Prop :=
  bundle.confidentialCoreSlotBundle.Valid modelTags ∧
    bundle.shellBoundarySlotBundle.Valid ∧
    bundle.runtime_witness.kernel_witness = some bundle.shell_boundary_bundle.kernel_witness ∧
    bundle.runtime_witness.runtime_kernel_refinement_witness =
      some bundle.shell_boundary_bundle.runtime_kernel_refinement_witness

def ImportedRuntimeConfidentialCoreShellBoundarySlotBundle.checkValid
  (bundle : ImportedRuntimeConfidentialCoreShellBoundarySlotBundle)
  (modelTags : SGXModelTags) : Bool :=
  bundle.confidentialCoreSlotBundle.checkValid modelTags &&
    bundle.shellBoundarySlotBundle.checkValid &&
    decide (bundle.runtime_witness.kernel_witness = some bundle.shell_boundary_bundle.kernel_witness) &&
    decide
      (bundle.runtime_witness.runtime_kernel_refinement_witness =
        some bundle.shell_boundary_bundle.runtime_kernel_refinement_witness)

def ImportedRuntimeConfidentialCoreShellBoundarySlotBundle.toRuntimeConfidentialCoreShellBoundarySlotBundle
  (bundle : ImportedRuntimeConfidentialCoreShellBoundarySlotBundle) :
  RuntimeConfidentialCoreShellBoundarySlotBundle :=
  { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
  , shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
  , confidentialSlotProgram := bundle.confidential_slot_program.toConfidentialKernelSlotProgram
  }

@[simp]
theorem importedRuntimeConfidentialCoreShellBoundarySlotBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeConfidentialCoreShellBoundarySlotBundle)
  (modelTags : SGXModelTags) :
  bundle.checkValid modelTags = true ↔ bundle.Valid modelTags := by
  unfold ImportedRuntimeConfidentialCoreShellBoundarySlotBundle.checkValid
    ImportedRuntimeConfidentialCoreShellBoundarySlotBundle.Valid
    ImportedRuntimeConfidentialCoreShellBoundarySlotBundle.confidentialCoreSlotBundle
    ImportedRuntimeConfidentialCoreShellBoundarySlotBundle.shellBoundarySlotBundle
  simp [importedRuntimeConfidentialCoreSlotBundle_checkValid_eq_true_iff,
    importedRuntimeShellBoundarySlotBundle_checkValid_eq_true_iff, and_assoc]

theorem importedRuntimeConfidentialCoreShellBoundarySlotBundle_toRuntimeValid
  (bundle : ImportedRuntimeConfidentialCoreShellBoundarySlotBundle)
  (modelTags : SGXModelTags)
  (hValid : bundle.Valid modelTags) :
  bundle.toRuntimeConfidentialCoreShellBoundarySlotBundle.Valid modelTags := by
  have hCore :
      bundle.confidentialCoreSlotBundle.toRuntimeConfidentialCoreSlotBundle.Valid modelTags := by
    exact importedRuntimeConfidentialCoreSlotBundle_toRuntimeValid
      bundle.confidentialCoreSlotBundle modelTags hValid.1
  have hShell :
      bundle.shellBoundarySlotBundle.toRuntimeShellBoundarySlotBundle.Valid := by
    exact importedRuntimeShellBoundarySlotBundle_toRuntimeValid
      bundle.shellBoundarySlotBundle hValid.2.1
  have hKernelExact :
      bundle.runtime_witness.toRuntimeWitness.kernelWitness =
        some bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.kernelWitness := by
    have hKernelMapped :=
      congrArg (Option.map ImportedRuntimeKernelWitness.toRuntimeKernelWitness) hValid.2.2.1
    simpa [ImportedRuntimeRefinementWitness.toRuntimeWitness,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle] using hKernelMapped
  have hRefinementExact :
      bundle.runtime_witness.toRuntimeWitness.runtimeKernelRefinementWitness =
        some bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.runtimeKernelRefinementWitness := by
    have hRefinementMapped :=
      congrArg
        (Option.map ImportedRuntimeKernelRefinementWitness.toRuntimeKernelRefinementWitness)
        hValid.2.2.2
    simpa [ImportedRuntimeRefinementWitness.toRuntimeWitness,
      ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle] using hRefinementMapped
  unfold ImportedRuntimeConfidentialCoreShellBoundarySlotBundle.toRuntimeConfidentialCoreShellBoundarySlotBundle
    RuntimeConfidentialCoreShellBoundarySlotBundle.Valid
  simpa [ImportedRuntimeRefinementWitness.toRuntimeWitness,
    ImportedRuntimeShellBoundarySlotBundle.toRuntimeShellBoundarySlotBundle,
    ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
    ImportedRuntimeConfidentialCoreSlotBundle.toRuntimeConfidentialCoreSlotBundle] using
    (show
      RuntimeConfidentialCoreSlotBundle.Valid
          { runtimeWitness := bundle.runtime_witness.toRuntimeWitness
          , confidentialProgram := bundle.confidential_slot_program.toConfidentialKernelSlotProgram
          } modelTags ∧
        RuntimeShellBoundarySlotBundle.Valid
          { shellBoundaryBundle := bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle
          , confidentialSlotProgram := bundle.confidential_slot_program.toConfidentialKernelSlotProgram
          } ∧
        bundle.runtime_witness.toRuntimeWitness.kernelWitness =
          some bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.kernelWitness ∧
        bundle.runtime_witness.toRuntimeWitness.runtimeKernelRefinementWitness =
          some bundle.shell_boundary_bundle.toRuntimeShellBoundaryBundle.runtimeKernelRefinementWitness from
      ⟨hCore, hShell, hKernelExact, hRefinementExact⟩)

def parseImportedRuntimeConfidentialCoreShellBoundarySlotBundle
  (input : String) : Except String ImportedRuntimeConfidentialCoreShellBoundarySlotBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeConfidentialCoreShellBoundarySlotBundle
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedRuntimeConfidentialCoreShellBoundarySlotBundle := do
  let bundle ← parseImportedRuntimeConfidentialCoreShellBoundarySlotBundle input
  if bundle.checkValid modelTags then
    pure bundle
  else
    throw
      "imported proof-grade runtime confidential-core shell-boundary slot bundle does not satisfy Lean validity checks"

def loadImportedRuntimeConfidentialCoreShellBoundarySlotBundle
  (path : System.FilePath) : IO ImportedRuntimeConfidentialCoreShellBoundarySlotBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeConfidentialCoreShellBoundarySlotBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime confidential-core shell-boundary slot bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreShellBoundarySlotBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedRuntimeConfidentialCoreShellBoundarySlotBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeConfidentialCoreShellBoundarySlotBundle input modelTags with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime confidential-core shell-boundary slot bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeConfidentialCoreShellBoundarySlotBundleToRuntimeBundle
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO RuntimeConfidentialCoreShellBoundarySlotBundle := do
  let bundle ←
    loadAndCheckImportedProofGradeRuntimeConfidentialCoreShellBoundarySlotBundle path modelTags
  pure bundle.toRuntimeConfidentialCoreShellBoundarySlotBundle

end UOToolchain
