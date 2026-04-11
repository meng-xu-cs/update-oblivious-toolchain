import UOToolchain.Composition

namespace UOToolchain

structure OutputShape where
  returnPresent : Bool
  returnLength : Nat
deriving Repr, DecidableEq

structure TEEView where
  entrypointId : String
  publicArgs : List String
  terminationStatus : Bool
  outputShape : OutputShape
  physicalReads : List PhysicalRead
  physicalWrites : List PhysicalWrite
  gasUsed : Nat
deriving Repr, DecidableEq

structure DeploymentResult where
  trace : Trace
  terminationStatus : Bool
  outputShape : OutputShape
deriving Repr, DecidableEq

abbrev DeploymentSemantics := Config → DeploymentResult

def withPublicBoundary
  (run : Semantics)
  (termination : Config → Bool)
  (outputShape : Config → OutputShape) : DeploymentSemantics :=
  fun cfg =>
    { trace := run cfg
    , terminationStatus := termination cfg
    , outputShape := outputShape cfg
    }

def viewTEEStore (cfg : Config) (result : DeploymentResult) : TEEView :=
  { entrypointId := cfg.program.entrypoint
  , publicArgs := cfg.input.publicArgs
  , terminationStatus := result.terminationStatus
  , outputShape := result.outputShape
  , physicalReads := result.trace.physicalReads
  , physicalWrites := result.trace.physicalWrites
  , gasUsed := result.trace.gasUsed
  }

def PublicTerminationSafe (termination : Config → Bool) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → termination cfg₁ = termination cfg₂

def PublicOutputShapeSafe (outputShape : Config → OutputShape) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → outputShape cfg₁ = outputShape cfg₂

def ExactTEEStorageOblivious (run : DeploymentSemantics) : Prop :=
  ∀ cfg₁ cfg₂,
    samePublicProjection cfg₁ cfg₂ →
    viewTEEStore cfg₁ (run cfg₁) = viewTEEStore cfg₂ (run cfg₂)

theorem samePublicProjection_entrypoint_eq {lhs rhs : Config} :
    samePublicProjection lhs rhs → lhs.program.entrypoint = rhs.program.entrypoint := by
  intro h
  exact congrArg Program.entrypoint (samePublicProjection_program_eq h)

theorem exactUO_projects_to_teeStorage
  {run : Semantics}
  {termination : Config → Bool}
  {outputShape : Config → OutputShape}
  (hExact : ExactUO run)
  (hTermination : PublicTerminationSafe termination)
  (hOutputShape : PublicOutputShapeSafe outputShape) :
  ExactTEEStorageOblivious (withPublicBoundary run termination outputShape) := by
  intro cfg₁ cfg₂ hPublic
  have hTrace : run cfg₁ = run cfg₂ :=
    viewMPlus_injective (hExact cfg₁ cfg₂ hPublic)
  have hEntry : cfg₁.program.entrypoint = cfg₂.program.entrypoint :=
    samePublicProjection_entrypoint_eq hPublic
  have hArgs : cfg₁.input.publicArgs = cfg₂.input.publicArgs :=
    samePublicProjection_publicArgs_eq hPublic
  have hTerm : termination cfg₁ = termination cfg₂ :=
    hTermination cfg₁ cfg₂ hPublic
  have hOutput : outputShape cfg₁ = outputShape cfg₂ :=
    hOutputShape cfg₁ cfg₂ hPublic
  simp [withPublicBoundary, viewTEEStore, hTrace, hEntry, hArgs, hTerm, hOutput]

def viewTEEStoreFromOramView
  (cfg : OramConfig)
  (terminationStatus : Bool)
  (outputShape : OutputShape)
  (view : ViewMPlus) :
    TEEView :=
  match view with
  | (_opcodeTrace, _logicalAccesses, _logicalWrites, physicalReads, physicalWrites, gasUsed) =>
      { entrypointId := cfg.pubData.witness.entrypointId
      , publicArgs := cfg.pubData.publicArgs
      , terminationStatus := terminationStatus
      , outputShape := outputShape
      , physicalReads := physicalReads
      , physicalWrites := physicalWrites
      , gasUsed := gasUsed
      }

def teeStoreDistribution
  (run : OramSemantics)
  (termination : OramConfig → Bool)
  (outputShape : OramConfig → OutputShape)
  (cfg : OramConfig) :
  Distribution TEEView :=
  (run cfg).map (viewTEEStoreFromOramView cfg (termination cfg) (outputShape cfg))

def OramPublicTerminationSafe (termination : OramConfig → Bool) : Prop :=
  ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ → termination cfg₁ = termination cfg₂

def OramPublicOutputShapeSafe (outputShape : OramConfig → OutputShape) : Prop :=
  ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ → outputShape cfg₁ = outputShape cfg₂

abbrev TEEStorageLocalTheorem := Distribution TEEView → Distribution TEEView → List OramAccessLeakage → Prop

def teeStorageLocalTheorem : TEEStorageLocalTheorem :=
  fun teeView₁ teeView₂ leakage =>
    ∃ cfg₁ cfg₂ termination outputShape view₁ view₂,
      sameOramPublicProjection cfg₁ cfg₂ ∧
      leakage = executionLeakage cfg₁ ∧
      oramLocalTheorem view₁ view₂ leakage ∧
      teeView₁ = view₁.map (viewTEEStoreFromOramView cfg₁ termination outputShape) ∧
      teeView₂ = view₂.map (viewTEEStoreFromOramView cfg₂ termination outputShape)

theorem oramLocalTheorem_projects_to_teeStorage
  (cfg₁ cfg₂ : OramConfig)
  (termination : Bool)
  (outputShape : OutputShape)
  (view₁ view₂ : Distribution ViewMPlus) :
  sameOramPublicProjection cfg₁ cfg₂ →
  oramLocalTheorem view₁ view₂ (executionLeakage cfg₁) →
  teeStorageLocalTheorem
    (view₁.map (viewTEEStoreFromOramView cfg₁ termination outputShape))
    (view₂.map (viewTEEStoreFromOramView cfg₂ termination outputShape))
    (executionLeakage cfg₁) := by
  intro hPublic hLocal
  refine ⟨cfg₁, cfg₂, termination, outputShape, view₁, view₂, hPublic, rfl, hLocal, rfl, rfl⟩

def ComputationalTEEStorageOblivious
  (run : OramSemantics)
  (termination : OramConfig → Bool)
  (outputShape : OramConfig → OutputShape) : Prop :=
  ∀ cfg₁ cfg₂,
    sameOramPublicProjection cfg₁ cfg₂ →
    teeStorageLocalTheorem
      (teeStoreDistribution run termination outputShape cfg₁)
      (teeStoreDistribution run termination outputShape cfg₂)
      (executionLeakage cfg₁)

theorem computationalUO_projects_to_teeStorage
  {run : OramSemantics}
  {termination : OramConfig → Bool}
  {outputShape : OramConfig → OutputShape}
  (hOram : ComputationalUO run)
  (hTermination : OramPublicTerminationSafe termination)
  (hOutputShape : OramPublicOutputShapeSafe outputShape) :
  ComputationalTEEStorageOblivious run termination outputShape := by
  intro cfg₁ cfg₂ hPublic
  have hTerm : termination cfg₁ = termination cfg₂ :=
    hTermination cfg₁ cfg₂ hPublic
  have hOutput : outputShape cfg₁ = outputShape cfg₂ :=
    hOutputShape cfg₁ cfg₂ hPublic
  simpa [teeStoreDistribution, hTerm, hOutput] using
    (oramLocalTheorem_projects_to_teeStorage
      cfg₁
      cfg₂
      (termination cfg₁)
      (outputShape cfg₁)
      (run cfg₁)
      (run cfg₂)
      hPublic
      (hOram cfg₁ cfg₂ hPublic))

def TEEStorageSecurity
  (exactRun : Semantics)
  (exactTermination : Config → Bool)
  (exactOutputShape : Config → OutputShape)
  (oramRun : OramSemantics)
  (oramTermination : OramConfig → Bool)
  (oramOutputShape : OramConfig → OutputShape) : Prop :=
  ExactTEEStorageOblivious (withPublicBoundary exactRun exactTermination exactOutputShape) ∧
    ComputationalTEEStorageOblivious oramRun oramTermination oramOutputShape

theorem artifactSecurity_projects_to_teeStorage
  {exactRun : Semantics}
  {exactTermination : Config → Bool}
  {exactOutputShape : Config → OutputShape}
  {oramRun : OramSemantics}
  {oramTermination : OramConfig → Bool}
  {oramOutputShape : OramConfig → OutputShape}
  (hArtifact : ArtifactSecurity exactRun oramRun)
  (hExactTermination : PublicTerminationSafe exactTermination)
  (hExactOutputShape : PublicOutputShapeSafe exactOutputShape)
  (hOramTermination : OramPublicTerminationSafe oramTermination)
  (hOramOutputShape : OramPublicOutputShapeSafe oramOutputShape) :
  TEEStorageSecurity
    exactRun
    exactTermination
    exactOutputShape
    oramRun
    oramTermination
    oramOutputShape := by
  rcases hArtifact with ⟨hExact, hOram⟩
  exact
    ⟨ exactUO_projects_to_teeStorage hExact hExactTermination hExactOutputShape
    , computationalUO_projects_to_teeStorage hOram hOramTermination hOramOutputShape
    ⟩

end UOToolchain
