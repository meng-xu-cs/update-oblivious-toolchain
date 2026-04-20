import Lean.Data.Json
import UOToolchain.RuntimeCoins
import UOToolchain.RuntimeRefinementJson
import UOToolchain.RuntimeShellBoundaryJson

open Lean

namespace UOToolchain

structure ImportedSeededRuntimeWitnessFamily where
  seed_count : Nat
  witnesses : List ImportedRuntimeRefinementWitness
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedSeededRuntimeWitnessFamily.witnessAt?
  (family : ImportedSeededRuntimeWitnessFamily)
  (seed : Nat) : Option ImportedRuntimeRefinementWitness :=
  family.witnesses[seed]?

def ImportedSeededRuntimeWitnessFamily.runtimeWitnessAt
  (family : ImportedSeededRuntimeWitnessFamily)
  (seed : Nat) : RuntimeRefinementWitness :=
  match family.witnessAt? seed with
  | some witness => witness.toRuntimeWitness
  | none => sampleImportedRuntimeRefinementWitness.toRuntimeWitness

def ImportedSeededRuntimeWitnessFamily.Valid
  (family : ImportedSeededRuntimeWitnessFamily)
  (modelTags : SGXModelTags) : Prop :=
  family.witnesses.length = family.seed_count ∧
    ∀ seed, seed < family.seed_count →
      ∃ witness,
        family.witnessAt? seed = some witness ∧
        witness.runtime_seed = some seed ∧
        witness.Valid modelTags

def ImportedSeededRuntimeWitnessFamily.ProofGradeValid
  (family : ImportedSeededRuntimeWitnessFamily)
  (modelTags : SGXModelTags) : Prop :=
  family.witnesses.length = family.seed_count ∧
    ∀ seed, seed < family.seed_count →
      ∃ witness,
        family.witnessAt? seed = some witness ∧
        witness.runtime_seed = some seed ∧
        witness.ProofGradeValid modelTags

def ImportedSeededRuntimeWitnessFamily.checkValid
  (family : ImportedSeededRuntimeWitnessFamily)
  (modelTags : SGXModelTags) : Bool :=
  decide (family.witnesses.length = family.seed_count) &&
    (List.range family.seed_count).all fun seed =>
      match family.witnessAt? seed with
      | some witness =>
          decide (witness.runtime_seed = some seed) &&
            witness.checkValid modelTags
      | none => false

def ImportedSeededRuntimeWitnessFamily.checkProofGrade
  (family : ImportedSeededRuntimeWitnessFamily)
  (modelTags : SGXModelTags) : Bool :=
  decide (family.witnesses.length = family.seed_count) &&
    (List.range family.seed_count).all fun seed =>
      match family.witnessAt? seed with
      | some witness =>
          decide (witness.runtime_seed = some seed) &&
            witness.checkProofGrade modelTags
      | none => false

def ImportedSeededRuntimeWitnessFamily.toSeededRuntimeWitnessFamily
  (family : ImportedSeededRuntimeWitnessFamily)
  (modelTags : SGXModelTags)
  (hValid : family.Valid modelTags) : SeededRuntimeWitnessFamily modelTags :=
  { seedCount := family.seed_count
  , witnessAt := family.runtimeWitnessAt
  , seedTagged := by
      intro seed hSeed
      rcases hValid.2 seed hSeed with ⟨witness, hGet, hTag, _hWitnessValid⟩
      change (family.runtimeWitnessAt seed).runtimeSeed = some seed
      rw [ImportedSeededRuntimeWitnessFamily.runtimeWitnessAt, hGet]
      simpa using hTag
  , valid := by
      intro seed hSeed
      rcases hValid.2 seed hSeed with ⟨witness, hGet, _hTag, hWitnessValid⟩
      change (family.runtimeWitnessAt seed).Valid modelTags
      rw [ImportedSeededRuntimeWitnessFamily.runtimeWitnessAt, hGet]
      simpa using hWitnessValid.1
  }

def parseImportedSeededRuntimeWitnessFamily
  (input : String) : Except String ImportedSeededRuntimeWitnessFamily := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedSeededRuntimeWitnessFamily
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedSeededRuntimeWitnessFamily := do
  let family ← parseImportedSeededRuntimeWitnessFamily input
  if family.checkValid modelTags then
    pure family
  else
    throw "imported seeded runtime witness family does not satisfy Lean validity checks"

def loadImportedSeededRuntimeWitnessFamily
  (path : System.FilePath) : IO ImportedSeededRuntimeWitnessFamily := do
  let input ← IO.FS.readFile path
  match parseImportedSeededRuntimeWitnessFamily input with
  | .ok family => pure family
  | .error err => throw <| IO.userError s!"failed to parse seeded runtime witness family: {err}"

def loadAndCheckImportedSeededRuntimeWitnessFamily
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedSeededRuntimeWitnessFamily := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedSeededRuntimeWitnessFamily input modelTags with
  | .ok family => pure family
  | .error err =>
      throw <| IO.userError s!"failed to validate seeded runtime witness family: {err}"

def parseAndCheckImportedProofGradeSeededRuntimeWitnessFamily
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedSeededRuntimeWitnessFamily := do
  let family ← parseImportedSeededRuntimeWitnessFamily input
  if family.checkProofGrade modelTags then
    pure family
  else
    throw
      "imported proof-grade seeded runtime witness family does not satisfy Lean validity checks"

def loadAndCheckImportedProofGradeSeededRuntimeWitnessFamily
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedSeededRuntimeWitnessFamily := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeSeededRuntimeWitnessFamily input modelTags with
  | .ok family => pure family
  | .error err =>
      throw
        <| IO.userError
            s!"failed to validate proof-grade seeded runtime witness family: {err}"

@[simp] theorem importedSeededRuntimeWitnessFamily_checkValid_eq_true_iff
  (family : ImportedSeededRuntimeWitnessFamily)
  (modelTags : SGXModelTags) :
  family.checkValid modelTags = true ↔ family.Valid modelTags := by
  constructor
  · intro hCheck
    rw [ImportedSeededRuntimeWitnessFamily.checkValid, Bool.and_eq_true] at hCheck
    refine ⟨?_, ?_⟩
    · simpa using hCheck.1
    · intro seed hSeed
      have hSeedCheck :
          (match family.witnessAt? seed with
            | some witness =>
                decide (witness.runtime_seed = some seed) &&
                  witness.checkValid modelTags
            | none => false) = true := by
        exact (List.all_eq_true.mp hCheck.2) seed (List.mem_range.mpr hSeed)
      cases hGet : family.witnessAt? seed with
      | none =>
          simp [hGet] at hSeedCheck
      | some witness =>
          have hWitness :
              witness.runtime_seed = some seed ∧ witness.Valid modelTags := by
            have :
                (decide (witness.runtime_seed = some seed) &&
                  witness.checkValid modelTags) = true := by
              simpa [hGet] using hSeedCheck
            rw [Bool.and_eq_true] at this
            refine ⟨?_, ?_⟩
            · simpa using this.1
            · exact (importedWitness_checkValid_eq_true_iff witness modelTags).mp this.2
          exact ⟨witness, rfl, hWitness.1, hWitness.2⟩
  · intro hValid
    rw [ImportedSeededRuntimeWitnessFamily.checkValid, Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · simpa using hValid.1
    · refine List.all_eq_true.mpr ?_
      intro seed hSeedMem
      have hSeed : seed < family.seed_count := List.mem_range.mp hSeedMem
      rcases hValid.2 seed hSeed with ⟨witness, hGet, hTag, hWitnessValid⟩
      simp [hGet, hTag, (importedWitness_checkValid_eq_true_iff witness modelTags).2 hWitnessValid]

@[simp] theorem importedSeededRuntimeWitnessFamily_checkProofGrade_eq_true_iff
  (family : ImportedSeededRuntimeWitnessFamily)
  (modelTags : SGXModelTags) :
  family.checkProofGrade modelTags = true ↔ family.ProofGradeValid modelTags := by
  constructor
  · intro hCheck
    rw [ImportedSeededRuntimeWitnessFamily.checkProofGrade, Bool.and_eq_true] at hCheck
    refine ⟨?_, ?_⟩
    · simpa using hCheck.1
    · intro seed hSeed
      have hSeedCheck :
          (match family.witnessAt? seed with
            | some witness =>
                decide (witness.runtime_seed = some seed) &&
                  witness.checkProofGrade modelTags
            | none => false) = true := by
        exact (List.all_eq_true.mp hCheck.2) seed (List.mem_range.mpr hSeed)
      cases hGet : family.witnessAt? seed with
      | none =>
          simp [hGet] at hSeedCheck
      | some witness =>
          have hWitness :
              witness.runtime_seed = some seed ∧ witness.ProofGradeValid modelTags := by
            have :
                (decide (witness.runtime_seed = some seed) &&
                  witness.checkProofGrade modelTags) = true := by
              simpa [hGet] using hSeedCheck
            rw [Bool.and_eq_true] at this
            refine ⟨?_, ?_⟩
            · simpa using this.1
            · exact (importedWitness_checkProofGrade_eq_true_iff witness modelTags).mp this.2
          exact ⟨witness, rfl, hWitness.1, hWitness.2⟩
  · intro hValid
    rw [ImportedSeededRuntimeWitnessFamily.checkProofGrade, Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · simpa using hValid.1
    · refine List.all_eq_true.mpr ?_
      intro seed hSeedMem
      have hSeed : seed < family.seed_count := List.mem_range.mp hSeedMem
      rcases hValid.2 seed hSeed with ⟨witness, hGet, hTag, hWitnessValid⟩
      simp [hGet, hTag,
        (importedWitness_checkProofGrade_eq_true_iff witness modelTags).2 hWitnessValid]

theorem importedSeededRuntimeWitnessFamily_proofGradeValid_implies_valid
  {family : ImportedSeededRuntimeWitnessFamily}
  {modelTags : SGXModelTags}
  (hValid : family.ProofGradeValid modelTags) :
  family.Valid modelTags := by
  refine ⟨hValid.1, ?_⟩
  intro seed hSeed
  rcases hValid.2 seed hSeed with ⟨witness, hGet, hTag, hWitnessValid⟩
  refine ⟨witness, hGet, hTag, ?_⟩
  rcases hWitnessValid with ⟨hRuntimeValid, hKernelProofGrade, hRefinementProofGrade⟩
  refine ⟨hRuntimeValid, ?_, ?_⟩
  · unfold ImportedRuntimeRefinementWitness.kernelWitnessValid
      ImportedRuntimeRefinementWitness.proofGradeKernelWitnessValid at *
    cases hKernel : witness.kernel_witness with
    | none =>
        simp [hKernel] at hKernelProofGrade
    | some kernelWitness =>
        simp [hKernel] at hKernelProofGrade
        exact hKernelProofGrade.1
  · unfold ImportedRuntimeRefinementWitness.runtimeKernelRefinementWitnessValid
      ImportedRuntimeRefinementWitness.proofGradeRuntimeKernelRefinementWitnessValid at *
    cases hKernel : witness.kernel_witness with
    | none =>
        cases hRefinement : witness.runtime_kernel_refinement_witness <;>
          simp [hKernel, hRefinement] at hRefinementProofGrade
    | some kernelWitness =>
        cases hRefinement : witness.runtime_kernel_refinement_witness with
        | none =>
            simp [hKernel, hRefinement] at hRefinementProofGrade
        | some runtimeKernelRefinementWitness =>
            simpa [hKernel, hRefinement] using hRefinementProofGrade

structure ImportedSeededRuntimePathOramWitnessFamily
    extends ImportedSeededRuntimeWitnessFamily where
  public_leaf_scaffold : List ImportedRuntimeOramLeafScaffoldCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedSeededRuntimePathOramWitnessFamily.runtimePublicLeafScaffold
  (family : ImportedSeededRuntimePathOramWitnessFamily) :
  List RuntimePathOramLeafScaffoldStep :=
  family.public_leaf_scaffold.map
    ImportedRuntimeOramLeafScaffoldCertificate.toRuntimePathOramLeafScaffoldStep

def ImportedSeededRuntimePathOramWitnessFamily.projectedPublicLeafScaffold
  (family : ImportedSeededRuntimePathOramWitnessFamily) :
  PathOramLeafScheduleScaffold :=
  family.runtimePublicLeafScaffold.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def ImportedSeededRuntimePathOramWitnessFamily.Valid
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Prop :=
  family.toImportedSeededRuntimeWitnessFamily.Valid modelTags ∧
    ∀ seed, seed < family.seed_count →
      ∃ witness,
        family.toImportedSeededRuntimeWitnessFamily.witnessAt? seed = some witness ∧
        witness.toRuntimeWitness.oramLeafPublicScaffold =
          family.runtimePublicLeafScaffold

def ImportedSeededRuntimePathOramWitnessFamily.ProofGradeValid
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Prop :=
  family.toImportedSeededRuntimeWitnessFamily.ProofGradeValid modelTags ∧
    ∀ seed, seed < family.seed_count →
      ∃ witness,
        family.toImportedSeededRuntimeWitnessFamily.witnessAt? seed = some witness ∧
        witness.toRuntimeWitness.oramLeafPublicScaffold =
          family.runtimePublicLeafScaffold

def ImportedSeededRuntimePathOramWitnessFamily.checkValid
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Bool :=
  family.toImportedSeededRuntimeWitnessFamily.checkValid modelTags &&
    (List.range family.seed_count).all fun seed =>
      match family.toImportedSeededRuntimeWitnessFamily.witnessAt? seed with
      | some witness =>
          decide
            (witness.toRuntimeWitness.oramLeafPublicScaffold =
              family.runtimePublicLeafScaffold)
      | none => false

def ImportedSeededRuntimePathOramWitnessFamily.checkProofGrade
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Bool :=
  family.toImportedSeededRuntimeWitnessFamily.checkProofGrade modelTags &&
    (List.range family.seed_count).all fun seed =>
      match family.toImportedSeededRuntimeWitnessFamily.witnessAt? seed with
      | some witness =>
          decide
            (witness.toRuntimeWitness.oramLeafPublicScaffold =
              family.runtimePublicLeafScaffold)
      | none => false

def ImportedSeededRuntimePathOramWitnessFamily.toSeededRuntimePathOramWitnessFamily
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags)
  (hValid : family.Valid modelTags) : SeededRuntimePathOramWitnessFamily modelTags :=
  { family.toImportedSeededRuntimeWitnessFamily.toSeededRuntimeWitnessFamily modelTags hValid.1 with
    publicLeafScaffold := family.projectedPublicLeafScaffold
  , publicLeafScaffoldExact := by
      intro seed hSeed
      rcases hValid.2 seed hSeed with ⟨witness, hGet, hScaffold⟩
      change
        List.map RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep
            (family.runtimeWitnessAt seed).oramLeafPublicScaffold =
          family.projectedPublicLeafScaffold
      rw [ImportedSeededRuntimeWitnessFamily.runtimeWitnessAt, hGet]
      simpa [ ImportedSeededRuntimePathOramWitnessFamily.projectedPublicLeafScaffold
        , ImportedSeededRuntimePathOramWitnessFamily.runtimePublicLeafScaffold
        , RuntimeRefinementWitness.projectedPublicPathOramLeafScaffold
        ] using
        congrArg
          (List.map RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep)
          hScaffold
  }

def parseImportedSeededRuntimePathOramWitnessFamily
  (input : String) : Except String ImportedSeededRuntimePathOramWitnessFamily := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedSeededRuntimePathOramWitnessFamily
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedSeededRuntimePathOramWitnessFamily := do
  let family ← parseImportedSeededRuntimePathOramWitnessFamily input
  if family.checkValid modelTags then
    pure family
  else
    throw "imported seeded path-ORAM runtime witness family does not satisfy Lean validity checks"

def loadImportedSeededRuntimePathOramWitnessFamily
  (path : System.FilePath) : IO ImportedSeededRuntimePathOramWitnessFamily := do
  let input ← IO.FS.readFile path
  match parseImportedSeededRuntimePathOramWitnessFamily input with
  | .ok family => pure family
  | .error err =>
      throw <| IO.userError s!"failed to parse seeded path-ORAM runtime witness family: {err}"

def loadAndCheckImportedSeededRuntimePathOramWitnessFamily
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedSeededRuntimePathOramWitnessFamily := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedSeededRuntimePathOramWitnessFamily input modelTags with
  | .ok family => pure family
  | .error err =>
      throw <| IO.userError
        s!"failed to validate seeded path-ORAM runtime witness family: {err}"

def parseAndCheckImportedProofGradeSeededRuntimePathOramWitnessFamily
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedSeededRuntimePathOramWitnessFamily := do
  let family ← parseImportedSeededRuntimePathOramWitnessFamily input
  if family.checkProofGrade modelTags then
    pure family
  else
    throw
      "imported proof-grade seeded path-ORAM runtime witness family does not satisfy Lean validity checks"

def loadAndCheckImportedProofGradeSeededRuntimePathOramWitnessFamily
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedSeededRuntimePathOramWitnessFamily := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofGradeSeededRuntimePathOramWitnessFamily input modelTags with
  | .ok family => pure family
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade seeded path-ORAM runtime witness family: {err}"

@[simp] theorem importedSeededRuntimePathOramWitnessFamily_checkValid_eq_true_iff
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) :
  family.checkValid modelTags = true ↔ family.Valid modelTags := by
  constructor
  · intro hCheck
    rw [ImportedSeededRuntimePathOramWitnessFamily.checkValid, Bool.and_eq_true] at hCheck
    refine ⟨?_, ?_⟩
    · exact
        (importedSeededRuntimeWitnessFamily_checkValid_eq_true_iff
          family.toImportedSeededRuntimeWitnessFamily modelTags).mp hCheck.1
    · intro seed hSeed
      have hSeedCheck :
          (match family.witnessAt? seed with
            | some witness =>
                decide
                  (witness.toRuntimeWitness.oramLeafPublicScaffold =
                    family.runtimePublicLeafScaffold)
            | none => false) = true := by
        exact (List.all_eq_true.mp hCheck.2) seed (List.mem_range.mpr hSeed)
      cases hGet : family.witnessAt? seed with
      | none =>
          simp [hGet] at hSeedCheck
      | some witness =>
          refine ⟨witness, rfl, ?_⟩
          simpa [hGet] using hSeedCheck
  · intro hValid
    rw [ImportedSeededRuntimePathOramWitnessFamily.checkValid, Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · exact
        (importedSeededRuntimeWitnessFamily_checkValid_eq_true_iff
          family.toImportedSeededRuntimeWitnessFamily modelTags).2 hValid.1
    · refine List.all_eq_true.mpr ?_
      intro seed hSeedMem
      have hSeed : seed < family.seed_count := List.mem_range.mp hSeedMem
      rcases hValid.2 seed hSeed with ⟨witness, hGet, hScaffold⟩
      simp [hGet, hScaffold]

@[simp] theorem importedSeededRuntimePathOramWitnessFamily_checkProofGrade_eq_true_iff
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) :
  family.checkProofGrade modelTags = true ↔ family.ProofGradeValid modelTags := by
  constructor
  · intro hCheck
    rw [ImportedSeededRuntimePathOramWitnessFamily.checkProofGrade, Bool.and_eq_true] at hCheck
    refine ⟨?_, ?_⟩
    · exact
        (importedSeededRuntimeWitnessFamily_checkProofGrade_eq_true_iff
          family.toImportedSeededRuntimeWitnessFamily modelTags).mp hCheck.1
    · intro seed hSeed
      have hSeedCheck :
          (match family.witnessAt? seed with
            | some witness =>
                decide
                  (witness.toRuntimeWitness.oramLeafPublicScaffold =
                    family.runtimePublicLeafScaffold)
            | none => false) = true := by
        exact (List.all_eq_true.mp hCheck.2) seed (List.mem_range.mpr hSeed)
      cases hGet : family.witnessAt? seed with
      | none =>
          simp [hGet] at hSeedCheck
      | some witness =>
          refine ⟨witness, rfl, ?_⟩
          simpa [hGet] using hSeedCheck
  · intro hValid
    rw [ImportedSeededRuntimePathOramWitnessFamily.checkProofGrade, Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · exact
        (importedSeededRuntimeWitnessFamily_checkProofGrade_eq_true_iff
          family.toImportedSeededRuntimeWitnessFamily modelTags).2 hValid.1
    · refine List.all_eq_true.mpr ?_
      intro seed hSeedMem
      have hSeed : seed < family.seed_count := List.mem_range.mp hSeedMem
      rcases hValid.2 seed hSeed with ⟨witness, hGet, hScaffold⟩
      simp [hGet, hScaffold]

theorem importedSeededRuntimePathOramWitnessFamily_proofGradeValid_implies_valid
  {family : ImportedSeededRuntimePathOramWitnessFamily}
  {modelTags : SGXModelTags}
  (hValid : family.ProofGradeValid modelTags) :
  family.Valid modelTags := by
  refine
    ⟨ importedSeededRuntimeWitnessFamily_proofGradeValid_implies_valid hValid.1
    , hValid.2
    ⟩

def ImportedSeededRuntimePathOramWitnessFamily.ProofGradeKernelInterfaceAssurance
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Prop :=
  family.ProofGradeValid modelTags ∧
    ∀ seed, seed < family.seed_count →
      ∃ witness,
        family.witnessAt? seed = some witness ∧
        ImportedRuntimeProofGradeKernelInterface witness

def checkImportedProofGradeSeededRuntimePathOramKernelInterfaceFamily
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Bool :=
  family.checkProofGrade modelTags

@[simp] theorem
    importedSeededRuntimePathOramKernelInterfaceFamily_check_eq_true_iff
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) :
  checkImportedProofGradeSeededRuntimePathOramKernelInterfaceFamily family modelTags = true ↔
    family.ProofGradeKernelInterfaceAssurance modelTags := by
  unfold checkImportedProofGradeSeededRuntimePathOramKernelInterfaceFamily
    ImportedSeededRuntimePathOramWitnessFamily.ProofGradeKernelInterfaceAssurance
  constructor
  · intro hCheck
    have hValid : family.ProofGradeValid modelTags := by
      exact
        (importedSeededRuntimePathOramWitnessFamily_checkProofGrade_eq_true_iff
          family modelTags).mp hCheck
    refine ⟨hValid, ?_⟩
    intro seed hSeed
    rcases hValid.1.2 seed hSeed with ⟨witness, hGet, _hTag, hWitnessValid⟩
    exact
      ⟨witness, hGet,
        importedWitness_proofGradeKernelInterface witness modelTags hWitnessValid⟩
  · intro hAssurance
    exact
      (importedSeededRuntimePathOramWitnessFamily_checkProofGrade_eq_true_iff
        family modelTags).mpr hAssurance.1

def parseAndCheckImportedProofGradeSeededRuntimePathOramKernelInterfaceFamily
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedSeededRuntimePathOramWitnessFamily := do
  let family ← parseImportedSeededRuntimePathOramWitnessFamily input
  if checkImportedProofGradeSeededRuntimePathOramKernelInterfaceFamily family modelTags then
    pure family
  else
    throw
      "imported proof-grade seeded path-ORAM runtime kernel-interface family does not satisfy Lean validity checks"

def loadAndCheckImportedProofGradeSeededRuntimePathOramKernelInterfaceFamily
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedSeededRuntimePathOramWitnessFamily := do
  let input ← IO.FS.readFile path
  match
      parseAndCheckImportedProofGradeSeededRuntimePathOramKernelInterfaceFamily
        input
        modelTags with
  | .ok family => pure family
  | .error err =>
      throw
        <| IO.userError
            s!"failed to validate proof-grade seeded path-ORAM runtime kernel-interface family: {err}"

def ImportedSeededRuntimePathOramWitnessFamily.PublicOutcomeUniform
  (family : ImportedSeededRuntimePathOramWitnessFamily) : Prop :=
  0 < family.seed_count ∧
    ∀ seed, seed < family.seed_count →
      (family.runtimeWitnessAt seed).publicOutcome =
        (family.runtimeWitnessAt 0).publicOutcome

def ImportedSeededRuntimePathOramWitnessFamily.BoundaryScheduleUniform
  (family : ImportedSeededRuntimePathOramWitnessFamily) : Prop :=
  0 < family.seed_count ∧
    ∀ seed, seed < family.seed_count →
      (family.runtimeWitnessAt seed).boundarySchedule =
        (family.runtimeWitnessAt 0).boundarySchedule

def ImportedSeededRuntimePathOramWitnessFamily.checkPublicOutcomeUniform
  (family : ImportedSeededRuntimePathOramWitnessFamily) : Bool :=
  decide (0 < family.seed_count) &&
    (List.range family.seed_count).all fun seed =>
      decide
        ((family.runtimeWitnessAt seed).publicOutcome =
          (family.runtimeWitnessAt 0).publicOutcome)

def ImportedSeededRuntimePathOramWitnessFamily.checkBoundaryScheduleUniform
  (family : ImportedSeededRuntimePathOramWitnessFamily) : Bool :=
  decide (0 < family.seed_count) &&
    (List.range family.seed_count).all fun seed =>
      decide
        ((family.runtimeWitnessAt seed).boundarySchedule =
          (family.runtimeWitnessAt 0).boundarySchedule)

@[simp] theorem
    importedSeededRuntimePathOramWitnessFamily_checkPublicOutcomeUniform_eq_true_iff
  (family : ImportedSeededRuntimePathOramWitnessFamily) :
  family.checkPublicOutcomeUniform = true ↔ family.PublicOutcomeUniform := by
  unfold ImportedSeededRuntimePathOramWitnessFamily.checkPublicOutcomeUniform
    ImportedSeededRuntimePathOramWitnessFamily.PublicOutcomeUniform
  constructor
  · intro hCheck
    rw [Bool.and_eq_true] at hCheck
    refine ⟨by simpa [decide_eq_true_eq] using hCheck.1, ?_⟩
    intro seed hSeed
    have hSeedCheck := (List.all_eq_true.mp hCheck.2) seed (List.mem_range.mpr hSeed)
    simpa [decide_eq_true_eq] using hSeedCheck
  · intro hUniform
    rw [Bool.and_eq_true]
    refine ⟨by simpa [decide_eq_true_eq] using hUniform.1, ?_⟩
    refine List.all_eq_true.mpr ?_
    intro seed hSeedMem
    have hSeed : seed < family.seed_count := List.mem_range.mp hSeedMem
    simpa [decide_eq_true_eq] using hUniform.2 seed hSeed

@[simp] theorem
    importedSeededRuntimePathOramWitnessFamily_checkBoundaryScheduleUniform_eq_true_iff
  (family : ImportedSeededRuntimePathOramWitnessFamily) :
  family.checkBoundaryScheduleUniform = true ↔ family.BoundaryScheduleUniform := by
  unfold ImportedSeededRuntimePathOramWitnessFamily.checkBoundaryScheduleUniform
    ImportedSeededRuntimePathOramWitnessFamily.BoundaryScheduleUniform
  constructor
  · intro hCheck
    rw [Bool.and_eq_true] at hCheck
    refine ⟨by simpa [decide_eq_true_eq] using hCheck.1, ?_⟩
    intro seed hSeed
    have hSeedCheck := (List.all_eq_true.mp hCheck.2) seed (List.mem_range.mpr hSeed)
    simpa [decide_eq_true_eq] using hSeedCheck
  · intro hUniform
    rw [Bool.and_eq_true]
    refine ⟨by simpa [decide_eq_true_eq] using hUniform.1, ?_⟩
    refine List.all_eq_true.mpr ?_
    intro seed hSeedMem
    have hSeed : seed < family.seed_count := List.mem_range.mp hSeedMem
    simpa [decide_eq_true_eq] using hUniform.2 seed hSeed

def ImportedSeededRuntimePathOramWitnessFamily.ProofGradePaperMainRuntimeAssurance
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Prop :=
  family.ProofGradeKernelInterfaceAssurance modelTags ∧
    family.PublicOutcomeUniform ∧
    family.BoundaryScheduleUniform

def checkImportedProofGradeSeededRuntimePathOramPaperMainFamily
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Bool :=
  checkImportedProofGradeSeededRuntimePathOramKernelInterfaceFamily family modelTags &&
    family.checkPublicOutcomeUniform &&
    family.checkBoundaryScheduleUniform

@[simp] theorem
    importedSeededRuntimePathOramPaperMainFamily_check_eq_true_iff
  (family : ImportedSeededRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) :
  checkImportedProofGradeSeededRuntimePathOramPaperMainFamily family modelTags = true ↔
    family.ProofGradePaperMainRuntimeAssurance modelTags := by
  unfold checkImportedProofGradeSeededRuntimePathOramPaperMainFamily
    ImportedSeededRuntimePathOramWitnessFamily.ProofGradePaperMainRuntimeAssurance
  rw [Bool.and_eq_true, Bool.and_eq_true]
  constructor
  · intro hCheck
    rcases hCheck with ⟨hKernelAndOutcome, hBoundary⟩
    rcases hKernelAndOutcome with ⟨hKernel, hOutcome⟩
    exact
      ⟨ (importedSeededRuntimePathOramKernelInterfaceFamily_check_eq_true_iff
            family
            modelTags).mp hKernel
      , (importedSeededRuntimePathOramWitnessFamily_checkPublicOutcomeUniform_eq_true_iff
            family).mp hOutcome
      , (importedSeededRuntimePathOramWitnessFamily_checkBoundaryScheduleUniform_eq_true_iff
            family).mp hBoundary
      ⟩
  · intro hAssurance
    exact
      ⟨ ⟨ (importedSeededRuntimePathOramKernelInterfaceFamily_check_eq_true_iff
              family
              modelTags).mpr hAssurance.1
        , (importedSeededRuntimePathOramWitnessFamily_checkPublicOutcomeUniform_eq_true_iff
              family).mpr hAssurance.2.1
        ⟩
      , (importedSeededRuntimePathOramWitnessFamily_checkBoundaryScheduleUniform_eq_true_iff
            family).mpr hAssurance.2.2
      ⟩

def parseAndCheckImportedProofGradeSeededRuntimePathOramPaperMainFamily
  (input : String)
  (modelTags : SGXModelTags) : Except String ImportedSeededRuntimePathOramWitnessFamily := do
  let family ← parseImportedSeededRuntimePathOramWitnessFamily input
  if checkImportedProofGradeSeededRuntimePathOramPaperMainFamily family modelTags then
    pure family
  else
    throw
      "imported proof-grade seeded path-ORAM runtime paper-main family does not satisfy Lean validity checks"

def loadAndCheckImportedProofGradeSeededRuntimePathOramPaperMainFamily
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedSeededRuntimePathOramWitnessFamily := do
  let input ← IO.FS.readFile path
  match
      parseAndCheckImportedProofGradeSeededRuntimePathOramPaperMainFamily
        input
        modelTags with
  | .ok family => pure family
  | .error err =>
      throw
        <| IO.userError
            s!"failed to validate proof-grade seeded path-ORAM runtime paper-main family: {err}"

structure ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily where
  seed_count : Nat
  witnesses : List ImportedRuntimeRefinementWitness
  public_leaf_scaffold : List ImportedRuntimeOramLeafScaffoldCertificate
  public_fresh_coin_scaffold : List ImportedRuntimeOramLeafScaffoldCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.witnessAt?
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (seed : Nat) : Option ImportedRuntimeRefinementWitness :=
  family.witnesses[seed]?

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.runtimeWitnessAt
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (seed : Nat) : RuntimeRefinementWitness :=
  match family.witnessAt? seed with
  | some witness => witness.toRuntimeWitness
  | none => sampleImportedRuntimeRefinementWitness.toRuntimeWitness

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.runtimePublicLeafScaffold
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily) :
  List RuntimePathOramLeafScaffoldStep :=
  family.public_leaf_scaffold.map
    ImportedRuntimeOramLeafScaffoldCertificate.toRuntimePathOramLeafScaffoldStep

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.projectedPublicLeafScaffold
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily) :
  PathOramLeafScheduleScaffold :=
  family.runtimePublicLeafScaffold.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.runtimePublicFreshCoinScaffold
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily) :
  List RuntimePathOramLeafScaffoldStep :=
  family.public_fresh_coin_scaffold.map
    ImportedRuntimeOramLeafScaffoldCertificate.toRuntimePathOramLeafScaffoldStep

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.projectedPublicFreshCoinScaffold
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily) :
  PathOramLeafScheduleScaffold :=
  family.runtimePublicFreshCoinScaffold.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.Valid
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Prop :=
  family.witnesses.length = family.seed_count ∧
    family.seed_count =
      pathOramLeafValueSeedSpaceSize family.projectedPublicFreshCoinScaffold ∧
    ∀ seed, seed < family.seed_count →
      ∃ witness,
        family.witnessAt? seed = some witness ∧
        witness.Valid modelTags ∧
        witness.toRuntimeWitness.oramLeafPublicScaffold =
          family.runtimePublicLeafScaffold ∧
        witness.toRuntimeWitness.pathOramFreshCoinScaffold? =
          some family.projectedPublicFreshCoinScaffold ∧
        witness.toRuntimeWitness.pathOramFreshCoinValues? =
          some (pathOramLeafValueTraceOfSeed family.projectedPublicFreshCoinScaffold seed)

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.checkValid
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) : Bool :=
  decide (family.witnesses.length = family.seed_count) &&
    decide
      (family.seed_count =
        pathOramLeafValueSeedSpaceSize family.projectedPublicFreshCoinScaffold) &&
    (List.range family.seed_count).all fun seed =>
      match family.witnessAt? seed with
      | some witness =>
          witness.checkValid modelTags &&
            decide
              (witness.toRuntimeWitness.oramLeafPublicScaffold =
                family.runtimePublicLeafScaffold) &&
            decide
              (witness.toRuntimeWitness.pathOramFreshCoinScaffold? =
                some family.projectedPublicFreshCoinScaffold) &&
            decide
              (witness.toRuntimeWitness.pathOramFreshCoinValues? =
                some
                  (pathOramLeafValueTraceOfSeed
                    family.projectedPublicFreshCoinScaffold
                    seed))
      | none => false

def ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.toCanonicalFreshCoinRuntimePathOramWitnessFamily
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags)
  (hValid : family.Valid modelTags) :
  CanonicalFreshCoinRuntimePathOramWitnessFamily modelTags :=
  { seedCount := family.seed_count
  , witnessAt := family.runtimeWitnessAt
  , valid := by
      intro seed hSeed
      rcases hValid.2.2 seed hSeed with
        ⟨witness, hGet, hWitnessValid, _hLeafScaffold, _hFreshScaffold, _hFreshValues⟩
      change (family.runtimeWitnessAt seed).Valid modelTags
      rw [ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.runtimeWitnessAt, hGet]
      simpa using hWitnessValid.1
  , publicLeafScaffold := family.projectedPublicLeafScaffold
  , publicLeafScaffoldExact := by
      intro seed hSeed
      rcases hValid.2.2 seed hSeed with
        ⟨witness, hGet, _hWitnessValid, hLeafScaffold, _hFreshScaffold, _hFreshValues⟩
      change
        List.map RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep
            (family.runtimeWitnessAt seed).oramLeafPublicScaffold =
          family.projectedPublicLeafScaffold
      rw [ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.runtimeWitnessAt, hGet]
      simpa
        [ ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.projectedPublicLeafScaffold
        , ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.runtimePublicLeafScaffold
        , RuntimeRefinementWitness.projectedPublicPathOramLeafScaffold
        ] using
        congrArg
          (List.map RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep)
          hLeafScaffold
  , publicFreshCoinScaffold := family.projectedPublicFreshCoinScaffold
  , freshCoinScaffoldExact := by
      intro seed hSeed
      rcases hValid.2.2 seed hSeed with
        ⟨witness, hGet, _hWitnessValid, _hLeafScaffold, hFreshScaffold, _hFreshValues⟩
      change
        (family.runtimeWitnessAt seed).pathOramFreshCoinScaffold? =
          some family.projectedPublicFreshCoinScaffold
      rw [ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.runtimeWitnessAt, hGet]
      simpa
        [ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.projectedPublicFreshCoinScaffold]
        using hFreshScaffold
  , freshCoinSeedSpaceExact := hValid.2.1
  , freshCoinValuesExact := by
      intro seed hSeed
      rcases hValid.2.2 seed hSeed with
        ⟨witness, hGet, _hWitnessValid, _hLeafScaffold, _hFreshScaffold, hFreshValues⟩
      change
        (family.runtimeWitnessAt seed).pathOramFreshCoinValues? =
          some
            (pathOramLeafValueTraceOfSeed family.projectedPublicFreshCoinScaffold seed)
      rw [ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.runtimeWitnessAt, hGet]
      simpa using hFreshValues
  }

def parseImportedCanonicalFreshCoinRuntimePathOramWitnessFamily
  (input : String) : Except String ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedCanonicalFreshCoinRuntimePathOramWitnessFamily
  (input : String)
  (modelTags : SGXModelTags) :
  Except String ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily := do
  let family ← parseImportedCanonicalFreshCoinRuntimePathOramWitnessFamily input
  if family.checkValid modelTags then
    pure family
  else
    throw "imported canonical fresh-coin path-ORAM runtime witness family does not satisfy Lean validity checks"

def loadImportedCanonicalFreshCoinRuntimePathOramWitnessFamily
  (path : System.FilePath) : IO ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily := do
  let input ← IO.FS.readFile path
  match parseImportedCanonicalFreshCoinRuntimePathOramWitnessFamily input with
  | .ok family => pure family
  | .error err =>
      throw <| IO.userError
        s!"failed to parse canonical fresh-coin path-ORAM runtime witness family: {err}"

def loadAndCheckImportedCanonicalFreshCoinRuntimePathOramWitnessFamily
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedCanonicalFreshCoinRuntimePathOramWitnessFamily input modelTags with
  | .ok family => pure family
  | .error err =>
      throw <| IO.userError
        s!"failed to validate canonical fresh-coin path-ORAM runtime witness family: {err}"

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramWitnessFamily_checkValid_eq_true_iff
  (family : ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
  (modelTags : SGXModelTags) :
  family.checkValid modelTags = true ↔ family.Valid modelTags := by
  constructor
  · intro hCheck
    rw [ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.checkValid, Bool.and_eq_true] at hCheck
    have hLenAndSeed := hCheck.1
    have hAll := hCheck.2
    rw [Bool.and_eq_true] at hLenAndSeed
    refine ⟨?_, ?_, ?_⟩
    · simpa using hLenAndSeed.1
    · simpa using hLenAndSeed.2
    · intro seed hSeed
      have hSeedCheck :
          (match family.witnessAt? seed with
            | some witness =>
                witness.checkValid modelTags &&
                  decide
                    (witness.toRuntimeWitness.oramLeafPublicScaffold =
                      family.runtimePublicLeafScaffold) &&
                  decide
                    (witness.toRuntimeWitness.pathOramFreshCoinScaffold? =
                      some family.projectedPublicFreshCoinScaffold) &&
                  decide
                    (witness.toRuntimeWitness.pathOramFreshCoinValues? =
                      some
                        (pathOramLeafValueTraceOfSeed
                          family.projectedPublicFreshCoinScaffold
                          seed))
            | none => false) = true := by
        exact (List.all_eq_true.mp hAll) seed (List.mem_range.mpr hSeed)
      cases hGet : family.witnessAt? seed with
      | none =>
          simp [hGet] at hSeedCheck
      | some witness =>
          have hWitness :
              witness.Valid modelTags ∧
              witness.toRuntimeWitness.oramLeafPublicScaffold =
                family.runtimePublicLeafScaffold ∧
              witness.toRuntimeWitness.pathOramFreshCoinScaffold? =
                some family.projectedPublicFreshCoinScaffold ∧
              witness.toRuntimeWitness.pathOramFreshCoinValues? =
                some
                  (pathOramLeafValueTraceOfSeed
                    family.projectedPublicFreshCoinScaffold
                    seed) := by
            have hWitnessBool :
                witness.checkValid modelTags = true ∧
                witness.toRuntimeWitness.oramLeafPublicScaffold =
                  family.runtimePublicLeafScaffold ∧
                witness.toRuntimeWitness.pathOramFreshCoinScaffold? =
                  some family.projectedPublicFreshCoinScaffold ∧
                witness.toRuntimeWitness.pathOramFreshCoinValues? =
                  some
                    (pathOramLeafValueTraceOfSeed
                      family.projectedPublicFreshCoinScaffold
                      seed) := by
              simpa [hGet, decide_eq_true_eq, and_assoc] using hSeedCheck
            refine
              ⟨ (importedWitness_checkValid_eq_true_iff witness modelTags).mp hWitnessBool.1
              , hWitnessBool.2.1
              , hWitnessBool.2.2.1
              , hWitnessBool.2.2.2
              ⟩
          refine ⟨witness, rfl, hWitness.1, hWitness.2.1, hWitness.2.2.1, hWitness.2.2.2⟩
  · intro hValid
    rw [ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily.checkValid, Bool.and_eq_true]
    refine ⟨?_, ?_⟩
    · rw [Bool.and_eq_true]
      exact ⟨by simpa using hValid.1, by simpa using hValid.2.1⟩
    · refine List.all_eq_true.mpr ?_
      intro seed hSeedMem
      have hSeed : seed < family.seed_count := List.mem_range.mp hSeedMem
      rcases hValid.2.2 seed hSeed with
        ⟨witness, hGet, hWitnessValid, hLeafScaffold, hFreshScaffold, hFreshValues⟩
      have hWitnessCheck :
          witness.checkValid modelTags = true :=
        (importedWitness_checkValid_eq_true_iff witness modelTags).2 hWitnessValid
      simp [hGet, hWitnessCheck, hLeafScaffold, hFreshScaffold, hFreshValues]

structure ImportedCanonicalFreshCoinRuntimePathOramTheoremInput where
  seed_count : Nat
  representative_seed : Nat
  representative_witness : ImportedRuntimeRefinementWitness
  public_leaf_scaffold : List ImportedRuntimeOramLeafScaffoldCertificate
  public_fresh_coin_scaffold : List ImportedRuntimeOramLeafScaffoldCertificate
deriving Repr, DecidableEq, FromJson, ToJson

def ImportedCanonicalFreshCoinRuntimePathOramTheoremInput.runtimeRepresentativeWitness
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput) : RuntimeRefinementWitness :=
  input.representative_witness.toRuntimeWitness

def ImportedCanonicalFreshCoinRuntimePathOramTheoremInput.runtimePublicLeafScaffold
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput) :
  List RuntimePathOramLeafScaffoldStep :=
  input.public_leaf_scaffold.map
    ImportedRuntimeOramLeafScaffoldCertificate.toRuntimePathOramLeafScaffoldStep

def ImportedCanonicalFreshCoinRuntimePathOramTheoremInput.projectedPublicLeafScaffold
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput) :
  PathOramLeafScheduleScaffold :=
  input.runtimePublicLeafScaffold.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def ImportedCanonicalFreshCoinRuntimePathOramTheoremInput.runtimePublicFreshCoinScaffold
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput) :
  List RuntimePathOramLeafScaffoldStep :=
  input.public_fresh_coin_scaffold.map
    ImportedRuntimeOramLeafScaffoldCertificate.toRuntimePathOramLeafScaffoldStep

def ImportedCanonicalFreshCoinRuntimePathOramTheoremInput.projectedPublicFreshCoinScaffold
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput) :
  PathOramLeafScheduleScaffold :=
  input.runtimePublicFreshCoinScaffold.map
    RuntimePathOramLeafScaffoldStep.toPathOramLeafScheduleScaffoldStep

def ImportedCanonicalFreshCoinRuntimePathOramTheoremInput.Valid
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput)
  (modelTags : SGXModelTags) : Prop :=
  input.representative_witness.Valid modelTags ∧
    input.seed_count =
      pathOramLeafValueSeedSpaceSize input.projectedPublicFreshCoinScaffold ∧
    input.representative_seed < input.seed_count ∧
    input.runtimeRepresentativeWitness.oramLeafPublicScaffold =
      input.runtimePublicLeafScaffold ∧
    input.runtimeRepresentativeWitness.pathOramFreshCoinScaffold? =
      some input.projectedPublicFreshCoinScaffold ∧
    input.runtimeRepresentativeWitness.pathOramFreshCoinValues? =
      some
        (pathOramLeafValueTraceOfSeed
          input.projectedPublicFreshCoinScaffold
          input.representative_seed)

def ImportedCanonicalFreshCoinRuntimePathOramTheoremInput.checkValid
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput)
  (modelTags : SGXModelTags) : Bool :=
  input.representative_witness.checkValid modelTags &&
    decide
      (input.seed_count =
        pathOramLeafValueSeedSpaceSize input.projectedPublicFreshCoinScaffold) &&
    decide (input.representative_seed < input.seed_count) &&
    decide
      (input.runtimeRepresentativeWitness.oramLeafPublicScaffold =
        input.runtimePublicLeafScaffold) &&
    decide
      (input.runtimeRepresentativeWitness.pathOramFreshCoinScaffold? =
        some input.projectedPublicFreshCoinScaffold) &&
    decide
      (input.runtimeRepresentativeWitness.pathOramFreshCoinValues? =
        some
          (pathOramLeafValueTraceOfSeed
            input.projectedPublicFreshCoinScaffold
            input.representative_seed))

def parseImportedCanonicalFreshCoinRuntimePathOramTheoremInput
  (input : String) : Except String ImportedCanonicalFreshCoinRuntimePathOramTheoremInput := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseAndCheckImportedCanonicalFreshCoinRuntimePathOramTheoremInput
  (input : String)
  (modelTags : SGXModelTags) :
  Except String ImportedCanonicalFreshCoinRuntimePathOramTheoremInput := do
  let theoremInput ← parseImportedCanonicalFreshCoinRuntimePathOramTheoremInput input
  if theoremInput.checkValid modelTags then
    pure theoremInput
  else
    throw "imported canonical fresh-coin path-ORAM theorem input does not satisfy Lean validity checks"

def loadImportedCanonicalFreshCoinRuntimePathOramTheoremInput
  (path : System.FilePath) : IO ImportedCanonicalFreshCoinRuntimePathOramTheoremInput := do
  let input ← IO.FS.readFile path
  match parseImportedCanonicalFreshCoinRuntimePathOramTheoremInput input with
  | .ok theoremInput => pure theoremInput
  | .error err =>
      throw <| IO.userError
        s!"failed to parse canonical fresh-coin path-ORAM theorem input: {err}"

def loadAndCheckImportedCanonicalFreshCoinRuntimePathOramTheoremInput
  (path : System.FilePath)
  (modelTags : SGXModelTags) : IO ImportedCanonicalFreshCoinRuntimePathOramTheoremInput := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedCanonicalFreshCoinRuntimePathOramTheoremInput input modelTags with
  | .ok theoremInput => pure theoremInput
  | .error err =>
      throw <| IO.userError
        s!"failed to validate canonical fresh-coin path-ORAM theorem input: {err}"

@[simp] theorem importedCanonicalFreshCoinRuntimePathOramTheoremInput_checkValid_eq_true_iff
  (input : ImportedCanonicalFreshCoinRuntimePathOramTheoremInput)
  (modelTags : SGXModelTags) :
  input.checkValid modelTags = true ↔ input.Valid modelTags := by
  simp
    [ ImportedCanonicalFreshCoinRuntimePathOramTheoremInput.checkValid
    , ImportedCanonicalFreshCoinRuntimePathOramTheoremInput.Valid
    , Bool.and_eq_true
    , and_assoc
    , decide_eq_true_eq
    ]

def sampleImportedCanonicalFreshCoinRuntimePathOramWitnessFamily :
  ImportedCanonicalFreshCoinRuntimePathOramWitnessFamily :=
  { seed_count := 1
  , witnesses := [sampleImportedRuntimeRefinementWitness]
  , public_leaf_scaffold := []
  , public_fresh_coin_scaffold := []
  }

def sampleImportedCanonicalFreshCoinRuntimePathOramWitnessFamilyRoundtrip : Bool :=
  match
      parseImportedCanonicalFreshCoinRuntimePathOramWitnessFamily
        (Json.compress (toJson sampleImportedCanonicalFreshCoinRuntimePathOramWitnessFamily))
    with
    | .ok family =>
        decide (family = sampleImportedCanonicalFreshCoinRuntimePathOramWitnessFamily)
    | .error _ => false

example : sampleImportedCanonicalFreshCoinRuntimePathOramWitnessFamilyRoundtrip = true := by
  native_decide

def sampleImportedCanonicalFreshCoinRuntimePathOramTheoremInput :
  ImportedCanonicalFreshCoinRuntimePathOramTheoremInput :=
  { seed_count := 1
  , representative_seed := 0
  , representative_witness := sampleImportedRuntimeRefinementWitness
  , public_leaf_scaffold := []
  , public_fresh_coin_scaffold := []
  }

def sampleImportedCanonicalFreshCoinRuntimePathOramTheoremInputRoundtrip : Bool :=
  match
      parseImportedCanonicalFreshCoinRuntimePathOramTheoremInput
        (Json.compress (toJson sampleImportedCanonicalFreshCoinRuntimePathOramTheoremInput))
    with
    | .ok theoremInput =>
        decide (theoremInput = sampleImportedCanonicalFreshCoinRuntimePathOramTheoremInput)
    | .error _ => false

example : sampleImportedCanonicalFreshCoinRuntimePathOramTheoremInputRoundtrip = true := by
  native_decide

def sampleImportedSeededRuntimeWitnessFamily : ImportedSeededRuntimeWitnessFamily :=
  { seed_count := 2
  , witnesses :=
      [ { sampleImportedRuntimeRefinementWitness with runtime_seed := some 0 }
      , { sampleImportedRuntimeRefinementWitness with runtime_seed := some 1 }
      ]
  }

def sampleImportedSeededRuntimePathOramWitnessFamily :
  ImportedSeededRuntimePathOramWitnessFamily :=
  { sampleImportedSeededRuntimeWitnessFamily with
    public_leaf_scaffold := []
  }

def sampleImportedSeededRuntimePathOramWitnessFamilyRoundtrip : Bool :=
  match
      parseImportedSeededRuntimePathOramWitnessFamily
        (Json.compress (toJson sampleImportedSeededRuntimePathOramWitnessFamily))
    with
    | .ok family => decide (family = sampleImportedSeededRuntimePathOramWitnessFamily)
    | .error _ => false

example : sampleImportedSeededRuntimePathOramWitnessFamilyRoundtrip = true := by
  native_decide

end UOToolchain
