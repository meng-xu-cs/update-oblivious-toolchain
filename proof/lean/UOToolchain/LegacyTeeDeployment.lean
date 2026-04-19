import UOToolchain.TeeDeployment
import UOToolchain.LegacyComposition
import UOToolchain.OramGame

namespace UOToolchain

abbrev legacyTeeStorageLocalTheorem : TEEStorageLocalTheorem :=
  teeStorageLocalTheoremWith legacyOramSecurityInterface

theorem legacyOramLocalTheorem_projects_to_teeStorage
  (cfg₁ cfg₂ : OramConfig)
  (termination : Bool)
  (outputShape : OutputShape)
  (view₁ view₂ : Distribution ViewMPlus) :
  sameOramPublicProjection cfg₁ cfg₂ →
  legacyOramLocalTheorem view₁ view₂ (executionLeakage cfg₁) →
  legacyTeeStorageLocalTheorem
    (view₁.map (viewTEEStoreFromOramView cfg₁ termination outputShape))
    (view₂.map (viewTEEStoreFromOramView cfg₂ termination outputShape))
    (executionLeakage cfg₁) := by
  exact oramSecurity_projects_to_teeStorage legacyOramSecurityInterface cfg₁ cfg₂ termination outputShape view₁ view₂

abbrev legacyComputationalTEEStorageOblivious
  (run : OramSemantics)
  (termination : OramConfig → Bool)
  (outputShape : OramConfig → OutputShape) : Prop :=
  ComputationalTEEStorageObliviousWith legacyOramSecurityInterface run termination outputShape

theorem legacyComputationalUO_projects_to_teeStorage
  {run : OramSemantics}
  {termination : OramConfig → Bool}
  {outputShape : OramConfig → OutputShape}
  (hOram : legacyComputationalUO run)
  (hTermination : OramPublicTerminationSafe termination)
  (hOutputShape : OramPublicOutputShapeSafe outputShape) :
  legacyComputationalTEEStorageOblivious run termination outputShape := by
  exact
    computationalUOWith_projects_to_teeStorage
      legacyOramSecurityInterface
      hOram
      hTermination
      hOutputShape

abbrev legacyTEEStorageSecurity
  (exactRun : Semantics)
  (exactTermination : Config → Bool)
  (exactOutputShape : Config → OutputShape)
  (oramRun : OramSemantics)
  (oramTermination : OramConfig → Bool)
  (oramOutputShape : OramConfig → OutputShape) : Prop :=
  TEEStorageSecurityWith
    legacyOramSecurityInterface
    exactRun
    exactTermination
    exactOutputShape
    oramRun
    oramTermination
    oramOutputShape

theorem artifactSecurity_projects_to_teeStorage
  {exactRun : Semantics}
  {exactTermination : Config → Bool}
  {exactOutputShape : Config → OutputShape}
  {oramRun : OramSemantics}
  {oramTermination : OramConfig → Bool}
  {oramOutputShape : OramConfig → OutputShape}
  (hArtifact : legacyArtifactSecurity exactRun oramRun)
  (hExactTermination : PublicTerminationSafe exactTermination)
  (hExactOutputShape : PublicOutputShapeSafe exactOutputShape)
  (hOramTermination : OramPublicTerminationSafe oramTermination)
  (hOramOutputShape : OramPublicOutputShapeSafe oramOutputShape) :
  legacyTEEStorageSecurity
    exactRun
    exactTermination
    exactOutputShape
    oramRun
    oramTermination
    oramOutputShape := by
  exact
    artifactSecurityWith_projects_to_teeStorage
      legacyOramSecurityInterface
      hArtifact
      hExactTermination
      hExactOutputShape
      hOramTermination
      hOramOutputShape

end UOToolchain
