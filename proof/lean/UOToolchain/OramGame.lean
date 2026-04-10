import UOToolchain.TraceModel

namespace UOToolchain

structure OramLeakage where
  scheme : String
  blockSize : Nat
  bucketSize : Nat
  bucketCount : Nat
  blocksPerBucket : Nat
  treeHeight : Nat
  stashBound : Nat
  recursionDepth : Nat
  metadataPages : Nat
  metadataPagesPerAccess : Nat
  bucketsPerAccess : Nat
  accessesPerCall : Nat
deriving Repr, DecidableEq

abbrev Distribution (α : Type) := List α

axiom oramLocalTheorem
  (view₁ view₂ : Distribution ViewMPlus)
  (leakage : OramLeakage) :
  Prop

end UOToolchain
