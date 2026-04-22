import UOToolchain.RuntimeShellBoundary

namespace UOToolchain

def sourceContainsAll (source : String) : List String → Prop
  | [] => True
  | needle :: needles => source.contains needle = true ∧ sourceContainsAll source needles

def sourceLacksAll (source : String) : List String → Prop
  | [] => True
  | needle :: needles => source.contains needle = false ∧ sourceLacksAll source needles

def checkSourceContainsAll (source : String) : List String → Bool
  | [] => true
  | needle :: needles => source.contains needle && checkSourceContainsAll source needles

def checkSourceLacksAll (source : String) : List String → Bool
  | [] => true
  | needle :: needles => !(source.contains needle) && checkSourceLacksAll source needles

@[simp] theorem checkSourceContainsAll_eq_true_iff
  (source : String) (needles : List String) :
  checkSourceContainsAll source needles = true ↔ sourceContainsAll source needles := by
  induction needles with
  | nil =>
      simp [checkSourceContainsAll, sourceContainsAll]
  | cons needle needles ih =>
      simp [checkSourceContainsAll, sourceContainsAll, ih]

@[simp] theorem checkSourceLacksAll_eq_true_iff
  (source : String) (needles : List String) :
  checkSourceLacksAll source needles = true ↔ sourceLacksAll source needles := by
  induction needles with
  | nil =>
      simp [checkSourceLacksAll, sourceLacksAll]
  | cons needle needles ih =>
      simp [checkSourceLacksAll, sourceLacksAll, ih]

def productionSource (source : String) : String :=
  (source.splitOn "#[cfg(test)]").head!

/--
Source-backed implementation interface for the real `uo-evm` runtime. This is
the syntactic proof/interface boundary for the real Rust runtime modules: the
public shell and engine must stay outside the confidential kernel surface,
runtime orchestration must remain routed through the shared bridge, and the
kernel / theorem finalizers must keep delegating to the shared boundary-tracker,
slot-executor, and trace-finalization objects that Lean already models.
-/
structure RuntimeImplementationInterface where
  runtimeEvmLibSource : String
  engineSource : String
  runtimeModuleSource : String
  shellSource : String
  stateSource : String
  kernelSource : String
  theoremSource : String
deriving Repr, DecidableEq

def RuntimeImplementationInterface.engineProductionSource
  (iface : RuntimeImplementationInterface) : String :=
  productionSource iface.engineSource

def RuntimeImplementationInterface.runtimeModuleProductionSource
  (iface : RuntimeImplementationInterface) : String :=
  productionSource iface.runtimeModuleSource

def RuntimeImplementationInterface.shellProductionSource
  (iface : RuntimeImplementationInterface) : String :=
  productionSource iface.shellSource

def RuntimeImplementationInterface.stateProductionSource
  (iface : RuntimeImplementationInterface) : String :=
  productionSource iface.stateSource

def RuntimeImplementationInterface.kernelProductionSource
  (iface : RuntimeImplementationInterface) : String :=
  productionSource iface.kernelSource

def RuntimeImplementationInterface.theoremProductionSource
  (iface : RuntimeImplementationInterface) : String :=
  productionSource iface.theoremSource

def RuntimeImplementationInterface.runtimeOwnsBridgeModules
  (iface : RuntimeImplementationInterface) : Prop :=
  sourceContainsAll iface.runtimeEvmLibSource ["mod runtime;"] ∧
    sourceLacksAll iface.runtimeEvmLibSource ["mod shell;", "mod theorem;"] ∧
    sourceContainsAll iface.runtimeModuleProductionSource
      [ "mod shell;"
      , "mod theorem;"
      , "theorem::run_traced_call("
      , "shell::run_public_entrypoint("
      ] ∧
    sourceLacksAll iface.runtimeModuleProductionSource
      ["pub(crate) mod theorem;", "pub(crate) mod shell;"]

def RuntimeImplementationInterface.checkRuntimeOwnsBridgeModules
  (iface : RuntimeImplementationInterface) : Bool :=
  checkSourceContainsAll iface.runtimeEvmLibSource ["mod runtime;"] &&
    checkSourceLacksAll iface.runtimeEvmLibSource ["mod shell;", "mod theorem;"] &&
    checkSourceContainsAll iface.runtimeModuleProductionSource
      [ "mod shell;"
      , "mod theorem;"
      , "theorem::run_traced_call("
      , "shell::run_public_entrypoint("
      ] &&
    checkSourceLacksAll iface.runtimeModuleProductionSource
      ["pub(crate) mod theorem;", "pub(crate) mod shell;"]

@[simp] theorem runtimeImplementationInterface_checkRuntimeOwnsBridgeModules_eq_true_iff
  (iface : RuntimeImplementationInterface) :
  iface.checkRuntimeOwnsBridgeModules = true ↔ iface.runtimeOwnsBridgeModules := by
  unfold RuntimeImplementationInterface.checkRuntimeOwnsBridgeModules
    RuntimeImplementationInterface.runtimeOwnsBridgeModules
  simpa [and_assoc]

def RuntimeImplementationInterface.engineDelegatesToRuntimeBridge
  (iface : RuntimeImplementationInterface) : Prop :=
  sourceContainsAll iface.engineProductionSource
    ["state: ContractRuntime", "run_contract_call("] ∧
    sourceLacksAll iface.engineProductionSource
      [ "run_traced_call("
      , "run_public_entrypoint("
      , "run_confidential_entrypoint("
      , "prepare_confidential_entrypoint("
      , "AllocatorPlan::from_manifest("
      , "PublicRuntimeKernel::begin("
      , "ConfidentialCallInputs"
      , "RuntimeKernelRefinementEventWitness"
      , "RuntimeControllerObserverCertificate"
      , "RuntimePathOramHiddenCertificate"
      , "RuntimeTrustedKernelBundle"
      , "ExecutionTrace {"
      ]

def RuntimeImplementationInterface.checkEngineDelegatesToRuntimeBridge
  (iface : RuntimeImplementationInterface) : Bool :=
  checkSourceContainsAll iface.engineProductionSource
    ["state: ContractRuntime", "run_contract_call("] &&
    checkSourceLacksAll iface.engineProductionSource
      [ "run_traced_call("
      , "run_public_entrypoint("
      , "run_confidential_entrypoint("
      , "prepare_confidential_entrypoint("
      , "AllocatorPlan::from_manifest("
      , "PublicRuntimeKernel::begin("
      , "ConfidentialCallInputs"
      , "RuntimeKernelRefinementEventWitness"
      , "RuntimeControllerObserverCertificate"
      , "RuntimePathOramHiddenCertificate"
      , "RuntimeTrustedKernelBundle"
      , "ExecutionTrace {"
      ]

@[simp] theorem runtimeImplementationInterface_checkEngineDelegatesToRuntimeBridge_eq_true_iff
  (iface : RuntimeImplementationInterface) :
  iface.checkEngineDelegatesToRuntimeBridge = true ↔ iface.engineDelegatesToRuntimeBridge := by
  unfold RuntimeImplementationInterface.checkEngineDelegatesToRuntimeBridge
    RuntimeImplementationInterface.engineDelegatesToRuntimeBridge
  simp

def RuntimeImplementationInterface.shellStaysPublicOnly
  (iface : RuntimeImplementationInterface) : Prop :=
  sourceContainsAll iface.shellProductionSource
    [ "use crate::runtime::kernel::PublicRuntimeKernel;"
    , "objects: &mut PublicRuntimeShadowState"
    ] ∧
    sourceLacksAll iface.shellProductionSource
      [ "ConfidentialCallInputs"
      , "use crate::runtime::kernel::RuntimeKernel;"
      , "use crate::runtime::objects::RuntimeObject;"
      , "RuntimeKernelRefinementEventWitness"
      , "RuntimeTrustedKernelBundle"
      , "ConfidentialKernelSlotProgram"
      ]

def RuntimeImplementationInterface.checkShellStaysPublicOnly
  (iface : RuntimeImplementationInterface) : Bool :=
  checkSourceContainsAll iface.shellProductionSource
    [ "use crate::runtime::kernel::PublicRuntimeKernel;"
    , "objects: &mut PublicRuntimeShadowState"
    ] &&
    checkSourceLacksAll iface.shellProductionSource
      [ "ConfidentialCallInputs"
      , "use crate::runtime::kernel::RuntimeKernel;"
      , "use crate::runtime::objects::RuntimeObject;"
      , "RuntimeKernelRefinementEventWitness"
      , "RuntimeTrustedKernelBundle"
      , "ConfidentialKernelSlotProgram"
      ]

@[simp] theorem runtimeImplementationInterface_checkShellStaysPublicOnly_eq_true_iff
  (iface : RuntimeImplementationInterface) :
  iface.checkShellStaysPublicOnly = true ↔ iface.shellStaysPublicOnly := by
  unfold RuntimeImplementationInterface.checkShellStaysPublicOnly
    RuntimeImplementationInterface.shellStaysPublicOnly
  simp

def RuntimeImplementationInterface.stateStagesConfidentialCallsInsideRuntime
  (iface : RuntimeImplementationInterface) : Prop :=
  sourceContainsAll iface.stateProductionSource
    [ "runtime_confidential_entrypoint_plan(entrypoint, public_object_ids)?"
    , "let args = ConfidentialCallInputs::from_raw_args(raw_args);"
    , "PublicRuntimeKernel::begin("
    , "CommittedRuntimeWitnessSnapshotBuilder::new("
    ] ∧
    sourceLacksAll iface.stateProductionSource
      ["fn finalize_runtime_kernel_refinement_witness"]

def RuntimeImplementationInterface.checkStateStagesConfidentialCallsInsideRuntime
  (iface : RuntimeImplementationInterface) : Bool :=
  checkSourceContainsAll iface.stateProductionSource
    [ "runtime_confidential_entrypoint_plan(entrypoint, public_object_ids)?"
    , "let args = ConfidentialCallInputs::from_raw_args(raw_args);"
    , "PublicRuntimeKernel::begin("
    , "CommittedRuntimeWitnessSnapshotBuilder::new("
    ] &&
    checkSourceLacksAll iface.stateProductionSource
      ["fn finalize_runtime_kernel_refinement_witness"]

@[simp] theorem runtimeImplementationInterface_checkStateStagesConfidentialCallsInsideRuntime_eq_true_iff
  (iface : RuntimeImplementationInterface) :
  iface.checkStateStagesConfidentialCallsInsideRuntime = true ↔
    iface.stateStagesConfidentialCallsInsideRuntime := by
  unfold RuntimeImplementationInterface.checkStateStagesConfidentialCallsInsideRuntime
    RuntimeImplementationInterface.stateStagesConfidentialCallsInsideRuntime
  simp

def RuntimeImplementationInterface.kernelDelegatesToSharedBoundaryObjects
  (iface : RuntimeImplementationInterface) : Prop :=
  sourceContainsAll iface.kernelProductionSource
    [ "boundary: RuntimeKernelBoundaryTracker"
    , "execute_confidential_kernel_slot_call(&mut runtime_effects, program, call_inputs)?"
    , ".bind_expected_kernel_program(program)"
    , ".expected_loaded_object_schedule_required()?"
    , ".into_finish_snapshot(entrypoint_id.into(), self.allocator.finish()?)"
    , "finish_snapshot\n            .into_finish_bundle()"
    ] ∧
    sourceLacksAll iface.kernelProductionSource
      [ "finish_bundle.to_witness_pair()?;"
      , "RuntimeKernelExecutionTracker"
      , "RuntimeKernelRefinementTracker"
      , "pub(crate) struct RuntimeKernel {"
      , "pub(crate) fn record_kernel_step("
      ]

def RuntimeImplementationInterface.checkKernelDelegatesToSharedBoundaryObjects
  (iface : RuntimeImplementationInterface) : Bool :=
  checkSourceContainsAll iface.kernelProductionSource
    [ "boundary: RuntimeKernelBoundaryTracker"
    , "execute_confidential_kernel_slot_call(&mut runtime_effects, program, call_inputs)?"
    , ".bind_expected_kernel_program(program)"
    , ".expected_loaded_object_schedule_required()?"
    , ".into_finish_snapshot(entrypoint_id.into(), self.allocator.finish()?)"
    , "finish_snapshot\n            .into_finish_bundle()"
    ] &&
    checkSourceLacksAll iface.kernelProductionSource
      [ "finish_bundle.to_witness_pair()?;"
      , "RuntimeKernelExecutionTracker"
      , "RuntimeKernelRefinementTracker"
      , "pub(crate) struct RuntimeKernel {"
      , "pub(crate) fn record_kernel_step("
      ]

@[simp] theorem runtimeImplementationInterface_checkKernelDelegatesToSharedBoundaryObjects_eq_true_iff
  (iface : RuntimeImplementationInterface) :
  iface.checkKernelDelegatesToSharedBoundaryObjects = true ↔
    iface.kernelDelegatesToSharedBoundaryObjects := by
  unfold RuntimeImplementationInterface.checkKernelDelegatesToSharedBoundaryObjects
    RuntimeImplementationInterface.kernelDelegatesToSharedBoundaryObjects
  simp

def RuntimeImplementationInterface.theoremFinalizerUsesSharedTraceBridge
  (iface : RuntimeImplementationInterface) : Prop :=
  sourceContainsAll iface.theoremProductionSource
    [ "runtime.begin_traced_call("
    , "runtime.finish_traced_call(call_outcome)?"
    , "ExecutionTrace::from_runtime_finalization_input("
    , ".into_execution_trace_inputs()"
    ] ∧
    sourceLacksAll iface.theoremProductionSource
      [ "ExecutionTrace {"
      , "RuntimeExecutionTraceParts::new("
      , "ExecutionTrace::from_runtime_trace_parts("
      , "ExecutionTrace::materialize_runtime_trusted_kernel_bundle("
      ]

def RuntimeImplementationInterface.checkTheoremFinalizerUsesSharedTraceBridge
  (iface : RuntimeImplementationInterface) : Bool :=
  checkSourceContainsAll iface.theoremProductionSource
    [ "runtime.begin_traced_call("
    , "runtime.finish_traced_call(call_outcome)?"
    , "ExecutionTrace::from_runtime_finalization_input("
    , ".into_execution_trace_inputs()"
    ] &&
    checkSourceLacksAll iface.theoremProductionSource
      [ "ExecutionTrace {"
      , "RuntimeExecutionTraceParts::new("
      , "ExecutionTrace::from_runtime_trace_parts("
      , "ExecutionTrace::materialize_runtime_trusted_kernel_bundle("
      ]

@[simp] theorem runtimeImplementationInterface_checkTheoremFinalizerUsesSharedTraceBridge_eq_true_iff
  (iface : RuntimeImplementationInterface) :
  iface.checkTheoremFinalizerUsesSharedTraceBridge = true ↔
    iface.theoremFinalizerUsesSharedTraceBridge := by
  unfold RuntimeImplementationInterface.checkTheoremFinalizerUsesSharedTraceBridge
    RuntimeImplementationInterface.theoremFinalizerUsesSharedTraceBridge
  simp

def RuntimeImplementationInterface.ConfinesSecretDependentWork
  (iface : RuntimeImplementationInterface) : Prop :=
  iface.runtimeOwnsBridgeModules ∧
    iface.engineDelegatesToRuntimeBridge ∧
    iface.shellStaysPublicOnly ∧
    iface.stateStagesConfidentialCallsInsideRuntime ∧
    iface.kernelDelegatesToSharedBoundaryObjects ∧
    iface.theoremFinalizerUsesSharedTraceBridge

def RuntimeImplementationInterface.Valid
  (iface : RuntimeImplementationInterface) : Prop :=
  iface.ConfinesSecretDependentWork

def RuntimeImplementationInterface.checkValid
  (iface : RuntimeImplementationInterface) : Bool :=
  iface.checkRuntimeOwnsBridgeModules &&
    iface.checkEngineDelegatesToRuntimeBridge &&
    iface.checkShellStaysPublicOnly &&
    iface.checkStateStagesConfidentialCallsInsideRuntime &&
    iface.checkKernelDelegatesToSharedBoundaryObjects &&
    iface.checkTheoremFinalizerUsesSharedTraceBridge

@[simp] theorem runtimeImplementationInterface_checkValid_eq_true_iff
  (iface : RuntimeImplementationInterface) :
  iface.checkValid = true ↔ iface.Valid := by
  unfold RuntimeImplementationInterface.checkValid RuntimeImplementationInterface.Valid
    RuntimeImplementationInterface.ConfinesSecretDependentWork
  simp [and_assoc]

structure RuntimeImplementationConfinementBoundary where
  implementationInterface : RuntimeImplementationInterface
  kernelInterfaceBundle : RuntimeKernelInterfaceBundle
  implementationValid : implementationInterface.Valid
  kernelInterfaceValid : kernelInterfaceBundle.Valid

noncomputable def RuntimeImplementationConfinementBoundary.runtimeKernelConfinementBoundary
  (boundary : RuntimeImplementationConfinementBoundary) : RuntimeKernelConfinementBoundary :=
  boundary.kernelInterfaceBundle.confinementBoundary boundary.kernelInterfaceValid

theorem RuntimeImplementationConfinementBoundary.implementationConfinement
  (boundary : RuntimeImplementationConfinementBoundary) :
  boundary.implementationInterface.ConfinesSecretDependentWork :=
  boundary.implementationValid

theorem RuntimeImplementationConfinementBoundary.projects_to_runtimeKernelConfinementBoundary
  (boundary : RuntimeImplementationConfinementBoundary) :
  let runtimeBoundary := boundary.runtimeKernelConfinementBoundary
  runtimeBoundary.refinementBoundary.runtimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.refinementBoundary.kernelWitness ∧
    runtimeBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace.Refines
      runtimeBoundary.refinementBoundary.kernelWitness.shellContract := by
  let runtimeBoundary := boundary.runtimeKernelConfinementBoundary
  exact
    ⟨RuntimeKernelConfinementBoundary.toRefinesLeanKernelState runtimeBoundary,
      RuntimeKernelConfinementBoundary.witness_refinesShellContract runtimeBoundary⟩

end UOToolchain
