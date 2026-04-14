import Lean.Data.Json
import UOToolchain.RuntimeCoinsJson

open Lean

namespace UOToolchain

structure ImportedManifestWitness where
  public_gas_budget : Nat
  secret_args : List Nat
  oram_accesses : List (Nat × Nat)
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedManifestWitness.toManifestWitness
  (witness : ImportedManifestWitness) : ManifestWitness :=
  { publicGasBudget := witness.public_gas_budget
  , secretArgs := witness.secret_args
  , oramAccesses := witness.oram_accesses
  }

structure ImportedOramEntrypointWitness extends ImportedManifestWitness where
  entrypoint_id : String
  oram_objects : List ImportedRuntimeOramObjectCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedOramEntrypointWitness.toOramEntrypointWitness
  (witness : ImportedOramEntrypointWitness) : OramEntrypointWitness :=
  { witness.toManifestWitness with
    entrypointId := witness.entrypoint_id
  , oramObjects := witness.oram_objects.map fun object =>
      object.toRuntimeOramObjectCertificate.toOramObjectManifest
  }

structure ImportedOramPublicData where
  witness : ImportedOramEntrypointWitness
  public_args : List String
  access_counters : List (Nat × Nat)
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedOramPublicData.toOramPublicData
  (data : ImportedOramPublicData) : OramPublicData :=
  { witness := data.witness.toOramEntrypointWitness
  , publicArgs := data.public_args
  , accessCounters := data.access_counters
  }

structure ImportedOramConfig where
  pub_data : ImportedOramPublicData
  secret_state : List String
  secret_args : List String
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedOramConfig.toOramConfig
  (cfg : ImportedOramConfig) : OramConfig :=
  { pubData := cfg.pub_data.toOramPublicData
  , secretState := cfg.secret_state
  , secretArgs := cfg.secret_args
  }

structure ImportedOramViewPublicPart where
  opcode_trace : List String
  logical_accesses : List ImportedLogicalEvent
  logical_writes : List ImportedLogicalEvent
  gas_used : Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedOramViewPublicPart.toOramViewPublicPart
  (part : ImportedOramViewPublicPart) : OramViewPublicPart :=
  { opcodeTrace := part.opcode_trace
  , logicalAccesses := part.logical_accesses.map ImportedLogicalEvent.toLogicalEvent
  , logicalWrites := part.logical_writes.map ImportedLogicalEvent.toLogicalEvent
  , gasUsed := part.gas_used
  }

structure ImportedPathOramPhysicalEventLabel where
  object : String
  location : String
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedPathOramPhysicalEventLabel.toPathOramPhysicalEventLabel
  (label : ImportedPathOramPhysicalEventLabel) : PathOramPhysicalEventLabel :=
  { object := label.object
  , location := label.location
  }

structure ImportedPathOramStorageLocationTrace where
  read_labels : List ImportedPathOramPhysicalEventLabel
  write_labels : List ImportedPathOramPhysicalEventLabel
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedPathOramStorageLocationTrace.toPathOramStorageLocationTrace
  (trace : ImportedPathOramStorageLocationTrace) : PathOramStorageLocationTrace :=
  { readLabels := trace.read_labels.map ImportedPathOramPhysicalEventLabel.toPathOramPhysicalEventLabel
  , writeLabels := trace.write_labels.map ImportedPathOramPhysicalEventLabel.toPathOramPhysicalEventLabel
  }

structure ImportedPathOramStorageShape where
  read_lengths : List Nat
  write_classes : List String
  write_lengths : List Nat
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedPathOramStorageShape.toPathOramStorageShape
  (shape : ImportedPathOramStorageShape) : PathOramStorageShape :=
  { readLengths := shape.read_lengths
  , writeClasses := shape.write_classes
  , writeLengths := shape.write_lengths
  }

structure ImportedSeededRuntimePathOramPairCertificate where
  cfg : ImportedOramConfig
  lhs_family : ImportedSeededRuntimePathOramWitnessFamily
  rhs_family : ImportedSeededRuntimePathOramWitnessFamily
  public_view : ImportedOramViewPublicPart
  public_location : ImportedPathOramStorageLocationTrace
  storage_shape : ImportedPathOramStorageShape
  public_outcome : ImportedPublicOutcomeTrace
  boundary_schedule : List ImportedBoundaryEvent
  controller_shape : ImportedSgxControllerShapeTrace
  normalized_micro_trace : ImportedNormalizedMicroTrace
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedSeededRuntimePathOramPairCertificate.runtimeCfg
  (certificate : ImportedSeededRuntimePathOramPairCertificate) : OramConfig :=
  certificate.cfg.toOramConfig

def ImportedSeededRuntimePathOramPairCertificate.runtimePublicView
  (certificate : ImportedSeededRuntimePathOramPairCertificate) : OramViewPublicPart :=
  certificate.public_view.toOramViewPublicPart

def ImportedSeededRuntimePathOramPairCertificate.runtimePublicLocation
  (certificate : ImportedSeededRuntimePathOramPairCertificate) : PathOramStorageLocationTrace :=
  certificate.public_location.toPathOramStorageLocationTrace

def ImportedSeededRuntimePathOramPairCertificate.runtimeStorageShape
  (certificate : ImportedSeededRuntimePathOramPairCertificate) : PathOramStorageShape :=
  certificate.storage_shape.toPathOramStorageShape

def ImportedSeededRuntimePathOramPairCertificate.runtimePublicOutcome
  (certificate : ImportedSeededRuntimePathOramPairCertificate) : SGXPublicOutcome :=
  certificate.public_outcome.toPublicOutcome

def ImportedSeededRuntimePathOramPairCertificate.runtimeBoundarySchedule
  (certificate : ImportedSeededRuntimePathOramPairCertificate) : List BoundaryEvent :=
  certificate.boundary_schedule.map ImportedBoundaryEvent.toBoundaryEvent

def ImportedSeededRuntimePathOramPairCertificate.runtimeControllerShape
  (certificate : ImportedSeededRuntimePathOramPairCertificate) : SGXControllerShape :=
  certificate.controller_shape.toControllerShape

def ImportedSeededRuntimePathOramPairCertificate.runtimeNormalizedMicroTrace
  (certificate : ImportedSeededRuntimePathOramPairCertificate) : NormalizedMicroTrace :=
  certificate.normalized_micro_trace.toNormalizedMicroTrace

def runtimeWitnessObjectsMatchPublicConfigCheck
  (witness : RuntimeRefinementWitness)
  (cfg : OramConfig) : Bool :=
  decide
    (cfg.pubData.witness.oramObjects =
      witness.oramObjects.map RuntimeOramObjectCertificate.toOramObjectManifest)

def wellFormedPathOramObjectCheck
  (object : OramObjectManifest) : Bool :=
  decide (object.scheme = pathOramScheme) &&
    decide (object.blocksPerBucket = pathOramBlocksPerBucket) &&
    decide
      (object.bucketSize =
        oramBucketHeaderBytes + object.blocksPerBucket * object.blockSize) &&
    decide (0 < object.bucketCount) &&
    decide (object.stashBound = max object.capacity 1) &&
    decide (object.recursionDepth = 0) &&
    decide (object.metadataPagesPerAccess = object.metadataPages + 1) &&
    decide (object.bucketsPerAccess = object.treeHeight + 1) &&
    decide (object.accessesPerCall = 1)

def pathOramConfigWellFormedCheck
  (cfg : OramConfig) : Bool :=
  cfg.pubData.witness.oramObjects.all wellFormedPathOramObjectCheck

@[simp] theorem runtimeWitnessObjectsMatchPublicConfigCheck_eq_true_iff
  (witness : RuntimeRefinementWitness)
  (cfg : OramConfig) :
  runtimeWitnessObjectsMatchPublicConfigCheck witness cfg = true ↔
    witness.ObjectsMatchPublicConfig cfg := by
  simp [runtimeWitnessObjectsMatchPublicConfigCheck,
    RuntimeRefinementWitness.ObjectsMatchPublicConfig,
    RuntimeOramObjectsMatchPublicConfig]

@[simp] theorem wellFormedPathOramObjectCheck_eq_true_iff
  (object : OramObjectManifest) :
  wellFormedPathOramObjectCheck object = true ↔ WellFormedPathOramObject object := by
  simp [wellFormedPathOramObjectCheck, WellFormedPathOramObject, and_assoc]

@[simp] theorem pathOramConfigWellFormedCheck_eq_true_iff
  (cfg : OramConfig) :
  pathOramConfigWellFormedCheck cfg = true ↔ PathOramConfigWellFormed cfg := by
  simp [pathOramConfigWellFormedCheck, PathOramConfigWellFormed]

def ImportedSeededRuntimePathOramPairCertificate.familyMatches
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Prop :=
  family.Valid modelTags ∧
    ∀ seed, seed < family.seed_count →
      ∃ witness,
        family.toImportedSeededRuntimeWitnessFamily.witnessAt? seed = some witness ∧
        witness.toRuntimeWitness.ObjectsMatchPublicConfig certificate.runtimeCfg ∧
        pathOramViewPublicPart (viewMPlus witness.toRuntimeWitness.trace) =
          certificate.runtimePublicView ∧
        pathOramPublicLocationTrace
            (pathOramStorageLocationTrace (oramStorageView (viewMPlus witness.toRuntimeWitness.trace))) =
          certificate.runtimePublicLocation ∧
        pathOramStorageShape (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
          certificate.runtimeStorageShape ∧
        witness.toRuntimeWitness.publicOutcome = certificate.runtimePublicOutcome ∧
        witness.toRuntimeWitness.boundarySchedule = certificate.runtimeBoundarySchedule ∧
        witness.toRuntimeWitness.controllerShape = certificate.runtimeControllerShape ∧
        witness.toRuntimeWitness.normalizedMicroTrace = certificate.runtimeNormalizedMicroTrace

def ImportedSeededRuntimePathOramPairCertificate.Valid
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags) : Prop :=
  PathOramConfigWellFormed certificate.runtimeCfg ∧
    certificate.familyMatches certificate.lhs_family modelTags ∧
    certificate.familyMatches certificate.rhs_family modelTags

def ImportedSeededRuntimePathOramPairCertificate.familyMatchesCheck
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Bool :=
  family.checkValid modelTags &&
    (List.range family.seed_count).all fun seed =>
      match family.toImportedSeededRuntimeWitnessFamily.witnessAt? seed with
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
            decide (witness.toRuntimeWitness.publicOutcome = certificate.runtimePublicOutcome) &&
            decide
              (witness.toRuntimeWitness.boundarySchedule =
                certificate.runtimeBoundarySchedule) &&
            decide (witness.toRuntimeWitness.controllerShape = certificate.runtimeControllerShape) &&
            decide
              (witness.toRuntimeWitness.normalizedMicroTrace =
                certificate.runtimeNormalizedMicroTrace)
      | none => false

def ImportedSeededRuntimePathOramPairCertificate.checkValid
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags) : Bool :=
  pathOramConfigWellFormedCheck certificate.runtimeCfg &&
    certificate.familyMatchesCheck certificate.lhs_family modelTags &&
    certificate.familyMatchesCheck certificate.rhs_family modelTags

def parseImportedSeededRuntimePathOramPairCertificate
  (input : String) : Except String ImportedSeededRuntimePathOramPairCertificate := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedSeededRuntimePathOramPairCertificate
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedSeededRuntimePathOramPairCertificate := do
  let certificate ← parseImportedSeededRuntimePathOramPairCertificate input
  if certificate.checkValid modelTags then
    pure certificate
  else
    throw "imported seeded path-ORAM pair certificate does not satisfy Lean validity checks"

def loadAndCheckImportedSeededRuntimePathOramPairCertificate
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedSeededRuntimePathOramPairCertificate := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedSeededRuntimePathOramPairCertificate input modelTags with
  | .ok certificate => pure certificate
  | .error err =>
      throw <| IO.userError
        s!"failed to validate seeded path-ORAM pair certificate: {err}"

@[simp] theorem importedSeededRuntimePathOramPairCertificate_familyMatchesCheck_eq_true_iff
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) :
  certificate.familyMatchesCheck family modelTags = true ↔
    certificate.familyMatches family modelTags := by
  constructor
  · intro hCheck
    rw [ImportedSeededRuntimePathOramPairCertificate.familyMatchesCheck, Bool.and_eq_true] at hCheck
    refine ⟨?_, ?_⟩
    · exact
        (importedSeededRuntimePathOramWitnessFamily_checkValid_eq_true_iff
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
            decide (witness.toRuntimeWitness.publicOutcome = certificate.runtimePublicOutcome) &&
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
                pathOramStorageShape
                    (oramStorageView (viewMPlus witness.toRuntimeWitness.trace)) =
                  certificate.runtimeStorageShape ∧
                witness.toRuntimeWitness.publicOutcome = certificate.runtimePublicOutcome ∧
                witness.toRuntimeWitness.boundarySchedule = certificate.runtimeBoundarySchedule ∧
                witness.toRuntimeWitness.controllerShape = certificate.runtimeControllerShape ∧
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
    rw [ImportedSeededRuntimePathOramPairCertificate.familyMatchesCheck, Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · exact
        (importedSeededRuntimePathOramWitnessFamily_checkValid_eq_true_iff
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

@[simp] theorem importedSeededRuntimePathOramPairCertificate_checkValid_eq_true_iff
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
  (modelTags : SGXModelTags) :
  certificate.checkValid modelTags = true ↔ certificate.Valid modelTags := by
  constructor
  · intro hCheck
    rw [ImportedSeededRuntimePathOramPairCertificate.checkValid, Bool.and_eq_true] at hCheck
    have hHead := hCheck.1
    rw [Bool.and_eq_true] at hHead
    refine ⟨?_, ?_, ?_⟩
    · exact (pathOramConfigWellFormedCheck_eq_true_iff certificate.runtimeCfg).mp hHead.1
    · exact
        (importedSeededRuntimePathOramPairCertificate_familyMatchesCheck_eq_true_iff
          certificate certificate.lhs_family modelTags).mp hHead.2
    · exact
        (importedSeededRuntimePathOramPairCertificate_familyMatchesCheck_eq_true_iff
          certificate certificate.rhs_family modelTags).mp hCheck.2
  · intro hValid
    rw [ImportedSeededRuntimePathOramPairCertificate.checkValid, Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · rw [Bool.and_eq_true]
      refine ⟨?_, ?_⟩
      · exact (pathOramConfigWellFormedCheck_eq_true_iff certificate.runtimeCfg).2 hValid.1
      · exact
          (importedSeededRuntimePathOramPairCertificate_familyMatchesCheck_eq_true_iff
            certificate certificate.lhs_family modelTags).2 hValid.2.1
    · exact
        (importedSeededRuntimePathOramPairCertificate_familyMatchesCheck_eq_true_iff
          certificate certificate.rhs_family modelTags).2 hValid.2.2

theorem importedSeededRuntimePathOramPairCertificate_familyMatches_witnessValid
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags)
  (hMatch : certificate.familyMatches family modelTags)
  {seed : Nat}
  (hSeed : seed < family.seed_count)
  {witness : ImportedRuntimeRefinementWitness}
  (hGet : family.witnessAt? seed = some witness) :
  witness.Valid modelTags := by
  rcases hMatch.1.1.2 seed hSeed with ⟨witness', hGet', _hTag, hValid⟩
  rw [hGet] at hGet'
  cases hGet'
  exact hValid

theorem importedSeededRuntimePathOramPairCertificate_familyMatches_projects_to_certificate_observer
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
  (family : ImportedSeededRuntimePathOramWitnessFamily)
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
    importedSeededRuntimePathOramPairCertificate_familyMatches_witnessValid
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

def ImportedSeededRuntimePathOramPairCertificate.WitnessProjectsToCertificateObserver
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
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

theorem importedSeededRuntimePathOramPairCertificate_familyMatches_projects_to_certificate_observer'
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags)
  (hMatch : certificate.familyMatches family modelTags)
  {seed : Nat}
  (hSeed : seed < family.seed_count) :
  ∃ witness,
    family.witnessAt? seed = some witness ∧
      certificate.WitnessProjectsToCertificateObserver witness := by
  rcases
      importedSeededRuntimePathOramPairCertificate_familyMatches_projects_to_certificate_observer
        certificate family modelTags hMatch hSeed
    with ⟨witness, hGet, hOutcome, hBoundary, hMicro, hController, hView, hLocation, hShape⟩
  exact
    ⟨witness, hGet,
      ⟨hOutcome, hBoundary, hMicro, hController, hView, hLocation, hShape⟩⟩

theorem importedSeededRuntimePathOramPairCertificate_valid_projects_lhs_rhs_to_common_observer
  (certificate : ImportedSeededRuntimePathOramPairCertificate)
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
      importedSeededRuntimePathOramPairCertificate_familyMatches_projects_to_certificate_observer'
        certificate certificate.lhs_family modelTags hValid.2.1 hLhsSeed
    with ⟨lhsWitness, hLhsGet, hLhsObserver⟩
  rcases
      importedSeededRuntimePathOramPairCertificate_familyMatches_projects_to_certificate_observer'
        certificate certificate.rhs_family modelTags hValid.2.2 hRhsSeed
    with ⟨rhsWitness, hRhsGet, hRhsObserver⟩
  exact ⟨lhsWitness, rhsWitness, hLhsGet, hRhsGet, hLhsObserver, hRhsObserver⟩

end UOToolchain
