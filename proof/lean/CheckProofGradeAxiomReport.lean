import UOToolchain.ProofGradeRoot

/-!
# Proof-grade axiom report

This checker pins the axiom dependency report for the named paper-facing
compiler and runtime theorems. It allows only Lean's standard logical axioms
and fails if the legacy demonstration axioms enter the dependency closure.
-/

/--
info: 'UOToolchain.proofGrade_compiler_correctness_supersedes_artifact_checker' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.proofGrade_compiler_correctness_supersedes_artifact_checker

/--
info: 'UOToolchain.RuntimeImplementationKernelMachineConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.RuntimeImplementationKernelMachineConfinementBoundary.paperEndToEndConfinementWithPublicOnlyHandwrittenShell

/--
info: 'UOToolchain.RuntimePaperNativeKernelAssumptions.paperEndToEndConfinementWithPublicOnlyHandwrittenShell' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.RuntimePaperNativeKernelAssumptions.paperEndToEndConfinementWithPublicOnlyHandwrittenShell

def main : IO UInt32 := pure 0
