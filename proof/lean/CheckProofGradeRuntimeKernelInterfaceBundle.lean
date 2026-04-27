import UOToolchain.ProofGrade

open UOToolchain

def usage : String :=
  "usage: checkProofGradeRuntimeKernelInterfaceBundle <kernel-interface-bundle.json>"

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel-interface bundles preserve validity through the
`toRuntimeKernelInterfaceBundle` projection. -/
theorem importedRuntimeKernelInterfaceBundle_validates_toRuntimeValid
  (bundle : ImportedRuntimeKernelInterfaceBundle)
  (hValid : bundle.Valid) :
  bundle.toRuntimeKernelInterfaceBundle.Valid :=
  importedRuntimeKernelInterfaceBundle_toRuntimeValid bundle hValid

/-- Paper-grade witness theorem (W7.2): validated imported runtime
kernel-interface bundles project to a runtime
`RuntimeKernelRefinementBoundary` whose runtime kernel-refinement
witness refines the projected kernel witness's Lean kernel state. -/
theorem importedRuntimeKernelInterfaceBundle_validates_runtimeKernelRefinementBoundary
  {bundle : ImportedRuntimeKernelInterfaceBundle}
  (hValid : bundle.Valid) :
  RuntimeKernelRefinementWitness.RefinesLeanKernelState
      (bundle.toRuntimeKernelRefinementBoundary hValid).runtimeKernelRefinementWitness
      (bundle.toRuntimeKernelRefinementBoundary hValid).kernelWitness :=
  importedRuntimeKernelInterfaceBundle_valid_projects_to_runtimeKernelRefinementBoundary
    hValid

def main (args : List String) : IO UInt32 := do
  match args with
  | [path] =>
      let bundle ← loadAndCheckImportedProofGradeRuntimeKernelInterfaceBundle path
      IO.println
        s!"validated proof-grade runtime kernel-interface bundle for {bundle.shell_boundary_bundle.kernel_witness.entrypoint_id}"
      pure 0
  | _ =>
      IO.eprintln usage
      pure 1
