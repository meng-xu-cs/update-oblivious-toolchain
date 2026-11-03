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

/--
info: 'UOToolchain.proofGrade_sol_kernel_steps_eq_of_continues' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.proofGrade_sol_kernel_steps_eq_of_continues

/--
info: 'UOToolchain.paperMain_exact_backend_noninterference_moduloReleases' depends on axioms: [propext]
-/
#guard_msgs in
#print axioms UOToolchain.paperMain_exact_backend_noninterference_moduloReleases

/--
info: 'UOToolchain.paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases

/--
info: 'UOToolchain.paperMain_pathOramPrivatePosmapV1_noninterference_moduloReleases' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.paperMain_pathOramPrivatePosmapV1_noninterference_moduloReleases

/--
info: 'UOToolchain.acceptedExactPackageCapstone_noninterference_moduloReleases' depends on axioms: [propext]
-/
#guard_msgs in
#print axioms UOToolchain.acceptedExactPackageCapstone_noninterference_moduloReleases

/--
info: 'UOToolchain.acceptedPathOramPackageCapstone_noninterference_moduloReleases' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.acceptedPathOramPackageCapstone_noninterference_moduloReleases

/--
info: 'UOToolchain.acceptedPrivatePosmapPathOramPackageCapstone_noninterference_moduloReleases' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.acceptedPrivatePosmapPathOramPackageCapstone_noninterference_moduloReleases

/--
info: 'UOToolchain.proofGrade_sol_kernel_steps_eq_of_wellTyped' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.proofGrade_sol_kernel_steps_eq_of_wellTyped

/--
info: 'UOToolchain.IR.evalKernelProgram_continues_of_wellTyped' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.IR.evalKernelProgram_continues_of_wellTyped

def main : IO UInt32 := pure 0
