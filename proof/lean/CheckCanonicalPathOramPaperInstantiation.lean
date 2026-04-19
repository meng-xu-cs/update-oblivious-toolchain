import UOToolchain

open UOToolchain

def usage : String :=
  "usage: checkCanonicalPathOramPaperInstantiation <pair-certificate.json> <page-model> <exit-model> <shared-resource-model>"

def checkerAssumptions : PathOramLocalPosmapV1SecurityAssumptions :=
  { bucketEncryptionINDCPA := True
  , metadataEncryptionINDCPA := True
  , stashOverflowBounded := True
  }

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
      if hPair : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.checkValid certificate modelTags then
        if hLhs : certificate.lhs_family.checkHiddenLeafCoverage then
          if hRhs : certificate.rhs_family.checkHiddenLeafCoverage then
            have hValid : certificate.Valid modelTags :=
              (importedCanonicalFreshCoinRuntimePathOramPairCertificate_checkValid_eq_true_iff
                certificate
                modelTags).mp (by simpa using hPair)
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
            IO.println
              s!"validated concrete local paper-main instantiation for {certificate.runtimePublicOutcome.entrypointId}"
            pure 0
          else
            IO.eprintln "rhs canonical family does not cover the hidden leaf-value seed space"
            pure 1
        else
          IO.eprintln "lhs canonical family does not cover the hidden leaf-value seed space"
          pure 1
      else
        IO.eprintln "pair certificate failed Lean validity checks"
        pure 1
  | _ =>
      IO.eprintln usage
      pure 1
