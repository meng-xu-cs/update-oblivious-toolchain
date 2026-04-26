import UOToolchain.TraceModel
import UOToolchain.FiniteDistribution
import UOToolchain.IRSemantics
import UOToolchain.ExactObjects
import UOToolchain.CompilerInvariant
import UOToolchain.OramModel
import UOToolchain.Composition
import UOToolchain.StandardOramReduction
import UOToolchain.PathOramSecurity
import UOToolchain.TeeDeployment
import UOToolchain.SgxBoundary
import UOToolchain.SgxRelation
import UOToolchain.SgxController
import UOToolchain.SgxControllerTrace
import UOToolchain.SgxMicroModel
import UOToolchain.SgxOramProjection
import UOToolchain.SgxExactProjection
import UOToolchain.SgxJointProjection
import UOToolchain.RuntimeRefinement
import UOToolchain.RuntimeTrustedKernel
import UOToolchain.RuntimeShellBoundary
import UOToolchain.RuntimeImplementationInterface
import UOToolchain.ConfidentialKernelDsl
import UOToolchain.ConfidentialFragment
import UOToolchain.RuntimeConfidentialCoreAssurance
import UOToolchain.RuntimeCoins
import UOToolchain.PathOramLocalPosmapV1
import UOToolchain.PathOramLocalPosmapV1Refinement
import UOToolchain.PathOramLocalPosmapV1StandardTheorem
import UOToolchain.PathOramJACMTheorem
import UOToolchain.PaperPathOramTheoremRoute
import UOToolchain.RuntimeRefinementJson
import UOToolchain.RuntimeTrustedKernelJson
import UOToolchain.RuntimeShellBoundaryJson
import UOToolchain.RuntimeImplementationInterfaceJson
import UOToolchain.RuntimeKernelFinishBundleJson
import UOToolchain.RuntimeKernelMachineFinishBoundaryJson
import UOToolchain.RuntimeKernelMachineFinishWitnessJson
import UOToolchain.RuntimeShellBoundarySlotJson
import UOToolchain.RuntimeShellBoundaryLoweringJson
import UOToolchain.ConfidentialFragmentJson
import UOToolchain.RuntimeKernelDslJson
import UOToolchain.RuntimeConfidentialCoreAssuranceJson
import UOToolchain.RuntimeConfidentialCoreKernelFinishSlotJson
import UOToolchain.RuntimeConfidentialCoreKernelInterfaceSlotJson
import UOToolchain.RuntimeConfidentialProofBundleFamilyJson
import UOToolchain.RuntimeConfidentialCoreShellBoundarySlotJson
import UOToolchain.RuntimeConfidentialCoreShellBoundaryLoweringJson
import UOToolchain.RuntimeCoinsJson
import UOToolchain.RuntimePathOramPairJson
import UOToolchain.RuntimeCanonicalPathOramPairJson
import UOToolchain.TranslationValidationJson
import UOToolchain.CompilerExactness
import UOToolchain.RuntimePaperInstantiation

namespace UOToolchain

theorem proofGradeCompilerFacts
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid) :
  ProofGradeCompilerFacts bundle := by
  exact proofGradeCompilerFactsOfValid bundle hValid

theorem proofGrade_source_manifest_secrets_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  entry.secret_args = fn.secret_args ∧
    entry.param_names = fn.params.map ImportedProofRelevantParamView.name := by
  exact
    bundle.source_view.manifest_secrets_exact_of_lookup
      (bundle.source_view_structural_valid hValid)
      hMem
      hLookup

theorem proofGrade_source_confidential_lowering_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  functionConfidentialLoweringMatchesManifest bundle.source_view fn entry = true := by
  exact
    bundle.source_view.confidential_lowering_exact_of_lookup
      (bundle.source_view_structural_valid hValid)
      hMem
      hLookup

theorem proofGrade_source_manifest_boundary_lengths_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ inputLen returnLen,
    expectedEntrypointInputLen fn = .ok inputLen ∧
    expectedReturnCanonicalLen fn = .ok returnLen ∧
    entry.entry_input_len = inputLen ∧
    entry.return_canonical_len = returnLen := by
  exact
    bundle.source_view.manifest_boundary_lengths_exact_of_lookup
      (bundle.source_view_structural_valid hValid)
      hMem
      hLookup

theorem proofGrade_source_manifest_counts_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ counts,
    countBodyStrings fn.body = .ok counts ∧
    entry.arena_bytes = 4096 + counts.localCount * 64 ∧
    entry.max_stack_words = 64 + counts.localCount ∧
    entry.uocell_reads = counts.cellReads ∧
    entry.uocell_writes = counts.cellWrites ∧
    entry.uoarray_reads = counts.arrayReads ∧
    entry.uoarray_writes = counts.arrayWrites ∧
    entry.uomap_reads = counts.mapReads ∧
    entry.uomap_writes = counts.mapWrites := by
  exact
    bundle.source_view.manifest_counts_exact_of_lookup
      (bundle.source_view_structural_valid hValid)
      hMem
      hLookup

theorem proofGrade_source_manifest_oram_accesses_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected,
    countOramAccessesInBodyStrings fn.body bundle.source_view.state = .ok expected ∧
    oramAccessesMatchExpected expected entry.oram_accesses = true ∧
    ∀ objectId accesses,
      (objectId, accesses) ∈ expected →
        (match
            stateObjectById? bundle.source_view.state objectId,
            manifestObjectById? bundle.source_view.manifest.objects objectId with
        | some stateObject, some manifestObject =>
            validateImportedOramShape stateObject manifestObject accesses
        | _, _ => false) = true := by
  exact
    bundle.source_view.manifest_oram_accesses_exact_of_lookup
      (bundle.source_view_structural_valid hValid)
      hMem
      hLookup

theorem proofGrade_source_manifest_commit_ops_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ maxCommitOps,
    expectedCommitOpsForFunction bundle.source_view fn = .ok maxCommitOps ∧
    entry.max_commit_ops = maxCommitOps := by
  exact
    bundle.source_view.manifest_commit_ops_exact_of_lookup
      (bundle.source_view_structural_valid hValid)
      hMem
      hLookup

theorem proofGrade_source_manifest_witness_with_expected_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected witness,
    countOramAccessesInBodyStrings fn.body bundle.source_view.state = .ok expected ∧
    witness = entry.toManifestWitnessWithExpected expected ∧
    witness.secretArgs = fn.secret_args ∧
    witness.publicGasBudget = entry.public_gas_budget ∧
    witness.oramAccesses = expected := by
  exact
    proofGradeManifestWitnessWithExpectedOfLookup bundle hValid hMem hLookup

theorem proofGrade_source_expected_oram_object_witness_exists_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∀ {objectId accesses},
    (objectId, accesses) ∈
        (match countOramAccessesInBodyStrings fn.body bundle.source_view.state with
        | .ok expected => expected
        | .error _ => []) →
      ∃ stateObject manifestObject object,
        stateObjectById? bundle.source_view.state objectId = some stateObject ∧
        manifestObjectById? bundle.source_view.manifest.objects objectId = some manifestObject ∧
        manifestObject.toOramObjectManifest? stateObject = some object ∧
        WellFormedOramObject object ∧
        ((1 < accesses) → WellFormedPathOramObject object) := by
  exact
    proofGradeExpectedOramObjectWitnessExistsOfLookup bundle hValid hMem hLookup

theorem proofGrade_source_expected_oram_object_witnesses_build_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected objects,
    countOramAccessesInBodyStrings fn.body bundle.source_view.state = .ok expected ∧
    bundle.source_view.buildExpectedOramObjectWitnesses expected = .ok objects ∧
    ∀ object, object ∈ objects → WellFormedOramObject object := by
  exact
    proofGradeExpectedOramObjectWitnessesBuildOfLookup bundle hValid hMem hLookup

theorem proofGrade_source_expected_path_oram_object_witness_exists_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∀ {objectId accesses},
    (objectId, accesses) ∈
        (match countOramAccessesInBodyStrings fn.body bundle.source_view.state with
        | .ok expected => expected
        | .error _ => []) →
      1 < accesses →
      ∃ stateObject manifestObject object,
        stateObjectById? bundle.source_view.state objectId = some stateObject ∧
        manifestObjectById? bundle.source_view.manifest.objects objectId = some manifestObject ∧
        manifestObject.toOramObjectManifest? stateObject = some object ∧
        WellFormedPathOramObject object := by
  exact
    proofGradeExpectedPathOramObjectWitnessExistsOfLookup bundle hValid hMem hLookup

theorem proofGrade_source_expected_oram_object_witnesses_aligned_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected objects,
    countOramAccessesInBodyStrings fn.body bundle.source_view.state = .ok expected ∧
    bundle.source_view.buildExpectedOramObjectWitnesses expected = .ok objects ∧
    ExpectedOramObjectWitnessAlignment expected objects := by
  exact
    proofGradeExpectedOramObjectWitnessesAlignedOfLookup bundle hValid hMem hLookup

theorem proofGrade_source_oram_entrypoint_witness_aligned_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected witness,
    countOramAccessesInBodyStrings fn.body bundle.source_view.state = .ok expected ∧
    bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
    witness.entrypointId = entry.signature ∧
    witness.secretArgs = fn.secret_args ∧
    witness.publicGasBudget = entry.public_gas_budget ∧
    witness.oramAccesses = expected ∧
    ExpectedOramObjectWitnessAlignment expected witness.oramObjects := by
  exact
    proofGradeOramEntrypointWitnessAlignedExactOfLookup bundle hValid hMem hLookup

theorem proofGrade_source_oram_entrypoint_witness_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected witness,
    countOramAccessesInBodyStrings fn.body bundle.source_view.state = .ok expected ∧
    bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
    witness.entrypointId = entry.signature ∧
    witness.secretArgs = fn.secret_args ∧
    witness.publicGasBudget = entry.public_gas_budget ∧
    witness.oramAccesses = expected ∧
    ∀ object, object ∈ witness.oramObjects → WellFormedOramObject object := by
  exact
    proofGradeOramEntrypointWitnessExactOfLookup bundle hValid hMem hLookup

theorem proofGrade_source_oram_entrypoint_witness_object_count_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry) :
  ∃ expected witness,
    countOramAccessesInBodyStrings fn.body bundle.source_view.state = .ok expected ∧
    bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
    witness.oramObjects.length = expected.length := by
  exact
    proofGradeOramEntrypointWitnessObjectCountExactOfLookup bundle hValid hMem hLookup

theorem proofGrade_source_confidential_kernel_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true) :
  ∃ expectedProgram fnProgram fnSlotProgram entryProgram entrySlotProgram expectedHashPartBytes,
    expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
    parseFunctionConfidentialProgram fn = .ok (some fnProgram) ∧
    parseFunctionConfidentialSlotProgram fn = .ok (some fnSlotProgram) ∧
    parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
    parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
    importedConfidentialKernelProgramEq fnProgram expectedProgram = true ∧
    fnProgram.expectedRuntimeKernelSteps = expectedProgram.expectedRuntimeKernelSteps ∧
    importedConfidentialKernelProgramEq fnProgram entryProgram = true ∧
    fnProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps ∧
    checkImportedConfidentialKernelProgramSlotLowering fnProgram fnSlotProgram = true ∧
    checkImportedConfidentialKernelProgramSlotLowering entryProgram entrySlotProgram = true ∧
    fn.confidential_program = entry.confidential_program ∧
    fn.confidential_slot_program = entry.confidential_slot_program ∧
    importedConfidentialKernelProgramMaxHashPartBytes bundle.source_view.state entryProgram = .ok expectedHashPartBytes ∧
    entryProgram.entrypoint_id = fn.signature ∧
    entrySlotProgram.entrypoint_id = fn.signature ∧
    entryProgram.secret_args = fn.secret_args ∧
    entrySlotProgram.secret_args = fn.secret_args ∧
    entry.max_hash_part_bytes = expectedHashPartBytes ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        entryProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        entrySlotProgram.expectedRuntimeKernelSteps = entry.kernel_steps := by
  exact
    functionConfidentialLoweringMatchesManifest_confidential_exact
      (bundle.source_view.confidential_lowering_exact_of_lookup
        (bundle.source_view_structural_valid hValid)
        hMem
        hLookup)
      hConf

theorem proofGrade_source_confidential_kernel_step_targets_non_raw_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true)
  {kernelStep : ImportedProofRelevantKernelStepView}
  {objectId : Nat}
  (hStepMem : kernelStep ∈ entry.kernel_steps)
  (hObjectId : kernelStep.object_id = some objectId) :
  ∃ stateObject,
    stateObjectById? bundle.source_view.state objectId = some stateObject ∧
      stateObject.backend ≠ "raw" := by
  exact
    bundle.source_view.confidential_kernel_step_targets_non_raw_of_lookup
      (bundle.source_view_structural_valid hValid)
      hMem
      hLookup
      hConf
      hStepMem
      hObjectId

theorem proofGrade_source_expected_kernel_schedule_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true) :
  ∃ expectedProgram entryProgram,
    expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
    parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
    expectedProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      expectedProgram.expectedRuntimeKernelSteps = entry.kernel_steps := by
  exact
    proofGradeSourceExpectedKernelScheduleExactOfLookup
      bundle hValid hMem hLookup hConf

theorem proofGrade_source_to_runtime_slot_schedule_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true) :
  ∃ expectedProgram entryProgram entrySlotProgram lowered runtimeProgram runtimeSlotProgram,
    expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
    parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
    parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
    entryProgram.toConfidentialKernelSlotProgram? = .ok lowered ∧
    runtimeProgram = entryProgram.toConfidentialKernelProgram ∧
    runtimeSlotProgram = lowered.toConfidentialKernelSlotProgram ∧
    expectedProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps ∧
    entryProgram.expectedRuntimeKernelSteps = lowered.expectedRuntimeKernelSteps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      expectedProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      entryProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      lowered.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    expectedProgram.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      runtimeProgram.expectedRuntimeKernelSteps ∧
    lowered.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      runtimeSlotProgram.expectedRuntimeKernelSteps ∧
    runtimeProgram.expectedRuntimeKernelSteps = runtimeSlotProgram.expectedRuntimeKernelSteps := by
  exact
    proofGradeSourceToRuntimeSlotScheduleExactOfLookup
      bundle hValid hMem hLookup hConf

theorem proofGrade_source_oram_entrypoint_recomputed_slot_lowering_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true) :
  ∃ expected witness entryProgram entrySlotProgram lowered,
    countOramAccessesInBodyStrings fn.body bundle.source_view.state = .ok expected ∧
    bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
    parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
    parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
    entryProgram.toConfidentialKernelSlotProgram? = .ok lowered ∧
    checkImportedConfidentialKernelSlotProgramEq lowered entrySlotProgram = true ∧
    lowered.entrypoint_id = entry.signature ∧
    lowered.secret_args = fn.secret_args ∧
    witness.entrypointId = lowered.entrypoint_id ∧
    witness.secretArgs = lowered.secret_args ∧
    witness.publicGasBudget = entry.public_gas_budget ∧
    witness.oramAccesses = expected ∧
    ExpectedOramObjectWitnessAlignment expected witness.oramObjects ∧
    entryProgram.toConfidentialKernelProgram.SlotLoweringMatches
      lowered.toConfidentialKernelSlotProgram ∧
    lowered.RuntimeNormalForm ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      entrySlotProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      entryProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    entryProgram.expectedRuntimeKernelSteps = lowered.expectedRuntimeKernelSteps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      lowered.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    entryProgram.toConfidentialKernelProgram.expectedRuntimeKernelSteps =
      lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps ∧
    lowered.expectedRuntimeKernelSteps.map ImportedRuntimeKernelStep.toRuntimeKernelStep =
      lowered.toConfidentialKernelSlotProgram.expectedRuntimeKernelSteps := by
  exact
    proofGradeOramEntrypointRecomputedSlotLoweringExactOfLookup
      bundle hValid hMem hLookup hConf

theorem proofGrade_source_oram_entrypoint_runtime_slot_program_exact_of_lookup
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMem : fn ∈ bundle.source_view.functions)
  (hLookup : lookupEntrypoint fn.signature bundle.source_view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true) :
  ∃ expected witness entryProgram entrySlotProgram lowered runtimeProgram runtimeSlotProgram,
    countOramAccessesInBodyStrings fn.body bundle.source_view.state = .ok expected ∧
    bundle.source_view.toOramEntrypointWitnessFromExpected entry expected = .ok witness ∧
    parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
    parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
    entryProgram.toConfidentialKernelSlotProgram? = .ok lowered ∧
    runtimeProgram = entryProgram.toConfidentialKernelProgram ∧
    runtimeSlotProgram = lowered.toConfidentialKernelSlotProgram ∧
    checkImportedConfidentialKernelSlotProgramEq lowered entrySlotProgram = true ∧
    witness.entrypointId = runtimeSlotProgram.entrypointId ∧
    witness.secretArgs = runtimeSlotProgram.secretArgs ∧
    witness.publicGasBudget = entry.public_gas_budget ∧
    witness.oramAccesses = expected ∧
    ExpectedOramObjectWitnessAlignment expected witness.oramObjects ∧
    runtimeProgram.SlotLoweringMatches runtimeSlotProgram ∧
    runtimeSlotProgram.RuntimeNormalForm ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
      entrySlotProgram.expectedRuntimeKernelSteps = entry.kernel_steps := by
  rcases
      proofGradeOramEntrypointRecomputedSlotLoweringExactOfLookup
        bundle hValid hMem hLookup hConf with
    ⟨ expected
    , witness
    , entryProgram
    , entrySlotProgram
    , lowered
    , hExpected
    , hWitness
    , hEntryProgram
    , hEntrySlotProgram
    , hLowered
    , hStoredEq
    , _hLoweredEntrypoint
    , _hLoweredSecrets
    , hWitnessEntrypoint
    , hWitnessSecrets
    , hGas
    , hAccesses
    , hAligned
    , hRuntimeLowering
    , hRuntimeNormal
    , hEntrySlotSteps
    , _hEntryProgramSteps
    , _hNamedImportedSteps
    , _hLoweredProofRelevantSteps
    , _hRuntimeStepEq
    , _hLoweredStepsToRuntime
    ⟩
  refine
    ⟨ expected
    , witness
    , entryProgram
    , entrySlotProgram
    , lowered
    , entryProgram.toConfidentialKernelProgram
    , lowered.toConfidentialKernelSlotProgram
    , hExpected
    , hWitness
    , hEntryProgram
    , hEntrySlotProgram
    , hLowered
    , rfl
    , rfl
    , hStoredEq
    , ?_
    , ?_
    , hGas
    , hAccesses
    , hAligned
    , hRuntimeLowering
    , hRuntimeNormal
    , hEntrySlotSteps
    ⟩
  · simpa [ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram] using hWitnessEntrypoint
  · simpa [ImportedConfidentialKernelSlotProgram.toConfidentialKernelSlotProgram] using hWitnessSecrets

/-! ## W4.3: Confidential-fragment characterization (paper facade)

`proofGrade_confidential_fragment_valid_iff_structurally_valid`
re-exports the W4.3 characterization theorem so the paper-facing
facade can cite a single named handle: "the count-based confidential-
fragment witness is `Valid` iff the function body is structurally
fragment-valid (no `Expr.structField`, no `Expr.arrayIndex`, no
non-branchless `Expr.select` arm)." This pins the WP4 admission/
rejection theorem against the structured `IRSyntax`-mirrored AST,
not against a string view.
-/

theorem proofGrade_confidential_fragment_valid_iff_structurally_valid
    (fn : IR.CompiledFunction) :
    (IR.confidentialFragmentEntrypointWitnessOf fn).Valid ↔
      fn.fragmentValid = true :=
  IR.confidentialFragmentEntrypointWitnessOf_valid_iff fn

end UOToolchain
