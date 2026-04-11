import UOToolchain.TeeDeployment

namespace UOToolchain

inductive BoundaryDirection where
  | enter
  | exit
deriving Repr, DecidableEq

structure BoundaryEvent where
  direction : BoundaryDirection
  apiId : String
  inputLen : Nat
  outputLen : Nat
deriving Repr, DecidableEq

inductive PageEventKind where
  | faultIn
  | evictOut
deriving Repr, DecidableEq

structure PageEvent where
  pageKind : String
  pageId : Nat
  kind : PageEventKind
deriving Repr, DecidableEq

inductive ExitEvent where
  | interruptExit
  | resume
  | terminate
deriving Repr, DecidableEq

abbrev SharedResourceTrace := List String

structure SGXView where
  entrypointId : String
  publicArgs : List String
  boundarySchedule : List BoundaryEvent
  persistentReads : List PhysicalRead
  persistentWrites : List PhysicalWrite
  pageTrace : List PageEvent
  exitTrace : List ExitEvent
  sharedResourceTrace : SharedResourceTrace
  terminationStatus : Bool
  outputShape : OutputShape
  gasUsed : Nat
deriving Repr, DecidableEq

structure SGXSetupPublic where
  measurement : String
  attestationPolicy : String
deriving Repr, DecidableEq

abbrev SGXExecutionView := SGXSetupPublic × List SGXView
abbrev SGXSemantics (κ : Type) := κ → Distribution SGXView
abbrev SGXSecurityRelation := Distribution SGXView → Distribution SGXView → Prop

def SGXExecutionOblivious
  {κ : Type}
  (samePublic : κ → κ → Prop)
  (R : SGXSecurityRelation)
  (run : SGXSemantics κ) : Prop :=
  ∀ cfg₁ cfg₂, samePublic cfg₁ cfg₂ → R (run cfg₁) (run cfg₂)

def PhysicalSideChannelsExcluded : Prop := True
def RawTimingExcluded : Prop := True

end UOToolchain
