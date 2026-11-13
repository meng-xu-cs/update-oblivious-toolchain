import Lean.Data.Json
import UOToolchain.RuntimeShellBoundaryJson

open Lean

namespace UOToolchain

def importedRuntimeKernelFinishBundleFieldNames : List String :=
  [ "entrypoint_id"
  , "arena_bytes"
  , "max_stack_words"
  , "scratch_bytes"
  , "peak_stack_words"
  , "value_scratch_peak_bytes"
  , "value_scratch_live_bytes_end"
  , "value_scratch_wipe_count"
  , "hash_scratch_peak_bytes"
  , "hash_scratch_live_bytes_end"
  , "hash_scratch_wipe_count"
  , "io_scratch_peak_bytes"
  , "io_scratch_live_bytes_end"
  , "io_scratch_wipe_count"
  , "resource_events"
  , "expected_kernel_steps"
  , "public_object_ids"
  , "expected_public_object_ids"
  , "kernel_steps"
  , "runtime_phase_events_before_finish"
  ]

/--
Imported proof-grade runtime kernel finish bundle. This is the exact
pre-witness finish payload emitted by the runtime kernel immediately before the
final kernel/refinement witnesses are materialized.
-/
structure ImportedRuntimeKernelFinishBundle where
  entrypoint_id : String
  arena_bytes : Nat
  max_stack_words : Nat
  scratch_bytes : Nat
  peak_stack_words : Nat
  value_scratch_peak_bytes : Nat
  value_scratch_live_bytes_end : Nat
  value_scratch_wipe_count : Nat
  hash_scratch_peak_bytes : Nat
  hash_scratch_live_bytes_end : Nat
  hash_scratch_wipe_count : Nat
  io_scratch_peak_bytes : Nat
  io_scratch_live_bytes_end : Nat
  io_scratch_wipe_count : Nat
  resource_events : List ImportedRuntimeKernelResourceEvent
  expected_kernel_steps : Option (List ImportedRuntimeKernelStep)
  public_object_ids : List Nat
  expected_public_object_ids : Option (List Nat)
  kernel_steps : List ImportedRuntimeKernelStep
  runtime_phase_events_before_finish : List ImportedRuntimeKernelRefinementEvent
deriving Repr, DecidableEq, ToJson

instance : FromJson ImportedRuntimeKernelFinishBundle where
  fromJson? json := do
    jsonRequireExactFields json importedRuntimeKernelFinishBundleFieldNames
    pure
      { entrypoint_id := ← jsonLookupFieldAs json "entrypoint_id"
      , arena_bytes := ← jsonLookupFieldAs json "arena_bytes"
      , max_stack_words := ← jsonLookupFieldAs json "max_stack_words"
      , scratch_bytes := ← jsonLookupFieldAs json "scratch_bytes"
      , peak_stack_words := ← jsonLookupFieldAs json "peak_stack_words"
      , value_scratch_peak_bytes := ← jsonLookupFieldAs json "value_scratch_peak_bytes"
      , value_scratch_live_bytes_end :=
          ← jsonLookupFieldAs json "value_scratch_live_bytes_end"
      , value_scratch_wipe_count := ← jsonLookupFieldAs json "value_scratch_wipe_count"
      , hash_scratch_peak_bytes := ← jsonLookupFieldAs json "hash_scratch_peak_bytes"
      , hash_scratch_live_bytes_end :=
          ← jsonLookupFieldAs json "hash_scratch_live_bytes_end"
      , hash_scratch_wipe_count := ← jsonLookupFieldAs json "hash_scratch_wipe_count"
      , io_scratch_peak_bytes := ← jsonLookupFieldAs json "io_scratch_peak_bytes"
      , io_scratch_live_bytes_end := ← jsonLookupFieldAs json "io_scratch_live_bytes_end"
      , io_scratch_wipe_count := ← jsonLookupFieldAs json "io_scratch_wipe_count"
      , resource_events := ← jsonLookupResourceEvents json "resource_events"
      , expected_kernel_steps :=
          ← jsonLookupExplicitOptionFieldAs json "expected_kernel_steps"
      , public_object_ids := ← jsonLookupFieldAs json "public_object_ids"
      , expected_public_object_ids :=
          ← jsonLookupExplicitOptionFieldAs json "expected_public_object_ids"
      , kernel_steps := ← jsonLookupFieldAs json "kernel_steps"
      , runtime_phase_events_before_finish :=
          ← jsonLookupFieldAs json "runtime_phase_events_before_finish"
      }

def ImportedRuntimeKernelFinishBundle.kernelWitness
  (bundle : ImportedRuntimeKernelFinishBundle) : ImportedRuntimeKernelWitness :=
  { entrypoint_id := bundle.entrypoint_id
  , arena_bytes := bundle.arena_bytes
  , max_stack_words := bundle.max_stack_words
  , scratch_bytes := bundle.scratch_bytes
  , peak_stack_words := bundle.peak_stack_words
  , value_scratch_peak_bytes := bundle.value_scratch_peak_bytes
  , value_scratch_live_bytes_end := bundle.value_scratch_live_bytes_end
  , value_scratch_wipe_count := bundle.value_scratch_wipe_count
  , hash_scratch_peak_bytes := bundle.hash_scratch_peak_bytes
  , hash_scratch_live_bytes_end := bundle.hash_scratch_live_bytes_end
  , hash_scratch_wipe_count := bundle.hash_scratch_wipe_count
  , io_scratch_peak_bytes := bundle.io_scratch_peak_bytes
  , io_scratch_live_bytes_end := bundle.io_scratch_live_bytes_end
  , io_scratch_wipe_count := bundle.io_scratch_wipe_count
  , resource_events := bundle.resource_events
  , expected_kernel_steps := bundle.expected_kernel_steps
  , public_object_ids := bundle.public_object_ids
  , expected_public_object_ids := bundle.expected_public_object_ids
  , kernel_steps := bundle.kernel_steps
  }

def ImportedRuntimeKernelFinishBundle.completedRuntimePhaseEvents
  (bundle : ImportedRuntimeKernelFinishBundle) : List ImportedRuntimeKernelRefinementEvent :=
  let coldStoreEvents :=
    bundle.runtime_phase_events_before_finish.filterMap (fun event =>
      if event.kind = "shadow_load_object" then
        event.object_id.map (fun object_id =>
          { kind := "cold_store_object", object_id := some object_id, opcode := none })
      else
        none)
  let postCommittedColdEvents :=
    bundle.public_object_ids.map (fun object_id =>
      { kind := "post_committed_cold_object", object_id := some object_id, opcode := none })
  bundle.runtime_phase_events_before_finish ++ coldStoreEvents ++ postCommittedColdEvents

def ImportedRuntimeKernelFinishBundle.runtimeKernelRefinementWitness
  (bundle : ImportedRuntimeKernelFinishBundle) : ImportedRuntimeKernelRefinementWitness :=
  { events := bundle.completedRuntimePhaseEvents }

def ImportedRuntimeKernelFinishBundle.shellBoundaryBundle
  (bundle : ImportedRuntimeKernelFinishBundle) : ImportedRuntimeShellBoundaryBundle :=
  let kernelWitness := bundle.kernelWitness
  let runtimeKernelRefinementWitness := bundle.runtimeKernelRefinementWitness
  { kernel_witness := kernelWitness
  , runtime_kernel_refinement_witness := runtimeKernelRefinementWitness
  , shell_contract := kernelWitness.importedShellContract
  , shell_trace := runtimeKernelRefinementWitness.importedShellTrace
  }

def ImportedRuntimeKernelFinishBundle.kernelInterfaceBundle?
  (bundle : ImportedRuntimeKernelFinishBundle) : Option ImportedRuntimeKernelInterfaceBundle := do
  let kernelWitness := bundle.kernelWitness
  let expectedKernelSteps ← kernelWitness.expected_kernel_steps
  let expectedPublicObjectIds ← kernelWitness.expected_public_object_ids
  let expectedKernelSchedule ← kernelWitness.expectedKernelSchedule?
  pure
    { shell_boundary_bundle := bundle.shellBoundaryBundle
    , expected_kernel_steps := expectedKernelSteps
    , expected_public_object_ids := expectedPublicObjectIds
    , expected_kernel_schedule := expectedKernelSchedule
    }

theorem importedRuntimeKernelFinishBundle_kernelInterfaceBundle_exact
  {bundle : ImportedRuntimeKernelFinishBundle}
  {kernelInterfaceBundle : ImportedRuntimeKernelInterfaceBundle}
  (hBundle : bundle.kernelInterfaceBundle? = some kernelInterfaceBundle) :
  bundle.shellBoundaryBundle = kernelInterfaceBundle.shell_boundary_bundle ∧
    bundle.kernelWitness.expected_kernel_steps =
      some kernelInterfaceBundle.expected_kernel_steps ∧
    bundle.kernelWitness.expected_public_object_ids =
      some kernelInterfaceBundle.expected_public_object_ids ∧
    bundle.kernelWitness.expectedKernelSchedule? =
      some kernelInterfaceBundle.expected_kernel_schedule := by
  unfold ImportedRuntimeKernelFinishBundle.kernelInterfaceBundle? at hBundle
  let kernelWitness := bundle.kernelWitness
  cases hExpectedSteps : kernelWitness.expected_kernel_steps with
  | none =>
      simp [kernelWitness, hExpectedSteps] at hBundle
  | some expectedKernelSteps =>
      cases hExpectedPublic : kernelWitness.expected_public_object_ids with
      | none =>
          simp [kernelWitness, hExpectedSteps, hExpectedPublic] at hBundle
      | some expectedPublicObjectIds =>
          cases hExpectedSchedule : kernelWitness.expectedKernelSchedule? with
          | none =>
              simp [kernelWitness, hExpectedSteps, hExpectedPublic, hExpectedSchedule] at hBundle
          | some expectedKernelSchedule =>
              have hBundleSome :
                  some
                      { shell_boundary_bundle := bundle.shellBoundaryBundle
                      , expected_kernel_steps := expectedKernelSteps
                      , expected_public_object_ids := expectedPublicObjectIds
                      , expected_kernel_schedule := expectedKernelSchedule
                      } =
                    some kernelInterfaceBundle := by
                simpa [kernelWitness, hExpectedSteps, hExpectedPublic, hExpectedSchedule] using
                  hBundle
              have hBundleEq :
                  { shell_boundary_bundle := bundle.shellBoundaryBundle
                  , expected_kernel_steps := expectedKernelSteps
                  , expected_public_object_ids := expectedPublicObjectIds
                  , expected_kernel_schedule := expectedKernelSchedule
                  } = kernelInterfaceBundle := by
                exact Option.some.inj hBundleSome
              cases hBundleEq
              simp

def ImportedRuntimeKernelFinishBundle.Valid
  (bundle : ImportedRuntimeKernelFinishBundle) : Prop :=
  ∃ kernelInterfaceBundle,
    bundle.kernelInterfaceBundle? = some kernelInterfaceBundle ∧
      kernelInterfaceBundle.Valid

def ImportedRuntimeKernelFinishBundle.checkValid
  (bundle : ImportedRuntimeKernelFinishBundle) : Bool :=
  match bundle.kernelInterfaceBundle? with
  | some kernelInterfaceBundle => kernelInterfaceBundle.checkValid
  | none => false

@[simp] theorem importedRuntimeKernelFinishBundle_checkValid_eq_true_iff
  (bundle : ImportedRuntimeKernelFinishBundle) :
  bundle.checkValid = true ↔ bundle.Valid := by
  unfold ImportedRuntimeKernelFinishBundle.checkValid ImportedRuntimeKernelFinishBundle.Valid
  cases hBundle : bundle.kernelInterfaceBundle? with
  | none =>
      simp
  | some kernelInterfaceBundle =>
      simp [importedRuntimeKernelInterfaceBundle_checkValid_eq_true_iff]

noncomputable def ImportedRuntimeKernelFinishBundle.toRuntimeKernelInterfaceBundle
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) : RuntimeKernelInterfaceBundle := by
  classical
  exact (Classical.choose hValid).toRuntimeKernelInterfaceBundle

theorem importedRuntimeKernelFinishBundle_toRuntimeKernelInterfaceBundle_valid
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelInterfaceBundle hValid).Valid := by
  classical
  unfold ImportedRuntimeKernelFinishBundle.toRuntimeKernelInterfaceBundle
  exact
    importedRuntimeKernelInterfaceBundle_toRuntimeValid
      (Classical.choose hValid)
      (Classical.choose_spec hValid).2

theorem importedRuntimeKernelFinishBundle_toRuntimeKernelInterfaceBundle_kernelWitness_exact
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelInterfaceBundle hValid).shellBoundaryBundle.kernelWitness =
    bundle.kernelWitness.toRuntimeKernelWitness := by
  classical
  unfold ImportedRuntimeKernelFinishBundle.toRuntimeKernelInterfaceBundle
  have hBundleExact :=
    importedRuntimeKernelFinishBundle_kernelInterfaceBundle_exact
      (bundle := bundle)
      (kernelInterfaceBundle := Classical.choose hValid)
      (Classical.choose_spec hValid).1
  rcases hBundleExact with ⟨hShellBoundary, _hExpectedSteps, _hExpectedPublic, _hExpectedSchedule⟩
  have hShellBoundaryRuntime :=
    congrArg
      (fun shellBoundaryBundle =>
        shellBoundaryBundle.toRuntimeShellBoundaryBundle.kernelWitness)
      hShellBoundary.symm
  simpa [ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
    ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
    ImportedRuntimeKernelFinishBundle.shellBoundaryBundle] using hShellBoundaryRuntime

theorem importedRuntimeKernelFinishBundle_toRuntimeKernelInterfaceBundle_runtimeKernelRefinementWitness_exact
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelInterfaceBundle hValid).shellBoundaryBundle.runtimeKernelRefinementWitness =
    bundle.runtimeKernelRefinementWitness.toRuntimeKernelRefinementWitness := by
  classical
  unfold ImportedRuntimeKernelFinishBundle.toRuntimeKernelInterfaceBundle
  have hBundleExact :=
    importedRuntimeKernelFinishBundle_kernelInterfaceBundle_exact
      (bundle := bundle)
      (kernelInterfaceBundle := Classical.choose hValid)
      (Classical.choose_spec hValid).1
  rcases hBundleExact with ⟨hShellBoundary, _hExpectedSteps, _hExpectedPublic, _hExpectedSchedule⟩
  have hShellBoundaryRuntime :=
    congrArg
      (fun shellBoundaryBundle =>
        shellBoundaryBundle.toRuntimeShellBoundaryBundle.runtimeKernelRefinementWitness)
      hShellBoundary.symm
  simpa [ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
    ImportedRuntimeShellBoundaryBundle.toRuntimeShellBoundaryBundle,
    ImportedRuntimeKernelFinishBundle.shellBoundaryBundle,
    ImportedRuntimeKernelFinishBundle.runtimeKernelRefinementWitness] using hShellBoundaryRuntime

theorem importedRuntimeKernelFinishBundle_toRuntimeKernelInterfaceBundle_expectedKernelSteps_exact
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelInterfaceBundle hValid).expectedKernelSteps =
    bundle.expected_kernel_steps.map (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep) := by
  classical
  unfold ImportedRuntimeKernelFinishBundle.toRuntimeKernelInterfaceBundle
  have hBundleExact :=
    importedRuntimeKernelFinishBundle_kernelInterfaceBundle_exact
      (bundle := bundle)
      (kernelInterfaceBundle := Classical.choose hValid)
      (Classical.choose_spec hValid).1
  exact
    by
      rcases hBundleExact with
        ⟨_hShellBoundary, hExpectedSteps, _hExpectedPublic, _hExpectedSchedule⟩
      simp [ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle]
      simpa [ImportedRuntimeKernelFinishBundle.kernelWitness] using
        congrArg
          (Option.map (List.map ImportedRuntimeKernelStep.toRuntimeKernelStep))
          hExpectedSteps.symm

theorem importedRuntimeKernelFinishBundle_toRuntimeKernelInterfaceBundle_expectedPublicObjectIds_exact
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  (bundle.toRuntimeKernelInterfaceBundle hValid).expectedPublicObjectIds =
    bundle.expected_public_object_ids := by
  classical
  unfold ImportedRuntimeKernelFinishBundle.toRuntimeKernelInterfaceBundle
  have hBundleExact :=
    importedRuntimeKernelFinishBundle_kernelInterfaceBundle_exact
      (bundle := bundle)
      (kernelInterfaceBundle := Classical.choose hValid)
      (Classical.choose_spec hValid).1
  exact
    by
      rcases hBundleExact with
        ⟨_hShellBoundary, _hExpectedSteps, hExpectedPublic, _hExpectedSchedule⟩
      simp [ImportedRuntimeKernelInterfaceBundle.toRuntimeKernelInterfaceBundle]
      simpa [ImportedRuntimeKernelFinishBundle.kernelWitness] using hExpectedPublic.symm

noncomputable def ImportedRuntimeKernelFinishBundle.toRuntimeKernelRefinementBoundary
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) : RuntimeKernelRefinementBoundary := by
  classical
  exact
    (Classical.choose hValid).toRuntimeKernelRefinementBoundary
      (Classical.choose_spec hValid).2

theorem importedRuntimeKernelFinishBundle_valid_projects_to_runtimeKernelRefinementBoundary
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      (bundle.toRuntimeKernelRefinementBoundary hValid).runtimeKernelRefinementWitness
      (bundle.toRuntimeKernelRefinementBoundary hValid).kernelWitness := by
  classical
  unfold ImportedRuntimeKernelFinishBundle.toRuntimeKernelRefinementBoundary
  exact
    importedRuntimeKernelInterfaceBundle_valid_projects_to_runtimeKernelRefinementBoundary
      (Classical.choose_spec hValid).2

noncomputable def ImportedRuntimeKernelFinishBundle.toRuntimeKernelConfinementBoundary
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) : RuntimeKernelConfinementBoundary := by
  classical
  exact
    (Classical.choose hValid).toRuntimeKernelConfinementBoundary
      (Classical.choose_spec hValid).2

theorem importedRuntimeKernelFinishBundle_valid_projects_to_runtimeKernelConfinementBoundary
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  let boundary := bundle.toRuntimeKernelConfinementBoundary hValid
  boundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      boundary.refinementBoundary.kernelWitness ∧
    boundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      boundary.refinementBoundary.kernelWitness.shellContract := by
  classical
  unfold ImportedRuntimeKernelFinishBundle.toRuntimeKernelConfinementBoundary
  exact
    importedRuntimeKernelInterfaceBundle_valid_projects_to_runtimeKernelConfinementBoundary
      (Classical.choose_spec hValid).2

theorem importedRuntimeKernelFinishBundle_valid_projects_to_runtimeKernelInterfaceBundle
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  ∃ runtimeKernelInterfaceBundle : RuntimeKernelInterfaceBundle,
    runtimeKernelInterfaceBundle.Valid := by
  rcases hValid with ⟨kernelInterfaceBundle, _hExact, hBundleValid⟩
  exact
    ⟨kernelInterfaceBundle.toRuntimeKernelInterfaceBundle,
      importedRuntimeKernelInterfaceBundle_toRuntimeValid
        kernelInterfaceBundle
        hBundleValid⟩

theorem importedRuntimeKernelFinishBundle_valid_projects_to_runtimeShellBoundaryBundle
  {bundle : ImportedRuntimeKernelFinishBundle}
  (hValid : bundle.Valid) :
  ∃ shellBoundaryBundle : RuntimeShellBoundaryBundle,
    shellBoundaryBundle.Valid := by
  rcases
      importedRuntimeKernelFinishBundle_valid_projects_to_runtimeKernelInterfaceBundle
        hValid with
    ⟨runtimeKernelInterfaceBundle, hBundleValid⟩
  exact ⟨runtimeKernelInterfaceBundle.shellBoundaryBundle, hBundleValid.1⟩

def parseImportedRuntimeKernelFinishBundle
  (input : String) : Except String ImportedRuntimeKernelFinishBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedProofGradeRuntimeKernelFinishBundle
  (input : String) : Except String ImportedRuntimeKernelFinishBundle := do
  let bundle ← parseImportedRuntimeKernelFinishBundle input
  if bundle.checkValid then
    pure bundle
  else
    throw
      "imported proof-grade runtime kernel finish bundle does not satisfy Lean validity checks"

def loadImportedRuntimeKernelFinishBundle
  (path : System.FilePath) : IO ImportedRuntimeKernelFinishBundle := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeKernelFinishBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse runtime kernel finish bundle: {err}"

def loadAndCheckImportedProofGradeRuntimeKernelFinishBundle
  (path : System.FilePath) : IO ImportedRuntimeKernelFinishBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeRuntimeKernelFinishBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade runtime kernel finish bundle: {err}"

end UOToolchain
