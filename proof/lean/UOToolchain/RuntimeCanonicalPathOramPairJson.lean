import Lean.Data.Json
import UOToolchain.RuntimePathOramPairJson

open Lean

namespace UOToolchain

structure ImportedCanonicalFreshCoinRuntimePathOramPairCertificate where
  cfg : ImportedOramConfig
  lhs_family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily
  rhs_family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily
  public_view : ImportedOramViewPublicPart
  public_location : ImportedPathOramStorageLocationTrace
  storage_shape : ImportedPathOramStorageShape
  public_outcome : ImportedPublicOutcomeTrace
  boundary_schedule : List ImportedBoundaryEvent
  controller_shape : ImportedSgxControllerShapeTrace
  normalized_micro_trace : ImportedNormalizedMicroTrace
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.runtimeCfg
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate) : OramConfig :=
  certificate.cfg.toOramConfig

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.runtimePublicView
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate) : OramViewPublicPart :=
  certificate.public_view.toOramViewPublicPart

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.runtimePublicLocation
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate) :
  PathOramStorageLocationTrace :=
  certificate.public_location.toPathOramStorageLocationTrace

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.runtimeStorageShape
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate) :
  PathOramStorageShape :=
  certificate.storage_shape.toPathOramStorageShape

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.runtimePublicOutcome
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate) : SGXPublicOutcome :=
  certificate.public_outcome.toPublicOutcome

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.runtimeBoundarySchedule
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate) : List BoundaryEvent :=
  certificate.boundary_schedule.map ImportedBoundaryEvent.toBoundaryEvent

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.runtimeControllerShape
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate) : SGXControllerShape :=
  certificate.controller_shape.toControllerShape

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.runtimeNormalizedMicroTrace
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate) : NormalizedMicroTrace :=
  certificate.normalized_micro_trace.toNormalizedMicroTrace

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.familyMatches
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Prop :=
  family.Valid modelTags ∧
    ∀ seed, seed < family.seed_count →
      ∃ witness,
        family.witnessAt? seed = some witness ∧
        witness.toRuntimeWitness.ObjectsMatchPublicConfig certificate.runtimeCfg ∧
        pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
          certificate.runtimePublicView ∧
        pathOramPublicLocationTrace
            (pathOramStorageLocationTrace
              (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
          certificate.runtimePublicLocation ∧
        pathOramStorageShape (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
          certificate.runtimeStorageShape ∧
        witness.toRuntimeWitness.publicOutcome = certificate.runtimePublicOutcome ∧
        witness.toRuntimeWitness.boundarySchedule = certificate.runtimeBoundarySchedule ∧
        witness.toRuntimeWitness.controllerShape = certificate.runtimeControllerShape ∧
        witness.toRuntimeWitness.normalizedMicroTrace = certificate.runtimeNormalizedMicroTrace

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.Valid
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags) : Prop :=
  PathOramConfigWellFormed certificate.runtimeCfg ∧
    certificate.familyMatches certificate.lhs_family modelTags ∧
    certificate.familyMatches certificate.rhs_family modelTags

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.familyMatchesCheck
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Bool :=
  family.checkValid modelTags &&
    (List.range family.seed_count).all fun seed =>
      match family.witnessAt? seed with
      | some witness =>
          runtimeWitnessObjectsMatchPublicConfigCheck
              witness.toRuntimeWitness
              certificate.runtimeCfg &&
            decide
              (pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
                certificate.runtimePublicView) &&
            decide
              (pathOramPublicLocationTrace
                  (pathOramStorageLocationTrace
                    (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
                certificate.runtimePublicLocation) &&
            decide
              (pathOramStorageShape (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
                certificate.runtimeStorageShape) &&
            decide (witness.toRuntimeWitness.publicOutcome = certificate.runtimePublicOutcome) &&
            decide
              (witness.toRuntimeWitness.boundarySchedule =
                certificate.runtimeBoundarySchedule) &&
            decide (witness.toRuntimeWitness.controllerShape = certificate.runtimeControllerShape) &&
            decide
              (witness.toRuntimeWitness.normalizedMicroTrace =
                certificate.runtimeNormalizedMicroTrace)
      | none => false

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.checkValid
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags) : Bool :=
  pathOramConfigWellFormedCheck certificate.runtimeCfg &&
    certificate.familyMatchesCheck certificate.lhs_family modelTags &&
    certificate.familyMatchesCheck certificate.rhs_family modelTags

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.proofGradeFamilyMatchesCheck
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Bool :=
  family.checkProofGrade modelTags &&
    (List.range family.seed_count).all fun seed =>
      match family.witnessAt? seed with
      | some witness =>
          runtimeWitnessObjectsMatchPublicConfigCheck
              witness.toRuntimeWitness
              certificate.runtimeCfg &&
            decide
              (pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
                certificate.runtimePublicView) &&
            decide
              (pathOramPublicLocationTrace
                  (pathOramStorageLocationTrace
                    (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
                certificate.runtimePublicLocation) &&
            decide
              (pathOramStorageShape (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
                certificate.runtimeStorageShape) &&
            decide (witness.toRuntimeWitness.publicOutcome = certificate.runtimePublicOutcome) &&
            decide
              (witness.toRuntimeWitness.boundarySchedule =
                certificate.runtimeBoundarySchedule) &&
            decide (witness.toRuntimeWitness.controllerShape = certificate.runtimeControllerShape) &&
            decide
              (witness.toRuntimeWitness.normalizedMicroTrace =
                certificate.runtimeNormalizedMicroTrace)
      | none => false

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.checkProofGrade
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags) : Bool :=
  pathOramConfigWellFormedCheck certificate.runtimeCfg &&
    certificate.proofGradeFamilyMatchesCheck certificate.lhs_family modelTags &&
    certificate.proofGradeFamilyMatchesCheck certificate.rhs_family modelTags

def parseImportedCanonicalFreshCoinRuntimePathOramPairCertificate
  (input : String) : Except String ImportedCanonicalFreshCoinRuntimePathOramPairCertificate := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedCanonicalFreshCoinRuntimePathOramPairCertificate
  (input : String)
  (modelTags : SGXModelTags) :
  Except String ImportedCanonicalFreshCoinRuntimePathOramPairCertificate := do
  let certificate ← parseImportedCanonicalFreshCoinRuntimePathOramPairCertificate input
  if certificate.checkValid modelTags then
    pure certificate
  else
    throw
      "imported canonical fresh-coin path-ORAM pair certificate does not satisfy Lean validity checks"

def loadAndCheckImportedCanonicalFreshCoinRuntimePathOramPairCertificate
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedCanonicalFreshCoinRuntimePathOramPairCertificate := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedCanonicalFreshCoinRuntimePathOramPairCertificate input modelTags with
  | .ok certificate => pure certificate
  | .error err =>
      throw <| IO.userError
        s!"failed to validate canonical fresh-coin path-ORAM pair certificate: {err}"

def parseAndCheckImportedProofGradeCanonicalFreshCoinRuntimePathOramPairCertificate
  (input : String)
  (modelTags : SGXModelTags) :
  Except String ImportedCanonicalFreshCoinRuntimePathOramPairCertificate := do
  let certificate ← parseImportedCanonicalFreshCoinRuntimePathOramPairCertificate input
  if certificate.checkProofGrade modelTags then
    pure certificate
  else
    throw
      "imported proof-grade canonical fresh-coin path-ORAM pair certificate does not satisfy Lean validity checks"

def loadAndCheckImportedProofGradeCanonicalFreshCoinRuntimePathOramPairCertificate
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedCanonicalFreshCoinRuntimePathOramPairCertificate := do
  let input ← IO.FS.readFile path
  match
      parseAndCheckImportedProofGradeCanonicalFreshCoinRuntimePathOramPairCertificate
        input
        modelTags with
  | .ok certificate => pure certificate
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade canonical fresh-coin path-ORAM pair certificate: {err}"

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramPairCertificate_familyMatchesCheck_eq_true_iff
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) :
  certificate.familyMatchesCheck family modelTags = true ↔
    certificate.familyMatches family modelTags := by
  constructor
  · intro hCheck
    rw [ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.familyMatchesCheck,
      Bool.and_eq_true] at hCheck
    refine ⟨?_, ?_⟩
    · exact
        (importedCanonicalFreshCoinRuntimePathOramWitnessFamily_checkValid_eq_true_iff
          family modelTags).mp hCheck.1
    · intro seed hSeed
      have hSeedCheck :
          (match family.witnessAt? seed with
            | some witness =>
                runtimeWitnessObjectsMatchPublicConfigCheck
                    witness.toRuntimeWitness
                    certificate.runtimeCfg &&
                  decide
                    (pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
                      certificate.runtimePublicView) &&
                  decide
                    (pathOramPublicLocationTrace
                        (pathOramStorageLocationTrace
                          (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
                      certificate.runtimePublicLocation) &&
                  decide
                    (pathOramStorageShape
                        (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
                      certificate.runtimeStorageShape) &&
                  decide
                    (witness.toRuntimeWitness.publicOutcome =
                      certificate.runtimePublicOutcome) &&
                  decide
                    (witness.toRuntimeWitness.boundarySchedule =
                      certificate.runtimeBoundarySchedule) &&
                  decide
                    (witness.toRuntimeWitness.controllerShape =
                      certificate.runtimeControllerShape) &&
                  decide
                    (witness.toRuntimeWitness.normalizedMicroTrace =
                      certificate.runtimeNormalizedMicroTrace)
            | none => false) = true := by
        exact (List.all_eq_true.mp hCheck.2) seed (List.mem_range.mpr hSeed)
      cases hGet : family.witnessAt? seed with
      | none =>
          simp [hGet] at hSeedCheck
      | some witness =>
          have hWitness :
              runtimeWitnessObjectsMatchPublicConfigCheck
                  witness.toRuntimeWitness
                  certificate.runtimeCfg = true ∧
                pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
                  certificate.runtimePublicView ∧
                pathOramPublicLocationTrace
                    (pathOramStorageLocationTrace
                      (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
                  certificate.runtimePublicLocation ∧
                pathOramStorageShape (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
                  certificate.runtimeStorageShape ∧
                witness.toRuntimeWitness.publicOutcome = certificate.runtimePublicOutcome ∧
                witness.toRuntimeWitness.boundarySchedule =
                  certificate.runtimeBoundarySchedule ∧
                witness.toRuntimeWitness.controllerShape =
                  certificate.runtimeControllerShape ∧
                witness.toRuntimeWitness.normalizedMicroTrace =
                  certificate.runtimeNormalizedMicroTrace := by
            simpa [hGet, Bool.and_eq_true, and_assoc] using hSeedCheck
          rcases hWitness with
            ⟨hMatchCheck, hView, hLocation, hShape, hOutcome, hBoundary, hController, hMicro⟩
          exact
            ⟨witness, rfl,
              (runtimeWitnessObjectsMatchPublicConfigCheck_eq_true_iff
                witness.toRuntimeWitness certificate.runtimeCfg).mp hMatchCheck,
              hView, hLocation, hShape, hOutcome, hBoundary, hController, hMicro⟩
  · intro hValid
    rw [ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.familyMatchesCheck, Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · exact
        (importedCanonicalFreshCoinRuntimePathOramWitnessFamily_checkValid_eq_true_iff
          family modelTags).2 hValid.1
    · refine List.all_eq_true.mpr ?_
      intro seed hSeedMem
      have hSeed : seed < family.seed_count := List.mem_range.mp hSeedMem
      rcases hValid.2 seed hSeed with
        ⟨witness, hGet, hMatch, hView, hLocation, hShape, hOutcome, hBoundary, hController, hMicro⟩
      have hViewNormalized :
          pathOramNormalizePublicPart
              (oramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace)) =
            certificate.runtimePublicView := by
        simpa [pathOramViewPublicPart] using hView
      have hMatchCheck :
          runtimeWitnessObjectsMatchPublicConfigCheck
              witness.toRuntimeWitness
              certificate.runtimeCfg = true :=
        (runtimeWitnessObjectsMatchPublicConfigCheck_eq_true_iff
          witness.toRuntimeWitness certificate.runtimeCfg).2 hMatch
      simp [hGet, hMatchCheck, hViewNormalized, hLocation, hShape, hOutcome, hBoundary,
        hController, hMicro]

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramPairCertificate_checkValid_eq_true_iff
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags) :
  certificate.checkValid modelTags = true ↔ certificate.Valid modelTags := by
  constructor
  · intro hCheck
    rw [ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.checkValid, Bool.and_eq_true] at hCheck
    have hHead := hCheck.1
    rw [Bool.and_eq_true] at hHead
    refine ⟨?_, ?_, ?_⟩
    · exact (pathOramConfigWellFormedCheck_eq_true_iff certificate.runtimeCfg).mp hHead.1
    · exact
        (importedCanonicalFreshCoinRuntimePathOramPairCertificate_familyMatchesCheck_eq_true_iff
          certificate certificate.lhs_family modelTags).mp hHead.2
    · exact
        (importedCanonicalFreshCoinRuntimePathOramPairCertificate_familyMatchesCheck_eq_true_iff
          certificate certificate.rhs_family modelTags).mp hCheck.2
  · intro hValid
    rw [ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.checkValid, Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · rw [Bool.and_eq_true]
      refine ⟨?_, ?_⟩
      · exact (pathOramConfigWellFormedCheck_eq_true_iff certificate.runtimeCfg).2 hValid.1
      · exact
          (importedCanonicalFreshCoinRuntimePathOramPairCertificate_familyMatchesCheck_eq_true_iff
            certificate certificate.lhs_family modelTags).2 hValid.2.1
    · exact
        (importedCanonicalFreshCoinRuntimePathOramPairCertificate_familyMatchesCheck_eq_true_iff
          certificate certificate.rhs_family modelTags).2 hValid.2.2

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.ProofGradeFamilyMatches
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Prop :=
  family.ProofGradeValid modelTags ∧
    ∀ seed, seed < family.seed_count →
      ∃ witness,
        family.witnessAt? seed = some witness ∧
        witness.toRuntimeWitness.ObjectsMatchPublicConfig certificate.runtimeCfg ∧
        pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
          certificate.runtimePublicView ∧
        pathOramPublicLocationTrace
            (pathOramStorageLocationTrace
              (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
          certificate.runtimePublicLocation ∧
        pathOramStorageShape (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
          certificate.runtimeStorageShape ∧
        witness.toRuntimeWitness.publicOutcome = certificate.runtimePublicOutcome ∧
        witness.toRuntimeWitness.boundarySchedule = certificate.runtimeBoundarySchedule ∧
        witness.toRuntimeWitness.controllerShape = certificate.runtimeControllerShape ∧
        witness.toRuntimeWitness.normalizedMicroTrace = certificate.runtimeNormalizedMicroTrace

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.ProofGradeValid
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags) : Prop :=
  PathOramConfigWellFormed certificate.runtimeCfg ∧
    certificate.ProofGradeFamilyMatches certificate.lhs_family modelTags ∧
    certificate.ProofGradeFamilyMatches certificate.rhs_family modelTags

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramPairCertificate_proofGradeFamilyMatchesCheck_eq_true_iff
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) :
  certificate.proofGradeFamilyMatchesCheck family modelTags = true ↔
    certificate.ProofGradeFamilyMatches family modelTags := by
  constructor
  · intro hCheck
    rw [ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.proofGradeFamilyMatchesCheck,
      Bool.and_eq_true] at hCheck
    refine ⟨?_, ?_⟩
    · exact
        (importedCanonicalFreshCoinRuntimePathOramWitnessFamily_checkProofGrade_eq_true_iff
          family modelTags).mp hCheck.1
    · intro seed hSeed
      have hSeedCheck :
          (match family.witnessAt? seed with
            | some witness =>
                runtimeWitnessObjectsMatchPublicConfigCheck
                    witness.toRuntimeWitness
                    certificate.runtimeCfg &&
                  decide
                    (pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
                      certificate.runtimePublicView) &&
                  decide
                    (pathOramPublicLocationTrace
                        (pathOramStorageLocationTrace
                          (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
                      certificate.runtimePublicLocation) &&
                  decide
                    (pathOramStorageShape
                        (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
                      certificate.runtimeStorageShape) &&
                  decide
                    (witness.toRuntimeWitness.publicOutcome =
                      certificate.runtimePublicOutcome) &&
                  decide
                    (witness.toRuntimeWitness.boundarySchedule =
                      certificate.runtimeBoundarySchedule) &&
                  decide
                    (witness.toRuntimeWitness.controllerShape =
                      certificate.runtimeControllerShape) &&
                  decide
                    (witness.toRuntimeWitness.normalizedMicroTrace =
                      certificate.runtimeNormalizedMicroTrace)
            | none => false) = true := by
        exact (List.all_eq_true.mp hCheck.2) seed (List.mem_range.mpr hSeed)
      cases hGet : family.witnessAt? seed with
      | none =>
          simp [hGet] at hSeedCheck
      | some witness =>
          have hWitness :
              runtimeWitnessObjectsMatchPublicConfigCheck
                  witness.toRuntimeWitness
                  certificate.runtimeCfg = true ∧
                pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
                  certificate.runtimePublicView ∧
                pathOramPublicLocationTrace
                    (pathOramStorageLocationTrace
                      (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
                  certificate.runtimePublicLocation ∧
                pathOramStorageShape (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
                  certificate.runtimeStorageShape ∧
                witness.toRuntimeWitness.publicOutcome = certificate.runtimePublicOutcome ∧
                witness.toRuntimeWitness.boundarySchedule =
                  certificate.runtimeBoundarySchedule ∧
                witness.toRuntimeWitness.controllerShape =
                  certificate.runtimeControllerShape ∧
                witness.toRuntimeWitness.normalizedMicroTrace =
                  certificate.runtimeNormalizedMicroTrace := by
            simpa [hGet, Bool.and_eq_true, and_assoc] using hSeedCheck
          rcases hWitness with
            ⟨hMatchCheck, hView, hLocation, hShape, hOutcome, hBoundary, hController, hMicro⟩
          exact
            ⟨witness, rfl,
              (runtimeWitnessObjectsMatchPublicConfigCheck_eq_true_iff
                witness.toRuntimeWitness certificate.runtimeCfg).mp hMatchCheck,
              hView, hLocation, hShape, hOutcome, hBoundary, hController, hMicro⟩
  · intro hValid
    rw [ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.proofGradeFamilyMatchesCheck,
      Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · exact
        (importedCanonicalFreshCoinRuntimePathOramWitnessFamily_checkProofGrade_eq_true_iff
          family modelTags).2 hValid.1
    · refine List.all_eq_true.mpr ?_
      intro seed hSeedMem
      have hSeed : seed < family.seed_count := List.mem_range.mp hSeedMem
      rcases hValid.2 seed hSeed with
        ⟨witness, hGet, hMatch, hView, hLocation, hShape, hOutcome, hBoundary, hController, hMicro⟩
      have hViewNormalized :
          pathOramNormalizePublicPart
              (oramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace)) =
            certificate.runtimePublicView := by
        simpa [pathOramViewPublicPart] using hView
      have hMatchCheck :
          runtimeWitnessObjectsMatchPublicConfigCheck
              witness.toRuntimeWitness
              certificate.runtimeCfg = true :=
        (runtimeWitnessObjectsMatchPublicConfigCheck_eq_true_iff
          witness.toRuntimeWitness certificate.runtimeCfg).2 hMatch
      simp [hGet, hMatchCheck, hViewNormalized, hLocation, hShape, hOutcome, hBoundary,
        hController, hMicro]

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramPairCertificate_checkProofGrade_eq_true_iff
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags) :
  certificate.checkProofGrade modelTags = true ↔ certificate.ProofGradeValid modelTags := by
  constructor
  · intro hCheck
    rw [ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.checkProofGrade, Bool.and_eq_true]
      at hCheck
    have hHead := hCheck.1
    rw [Bool.and_eq_true] at hHead
    refine ⟨?_, ?_, ?_⟩
    · exact (pathOramConfigWellFormedCheck_eq_true_iff certificate.runtimeCfg).mp hHead.1
    · exact
        (importedCanonicalFreshCoinRuntimePathOramPairCertificate_proofGradeFamilyMatchesCheck_eq_true_iff
          certificate certificate.lhs_family modelTags).mp hHead.2
    · exact
        (importedCanonicalFreshCoinRuntimePathOramPairCertificate_proofGradeFamilyMatchesCheck_eq_true_iff
          certificate certificate.rhs_family modelTags).mp hCheck.2
  · intro hValid
    rw [ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.checkProofGrade, Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · rw [Bool.and_eq_true]
      refine ⟨?_, ?_⟩
      · exact (pathOramConfigWellFormedCheck_eq_true_iff certificate.runtimeCfg).2 hValid.1
      · exact
          (importedCanonicalFreshCoinRuntimePathOramPairCertificate_proofGradeFamilyMatchesCheck_eq_true_iff
            certificate certificate.lhs_family modelTags).2 hValid.2.1
    · exact
        (importedCanonicalFreshCoinRuntimePathOramPairCertificate_proofGradeFamilyMatchesCheck_eq_true_iff
          certificate certificate.rhs_family modelTags).2 hValid.2.2

theorem importedCanonicalFreshCoinRuntimePathOramPairCertificate_proofGradeValid_implies_valid
  {certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate}
  {modelTags : SGXModelTags}
  (hValid : certificate.ProofGradeValid modelTags) :
  certificate.Valid modelTags := by
  refine ⟨hValid.1, ?_, ?_⟩
  · exact
      ⟨ importedCanonicalFreshCoinRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
          hValid.2.1.1
      , hValid.2.1.2
      ⟩
  · exact
      ⟨ importedCanonicalFreshCoinRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
          hValid.2.2.1
      , hValid.2.2.2
      ⟩

theorem importedCanonicalFreshCoinRuntimePathOramPairCertificate_familyMatches_witnessValid
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags)
  (hMatch : certificate.familyMatches family modelTags)
  {seed : Nat}
  (hSeed : seed < family.seed_count)
  {witness : ImportedRuntimeRefinementWitness}
  (hGet : family.witnessAt? seed = some witness) :
  witness.Valid modelTags := by
  rcases hMatch.1.2.2 seed hSeed with
    ⟨witness', hGet', hValid, _hLeafScaffold, _hFreshScaffold, _hFreshValues⟩
  rw [hGet] at hGet'
  cases hGet'
  exact hValid

theorem importedCanonicalFreshCoinRuntimePathOramPairCertificate_familyMatches_projects_to_certificate_observer
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags)
  (hMatch : certificate.familyMatches family modelTags)
  {seed : Nat}
  (hSeed : seed < family.seed_count) :
  ∃ witness,
    family.witnessAt? seed = some witness ∧
      sgxPublicOutcome witness.toRuntimeWitness.sgxView = certificate.runtimePublicOutcome ∧
      witness.toRuntimeWitness.sgxView.boundarySchedule =
        certificate.runtimeBoundarySchedule ∧
      normalizeMicroTrace (sgxMicroTrace witness.toRuntimeWitness.sgxView) =
        certificate.runtimeNormalizedMicroTrace ∧
      witness.toRuntimeWitness.controllerShape = certificate.runtimeControllerShape ∧
      pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
        certificate.runtimePublicView ∧
      pathOramPublicLocationTrace
          (pathOramStorageLocationTrace
            (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
        certificate.runtimePublicLocation ∧
      pathOramStorageShape (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
        certificate.runtimeStorageShape := by
  rcases hMatch.2 seed hSeed with
    ⟨witness, hGet, _hCfgMatch, hView, hLocation, hShape, hOutcome, hBoundary, hController, hMicro⟩
  have hWitnessValid :
      witness.Valid modelTags :=
    importedCanonicalFreshCoinRuntimePathOramPairCertificate_familyMatches_witnessValid
      certificate family modelTags hMatch hSeed hGet
  have hObserver :=
    importedWitness_projects_to_paper_observer witness modelTags hWitnessValid
  rcases hObserver with ⟨hPublicOutcome, hBoundaryView, _hStorageView, hNormalizedMicro⟩
  exact
    ⟨witness, hGet,
      hPublicOutcome.trans hOutcome,
      hBoundaryView.trans hBoundary,
      hNormalizedMicro.trans hMicro,
      hController,
      hView,
      hLocation,
      hShape⟩

def ImportedCanonicalFreshCoinRuntimePathOramPairCertificate.WitnessProjectsToCertificateObserver
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (witness : ImportedRuntimeRefinementWitness) : Prop :=
  sgxPublicOutcome witness.toRuntimeWitness.sgxView = certificate.runtimePublicOutcome ∧
    witness.toRuntimeWitness.sgxView.boundarySchedule =
      certificate.runtimeBoundarySchedule ∧
    normalizeMicroTrace (sgxMicroTrace witness.toRuntimeWitness.sgxView) =
      certificate.runtimeNormalizedMicroTrace ∧
    witness.toRuntimeWitness.controllerShape = certificate.runtimeControllerShape ∧
    pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
      certificate.runtimePublicView ∧
    pathOramPublicLocationTrace
        (pathOramStorageLocationTrace
          (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
      certificate.runtimePublicLocation ∧
    pathOramStorageShape (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
      certificate.runtimeStorageShape

theorem importedCanonicalFreshCoinRuntimePathOramPairCertificate_valid_projects_lhs_rhs_to_common_observer
  (certificate : ImportedCanonicalFreshCoinRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags)
  (hValid : certificate.Valid modelTags)
  {lhsSeed rhsSeed : Nat}
  (hLhsSeed : lhsSeed < certificate.lhs_family.seed_count)
  (hRhsSeed : rhsSeed < certificate.rhs_family.seed_count) :
  ∃ lhsWitness rhsWitness,
    certificate.lhs_family.witnessAt? lhsSeed = some lhsWitness ∧
      certificate.rhs_family.witnessAt? rhsSeed = some rhsWitness ∧
      certificate.WitnessProjectsToCertificateObserver lhsWitness ∧
      certificate.WitnessProjectsToCertificateObserver rhsWitness := by
  rcases
      importedCanonicalFreshCoinRuntimePathOramPairCertificate_familyMatches_projects_to_certificate_observer
        certificate certificate.lhs_family modelTags hValid.2.1 hLhsSeed
    with ⟨lhsWitness, hLhsGet, hLhsOutcome, hLhsBoundary, hLhsMicro, hLhsController, hLhsView,
      hLhsLocation, hLhsShape⟩
  rcases
      importedCanonicalFreshCoinRuntimePathOramPairCertificate_familyMatches_projects_to_certificate_observer
        certificate certificate.rhs_family modelTags hValid.2.2 hRhsSeed
    with ⟨rhsWitness, hRhsGet, hRhsOutcome, hRhsBoundary, hRhsMicro, hRhsController, hRhsView,
      hRhsLocation, hRhsShape⟩
  exact
    ⟨lhsWitness, rhsWitness, hLhsGet, hRhsGet,
      ⟨hLhsOutcome, hLhsBoundary, hLhsMicro, hLhsController, hLhsView, hLhsLocation, hLhsShape⟩,
      ⟨hRhsOutcome, hRhsBoundary, hRhsMicro, hRhsController, hRhsView, hRhsLocation, hRhsShape⟩⟩

structure ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput where
  cfg : ImportedOramConfig
  lhs_input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput
  rhs_input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput
  public_view : ImportedOramViewPublicPart
  public_location : ImportedPathOramStorageLocationTrace
  storage_shape : ImportedPathOramStorageShape
  public_outcome : ImportedPublicOutcomeTrace
  boundary_schedule : List ImportedBoundaryEvent
  controller_shape : ImportedSgxControllerShapeTrace
  normalized_micro_trace : ImportedNormalizedMicroTrace
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.runtimeCfg
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput) : OramConfig :=
  input.cfg.toOramConfig

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.runtimePublicView
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput) : OramViewPublicPart :=
  input.public_view.toOramViewPublicPart

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.runtimePublicLocation
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput) :
  PathOramStorageLocationTrace :=
  input.public_location.toPathOramStorageLocationTrace

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.runtimeStorageShape
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput) :
  PathOramStorageShape :=
  input.storage_shape.toPathOramStorageShape

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.runtimePublicOutcome
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput) : SGXPublicOutcome :=
  input.public_outcome.toPublicOutcome

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.runtimeBoundarySchedule
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput) : List BoundaryEvent :=
  input.boundary_schedule.map ImportedBoundaryEvent.toBoundaryEvent

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.runtimeControllerShape
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput) : SGXControllerShape :=
  input.controller_shape.toControllerShape

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.runtimeNormalizedMicroTrace
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput) : NormalizedMicroTrace :=
  input.normalized_micro_trace.toNormalizedMicroTrace

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.inputMatches
  (pairInput : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput)
  (modelTags : SGXModelTags) : Prop :=
  input.Valid modelTags ∧
    input.runtimeRepresentativeWitness.ObjectsMatchPublicConfig pairInput.runtimeCfg ∧
    pathOramViewPublicPart (viewMPlus input.runtimeRepresentativeWitness.trace) =
      pairInput.runtimePublicView ∧
    pathOramPublicLocationTrace
        (pathOramStorageLocationTrace
          (oramStorageView (viewMPlus input.runtimeRepresentativeWitness.trace))) =
      pairInput.runtimePublicLocation ∧
    pathOramStorageShape (oramStorageView (viewMPlus input.runtimeRepresentativeWitness.trace)) =
      pairInput.runtimeStorageShape ∧
    input.runtimeRepresentativeWitness.publicOutcome = pairInput.runtimePublicOutcome ∧
    input.runtimeRepresentativeWitness.boundarySchedule = pairInput.runtimeBoundarySchedule ∧
    input.runtimeRepresentativeWitness.controllerShape = pairInput.runtimeControllerShape ∧
    input.runtimeRepresentativeWitness.normalizedMicroTrace =
      pairInput.runtimeNormalizedMicroTrace

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.proofGradeInputMatches
  (pairInput : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput)
  (modelTags : SGXModelTags) : Prop :=
  input.ProofGradeValid modelTags ∧
    input.runtimeRepresentativeWitness.ObjectsMatchPublicConfig pairInput.runtimeCfg ∧
    pathOramViewPublicPart (viewMPlus input.runtimeRepresentativeWitness.trace) =
      pairInput.runtimePublicView ∧
    pathOramPublicLocationTrace
        (pathOramStorageLocationTrace
          (oramStorageView (viewMPlus input.runtimeRepresentativeWitness.trace))) =
      pairInput.runtimePublicLocation ∧
    pathOramStorageShape (oramStorageView (viewMPlus input.runtimeRepresentativeWitness.trace)) =
      pairInput.runtimeStorageShape ∧
    input.runtimeRepresentativeWitness.publicOutcome = pairInput.runtimePublicOutcome ∧
    input.runtimeRepresentativeWitness.boundarySchedule = pairInput.runtimeBoundarySchedule ∧
    input.runtimeRepresentativeWitness.controllerShape = pairInput.runtimeControllerShape ∧
    input.runtimeRepresentativeWitness.normalizedMicroTrace =
      pairInput.runtimeNormalizedMicroTrace

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.Valid
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (modelTags : SGXModelTags) : Prop :=
  PathOramConfigWellFormed input.runtimeCfg ∧
    input.inputMatches input.lhs_input modelTags ∧
    input.inputMatches input.rhs_input modelTags

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.ProofGradeValid
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (modelTags : SGXModelTags) : Prop :=
  PathOramConfigWellFormed input.runtimeCfg ∧
    input.proofGradeInputMatches input.lhs_input modelTags ∧
    input.proofGradeInputMatches input.rhs_input modelTags

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.inputMatchesCheck
  (pairInput : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput)
  (modelTags : SGXModelTags) : Bool :=
  input.checkValid modelTags &&
    runtimeWitnessObjectsMatchPublicConfigCheck input.runtimeRepresentativeWitness pairInput.runtimeCfg &&
    decide
      (pathOramViewPublicPart (viewMPlus input.runtimeRepresentativeWitness.trace) =
        pairInput.runtimePublicView) &&
    decide
      (pathOramPublicLocationTrace
          (pathOramStorageLocationTrace
            (oramStorageView (viewMPlus input.runtimeRepresentativeWitness.trace))) =
        pairInput.runtimePublicLocation) &&
    decide
      (pathOramStorageShape (oramStorageView (viewMPlus input.runtimeRepresentativeWitness.trace)) =
        pairInput.runtimeStorageShape) &&
    decide (input.runtimeRepresentativeWitness.publicOutcome = pairInput.runtimePublicOutcome) &&
    decide
      (input.runtimeRepresentativeWitness.boundarySchedule = pairInput.runtimeBoundarySchedule) &&
    decide (input.runtimeRepresentativeWitness.controllerShape = pairInput.runtimeControllerShape) &&
    decide
      (input.runtimeRepresentativeWitness.normalizedMicroTrace =
        pairInput.runtimeNormalizedMicroTrace)

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.proofGradeInputMatchesCheck
  (pairInput : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput)
  (modelTags : SGXModelTags) : Bool :=
  input.checkProofGrade modelTags &&
    runtimeWitnessObjectsMatchPublicConfigCheck input.runtimeRepresentativeWitness pairInput.runtimeCfg &&
    decide
      (pathOramViewPublicPart (viewMPlus input.runtimeRepresentativeWitness.trace) =
        pairInput.runtimePublicView) &&
    decide
      (pathOramPublicLocationTrace
          (pathOramStorageLocationTrace
            (oramStorageView (viewMPlus input.runtimeRepresentativeWitness.trace))) =
        pairInput.runtimePublicLocation) &&
    decide
      (pathOramStorageShape (oramStorageView (viewMPlus input.runtimeRepresentativeWitness.trace)) =
        pairInput.runtimeStorageShape) &&
    decide (input.runtimeRepresentativeWitness.publicOutcome = pairInput.runtimePublicOutcome) &&
    decide
      (input.runtimeRepresentativeWitness.boundarySchedule = pairInput.runtimeBoundarySchedule) &&
    decide (input.runtimeRepresentativeWitness.controllerShape = pairInput.runtimeControllerShape) &&
    decide
      (input.runtimeRepresentativeWitness.normalizedMicroTrace =
        pairInput.runtimeNormalizedMicroTrace)

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.checkValid
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (modelTags : SGXModelTags) : Bool :=
  pathOramConfigWellFormedCheck input.runtimeCfg &&
    input.inputMatchesCheck input.lhs_input modelTags &&
    input.inputMatchesCheck input.rhs_input modelTags

def ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.checkProofGrade
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (modelTags : SGXModelTags) : Bool :=
  pathOramConfigWellFormedCheck input.runtimeCfg &&
    input.proofGradeInputMatchesCheck input.lhs_input modelTags &&
    input.proofGradeInputMatchesCheck input.rhs_input modelTags

def parseImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput
  (input : String) : Except String ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput
  (input : String)
  (modelTags : SGXModelTags) :
  Except String ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput := do
  let theoremInput ← parseImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput input
  if theoremInput.checkValid modelTags then
    pure theoremInput
  else
    throw "imported canonical fresh-coin path-ORAM pair theorem input does not satisfy Lean validity checks"

def loadAndCheckImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput input modelTags with
  | .ok theoremInput => pure theoremInput
  | .error err =>
      throw <| IO.userError
        s!"failed to validate canonical fresh-coin path-ORAM pair theorem input: {err}"

def parseAndCheckImportedProofGradeCanonicalFreshCoinRuntimePathOramPairTheoremInput
  (input : String)
  (modelTags : SGXModelTags) :
  Except String ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput := do
  let theoremInput ← parseImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput input
  if theoremInput.checkProofGrade modelTags then
    pure theoremInput
  else
    throw
      "imported proof-grade canonical fresh-coin path-ORAM pair theorem input does not satisfy Lean validity checks"

def loadAndCheckImportedProofGradeCanonicalFreshCoinRuntimePathOramPairTheoremInput
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeCanonicalFreshCoinRuntimePathOramPairTheoremInput
      input
      modelTags with
  | .ok theoremInput => pure theoremInput
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade canonical fresh-coin path-ORAM pair theorem input: {err}"

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramPairTheoremInput_inputMatchesCheck_eq_true_iff
  (pairInput : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput)
  (modelTags : SGXModelTags) :
  pairInput.inputMatchesCheck input modelTags = true ↔
    pairInput.inputMatches input modelTags := by
  simp
    [ ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.inputMatchesCheck
    , ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.inputMatches
    , importedCanonicalFreshCoinRuntimePathOramTheoremInput_checkValid_eq_true_iff
    , runtimeWitnessObjectsMatchPublicConfigCheck_eq_true_iff
    , Bool.and_eq_true
    , decide_eq_true_eq
    , and_assoc
    ]

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramPairTheoremInput_checkValid_eq_true_iff
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (modelTags : SGXModelTags) :
  input.checkValid modelTags = true ↔ input.Valid modelTags := by
  simp
    [ ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.checkValid
    , ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.Valid
    , importedCanonicalFreshCoinRuntimePathOramPairTheoremInput_inputMatchesCheck_eq_true_iff
    , pathOramConfigWellFormedCheck_eq_true_iff
    , Bool.and_eq_true
    , and_assoc
    ]

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramPairTheoremInput_proofGradeInputMatchesCheck_eq_true_iff
  (pairInput : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput)
  (modelTags : SGXModelTags) :
  pairInput.proofGradeInputMatchesCheck input modelTags = true ↔
    pairInput.proofGradeInputMatches input modelTags := by
  simp
    [ ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.proofGradeInputMatchesCheck
    , ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.proofGradeInputMatches
    , importedCanonicalFreshCoinRuntimePathOramTheoremInput_checkProofGrade_eq_true_iff
    , runtimeWitnessObjectsMatchPublicConfigCheck_eq_true_iff
    , Bool.and_eq_true
    , decide_eq_true_eq
    , and_assoc
    ]

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramPairTheoremInput_checkProofGrade_eq_true_iff
  (input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput)
  (modelTags : SGXModelTags) :
  input.checkProofGrade modelTags = true ↔ input.ProofGradeValid modelTags := by
  simp
    [ ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.checkProofGrade
    , ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput.ProofGradeValid
    , importedCanonicalFreshCoinRuntimePathOramPairTheoremInput_proofGradeInputMatchesCheck_eq_true_iff
    , pathOramConfigWellFormedCheck_eq_true_iff
    , Bool.and_eq_true
    , and_assoc
    ]

theorem importedCanonicalFreshCoinRuntimePathOramPairTheoremInput_proofGradeValid_implies_valid
  {input : ImportedCanonicalFreshCoinRuntimePathOramPairTheoremInput}
  {modelTags : SGXModelTags}
  (hValid : input.ProofGradeValid modelTags) :
  input.Valid modelTags := by
  rcases hValid with ⟨hCfg, hLhs, hRhs⟩
  rcases hLhs with
    ⟨ hLhsProofGrade
    , hLhsObjects
    , hLhsView
    , hLhsLocation
    , hLhsShape
    , hLhsOutcome
    , hLhsBoundary
    , hLhsController
    , hLhsMicro
    ⟩
  rcases hRhs with
    ⟨ hRhsProofGrade
    , hRhsObjects
    , hRhsView
    , hRhsLocation
    , hRhsShape
    , hRhsOutcome
    , hRhsBoundary
    , hRhsController
    , hRhsMicro
    ⟩
  exact
    ⟨ hCfg
    , ⟨ importedCanonicalFreshCoinRuntimePathOramTheoremInput_proofGradeValid_implies_valid
          hLhsProofGrade
      , hLhsObjects
      , hLhsView
      , hLhsLocation
      , hLhsShape
      , hLhsOutcome
      , hLhsBoundary
      , hLhsController
      , hLhsMicro
      ⟩
    , ⟨ importedCanonicalFreshCoinRuntimePathOramTheoremInput_proofGradeValid_implies_valid
          hRhsProofGrade
      , hRhsObjects
      , hRhsView
      , hRhsLocation
      , hRhsShape
      , hRhsOutcome
      , hRhsBoundary
      , hRhsController
      , hRhsMicro
      ⟩
    ⟩

end UOToolchain
