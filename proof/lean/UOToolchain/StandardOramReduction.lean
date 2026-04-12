import UOToolchain.OramGame

namespace UOToolchain

structure OramViewPublicPart where
  opcodeTrace : List String
  logicalAccesses : List LogicalEvent
  logicalWrites : List LogicalEvent
  gasUsed : Nat
deriving Repr, DecidableEq

structure OramStorageView where
  physicalReads : List PhysicalRead
  physicalWrites : List PhysicalWrite
deriving Repr, DecidableEq

def oramViewPublicPart (view : ViewMPlus) : OramViewPublicPart :=
  match view with
  | (opcodeTrace, logicalAccesses, logicalWrites, _physicalReads, _physicalWrites, gasUsed) =>
      { opcodeTrace := opcodeTrace
      , logicalAccesses := logicalAccesses
      , logicalWrites := logicalWrites
      , gasUsed := gasUsed
      }

def oramStorageView (view : ViewMPlus) : OramStorageView :=
  match view with
  | (_opcodeTrace, _logicalAccesses, _logicalWrites, physicalReads, physicalWrites, _gasUsed) =>
      { physicalReads := physicalReads
      , physicalWrites := physicalWrites
      }

def assembleOramView
  (publicPart : OramViewPublicPart)
  (storageView : OramStorageView) : ViewMPlus :=
  ( publicPart.opcodeTrace
  , publicPart.logicalAccesses
  , publicPart.logicalWrites
  , storageView.physicalReads
  , storageView.physicalWrites
  , publicPart.gasUsed
  )

@[simp] theorem oramViewPublicPart_assembleOramView
  (publicPart : OramViewPublicPart)
  (storageView : OramStorageView) :
  oramViewPublicPart (assembleOramView publicPart storageView) = publicPart := by
  cases publicPart
  rfl

@[simp] theorem oramStorageView_assembleOramView
  (publicPart : OramViewPublicPart)
  (storageView : OramStorageView) :
  oramStorageView (assembleOramView publicPart storageView) = storageView := by
  cases publicPart
  cases storageView
  rfl

@[simp] theorem assembleOramView_oramViewPublicPart_oramStorageView
  (view : ViewMPlus) :
  assembleOramView (oramViewPublicPart view) (oramStorageView view) = view := by
  cases view
  rfl

@[simp] theorem map_oramStorageView_assembleOramView
  (publicPart : OramViewPublicPart)
  (views : Distribution OramStorageView) :
  views.map (fun storage => oramStorageView (assembleOramView publicPart storage)) = views := by
  induction views with
  | nil =>
      rfl
  | cons head tail ih =>
      simp

def OramConstantProjection
  {α β : Type}
  (project : α → β)
  (views : Distribution α)
  (value : β) : Prop :=
  ∀ view, view ∈ views → project view = value

def OramExactProjectionRelation
  {α β : Type}
  (project : α → β)
  (views₁ views₂ : Distribution α) : Prop :=
  ∃ value,
    OramConstantProjection project views₁ value ∧
    OramConstantProjection project views₂ value

theorem oramExactProjectionRelation_of_constant
  {α β : Type}
  {project : α → β}
  {views₁ views₂ : Distribution α}
  {value₁ value₂ : β}
  (hValue : value₁ = value₂)
  (hViews₁ : OramConstantProjection project views₁ value₁)
  (hViews₂ : OramConstantProjection project views₂ value₂) :
  OramExactProjectionRelation project views₁ views₂ := by
  refine ⟨value₁, hViews₁, ?_⟩
  intro view hMem
  rw [hValue]
  exact hViews₂ view hMem

theorem oramConstantProjection_map_of_const
  {α β γ : Type}
  (project : β → γ)
  (value : γ)
  (f : α → β)
  (views : Distribution α)
  (hConst : ∀ view, view ∈ views → project (f view) = value) :
  OramConstantProjection project (views.map f) value := by
  intro projectedView hMem
  simp at hMem
  rcases hMem with ⟨view, hView, rfl⟩
  exact hConst view hView

abbrev StandardOramStorageRelation :=
  Distribution OramStorageView → Distribution OramStorageView → List OramAccessLeakage → Prop

structure StandardOramSecurityInterface where
  storageRel : StandardOramStorageRelation

def standardOramViewRelation
  (security : StandardOramSecurityInterface)
  (views₁ views₂ : Distribution ViewMPlus)
  (leakage : List OramAccessLeakage) : Prop :=
  OramExactProjectionRelation oramViewPublicPart views₁ views₂ ∧
    security.storageRel
      (views₁.map oramStorageView)
      (views₂.map oramStorageView)
      leakage

def StandardOramSecurityInterface.toOramSecurityInterface
  (security : StandardOramSecurityInterface) : OramSecurityInterface :=
  { localTheorem := standardOramViewRelation security }

abbrev OramStorageSemantics := OramConfig → Distribution OramStorageView

def liftOramStorageSemantics
  (publicPart : OramConfig → OramViewPublicPart)
  (run : OramStorageSemantics) : OramSemantics :=
  fun cfg => (run cfg).map (assembleOramView (publicPart cfg))

def OramPublicViewSafe (publicPart : OramConfig → OramViewPublicPart) : Prop :=
  ∀ cfg₁ cfg₂, sameOramPublicProjection cfg₁ cfg₂ → publicPart cfg₁ = publicPart cfg₂

def ComputationalStandardOramWith
  (security : StandardOramSecurityInterface)
  (run : OramStorageSemantics) : Prop :=
  ∀ cfg₁ cfg₂,
    sameOramPublicProjection cfg₁ cfg₂ →
    security.storageRel (run cfg₁) (run cfg₂) (executionLeakage cfg₁)

theorem computationalStandardOram_projects_to_computationalUOWith
  (security : StandardOramSecurityInterface)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  (hPublic : OramPublicViewSafe publicPart)
  (hStorage : ComputationalStandardOramWith security run) :
  ComputationalUOWith
    (security.toOramSecurityInterface)
    (liftOramStorageSemantics publicPart run) := by
  intro cfg₁ cfg₂ hSame
  constructor
  · apply oramExactProjectionRelation_of_constant (hPublic cfg₁ cfg₂ hSame)
    · refine oramConstantProjection_map_of_const oramViewPublicPart (publicPart cfg₁) _ (run cfg₁) ?_
      intro storage hMem
      simp
    · refine oramConstantProjection_map_of_const oramViewPublicPart (publicPart cfg₂) _ (run cfg₂) ?_
      intro storage hMem
      simp
  · have hMap₁ :
        (liftOramStorageSemantics publicPart run cfg₁).map oramStorageView = run cfg₁ := by
      unfold liftOramStorageSemantics
      rw [List.map_map]
      change
        (run cfg₁).map
          (fun storage => oramStorageView (assembleOramView (publicPart cfg₁) storage)) =
          run cfg₁
      exact map_oramStorageView_assembleOramView (publicPart cfg₁) (run cfg₁)
    have hMap₂ :
        (liftOramStorageSemantics publicPart run cfg₂).map oramStorageView = run cfg₂ := by
      unfold liftOramStorageSemantics
      rw [List.map_map]
      change
        (run cfg₂).map
          (fun storage => oramStorageView (assembleOramView (publicPart cfg₂) storage)) =
          run cfg₂
      exact map_oramStorageView_assembleOramView (publicPart cfg₂) (run cfg₂)
    rw [hMap₁, hMap₂]
    exact hStorage cfg₁ cfg₂ hSame

theorem standardOramViewRelation_of_publicStorage
  (security : StandardOramSecurityInterface)
  {publicPart : OramConfig → OramViewPublicPart}
  {run : OramStorageSemantics}
  (cfg₁ cfg₂ : OramConfig)
  (hSame : sameOramPublicProjection cfg₁ cfg₂)
  (hPublic : OramPublicViewSafe publicPart)
  (hStorage : security.storageRel (run cfg₁) (run cfg₂) (executionLeakage cfg₁)) :
  standardOramViewRelation
    security
    (liftOramStorageSemantics publicPart run cfg₁)
    (liftOramStorageSemantics publicPart run cfg₂)
    (executionLeakage cfg₁) := by
  constructor
  · apply oramExactProjectionRelation_of_constant (hPublic cfg₁ cfg₂ hSame)
    · refine oramConstantProjection_map_of_const oramViewPublicPart (publicPart cfg₁) _ (run cfg₁) ?_
      intro storage hMem
      simp
    · refine oramConstantProjection_map_of_const oramViewPublicPart (publicPart cfg₂) _ (run cfg₂) ?_
      intro storage hMem
      simp
  · have hMap₁ :
        (liftOramStorageSemantics publicPart run cfg₁).map oramStorageView = run cfg₁ := by
      unfold liftOramStorageSemantics
      rw [List.map_map]
      change
        (run cfg₁).map
          (fun storage => oramStorageView (assembleOramView (publicPart cfg₁) storage)) =
          run cfg₁
      exact map_oramStorageView_assembleOramView (publicPart cfg₁) (run cfg₁)
    have hMap₂ :
        (liftOramStorageSemantics publicPart run cfg₂).map oramStorageView = run cfg₂ := by
      unfold liftOramStorageSemantics
      rw [List.map_map]
      change
        (run cfg₂).map
          (fun storage => oramStorageView (assembleOramView (publicPart cfg₂) storage)) =
          run cfg₂
      exact map_oramStorageView_assembleOramView (publicPart cfg₂) (run cfg₂)
    rw [hMap₁, hMap₂]
    exact hStorage

end UOToolchain
