namespace UOToolchain

namespace RuntimeKernelMachineSchedule

inductive Effect where
  | cellGet
  | cellSet
  | arrayGet
  | arraySet
  | mapGet
  | mapPut
  | commit
  | finish
deriving Repr, DecidableEq

inductive ScratchRegion where
  | value
  | hash
  | io
deriving Repr, DecidableEq

inductive Action where
  | recordOpcode (opcode : String) (objectBearing : Bool)
  | recordKernelOp
  | reserveValueScratch (bound : String)
  | objectStoreCall (name : String)
  | appendCommitSchedule
  | wipeScratch (region : ScratchRegion)
  | finishSnapshot
deriving Repr, DecidableEq

def effectSchedule : Effect → List Action
  | Effect.cellGet =>
      [ Action.recordOpcode "CellGet" true
      , Action.recordKernelOp
      , Action.objectStoreCall "cell_get"
      ]
  | Effect.cellSet =>
      [ Action.recordOpcode "CellSet" true
      , Action.recordKernelOp
      , Action.reserveValueScratch "value_len"
      , Action.objectStoreCall "cell_set"
      ]
  | Effect.arrayGet =>
      [ Action.recordOpcode "ArrayGet" true
      , Action.recordKernelOp
      , Action.reserveValueScratch "32"
      , Action.objectStoreCall "array_get"
      ]
  | Effect.arraySet =>
      [ Action.recordOpcode "ArraySet" true
      , Action.recordKernelOp
      , Action.reserveValueScratch "max(value_len, 32)"
      , Action.objectStoreCall "array_set"
      ]
  | Effect.mapGet =>
      [ Action.recordOpcode "MapGet" true
      , Action.recordKernelOp
      , Action.reserveValueScratch "key_len"
      , Action.objectStoreCall "map_get"
      ]
  | Effect.mapPut =>
      [ Action.recordOpcode "MapPut" true
      , Action.recordKernelOp
      , Action.reserveValueScratch "max(key_len, value_len)"
      , Action.objectStoreCall "map_put"
      ]
  | Effect.commit =>
      [ Action.recordOpcode "Commit" false
      , Action.recordKernelOp
      , Action.objectStoreCall "commit_against"
      , Action.appendCommitSchedule
      ]
  | Effect.finish =>
      [ Action.recordOpcode "Wipe" false
      , Action.recordKernelOp
      , Action.wipeScratch ScratchRegion.value
      , Action.wipeScratch ScratchRegion.hash
      , Action.wipeScratch ScratchRegion.io
      , Action.finishSnapshot
      ]

theorem effectSchedule_startsWithPublicOpcodeAndKernelOp
  (effect : Effect) :
  ∃ opcode objectBearing tail,
    effectSchedule effect =
      Action.recordOpcode opcode objectBearing :: Action.recordKernelOp :: tail := by
  cases effect <;> simp [effectSchedule]

theorem objectEffectSchedule_hasObjectStoreCall
  (effect : Effect)
  (h : effect ≠ Effect.finish) :
  ∃ name, Action.objectStoreCall name ∈ effectSchedule effect := by
  cases effect <;> simp [effectSchedule] at h ⊢

theorem mutatingObjectEffectSchedule_hasBoundedValueScratch
  (effect : Effect)
  (h : effect = Effect.cellSet ∨ effect = Effect.arrayGet ∨
    effect = Effect.arraySet ∨ effect = Effect.mapGet ∨ effect = Effect.mapPut) :
  ∃ bound, Action.reserveValueScratch bound ∈ effectSchedule effect := by
  cases effect <;> simp [effectSchedule] at h ⊢

theorem finishSchedule_wipesAllScratchBeforeSnapshot :
  effectSchedule Effect.finish =
    [ Action.recordOpcode "Wipe" false
    , Action.recordKernelOp
    , Action.wipeScratch ScratchRegion.value
    , Action.wipeScratch ScratchRegion.hash
    , Action.wipeScratch ScratchRegion.io
    , Action.finishSnapshot
    ] := by
  rfl

end RuntimeKernelMachineSchedule

end UOToolchain
