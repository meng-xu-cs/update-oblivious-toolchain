import UOToolchain.IRSemantics

/-!
# Public environment and authorization boundary

This module records the F-14 boundary: caller and selected chain/context
variables are public inputs. Authorization branches may abort, but if their
guards depend only on this public environment and public state, they do not add
secret-dependent observer effects.
-/

namespace UOToolchain
namespace EnvironmentAuth

inductive PublicEnvField where
  | msgSender
  | txOrigin
  | blockNumber
  | blockTimestamp
  | blockChainId
deriving Repr, DecidableEq

def PublicEnvField.label : PublicEnvField → String
  | .msgSender => "msg.sender"
  | .txOrigin => "tx.origin"
  | .blockNumber => "block.number"
  | .blockTimestamp => "block.timestamp"
  | .blockChainId => "block.chainid"

abbrev PublicEnvironment := List (String × IR.Value)

def lookupPublicEnv (env : PublicEnvironment) (name : String) : Option IR.Value :=
  match env.find? (fun entry => entry.fst = name) with
  | some (_, value) => some value
  | none => none

structure PublicEnvironmentWellFormed (env : PublicEnvironment) : Prop where
  msgSender_public :
    ∃ value, lookupPublicEnv env PublicEnvField.msgSender.label = some value
  noSecretInputs : True

structure InitializationPolicy where
  initializer : String
  initialized : Bool
  deriving Repr, DecidableEq

def initializationAdmits (policy : InitializationPolicy) (entrypoint : String) : Bool :=
  if entrypoint = policy.initializer then
    !policy.initialized
  else
    policy.initialized

theorem initializationAdmits_initializer_before_setup
  (initializer : String) :
  initializationAdmits
    { initializer := initializer, initialized := false } initializer = true := by
  simp [initializationAdmits]

theorem initializationRejects_initializer_after_setup
  (initializer : String) :
  initializationAdmits
    { initializer := initializer, initialized := true } initializer = false := by
  simp [initializationAdmits]

def callerAuthorized
  (env : PublicEnvironment) (authorized : IR.Value) : Prop :=
  lookupPublicEnv env PublicEnvField.msgSender.label = some authorized

theorem callerAuthorization_public_env_determined
  {env₁ env₂ : PublicEnvironment} {authorized : IR.Value}
  (hEnv : env₁ = env₂) :
  callerAuthorized env₁ authorized ↔ callerAuthorized env₂ authorized := by
  simp [callerAuthorized, hEnv]

theorem operational_public_projection_includes_environment
  {cfg₁ cfg₂ : IR.OperationalConfig}
  (hPublic : IR.sameOperationalPublicProjection cfg₁ cfg₂) :
  cfg₁.publicEnv = cfg₂.publicEnv :=
  IR.sameOperationalPublicProjection_publicEnv_eq hPublic

theorem trace_public_projection_includes_environment
  {cfg₁ cfg₂ : Config}
  (hPublic : samePublicProjection cfg₁ cfg₂) :
  cfg₁.input.publicEnv = cfg₂.input.publicEnv :=
  samePublicProjection_publicEnv_eq hPublic

end EnvironmentAuth
end UOToolchain
