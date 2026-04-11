import UOToolchain.Composition

namespace UOToolchain

structure TEEView where
  entrypointId : String
  publicArgs : List String
  terminationStatus : Bool
  physicalReads : List PhysicalRead
  physicalWrites : List PhysicalWrite
  gasUsed : Nat
deriving Repr, DecidableEq

structure DeploymentResult where
  trace : Trace
  terminationStatus : Bool
deriving Repr, DecidableEq

abbrev DeploymentSemantics := Config → DeploymentResult

def withTermination (run : Semantics) (termination : Config → Bool) : DeploymentSemantics :=
  fun cfg =>
    { trace := run cfg
    , terminationStatus := termination cfg
    }

def viewTEEStore (cfg : Config) (result : DeploymentResult) : TEEView :=
  { entrypointId := cfg.program.entrypoint
  , publicArgs := cfg.input.publicArgs
  , terminationStatus := result.terminationStatus
  , physicalReads := result.trace.physicalReads
  , physicalWrites := result.trace.physicalWrites
  , gasUsed := result.trace.gasUsed
  }

def PublicTerminationSafe (termination : Config → Bool) : Prop :=
  ∀ cfg₁ cfg₂, samePublicProjection cfg₁ cfg₂ → termination cfg₁ = termination cfg₂

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
  (hExact : ExactUO run)
  (hTermination : PublicTerminationSafe termination) :
  ExactTEEStorageOblivious (withTermination run termination) := by
  intro cfg₁ cfg₂ hPublic
  have hTrace : run cfg₁ = run cfg₂ :=
    viewMPlus_injective (hExact cfg₁ cfg₂ hPublic)
  have hEntry : cfg₁.program.entrypoint = cfg₂.program.entrypoint :=
    samePublicProjection_entrypoint_eq hPublic
  have hArgs : cfg₁.input.publicArgs = cfg₂.input.publicArgs :=
    samePublicProjection_publicArgs_eq hPublic
  have hTerm : termination cfg₁ = termination cfg₂ :=
    hTermination cfg₁ cfg₂ hPublic
  simp [withTermination, viewTEEStore, hTrace, hEntry, hArgs, hTerm]

def viewTEEStoreFromOramView (cfg : OramConfig) (terminationStatus : Bool) (view : ViewMPlus) :
    TEEView :=
  match view with
  | (_opcodeTrace, _logicalAccesses, _logicalWrites, physicalReads, physicalWrites, gasUsed) =>
      { entrypointId := cfg.pubData.witness.entrypointId
      , publicArgs := cfg.pubData.publicArgs
      , terminationStatus := terminationStatus
      , physicalReads := physicalReads
      , physicalWrites := physicalWrites
      , gasUsed := gasUsed
      }

def teeStoreDistribution
  (run : OramSemantics)
  (termination : OramConfig → Bool)
  (cfg : OramConfig) :
  Distribution TEEView :=
  (run cfg).map (viewTEEStoreFromOramView cfg (termination cfg))

def OramPublicTerminationSafe (termination : OramConfig → Bool) : Prop :=
  ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ → termination cfg₁ = termination cfg₂

abbrev TEEStorageLocalTheorem := Distribution TEEView → Distribution TEEView → List OramAccessLeakage → Prop

def teeStorageLocalTheorem : TEEStorageLocalTheorem :=
  fun teeView₁ teeView₂ leakage =>
    ∃ cfg₁ cfg₂ termination₁ termination₂ view₁ view₂,
      sameOramPublicProjection cfg₁ cfg₂ ∧
      termination₁ = termination₂ ∧
      leakage = executionLeakage cfg₁ ∧
      oramLocalTheorem view₁ view₂ leakage ∧
      teeView₁ = view₁.map (viewTEEStoreFromOramView cfg₁ termination₁) ∧
      teeView₂ = view₂.map (viewTEEStoreFromOramView cfg₂ termination₂)

theorem oramLocalTheorem_projects_to_teeStorage
  (cfg₁ cfg₂ : OramConfig)
  (termination : Bool)
  (view₁ view₂ : Distribution ViewMPlus) :
  sameOramPublicProjection cfg₁ cfg₂ →
  oramLocalTheorem view₁ view₂ (executionLeakage cfg₁) →
  teeStorageLocalTheorem
    (view₁.map (viewTEEStoreFromOramView cfg₁ termination))
    (view₂.map (viewTEEStoreFromOramView cfg₂ termination))
    (executionLeakage cfg₁) := by
  intro hPublic hLocal
  refine ⟨cfg₁, cfg₂, termination, termination, view₁, view₂, hPublic, rfl, rfl, hLocal, rfl, rfl⟩

def ComputationalTEEStorageOblivious
  (run : OramSemantics)
  (termination : OramConfig → Bool) : Prop :=
  ∀ cfg₁ cfg₂,
    sameOramPublicProjection cfg₁ cfg₂ →
    teeStorageLocalTheorem
      (teeStoreDistribution run termination cfg₁)
      (teeStoreDistribution run termination cfg₂)
      (executionLeakage cfg₁)

theorem computationalUO_projects_to_teeStorage
  {run : OramSemantics}
  {termination : OramConfig → Bool}
  (hOram : ComputationalUO run)
  (hTermination : OramPublicTerminationSafe termination) :
  ComputationalTEEStorageOblivious run termination := by
  intro cfg₁ cfg₂ hPublic
  have hTerm : termination cfg₁ = termination cfg₂ :=
    hTermination cfg₁ cfg₂ hPublic
  simpa [teeStoreDistribution, hTerm] using
    (oramLocalTheorem_projects_to_teeStorage
      cfg₁
      cfg₂
      (termination cfg₁)
      (run cfg₁)
      (run cfg₂)
      hPublic
      (hOram cfg₁ cfg₂ hPublic))

def TEEStorageSecurity
  (exactRun : Semantics)
  (exactTermination : Config → Bool)
  (oramRun : OramSemantics)
  (oramTermination : OramConfig → Bool) : Prop :=
  ExactTEEStorageOblivious (withTermination exactRun exactTermination) ∧
    ComputationalTEEStorageOblivious oramRun oramTermination

theorem artifactSecurity_projects_to_teeStorage
  {exactRun : Semantics}
  {exactTermination : Config → Bool}
  {oramRun : OramSemantics}
  {oramTermination : OramConfig → Bool}
  (hArtifact : ArtifactSecurity exactRun oramRun)
  (hExactTermination : PublicTerminationSafe exactTermination)
  (hOramTermination : OramPublicTerminationSafe oramTermination) :
  TEEStorageSecurity exactRun exactTermination oramRun oramTermination := by
  rcases hArtifact with ⟨hExact, hOram⟩
  exact
    ⟨ exactUO_projects_to_teeStorage hExact hExactTermination
    , computationalUO_projects_to_teeStorage hOram hOramTermination
    ⟩

end UOToolchain
