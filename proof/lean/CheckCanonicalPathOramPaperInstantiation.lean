import UOToolchain.ProofGrade
import UOToolchain.PathOramAdmitted

open UOToolchain

def usage : String :=
  "usage: checkCanonicalPathOramPaperInstantiation <pair-certificate.json> <page-model> <exit-model> <shared-resource-model>"

def checkerAssumptions : PathOramLocalPosmapV1SecurityAssumptions :=
  { bucketEncryptionINDCPA := True
  , metadataEncryptionINDCPA := True
  , stashOverflowBounded := True
  }

noncomputable def importedCertificateProjectsToLhsRuntimeKernelConfinementBoundary
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags)
  (hProofValid : certificate.ProofGradeValid modelTags)
  (hLhsCoverage :
    ∀ hiddenSeed,
        hiddenSeed <
            pathOramLeafValueSeedSpaceSize certificate.lhs_family.projectedPublicLeafScaffold →
          ∃ freshSeed, freshSeed < certificate.lhs_family.seed_count ∧
            pathOramLeafValues
                (certificate.lhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed
                certificate.lhs_family.projectedPublicLeafScaffold
                hiddenSeed)
  (hRhsCoverage :
    ∀ hiddenSeed,
        hiddenSeed <
            pathOramLeafValueSeedSpaceSize certificate.rhs_family.projectedPublicLeafScaffold →
          ∃ freshSeed, freshSeed < certificate.rhs_family.seed_count ∧
            pathOramLeafValues
                (certificate.rhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed
                certificate.rhs_family.projectedPublicLeafScaffold
                hiddenSeed) :
  ∀ seed,
      seed <
          (certificate.toProofGradeConcretePairSlice
            modelTags
            hProofValid
            hLhsCoverage
            hRhsCoverage).lhs.toConcreteRuntimePathOramConfigSlice.family.seedCount →
        RuntimeKernelConfinementBoundary :=
  (certificate.toProofGradeConcretePairSlice
    modelTags
    hProofValid
    hLhsCoverage
    hRhsCoverage).lhs.runtimeKernelConfinementBoundary

noncomputable def importedCertificateProjectsToRhsRuntimeKernelConfinementBoundary
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags)
  (hProofValid : certificate.ProofGradeValid modelTags)
  (hLhsCoverage :
    ∀ hiddenSeed,
        hiddenSeed <
            pathOramLeafValueSeedSpaceSize certificate.lhs_family.projectedPublicLeafScaffold →
          ∃ freshSeed, freshSeed < certificate.lhs_family.seed_count ∧
            pathOramLeafValues
                (certificate.lhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed
                certificate.lhs_family.projectedPublicLeafScaffold
                hiddenSeed)
  (hRhsCoverage :
    ∀ hiddenSeed,
        hiddenSeed <
            pathOramLeafValueSeedSpaceSize certificate.rhs_family.projectedPublicLeafScaffold →
          ∃ freshSeed, freshSeed < certificate.rhs_family.seed_count ∧
            pathOramLeafValues
                (certificate.rhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
              pathOramLeafValueTraceOfSeed
                certificate.rhs_family.projectedPublicLeafScaffold
                hiddenSeed) :
  ∀ seed,
      seed <
          (certificate.toProofGradeConcretePairSlice
            modelTags
            hProofValid
            hLhsCoverage
            hRhsCoverage).rhs.toConcreteRuntimePathOramConfigSlice.family.seedCount →
        RuntimeKernelConfinementBoundary :=
  (certificate.toProofGradeConcretePairSlice
    modelTags
    hProofValid
    hLhsCoverage
    hRhsCoverage).rhs.runtimeKernelConfinementBoundary

def main (args : List String) : IO UInt32 := do
  match args with
  | [path, pageModel, exitModel, sharedResourceModel] =>
      let modelTags : SGXModelTags :=
        { pageModel := pageModel
        , exitModel := exitModel
        , sharedResourceModel := sharedResourceModel
        }
      let input ← IO.FS.readFile path
      let certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate ←
        match parseImportedCanonicalFreshCoinRuntimePathOramPairCertificate input with
        | .ok certificate => pure certificate
        | .error err =>
            throw <| IO.userError
              s!"failed to parse canonical fresh-coin path-ORAM pair certificate: {err}"
      if hPair :
          ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.checkProofGrade
            certificate
            modelTags then
        if hLhs : certificate.lhs_family.checkHiddenLeafCoverage then
          if hRhs : certificate.rhs_family.checkHiddenLeafCoverage then
            have hProofValid : certificate.ProofGradeValid modelTags :=
              (importedCanonicalFreshCoinRuntimePathOramPairCertificate_checkProofGrade_eq_true_iff
                certificate
                modelTags).mp (by simpa using hPair)
            have hValid : certificate.Valid modelTags :=
              importedCanonicalFreshCoinRuntimePathOramPairCertificate_proofGradeValid_implies_valid
                hProofValid
            have hLhsCoverage :
                ∀ hiddenSeed,
                    hiddenSeed <
                        pathOramLeafValueSeedSpaceSize
                          certificate.lhs_family.projectedPublicLeafScaffold →
                      ∃ freshSeed, freshSeed < certificate.lhs_family.seed_count ∧
                        pathOramLeafValues
                            (certificate.lhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
                          pathOramLeafValueTraceOfSeed
                            certificate.lhs_family.projectedPublicLeafScaffold
                            hiddenSeed :=
              (importedCanonicalFreshCoinRuntimePathOramWitnessFamily_checkHiddenLeafCoverage_eq_true_iff
                certificate.lhs_family).mp (by simpa using hLhs)
            have hRhsCoverage :
                ∀ hiddenSeed,
                    hiddenSeed <
                        pathOramLeafValueSeedSpaceSize
                          certificate.rhs_family.projectedPublicLeafScaffold →
                      ∃ freshSeed, freshSeed < certificate.rhs_family.seed_count ∧
                        pathOramLeafValues
                            (certificate.rhs_family.runtimeWitnessAt freshSeed).pathOramLeafScheduleTrace =
                          pathOramLeafValueTraceOfSeed
                            certificate.rhs_family.projectedPublicLeafScaffold
                            hiddenSeed :=
              (importedCanonicalFreshCoinRuntimePathOramWitnessFamily_checkHiddenLeafCoverage_eq_true_iff
                certificate.rhs_family).mp (by simpa using hRhs)
            have _ :
                ConcreteRuntimePathOramPaperPairBoundary
                  (modelTags := modelTags)
                  checkerAssumptions
                  certificate.runtimeCfg
                  certificate.runtimePublicOutcome
                  certificate.runtimeBoundarySchedule
                  ((certificate.toLhsConcreteSlice modelTags hValid hLhsCoverage).run)
                  ((certificate.toRhsConcreteSlice modelTags hValid hRhsCoverage).run) :=
              certificate.paperPairBoundary
                modelTags
                checkerAssumptions
                hValid
                hLhsCoverage
                hRhsCoverage
            -- The same pair is a bundle over its two sides, which agree on the
            -- public projection and differ in their secret inputs, and the
            -- general theorem over admitted configurations relates them.
            have _ :
                (certificate.toConcretePairSlice modelTags hValid hLhsCoverage hRhsCoverage).Admitted
                    (certificate.toConcretePairSlice modelTags hValid hLhsCoverage hRhsCoverage).lhsCfg ∧
                  (certificate.toConcretePairSlice modelTags hValid hLhsCoverage hRhsCoverage).Admitted
                    (certificate.toConcretePairSlice modelTags hValid hLhsCoverage hRhsCoverage).rhsCfg ∧
                  sameOramPublicProjection
                    (certificate.toConcretePairSlice modelTags hValid hLhsCoverage hRhsCoverage).lhsCfg
                    (certificate.toConcretePairSlice modelTags hValid hLhsCoverage hRhsCoverage).rhsCfg ∧
                  (certificate.toConcretePairSlice modelTags hValid hLhsCoverage hRhsCoverage).lhsCfg ≠
                    (certificate.toConcretePairSlice modelTags hValid hLhsCoverage hRhsCoverage).rhsCfg :=
              (certificate.toConcretePairSlice
                modelTags
                hValid
                hLhsCoverage
                hRhsCoverage).toPaperMainBundleOn_admits_distinct_pair
            have _ :=
              (certificate.toConcretePairSlice
                modelTags
                hValid
                hLhsCoverage
                hRhsCoverage).sgxViewRelation_sides
                checkerAssumptions
            IO.println
              s!"validated proof-grade concrete local paper-main instantiation for {certificate.runtimePublicOutcome.entrypointId}"
            IO.println
              s!"derived the Path ORAM bundle over admitted configurations for {certificate.runtimePublicOutcome.entrypointId}: two admitted sides, one public projection"
            pure 0
          else
            IO.eprintln "rhs canonical family does not cover the hidden leaf-value seed space"
            pure 1
        else
          IO.eprintln "lhs canonical family does not cover the hidden leaf-value seed space"
          pure 1
      else
        IO.eprintln "pair certificate failed Lean proof-grade validity checks"
        pure 1
  | _ =>
      IO.eprintln usage
      pure 1
