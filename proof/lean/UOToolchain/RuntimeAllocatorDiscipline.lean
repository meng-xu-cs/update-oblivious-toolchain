namespace UOToolchain

namespace RuntimeAllocatorDiscipline

inductive Region where
  | value
  | hash
  | io
deriving Repr, DecidableEq

structure Plan where
  maxKernelOps : Nat
  maxStackWords : Nat
  scratchBytes : Nat
  /-- The entrypoint's commit operations (the manifest's `max_commit_ops`):
  the slots, pages and buckets the call writes. The call opens each one when
  it loads its object or reads its path and seals it when it writes it, and
  it opens a slot of an exact object once more to restore it when the call
  aborts or leaves the object unread: three reservations of scratch, each
  wiped, so six resource events each. -/
  maxCommitOps : Nat := 0
deriving Repr, DecidableEq

structure Usage where
  liveBytes : Nat
  peakBytes : Nat
  wipeCount : Nat
deriving Repr, DecidableEq

structure EventLog where
  capacity : Nat
  len : Nat
  overflowed : Bool
deriving Repr, DecidableEq

structure State where
  plan : Plan
  kernelOpCount : Nat
  peakStackWords : Nat
  valueScratch : Usage
  hashScratch : Usage
  ioScratch : Usage
  eventLog : EventLog
deriving Repr, DecidableEq

def resourceEventCapacity (plan : Plan) : Nat :=
  (plan.maxKernelOps + plan.maxStackWords) * 128 + 128 + plan.maxCommitOps * 6

def emptyUsage : Usage :=
  { liveBytes := 0, peakBytes := 0, wipeCount := 0 }

def initialState (plan : Plan) : State :=
  { plan
  , kernelOpCount := 0
  , peakStackWords := 0
  , valueScratch := emptyUsage
  , hashScratch := emptyUsage
  , ioScratch := emptyUsage
  , eventLog :=
      { capacity := resourceEventCapacity plan
      , len := 0
      , overflowed := false
      }
  }

def getUsage (state : State) : Region → Usage
  | Region.value => state.valueScratch
  | Region.hash => state.hashScratch
  | Region.io => state.ioScratch

def setUsage (state : State) (region : Region) (usage : Usage) : State :=
  match region with
  | Region.value => { state with valueScratch := usage }
  | Region.hash => { state with hashScratch := usage }
  | Region.io => { state with ioScratch := usage }

def pushEvent (log : EventLog) : EventLog :=
  if log.len < log.capacity then
    { log with len := log.len + 1 }
  else
    { log with overflowed := true }

def recordKernelOp (state : State) : Option State :=
  if state.kernelOpCount < state.plan.maxKernelOps then
    some { state with kernelOpCount := state.kernelOpCount + 1 }
  else
    none

def reserveScratch (state : State) (region : Region) (bytes : Nat) :
    Option State :=
  if bytes ≤ state.plan.scratchBytes then
    let usage := getUsage state region
    let usage' :=
      { liveBytes := bytes
      , peakBytes := max usage.peakBytes bytes
      , wipeCount := usage.wipeCount
      }
    some { setUsage state region usage' with eventLog := pushEvent state.eventLog }
  else
    none

def wipeScratch (state : State) (region : Region) : State :=
  let usage := getUsage state region
  let usage' :=
    { liveBytes := 0
    , peakBytes := usage.peakBytes
    , wipeCount := usage.wipeCount + 1
    }
  { setUsage state region usage' with eventLog := pushEvent state.eventLog }

def enforceStackWords (state : State) (words : Nat) : Option State :=
  if words ≤ state.plan.maxStackWords then
    some
      { state with
        peakStackWords := max state.peakStackWords words
        eventLog := pushEvent state.eventLog
      }
  else
    none

def regionWipedAtFinish (usage : Usage) : Prop :=
  usage.liveBytes = 0 ∧ (usage.peakBytes ≠ 0 → usage.wipeCount ≠ 0)

def finishAccepted (state : State) : Prop :=
  state.eventLog.overflowed = false ∧
    regionWipedAtFinish state.valueScratch ∧
    regionWipedAtFinish state.hashScratch ∧
    regionWipedAtFinish state.ioScratch

theorem initialState_eventLogCapacity (plan : Plan) :
    (initialState plan).eventLog.capacity = resourceEventCapacity plan := by
  rfl

theorem resourceEventCapacity_public_formula (plan : Plan) :
    resourceEventCapacity plan =
      (plan.maxKernelOps + plan.maxStackWords) * 128 + 128 + plan.maxCommitOps * 6 := by
  rfl

theorem recordKernelOp_acceptsOnlyBelowBudget
    {state next : State}
    (h : recordKernelOp state = some next) :
    state.kernelOpCount < state.plan.maxKernelOps := by
  unfold recordKernelOp at h
  split at h
  · assumption
  · contradiction

theorem recordKernelOp_incrementsByOne
    {state next : State}
    (h : recordKernelOp state = some next) :
    next.kernelOpCount = state.kernelOpCount + 1 := by
  unfold recordKernelOp at h
  split at h
  · injection h with hnext
    rw [← hnext]
  · contradiction

theorem reserveScratch_acceptsOnlyWithinBudget
    {state next : State} {region : Region} {bytes : Nat}
    (h : reserveScratch state region bytes = some next) :
    bytes ≤ state.plan.scratchBytes := by
  unfold reserveScratch at h
  split at h
  · assumption
  · contradiction

theorem reserveScratch_setsLiveBytes
    {state next : State} {region : Region} {bytes : Nat}
    (h : reserveScratch state region bytes = some next) :
    (getUsage next region).liveBytes = bytes := by
  unfold reserveScratch at h
  split at h
  · injection h with hnext
    rw [← hnext]
    cases region <;> rfl
  · contradiction

theorem wipeScratch_clearsLiveBytes
    (state : State) (region : Region) :
    (getUsage (wipeScratch state region) region).liveBytes = 0 := by
  cases region <;> rfl

theorem enforceStackWords_acceptsOnlyWithinBudget
    {state next : State} {words : Nat}
    (h : enforceStackWords state words = some next) :
    words ≤ state.plan.maxStackWords := by
  unfold enforceStackWords at h
  split at h
  · assumption
  · contradiction

theorem finishAccepted_impliesNoResourceEventOverflow
    {state : State}
    (h : finishAccepted state) :
    state.eventLog.overflowed = false :=
  h.1

theorem finishAccepted_impliesAllScratchWiped
    {state : State}
    (h : finishAccepted state) :
    regionWipedAtFinish state.valueScratch ∧
      regionWipedAtFinish state.hashScratch ∧
      regionWipedAtFinish state.ioScratch :=
  h.2

end RuntimeAllocatorDiscipline

end UOToolchain
