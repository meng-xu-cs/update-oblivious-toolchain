import Lean.Data.Json
import UOToolchain.RuntimeImplementationInterface
import UOToolchain.RuntimeShellBoundaryJson

open Lean

namespace UOToolchain

def importedRuntimeImplementationInterfaceFieldNames : List String :=
  [ "runtime_evm_lib_source"
  , "engine_source"
  , "runtime_module_source"
  , "shell_source"
  , "state_source"
  , "kernel_source"
  , "theorem_source"
  ]

structure ImportedRuntimeImplementationInterface where
  runtime_evm_lib_source : String
  engine_source : String
  runtime_module_source : String
  shell_source : String
  state_source : String
  kernel_source : String
  theorem_source : String
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeImplementationInterface.toRuntimeImplementationInterface
  (iface : ImportedRuntimeImplementationInterface) : RuntimeImplementationInterface :=
  { runtimeEvmLibSource := iface.runtime_evm_lib_source
  , engineSource := iface.engine_source
  , runtimeModuleSource := iface.runtime_module_source
  , shellSource := iface.shell_source
  , stateSource := iface.state_source
  , kernelSource := iface.kernel_source
  , theoremSource := iface.theorem_source
  }

def ImportedRuntimeImplementationInterface.Valid
  (iface : ImportedRuntimeImplementationInterface) : Prop :=
  iface.toRuntimeImplementationInterface.Valid

def ImportedRuntimeImplementationInterface.checkValid
  (iface : ImportedRuntimeImplementationInterface) : Bool :=
  iface.toRuntimeImplementationInterface.checkValid

@[simp] theorem importedRuntimeImplementationInterface_checkValid_eq_true_iff
  (iface : ImportedRuntimeImplementationInterface) :
  iface.checkValid = true ↔ iface.Valid := by
  unfold ImportedRuntimeImplementationInterface.checkValid
    ImportedRuntimeImplementationInterface.Valid
  simp [runtimeImplementationInterface_checkValid_eq_true_iff]

theorem importedRuntimeImplementationInterface_toRuntimeValid
  (iface : ImportedRuntimeImplementationInterface)
  (hValid : iface.Valid) :
  iface.toRuntimeImplementationInterface.Valid := hValid

structure ImportedRuntimeImplementationConfinementBoundary where
  implementation_interface : ImportedRuntimeImplementationInterface
  kernel_interface_bundle : ImportedRuntimeKernelInterfaceBundle
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedRuntimeImplementationConfinementBoundary.Valid
  (boundary : ImportedRuntimeImplementationConfinementBoundary) : Prop :=
  boundary.implementation_interface.Valid ∧
    boundary.kernel_interface_bundle.Valid

def ImportedRuntimeImplementationConfinementBoundary.checkValid
  (boundary : ImportedRuntimeImplementationConfinementBoundary) : Bool :=
  boundary.implementation_interface.checkValid &&
    boundary.kernel_interface_bundle.checkValid

def ImportedRuntimeImplementationConfinementBoundary.toRuntimeImplementationConfinementBoundary
  (boundary : ImportedRuntimeImplementationConfinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationConfinementBoundary :=
  { implementationInterface :=
      boundary.implementation_interface.toRuntimeImplementationInterface
  , kernelInterfaceBundle :=
      boundary.kernel_interface_bundle.toRuntimeKernelInterfaceBundle
  , implementationValid := by
      exact importedRuntimeImplementationInterface_toRuntimeValid
        boundary.implementation_interface hValid.1
  , kernelInterfaceValid := by
      exact importedRuntimeKernelInterfaceBundle_toRuntimeValid
        boundary.kernel_interface_bundle hValid.2
  }

@[simp] theorem importedRuntimeImplementationConfinementBoundary_checkValid_eq_true_iff
  (boundary : ImportedRuntimeImplementationConfinementBoundary) :
  boundary.checkValid = true ↔ boundary.Valid := by
  unfold ImportedRuntimeImplementationConfinementBoundary.checkValid
    ImportedRuntimeImplementationConfinementBoundary.Valid
  simp [importedRuntimeImplementationInterface_checkValid_eq_true_iff,
    importedRuntimeKernelInterfaceBundle_checkValid_eq_true_iff]

theorem importedRuntimeImplementationConfinementBoundary_toRuntimeImplementationConfinement
  (boundary : ImportedRuntimeImplementationConfinementBoundary)
  (hValid : boundary.Valid) :
  RuntimeImplementationInterface.ConfinesSecretDependentWork
    (boundary.toRuntimeImplementationConfinementBoundary hValid).implementationInterface := by
  exact
    RuntimeImplementationConfinementBoundary.implementationConfinement
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

theorem importedRuntimeImplementationConfinementBoundary_valid_projects_to_runtimeKernelConfinementBoundary
  {boundary : ImportedRuntimeImplementationConfinementBoundary}
  (hValid : boundary.Valid) :
  let runtimeBoundary := boundary.toRuntimeImplementationConfinementBoundary hValid
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness ∧
    RuntimeShellTrace.Refines
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.runtimeKernelRefinementWitness.shellTrace
      runtimeBoundary.runtimeKernelConfinementBoundary.refinementBoundary.kernelWitness.shellContract := by
  exact
    RuntimeImplementationConfinementBoundary.projects_to_runtimeKernelConfinementBoundary
      (boundary.toRuntimeImplementationConfinementBoundary hValid)

def parseImportedRuntimeImplementationInterface
  (input : String) : Except String ImportedRuntimeImplementationInterface := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationInterface
  (input : String) : Except String ImportedRuntimeImplementationInterface := do
  let iface ← parseImportedRuntimeImplementationInterface input
  if iface.checkValid then
    pure iface
  else
    throw "imported runtime implementation interface does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationInterface
  (path : System.FilePath) : IO ImportedRuntimeImplementationInterface := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationInterface input with
  | .ok iface => pure iface
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation interface: {err}"

def loadAndCheckImportedRuntimeImplementationInterface
  (path : System.FilePath) : IO ImportedRuntimeImplementationInterface := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationInterface input with
  | .ok iface => pure iface
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation interface: {err}"

def parseImportedRuntimeImplementationConfinementBoundary
  (input : String) : Except String ImportedRuntimeImplementationConfinementBoundary := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedRuntimeImplementationConfinementBoundary
  (input : String) : Except String ImportedRuntimeImplementationConfinementBoundary := do
  let boundary ← parseImportedRuntimeImplementationConfinementBoundary input
  if boundary.checkValid then
    pure boundary
  else
    throw "imported runtime implementation confinement boundary does not satisfy Lean validity checks"

def loadImportedRuntimeImplementationConfinementBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationConfinementBoundary := do
  let input ← IO.FS.readFile path
  match parseImportedRuntimeImplementationConfinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to parse runtime implementation confinement boundary: {err}"

def loadAndCheckImportedRuntimeImplementationConfinementBoundary
  (path : System.FilePath) : IO ImportedRuntimeImplementationConfinementBoundary := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedRuntimeImplementationConfinementBoundary input with
  | .ok boundary => pure boundary
  | .error err =>
      throw <| IO.userError
        s!"failed to validate runtime implementation confinement boundary: {err}"

end UOToolchain
