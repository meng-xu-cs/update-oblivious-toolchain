import UOToolchain.TraceModel

namespace UOToolchain

structure ObjectShape where
  objectId : Nat
  backend : String
  capacity : Nat
deriving Repr, DecidableEq

structure Program where
  contract : String
  entrypoint : String
  objects : List ObjectShape
deriving Repr, DecidableEq

structure Input where
  publicArgs : List String
  secretArgs : List String
deriving Repr, DecidableEq

structure Config where
  program : Program
  input : Input
  publicState : List String
  secretState : List String
deriving Repr, DecidableEq

structure PublicProjection where
  program : Program
  publicArgs : List String
  publicState : List String
deriving Repr, DecidableEq

abbrev Semantics := Config → Trace

def publicProjection (cfg : Config) : PublicProjection :=
  { program := cfg.program
  , publicArgs := cfg.input.publicArgs
  , publicState := cfg.publicState
  }

def samePublicProjection (lhs rhs : Config) : Prop :=
  publicProjection lhs = publicProjection rhs

theorem samePublicProjection_refl (cfg : Config) : samePublicProjection cfg cfg := rfl

theorem samePublicProjection_symm {lhs rhs : Config} :
    samePublicProjection lhs rhs → samePublicProjection rhs lhs := by
  intro h
  exact h.symm

theorem samePublicProjection_trans {a b c : Config} :
    samePublicProjection a b → samePublicProjection b c → samePublicProjection a c := by
  intro hab hbc
  exact hab.trans hbc

theorem samePublicProjection_program_eq {lhs rhs : Config} :
    samePublicProjection lhs rhs → lhs.program = rhs.program := by
  intro h
  exact congrArg PublicProjection.program h

theorem samePublicProjection_publicArgs_eq {lhs rhs : Config} :
    samePublicProjection lhs rhs → lhs.input.publicArgs = rhs.input.publicArgs := by
  intro h
  exact congrArg PublicProjection.publicArgs h

theorem samePublicProjection_publicState_eq {lhs rhs : Config} :
    samePublicProjection lhs rhs → lhs.publicState = rhs.publicState := by
  intro h
  exact congrArg PublicProjection.publicState h

end UOToolchain
