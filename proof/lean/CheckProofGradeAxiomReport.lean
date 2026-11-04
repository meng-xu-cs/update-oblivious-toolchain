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

/--
info: 'UOToolchain.IR.admittedKernel_exactUO' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.IR.admittedKernel_exactUO

/--
info: 'UOToolchain.paperMain_admittedKernel_exact_noninterference_moduloReleases' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.paperMain_admittedKernel_exact_noninterference_moduloReleases

/--
info: 'UOToolchain.IR.evalKernelProgram_flow_ni' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.IR.evalKernelProgram_flow_ni

/--
info: 'UOToolchain.IR.kernelPublicOutcome_safe' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.IR.kernelPublicOutcome_safe

/--
info: 'UOToolchain.paperMain_admittedKernelRun_exact_noninterference_moduloReleases' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.paperMain_admittedKernelRun_exact_noninterference_moduloReleases

/--
info: 'UOToolchain.IR.KernelProgram.admissionCheck_sound' depends on axioms: [propext]
-/
#guard_msgs in
#print axioms UOToolchain.IR.KernelProgram.admissionCheck_sound

/--
info: 'UOToolchain.paperMain_checkedKernel_exact_noninterference_moduloReleases' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.paperMain_checkedKernel_exact_noninterference_moduloReleases

/--
info: 'UOToolchain.PathOramFreshLeaves.observedLeaves_canonical' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.PathOramFreshLeaves.observedLeaves_canonical

/--
info: 'UOToolchain.PathOramFreshLeaves.observedLeaves_finalLeaves_uniform' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.PathOramFreshLeaves.observedLeaves_finalLeaves_uniform

/--
info: 'UOToolchain.PathOramFreshLeaves.replay_runLeaves' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.PathOramFreshLeaves.replay_runLeaves

/--
info: 'UOToolchain.PathOramFreshLeaves.multiObservedLeaves_canonical' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.PathOramFreshLeaves.multiObservedLeaves_canonical

/--
info: 'UOToolchain.PathOramFreshLeaves.replay_runLeaves_interleaved' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.PathOramFreshLeaves.replay_runLeaves_interleaved

/--
info: 'UOToolchain.SeededRuntimePathOramProofBundleOn.computationalUOWithOn' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.SeededRuntimePathOramProofBundleOn.computationalUOWithOn

/--
info: 'UOToolchain.paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases_on' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.paperMain_pathOramLocalPosmapV1_noninterference_moduloReleases_on

/--
info: 'UOToolchain.SeededRuntimePaperMainBundleOn.paperMain_noninterference_moduloReleases' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.SeededRuntimePaperMainBundleOn.paperMain_noninterference_moduloReleases

/--
info: 'UOToolchain.ConcreteRuntimePathOramPairSlice.toPaperMainBundleOn_admits_distinct_pair' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.ConcreteRuntimePathOramPairSlice.toPaperMainBundleOn_admits_distinct_pair

/--
info: 'UOToolchain.ConcreteRuntimePathOramPairSlice.sgxViewRelation_sides' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.ConcreteRuntimePathOramPairSlice.sgxViewRelation_sides

/--
info: 'UOToolchain.TapeRuntimePathOramWitnessFamily.leafValues_perm_canonical' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.TapeRuntimePathOramWitnessFamily.leafValues_perm_canonical

/--
info: 'UOToolchain.TapeRuntimePathOramWitnessFamily.toSeeded_realizesCanonicalLeafValueSeedSpace' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.TapeRuntimePathOramWitnessFamily.toSeeded_realizesCanonicalLeafValueSeedSpace

/--
info: 'UOToolchain.TapePathOramPaperMainEvidenceOn.paperMain_noninterference_moduloReleases' depends on axioms: [propext,
 Classical.choice,
 Quot.sound]
-/
#guard_msgs in
#print axioms UOToolchain.TapePathOramPaperMainEvidenceOn.paperMain_noninterference_moduloReleases

def main : IO UInt32 := pure 0
