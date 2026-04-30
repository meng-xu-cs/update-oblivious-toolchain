import Lean.Data.Json
import UOToolchain.RuntimeKernelDslJson

open Lean

namespace UOToolchain

structure ImportedProofRelevantStateObjectView where
  id : Nat
  name : String
  kind : String
  backend : String
  oram_scheme : String
  value_type : String
  value_type_short_name : String
  key_type : Option String
  key_type_short_name : Option String
  capacity : Option Nat
  confidential : Bool
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedProofRelevantParamView where
  name : String
  ty : String
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedProofRelevantFunctionView where
  signature : String
  params : List ImportedProofRelevantParamView
  public_env : List String
  return_type : Option String
  body : List String
  secret_args : List Nat
  confidential : Bool
  confidential_program : Option String
  confidential_slot_program : Option String
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedProofRelevantOramView where
  scheme : String
  block_size : Nat
  bucket_size : Nat
  bucket_count : Nat
  blocks_per_bucket : Nat
  tree_height : Nat
  stash_bound : Nat
  recursion_depth : Nat
  metadata_pages : Nat
  metadata_pages_per_access : Nat
  buckets_per_access : Nat
  accesses_per_call : Nat
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedProofRelevantManifestObjectView where
  id : Nat
  name : String
  kind : String
  backend : String
  capacity : Option Nat
  value_type : Option String
  key_type : Option String
  oram : Option ImportedProofRelevantOramView
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedProofRelevantKernelStepView where
  opcode : String
  object_id : Option Nat
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedProofRelevantOramAccessView where
  object_id : Nat
  accesses : Nat
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedProofRelevantEntrypointView where
  signature : String
  secret_args : List Nat
  param_names : List String
  public_env : List String
  entry_input_len : Nat
  initializer : Bool
  requires_initialized : Bool
  public_gas_budget : Nat
  arena_bytes : Nat
  max_stack_words : Nat
  max_hash_part_bytes : Nat
  return_canonical_len : Option Nat
  returns : String
  status : String
  declassifies : List String
  public_state_declassifies : List String
  confidential_program : Option String
  confidential_slot_program : Option String
  kernel_steps : List ImportedProofRelevantKernelStepView
  uocell_reads : Nat
  uocell_writes : Nat
  uoarray_reads : Nat
  uoarray_writes : Nat
  uomap_reads : Nat
  uomap_writes : Nat
  max_commit_ops : Nat
  oram_accesses : List ImportedProofRelevantOramAccessView
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedProofRelevantManifestView where
  contract : String
  compilation_mode : String
  objects : List ImportedProofRelevantManifestObjectView
  entrypoints : List ImportedProofRelevantEntrypointView
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedProofRelevantContractView where
  contract : String
  mode : String
  state : List ImportedProofRelevantStateObjectView
  functions : List ImportedProofRelevantFunctionView
  manifest : ImportedProofRelevantManifestView
deriving Repr, DecidableEq, FromJson, ToJson

structure ImportedAdmittedPackageIdentity where
  schema : String
  source_language : String
  source_sha256 : String
  metadata_sha256 : String
  raw_metadata_sha256 : String
  metadata_canonicalization_sha256 : String
  compilation_mode : String
  compiler_version : String
  toolchain_manifest_sha256 : String
  package_sha256 : String
deriving Repr, DecidableEq, FromJson, ToJson

private def admittedPackageSchema : String := "uo-admitted-package-v5"
private def admittedPackageSourceLanguage : String := "uo-solidity-like-dsl-v1"

def ImportedAdmittedPackageIdentity.WellFormed
  (identity : ImportedAdmittedPackageIdentity) : Prop :=
  identity.schema = admittedPackageSchema ∧
    identity.source_language = admittedPackageSourceLanguage ∧
    identity.raw_metadata_sha256.length = 64 ∧
    identity.metadata_canonicalization_sha256.length = 64 ∧
    identity.toolchain_manifest_sha256.length = 64

instance (identity : ImportedAdmittedPackageIdentity) :
    Decidable identity.WellFormed := by
  unfold ImportedAdmittedPackageIdentity.WellFormed
  infer_instance

def ImportedAdmittedPackageIdentity.checkWellFormed
  (identity : ImportedAdmittedPackageIdentity) : Bool :=
  (identity.schema == admittedPackageSchema) &&
    (identity.source_language == admittedPackageSourceLanguage) &&
    (identity.raw_metadata_sha256.length == 64) &&
    (identity.metadata_canonicalization_sha256.length == 64) &&
    (identity.toolchain_manifest_sha256.length == 64)

@[simp] theorem importedAdmittedPackageIdentity_checkWellFormed_eq_true_iff
  (identity : ImportedAdmittedPackageIdentity) :
  identity.checkWellFormed = true ↔ identity.WellFormed := by
  unfold ImportedAdmittedPackageIdentity.checkWellFormed
    ImportedAdmittedPackageIdentity.WellFormed
  simp [and_assoc]

structure ImportedProofRelevantTranslationBundle where
  source_path : String
  metadata_contract : String
  source_admitted_package : Option ImportedAdmittedPackageIdentity
  artifact_admitted_package : Option ImportedAdmittedPackageIdentity
  source_contract_json : String
  artifact_contract_json : String
  source_view : ImportedProofRelevantContractView
  artifact_view : ImportedProofRelevantContractView
deriving Repr, DecidableEq, BEq, FromJson, ToJson

private def distinctList [BEq α] : List α → Bool
  | [] => true
  | x :: xs => !(xs.contains x) && distinctList xs

private def listedSubset [BEq α] : List α → List α → Bool
  | [], _ => true
  | x :: xs, ys => ys.contains x && listedSubset xs ys

private def listedEquivalent [BEq α] (lhs rhs : List α) : Bool :=
  listedSubset lhs rhs && listedSubset rhs lhs

def lookupEntrypoint
  (signature : String) :
  List ImportedProofRelevantEntrypointView → Option ImportedProofRelevantEntrypointView
  | [] => none
  | entry :: rest =>
      if entry.signature == signature then
        some entry
      else
        lookupEntrypoint signature rest

def publicEnvFieldParamName : String → String
  | "msg_sender" => "__uo_env_msg_sender"
  | "tx_origin" => "__uo_env_tx_origin"
  | "block_number" => "__uo_env_block_number"
  | "block_timestamp" => "__uo_env_block_timestamp"
  | "block_chain_id" => "__uo_env_block_chainid"
  | other => s!"__uo_env_unknown_{other}"

def publicEnvParamNames (fields : List String) : List String :=
  fields.map publicEnvFieldParamName

private def functionsMatchManifestSecrets :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → Bool
  | [], _ => true
  | fn :: rest, entrypoints =>
      match lookupEntrypoint fn.signature entrypoints with
      | none => false
      | some entry =>
          (entry.secret_args == fn.secret_args) &&
            (entry.param_names == fn.params.map ImportedProofRelevantParamView.name) &&
            (entry.public_env == fn.public_env) &&
            functionsMatchManifestSecrets rest entrypoints

private def publicStateDeclassifyTargetsWellFormed
  (state : List ImportedProofRelevantStateObjectView)
  (targets : List String) : Bool :=
  distinctList targets &&
    targets.all (fun target =>
      match state.find? (fun object => object.name == target) with
      | some object => object.confidential == false
      | none => false)

private def functionSecretPolicyWellFormed
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  (if fn.confidential then true else fn.secret_args.isEmpty) &&
    (entry.secret_args == fn.secret_args)

structure CountSummary where
  localCount : Nat := 0
  cellReads : Nat := 0
  cellWrites : Nat := 0
  arrayReads : Nat := 0
  arrayWrites : Nat := 0
  mapReads : Nat := 0
  mapWrites : Nat := 0
deriving Repr, DecidableEq

private def CountSummary.add (lhs rhs : CountSummary) : CountSummary :=
  { localCount := lhs.localCount + rhs.localCount
  , cellReads := lhs.cellReads + rhs.cellReads
  , cellWrites := lhs.cellWrites + rhs.cellWrites
  , arrayReads := lhs.arrayReads + rhs.arrayReads
  , arrayWrites := lhs.arrayWrites + rhs.arrayWrites
  , mapReads := lhs.mapReads + rhs.mapReads
  , mapWrites := lhs.mapWrites + rhs.mapWrites
  }

private def parseJsonString (input : String) : Except String Json :=
  Lean.Json.parse input

private def objectEntries (json : Json) : Except String (List (String × Json)) :=
  match json with
  | Json.obj obj => pure obj.toList
  | _ => throw "expected JSON object"

private def lookupFieldJson (json : Json) (field : String) : Except String Json := do
  let entries ← objectEntries json
  match entries.find? (fun entry => entry.fst == field) with
  | some (_, value) => pure value
  | none => throw s!"missing object field {field}"

private def lookupFieldAs [FromJson α] (json : Json) (field : String) : Except String α := do
  fromJson? (← lookupFieldJson json field)

private def lookupOptionalFieldJson (json : Json) (field : String) : Except String (Option Json) := do
  let entries ← objectEntries json
  match entries.find? (fun entry => entry.fst == field) with
  | none => pure none
  | some (_, Json.null) => pure none
  | some (_, value) => pure (some value)

private def lookupOptionalFieldAs [FromJson α]
  (json : Json) (field : String) : Except String (Option α) := do
  match ← lookupOptionalFieldJson json field with
  | none => pure none
  | some value => some <$> fromJson? value

private def expectTaggedPayload (json : Json) (tag : String) : Except String Json := do
  let entries ← objectEntries json
  match entries with
  | [(actualTag, payload)] =>
      if actualTag == tag then
        pure payload
      else
        throw s!"expected tag {tag}, found {actualTag}"
  | _ => throw s!"expected externally-tagged JSON object for {tag}"

private def taggedPayload? (json : Json) (tag : String) : Option Json :=
  match json with
  | Json.obj obj =>
      match obj.toList with
      | [(actualTag, payload)] =>
          if actualTag == tag then
            some payload
          else
            none
      | _ => none
  | _ => none

private def uint256Modulus : Nat := 2 ^ 256

private def uint256 (value : Nat) : Nat :=
  value % uint256Modulus

private def uint256Sub (lhs rhs : Nat) : Nat :=
  uint256 (uint256 lhs + uint256Modulus - uint256 rhs)

private def uint256Literal? (value : Nat) : Option Nat :=
  if value < uint256Modulus then
    some value
  else
    none

private def asUintLiteral? (json : Json) : Option Nat :=
  match taggedPayload? json "Uint" with
  | some payload =>
      match (fromJson? payload : Except String Nat) with
      | .ok value => uint256Literal? value
      | .error _ =>
          match (fromJson? payload : Except String String) with
          | .ok value =>
              match value.toNat? with
              | some parsed => uint256Literal? parsed
              | none => none
          | .error _ => none
  | none => none

private def asBoolLiteral? (json : Json) : Option Nat :=
  match taggedPayload? json "Bool" with
  | some payload =>
      match fromJson? payload with
      | .ok true => some 1
      | .ok false => some 0
      | .error _ => none
  | none => none

def stateObjectById?
  (state : List ImportedProofRelevantStateObjectView)
  (objectId : Nat) : Option ImportedProofRelevantStateObjectView :=
  state.find? (fun object => object.id == objectId)

def manifestObjectById?
  (objects : List ImportedProofRelevantManifestObjectView)
  (objectId : Nat) : Option ImportedProofRelevantManifestObjectView :=
  objects.find? (fun object => object.id == objectId)

private def lookupOramAccessCount
  (objectId : Nat)
  (accesses : List ImportedProofRelevantOramAccessView) : Nat :=
  match accesses.find? (fun access => access.object_id == objectId) with
  | some access => access.accesses
  | none => 0

private def expectJsonArray (json : Json) : Except String (List Json) :=
  match json with
  | Json.arr arr => pure arr.toList
  | _ => throw "expected JSON array"

private def rawProgramModeTag (raw : String) : Except String String :=
  match raw with
  | "Raw" => pure "raw"
  | "Uo" => pure "uo"
  | other => throw s!"unsupported program mode tag {other}"

private def rawContainerKindTag (raw : String) : Except String String :=
  match raw with
  | "Cell" => pure "cell"
  | "Array" => pure "array"
  | "Map" => pure "map"
  | other => throw s!"unsupported container kind tag {other}"

private def rawBackendKindTag (raw : String) : Except String String :=
  match raw with
  | "Raw" => pure "raw"
  | "FullScan" => pure "full_scan"
  | "Oram" => pure "oram"
  | other => throw s!"unsupported backend kind tag {other}"

private def scalarTypeShortNameFromJson (json : Json) : Except String String := do
  match json with
  | Json.str "Bool" => pure "bool"
  | Json.str "Bytes32" => pure "bytes32"
  | Json.str "Address" => pure "address"
  | Json.obj obj =>
      match obj.toList with
      | [("Uint", payload)] =>
          let bits : Nat ← fromJson? payload
          pure s!"uint{bits}"
      | _ => throw "unsupported scalar type encoding"
  | _ => throw "unsupported scalar type encoding"

private partial def typeShortNameFromJson (json : Json) : Except String String := do
  if let some payload := taggedPayload? json "Scalar" then
    scalarTypeShortNameFromJson payload
  else if let some payload := taggedPayload? json "Struct" then
    let fields ← expectJsonArray payload
    let rendered ← fields.mapM fun fieldJson => do
      let name : String ← lookupFieldAs fieldJson "name"
      let tyJson ← lookupFieldJson fieldJson "ty"
      pure s!"{name}:{← typeShortNameFromJson tyJson}"
    let inner := String.intercalate "," rendered
    pure ("struct{" ++ inner ++ "}")
  else if let some payload := taggedPayload? json "Array" then
    let items ← expectJsonArray payload
    match items with
    | [elementJson, sizeJson] =>
        let size : Nat ← fromJson? sizeJson
        pure s!"{← typeShortNameFromJson elementJson}[{size}]"
    | _ => throw "unsupported array type encoding"
  else
    throw "unsupported type encoding"

private partial def typeCanonicalLenFromJson (json : Json) : Except String Nat := do
  if let some payload := taggedPayload? json "Scalar" then
    match payload with
    | Json.str "Bool" => pure 1
    | Json.str "Bytes32" => pure 32
    | Json.str "Address" => pure 20
    | Json.obj obj =>
        match obj.toList with
        | [("Uint", _)] => pure 32
        | _ => throw "unsupported scalar type encoding"
    | _ => throw "unsupported scalar type encoding"
  else if let some payload := taggedPayload? json "Struct" then
    let fields ← expectJsonArray payload
    fields.foldlM
      (init := 0)
      (fun acc fieldJson => do
        let name : String ← lookupFieldAs fieldJson "name"
        let tyJson ← lookupFieldJson fieldJson "ty"
        pure (acc + 4 + name.length + 4 + (← typeCanonicalLenFromJson tyJson)))
  else if let some payload := taggedPayload? json "Array" then
    let items ← expectJsonArray payload
    match items with
    | [elementJson, sizeJson] =>
        let size : Nat ← fromJson? sizeJson
        pure (size * (4 + (← typeCanonicalLenFromJson elementJson)))
    | _ => throw "unsupported array type encoding"
  else
    throw "unsupported type encoding"

private def typeCanonicalLenFromRawString (input : String) : Except String Nat := do
  typeCanonicalLenFromJson (← parseJsonString input)

def expectedEntrypointInputLen
  (fn : ImportedProofRelevantFunctionView) : Except String Nat := do
  let lengths ← fn.params.mapM fun param => typeCanonicalLenFromRawString param.ty
  pure (lengths.foldl (· + ·) 0)

def expectedReturnCanonicalLen
  (fn : ImportedProofRelevantFunctionView) : Except String (Option Nat) := do
  match fn.return_type with
  | none => pure none
  | some ty => some <$> typeCanonicalLenFromRawString ty

private def functionBoundaryLengthsMatchManifest
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  match expectedEntrypointInputLen fn, expectedReturnCanonicalLen fn with
  | .ok expectedInputLen, .ok expectedReturnLen =>
      entry.entry_input_len == expectedInputLen &&
        entry.return_canonical_len == expectedReturnLen
  | _, _ => false

private def functionBoundaryLengthMismatchMessage
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : String :=
  match expectedEntrypointInputLen fn, expectedReturnCanonicalLen fn with
  | .error err, _
  | _, .error err =>
      s!"{fn.signature}: failed to compute manifest boundary lengths: {err}"
  | .ok expectedInputLen, .ok expectedReturnLen =>
      s!"{fn.signature}: expected entry_input_len={expectedInputLen}, return_canonical_len={expectedReturnLen}; manifest has entry_input_len={entry.entry_input_len}, return_canonical_len={entry.return_canonical_len}"

private def insertOramAccessSorted
  (access : ImportedProofRelevantOramAccessView) :
  List ImportedProofRelevantOramAccessView →
  List ImportedProofRelevantOramAccessView
  | [] => [access]
  | head :: tail =>
      if access.object_id ≤ head.object_id then
        access :: head :: tail
      else
        head :: insertOramAccessSorted access tail

private def parseImportedOramAccessViewsFromRawJson
  (json : Json) : Except String (List ImportedProofRelevantOramAccessView) := do
  let entries ← objectEntries json
  entries.foldlM (init := ([] : List ImportedProofRelevantOramAccessView)) fun acc entry => do
    let objectId ←
      match entry.fst.toNat? with
      | some value => pure value
      | none => throw s!"invalid ORAM access object id {entry.fst}"
    let accesses : Nat ← fromJson? entry.snd
    pure <| insertOramAccessSorted { object_id := objectId, accesses := accesses } acc

private def parseImportedManifestEntrypointViewFromRawJson
  (signature : String)
  (json : Json) : Except String ImportedProofRelevantEntrypointView := do
  let entryInputLen? : Option Nat ← lookupOptionalFieldAs json "entry_input_len"
  let publicStateDeclassifies? : Option (List String) ←
    lookupOptionalFieldAs json "public_state_declassifies"
  pure
    { signature := signature
    , secret_args := ← lookupFieldAs json "secret_args"
    , param_names := ← lookupFieldAs json "param_names"
    , public_env := (← lookupOptionalFieldAs json "public_env").getD []
    , entry_input_len := entryInputLen?.getD 0
    , initializer := (← lookupOptionalFieldAs json "initializer").getD false
    , requires_initialized := (← lookupOptionalFieldAs json "requires_initialized").getD false
    , public_gas_budget := ← lookupFieldAs json "public_gas_budget"
    , arena_bytes := ← lookupFieldAs json "arena_bytes"
    , max_stack_words := ← lookupFieldAs json "max_stack_words"
    , max_hash_part_bytes := (← lookupOptionalFieldAs json "max_hash_part_bytes").getD 0
    , return_canonical_len := ← lookupOptionalFieldAs json "return_canonical_len"
    , returns := ← lookupFieldAs json "returns"
    , status := ← lookupFieldAs json "status"
    , declassifies := ← lookupFieldAs json "declassifies"
    , public_state_declassifies := publicStateDeclassifies?.getD []
    , confidential_program := (← lookupOptionalFieldJson json "confidential_program").map Json.compress
    , confidential_slot_program :=
        (← lookupOptionalFieldJson json "confidential_slot_program").map Json.compress
    , kernel_steps := ← lookupFieldAs json "kernel_steps"
    , uocell_reads := ← lookupFieldAs json "uocell_reads"
    , uocell_writes := ← lookupFieldAs json "uocell_writes"
    , uoarray_reads := ← lookupFieldAs json "uoarray_reads"
    , uoarray_writes := ← lookupFieldAs json "uoarray_writes"
    , uomap_reads := ← lookupFieldAs json "uomap_reads"
    , uomap_writes := ← lookupFieldAs json "uomap_writes"
    , max_commit_ops := ← lookupFieldAs json "max_commit_ops"
    , oram_accesses := ← parseImportedOramAccessViewsFromRawJson (← lookupFieldJson json "oram_accesses")
    }

private def parseImportedManifestViewFromRawJson
  (json : Json) : Except String ImportedProofRelevantManifestView := do
  let entrypointEntries ← objectEntries (← lookupFieldJson json "entrypoints")
  pure
    { contract := ← lookupFieldAs json "contract"
    , compilation_mode := ← lookupFieldAs json "compilation_mode"
    , objects := ← lookupFieldAs json "objects"
    , entrypoints := ← entrypointEntries.mapM fun entry =>
        parseImportedManifestEntrypointViewFromRawJson entry.fst entry.snd
    }

private def parseImportedParamViewFromRawJson
  (json : Json) : Except String ImportedProofRelevantParamView := do
  let items ← expectJsonArray json
  match items with
  | [nameJson, tyJson] =>
      pure { name := ← fromJson? nameJson, ty := tyJson.compress }
  | _ => throw "expected parameter pair encoding"

private def parseImportedFunctionViewFromRawJson
  (json : Json) : Except String ImportedProofRelevantFunctionView := do
  let paramsJson ← lookupFieldJson json "params"
  let returnType? ← lookupOptionalFieldJson json "return_type"
  let bodyJsons : List Json ← lookupFieldAs json "body"
  pure
    { signature := ← lookupFieldAs json "signature"
    , params := ← (← expectJsonArray paramsJson).mapM parseImportedParamViewFromRawJson
    , public_env := (← lookupOptionalFieldAs json "public_env").getD []
    , return_type := returnType?.map Json.compress
    , body := bodyJsons.map Json.compress
    , secret_args := ← lookupFieldAs json "secret_args"
    , confidential := ← lookupFieldAs json "confidential"
    , confidential_program := (← lookupOptionalFieldJson json "confidential_program").map Json.compress
    , confidential_slot_program :=
        (← lookupOptionalFieldJson json "confidential_slot_program").map Json.compress
    }

private def parseImportedStateObjectViewFromRawJson
  (json : Json) : Except String ImportedProofRelevantStateObjectView := do
  let kindRaw : String ← lookupFieldAs json "kind"
  let backendRaw : String ← lookupFieldAs json "backend"
  let valueTypeJson ← lookupFieldJson json "value_type"
  let keyType? ← lookupOptionalFieldJson json "key_type"
  pure
    { id := ← lookupFieldAs json "id"
    , name := ← lookupFieldAs json "name"
    , kind := ← rawContainerKindTag kindRaw
    , backend := ← rawBackendKindTag backendRaw
    , oram_scheme := ← lookupFieldAs json "oram_scheme"
    , value_type := valueTypeJson.compress
    , value_type_short_name := ← typeShortNameFromJson valueTypeJson
    , key_type := keyType?.map Json.compress
    , key_type_short_name := ← keyType?.mapM typeShortNameFromJson
    , capacity := ← lookupFieldAs json "capacity"
    , confidential := ← lookupFieldAs json "confidential"
    }

private def parseImportedContractViewFromRawContractJson
  (json : Json) : Except String ImportedProofRelevantContractView := do
  let stateJson : List Json ← lookupFieldAs json "state"
  let functionsJson : List Json ← lookupFieldAs json "functions"
  let modeRaw : String ← lookupFieldAs json "mode"
  pure
    { contract := ← lookupFieldAs json "contract"
    , mode := ← rawProgramModeTag modeRaw
    , state := ← stateJson.mapM parseImportedStateObjectViewFromRawJson
    , functions := ← functionsJson.mapM parseImportedFunctionViewFromRawJson
    , manifest := ← parseImportedManifestViewFromRawJson (← lookupFieldJson json "manifest")
    }

private def parseImportedContractViewFromRawContractString
  (input : String) : Except String ImportedProofRelevantContractView := do
  parseImportedContractViewFromRawContractJson (← parseJsonString input)

private def parseImportedContractViewAndRawContractStringFromArtifactJson
  (json : Json) : Except String (String × ImportedProofRelevantContractView) := do
  let contractJson ← lookupFieldJson json "contract"
  let contractView ← parseImportedContractViewFromRawContractJson contractJson
  pure (contractJson.compress, contractView)

private def lookupLoopVar
  (name : String)
  (loopEnv : List (String × Nat)) : Option Nat :=
  loopEnv.findSome? fun entry =>
    if entry.fst == name then
      some entry.snd
    else
      none

private partial def evalLoopBoundJson
  (expr : Json)
  (loopEnv : List (String × Nat)) : Option Nat :=
  match taggedPayload? expr "Literal" with
  | some payload =>
      asUintLiteral? payload <|> asBoolLiteral? payload
  | none =>
      match taggedPayload? expr "Var" with
      | some payload =>
          match fromJson? payload with
          | .ok name => lookupLoopVar name loopEnv
          | .error _ => none
      | none =>
          match taggedPayload? expr "Unary" with
          | some payload =>
              match lookupFieldJson payload "op" with
              | .ok opJson =>
                  match lookupFieldJson payload "expr" with
                  | .ok innerExpr =>
                      match (fromJson? opJson : Except String String) with
                      | .ok "Neg" =>
                          match evalLoopBoundJson innerExpr loopEnv with
                          | some value => some (uint256Sub 0 value)
                          | none => none
                      | .ok "Not" =>
                          match evalLoopBoundJson innerExpr loopEnv with
                          | some value => some (if uint256 value == 0 then 1 else 0)
                          | none => none
                      | _ => none
                  | .error _ => none
              | _ => none
          | none =>
              match taggedPayload? expr "Binary" with
              | some payload =>
                  match lookupFieldJson payload "op" with
                  | .ok opJson =>
                      match lookupFieldJson payload "lhs" with
                      | .ok lhsExpr =>
                          match lookupFieldJson payload "rhs" with
                          | .ok rhsExpr =>
                              match (fromJson? opJson : Except String String) with
                              | .ok "Add" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (uint256 (lhs + rhs))
                                  | _, _ => none
                              | .ok "Sub" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (uint256Sub lhs rhs)
                                  | _, _ => none
                              | .ok "Mul" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (uint256 (lhs * rhs))
                                  | _, _ => none
                              | .ok "Div" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs =>
                                      let divisor := uint256 rhs
                                      if divisor == 0 then some 0 else some (uint256 lhs / divisor)
                                  | _, _ => none
                              | .ok "Mod" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs =>
                                      let divisor := uint256 rhs
                                      if divisor == 0 then some 0 else some (uint256 lhs % divisor)
                                  | _, _ => none
                              | .ok "BitAnd" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (uint256 (Nat.land (uint256 lhs) (uint256 rhs)))
                                  | _, _ => none
                              | .ok "BitOr" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (uint256 (Nat.lor (uint256 lhs) (uint256 rhs)))
                                  | _, _ => none
                              | .ok "BitXor" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (uint256 (Nat.xor (uint256 lhs) (uint256 rhs)))
                                  | _, _ => none
                              | .ok "Eq" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if uint256 lhs == uint256 rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "Neq" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if uint256 lhs != uint256 rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "Lt" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if uint256 lhs < uint256 rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "Lte" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if uint256 lhs ≤ uint256 rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "Gt" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if uint256 lhs > uint256 rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "Gte" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if uint256 lhs ≥ uint256 rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "And" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs =>
                                      some (if uint256 lhs != 0 && uint256 rhs != 0 then 1 else 0)
                                  | _, _ => none
                              | .ok "Or" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs =>
                                      some (if uint256 lhs != 0 || uint256 rhs != 0 then 1 else 0)
                                  | _, _ => none
                              | _ => none
                          | .error _ => none
                      | .error _ => none
                  | .error _ => none
              | none =>
                  match taggedPayload? expr "Select" with
                  | some payload =>
                      match lookupFieldJson payload "cond" with
                      | .ok condExpr =>
                          match lookupFieldJson payload "when_true" with
                          | .ok whenTrueExpr =>
                              match lookupFieldJson payload "when_false" with
                              | .ok whenFalseExpr =>
                                  match evalLoopBoundJson condExpr loopEnv with
                                  | some cond =>
                                      if uint256 cond != 0 then
                                        evalLoopBoundJson whenTrueExpr loopEnv
                                      else
                                        evalLoopBoundJson whenFalseExpr loopEnv
                                  | none => none
                              | .error _ => none
                          | .error _ => none
                      | .error _ => none
                  | none => none

mutual

private partial def countExpr (json : Json) : Except String CountSummary := do
  if taggedPayload? json "Literal" |>.isSome then
    pure {}
  else if taggedPayload? json "Var" |>.isSome then
    pure {}
  else if let some inner := taggedPayload? json "Unary" then
    countExpr (← lookupFieldJson inner "expr")
  else if let some inner := taggedPayload? json "Binary" then
    return (← countExpr (← lookupFieldJson inner "lhs")).add
      (← countExpr (← lookupFieldJson inner "rhs"))
  else if let some inner := taggedPayload? json "Select" then
    return ((← countExpr (← lookupFieldJson inner "cond")).add
      (← countExpr (← lookupFieldJson inner "when_true"))).add
      (← countExpr (← lookupFieldJson inner "when_false"))
  else if taggedPayload? json "CellGet" |>.isSome then
    pure { cellReads := 1 }
  else if let some inner := taggedPayload? json "ArrayGet" then
    let indexCounts ← countExpr (← lookupFieldJson inner "index")
    pure { indexCounts with arrayReads := indexCounts.arrayReads + 1 }
  else if let some inner := taggedPayload? json "MapGet" then
    let keyCounts ← countExpr (← lookupFieldJson inner "key")
    pure { keyCounts with mapReads := keyCounts.mapReads + 1 }
  else if let some inner := taggedPayload? json "StructField" then
    countExpr (← lookupFieldJson inner "base")
  else if let some inner := taggedPayload? json "ArrayIndex" then
    return (← countExpr (← lookupFieldJson inner "base")).add
      (← countExpr (← lookupFieldJson inner "index"))
  else if let some inner := taggedPayload? json "Keccak256" then
    countExprList (← lookupFieldAs inner "parts")
  else
    throw "unsupported expression shape in translation bundle"

private partial def countExprList (items : List Json) : Except String CountSummary :=
  items.foldlM (init := ({ } : CountSummary)) fun acc item => do
    pure <| acc.add (← countExpr item)

private partial def countOptionalExprField
  (json : Json)
  (field : String) : Except String CountSummary := do
  let value? ← lookupOptionalFieldJson json field
  match value? with
  | none => pure {}
  | some value => countExpr value

private partial def countStatementJson
  (json : Json)
  (loopEnv : List (String × Nat) := []) : Except String CountSummary := do
  if let some inner := taggedPayload? json "Declare" then
    let valueCounts ← countExpr (← lookupFieldJson inner "value")
    pure { valueCounts with localCount := valueCounts.localCount + 1 }
  else if let some inner := taggedPayload? json "Assign" then
    countExpr (← lookupFieldJson inner "value")
  else if let some inner := taggedPayload? json "Require" then
    countExpr (← lookupFieldJson inner "cond")
  else if let some inner := taggedPayload? json "AbortIf" then
    countExpr (← lookupFieldJson inner "cond")
  else if let some inner := taggedPayload? json "If" then
    return ((← countExpr (← lookupFieldJson inner "cond")).add
      (← countNestedStatementArray (← lookupFieldAs inner "then_body") loopEnv)).add
      (← countNestedStatementArray (← lookupFieldAs inner "else_body") loopEnv)
  else if let some inner := taggedPayload? json "For" then
    let startExpr ← lookupFieldJson inner "start"
    let endExpr ← lookupFieldJson inner "end"
    let body : List Json ← lookupFieldAs inner "body"
    let indexVar : String ← lookupFieldAs inner "index_var"
    let startCounts ← countExpr startExpr
    let endCounts ← countExpr endExpr
    let bodyCounts ←
      match (evalLoopBoundJson startExpr loopEnv, evalLoopBoundJson endExpr loopEnv) with
      | (some startValue, some endValue) =>
          let rec go (index : Nat) (acc : CountSummary) : Except String CountSummary := do
            if index < endValue then
              let nestedCounts ←
                countNestedStatementArray body ((indexVar, index) :: loopEnv)
              go (index + 1) (acc.add nestedCounts)
            else
              pure acc
          go startValue ({ } : CountSummary)
      | _ =>
          countNestedStatementArray body loopEnv
    pure <| startCounts.add endCounts |>.add bodyCounts
  else if let some inner := taggedPayload? json "CellSet" then
    let valueCounts ← countExpr (← lookupFieldJson inner "value")
    let predicateCounts ← countOptionalExprField inner "predicate"
    return valueCounts.add predicateCounts |>.add { cellWrites := 1 }
  else if let some inner := taggedPayload? json "ArraySet" then
    let indexCounts ← countExpr (← lookupFieldJson inner "index")
    let valueCounts ← countExpr (← lookupFieldJson inner "value")
    let predicateCounts ← countOptionalExprField inner "predicate"
    return indexCounts.add valueCounts |>.add predicateCounts |>.add { arrayWrites := 1 }
  else if let some inner := taggedPayload? json "MapPut" then
    let keyCounts ← countExpr (← lookupFieldJson inner "key")
    let valueCounts ← countExpr (← lookupFieldJson inner "value")
    let predicateCounts ← countOptionalExprField inner "predicate"
    return keyCounts.add valueCounts |>.add predicateCounts |>.add { mapWrites := 1 }
  else if let some inner := taggedPayload? json "Return" then
    countOptionalExprField inner "value"
  else
    throw "unsupported statement shape in translation bundle"

private partial def countNestedStatementArray
  (items : List Json)
  (loopEnv : List (String × Nat) := []) : Except String CountSummary :=
  items.foldlM (init := ({ } : CountSummary)) fun acc item => do
    pure <| acc.add (← countStatementJson item loopEnv)

end

def countBodyStrings (body : List String) : Except String CountSummary :=
  body.foldlM (init := ({ } : CountSummary)) fun acc item => do
    pure <| acc.add (← countStatementJson (← parseJsonString item))

def translationPathOramScheme : String := "path_oram_local_posmap_v1"

def translationPathOramPrivatePosmapScheme : String := "path_oram_private_posmap_v1"

def translationPathOramLocalPosmapMaxCapacity : Nat := 128

def translationSurrogateOramScheme : String := "surrogate_public_schedule_v1"

def translationOramBucketHeaderBytes : Nat := 24

def translationIsPathOramScheme (scheme : String) : Bool :=
  scheme == translationPathOramScheme || scheme == translationPathOramPrivatePosmapScheme

def translationPathOramPositionMapShapeWellFormed
  (scheme : String)
  (capacity recursionDepth : Nat) : Bool :=
  if scheme == translationPathOramScheme then
    capacity <= translationPathOramLocalPosmapMaxCapacity &&
      recursionDepth == 0
  else if scheme == translationPathOramPrivatePosmapScheme then
    recursionDepth == 1
  else
    false

private def mergeDistinctNatLists (lhs rhs : List Nat) : List Nat :=
  rhs.foldl (init := lhs) fun acc objectId =>
    if acc.contains objectId then
      acc
    else
      objectId :: acc

private def lookupPairCount (objectId : Nat) (counts : List (Nat × Nat)) : Nat :=
  match counts.find? (fun entry => entry.fst == objectId) with
  | some (_, value) => value
  | none => 0

private def addPairCount (objectId delta : Nat) : List (Nat × Nat) → List (Nat × Nat)
  | [] => [(objectId, delta)]
  | (currentId, currentCount) :: rest =>
      if currentId == objectId then
        (currentId, currentCount + delta) :: rest
      else
        (currentId, currentCount) :: addPairCount objectId delta rest

private def mergePairCounts (lhs rhs : List (Nat × Nat)) : List (Nat × Nat) :=
  rhs.foldl (init := lhs) fun acc entry =>
    addPairCount entry.fst entry.snd acc

private def pairCountObjectIds (counts : List (Nat × Nat)) : List Nat :=
  counts.map Prod.fst

private def entryOramAccessObjectIds
  (accesses : List ImportedProofRelevantOramAccessView) : List Nat :=
  accesses.map ImportedProofRelevantOramAccessView.object_id

private def renderPairCounts (counts : List (Nat × Nat)) : String :=
  String.intercalate ", "
    (counts.map fun entry => s!"{entry.fst}:{entry.snd}")

private def renderEntrypointOramAccesses
  (accesses : List ImportedProofRelevantOramAccessView) : String :=
  String.intercalate ", "
    (accesses.map fun access => s!"{access.object_id}:{access.accesses}")

private def isPowerOfTwo (value : Nat) : Bool :=
  value != 0 && Nat.land value (value - 1) == 0

private def log2Ceil (value : Nat) : Nat :=
  let target := max value 1
  match (List.range 129).find? (fun height => target ≤ 2 ^ height) with
  | some height => height
  | none => 128

private def totalCommitOps (oram : ImportedProofRelevantOramView) : Nat :=
  oram.metadata_pages_per_access + oram.buckets_per_access

mutual

private partial def collectAccessedObjectIdsExpr
  (json : Json) : Except String (List Nat) := do
  if taggedPayload? json "Literal" |>.isSome then
    pure []
  else if taggedPayload? json "Var" |>.isSome then
    pure []
  else if let some inner := taggedPayload? json "Unary" then
    collectAccessedObjectIdsExpr (← lookupFieldJson inner "expr")
  else if let some inner := taggedPayload? json "Binary" then
    pure <| mergeDistinctNatLists
      (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "lhs"))
      (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "rhs"))
  else if let some inner := taggedPayload? json "Select" then
    pure <| mergeDistinctNatLists
      (mergeDistinctNatLists
        (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "cond"))
        (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "when_true")))
      (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "when_false"))
  else if let some inner := taggedPayload? json "CellGet" then
    pure [← lookupFieldAs inner "object_id"]
  else if let some inner := taggedPayload? json "ArrayGet" then
    pure <| mergeDistinctNatLists
      [← lookupFieldAs inner "object_id"]
      (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "index"))
  else if let some inner := taggedPayload? json "MapGet" then
    pure <| mergeDistinctNatLists
      [← lookupFieldAs inner "object_id"]
      (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "key"))
  else if let some inner := taggedPayload? json "StructField" then
    collectAccessedObjectIdsExpr (← lookupFieldJson inner "base")
  else if let some inner := taggedPayload? json "ArrayIndex" then
    pure <| mergeDistinctNatLists
      (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "base"))
      (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "index"))
  else if let some inner := taggedPayload? json "Keccak256" then
    collectAccessedObjectIdsExprList (← lookupFieldAs inner "parts")
  else
    throw "unsupported expression shape in translation bundle"

private partial def collectAccessedObjectIdsExprList
  (items : List Json) : Except String (List Nat) :=
  items.foldlM (init := ([] : List Nat)) fun acc item => do
    pure <| mergeDistinctNatLists acc (← collectAccessedObjectIdsExpr item)

private partial def collectAccessedObjectIdsStatement
  (json : Json) : Except String (List Nat) := do
  if let some inner := taggedPayload? json "Declare" then
    collectAccessedObjectIdsExpr (← lookupFieldJson inner "value")
  else if let some inner := taggedPayload? json "Assign" then
    collectAccessedObjectIdsExpr (← lookupFieldJson inner "value")
  else if let some inner := taggedPayload? json "Require" then
    collectAccessedObjectIdsExpr (← lookupFieldJson inner "cond")
  else if let some inner := taggedPayload? json "AbortIf" then
    collectAccessedObjectIdsExpr (← lookupFieldJson inner "cond")
  else if let some inner := taggedPayload? json "If" then
    pure <| mergeDistinctNatLists
      (mergeDistinctNatLists
        (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "cond"))
        (← collectAccessedObjectIdsStatementArray (← lookupFieldAs inner "then_body")))
      (← collectAccessedObjectIdsStatementArray (← lookupFieldAs inner "else_body"))
  else if let some inner := taggedPayload? json "For" then
    pure <| mergeDistinctNatLists
      (mergeDistinctNatLists
        (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "start"))
        (← collectAccessedObjectIdsExpr (← lookupFieldJson inner "end")))
      (← collectAccessedObjectIdsStatementArray (← lookupFieldAs inner "body"))
  else if let some inner := taggedPayload? json "CellSet" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    let valueIds ← collectAccessedObjectIdsExpr (← lookupFieldJson inner "value")
    let predicateIds ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => collectAccessedObjectIdsExpr predicate
    pure <| mergeDistinctNatLists [objectId] (mergeDistinctNatLists valueIds predicateIds)
  else if let some inner := taggedPayload? json "ArraySet" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    let indexIds ← collectAccessedObjectIdsExpr (← lookupFieldJson inner "index")
    let valueIds ← collectAccessedObjectIdsExpr (← lookupFieldJson inner "value")
    let predicateIds ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => collectAccessedObjectIdsExpr predicate
    pure <| mergeDistinctNatLists
      [objectId]
      (mergeDistinctNatLists (mergeDistinctNatLists indexIds valueIds) predicateIds)
  else if let some inner := taggedPayload? json "MapPut" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    let keyIds ← collectAccessedObjectIdsExpr (← lookupFieldJson inner "key")
    let valueIds ← collectAccessedObjectIdsExpr (← lookupFieldJson inner "value")
    let predicateIds ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => collectAccessedObjectIdsExpr predicate
    pure <| mergeDistinctNatLists
      [objectId]
      (mergeDistinctNatLists (mergeDistinctNatLists keyIds valueIds) predicateIds)
  else if let some inner := taggedPayload? json "Return" then
    match ← lookupOptionalFieldJson inner "value" with
    | none => pure []
    | some value => collectAccessedObjectIdsExpr value
  else
    throw "unsupported statement shape in translation bundle"

private partial def collectAccessedObjectIdsStatementArray
  (items : List Json) : Except String (List Nat) :=
  items.foldlM (init := ([] : List Nat)) fun acc item => do
    pure <| mergeDistinctNatLists acc (← collectAccessedObjectIdsStatement item)

private partial def collectOramExprAccesses
  (json : Json)
  (state : List ImportedProofRelevantStateObjectView) :
  Except String (List (Nat × Nat)) := do
  if taggedPayload? json "Literal" |>.isSome then
    pure []
  else if taggedPayload? json "Var" |>.isSome then
    pure []
  else if let some inner := taggedPayload? json "Unary" then
    collectOramExprAccesses (← lookupFieldJson inner "expr") state
  else if let some inner := taggedPayload? json "Binary" then
    pure <| mergePairCounts
      (← collectOramExprAccesses (← lookupFieldJson inner "lhs") state)
      (← collectOramExprAccesses (← lookupFieldJson inner "rhs") state)
  else if let some inner := taggedPayload? json "Select" then
    pure <| mergePairCounts
      (mergePairCounts
        (← collectOramExprAccesses (← lookupFieldJson inner "cond") state)
        (← collectOramExprAccesses (← lookupFieldJson inner "when_true") state))
      (← collectOramExprAccesses (← lookupFieldJson inner "when_false") state)
  else if let some inner := taggedPayload? json "ArrayGet" then
    collectOramExprAccesses (← lookupFieldJson inner "index") state
  else if let some inner := taggedPayload? json "MapGet" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    let keyCounts ← collectOramExprAccesses (← lookupFieldJson inner "key") state
    match stateObjectById? state objectId with
    | some object =>
        if object.backend == "oram" then
          pure <| addPairCount objectId 1 keyCounts
        else
          pure keyCounts
    | none => throw s!"unknown object id {objectId}"
  else if let some inner := taggedPayload? json "StructField" then
    collectOramExprAccesses (← lookupFieldJson inner "base") state
  else if let some inner := taggedPayload? json "ArrayIndex" then
    pure <| mergePairCounts
      (← collectOramExprAccesses (← lookupFieldJson inner "base") state)
      (← collectOramExprAccesses (← lookupFieldJson inner "index") state)
  else if let some inner := taggedPayload? json "Keccak256" then
    collectOramExprAccessesList (← lookupFieldAs inner "parts") state
  else if taggedPayload? json "CellGet" |>.isSome then
    pure []
  else
    throw "unsupported expression shape in translation bundle"

private partial def collectOramExprAccessesList
  (items : List Json)
  (state : List ImportedProofRelevantStateObjectView) :
  Except String (List (Nat × Nat)) :=
  items.foldlM (init := ([] : List (Nat × Nat))) fun acc item => do
    pure <| mergePairCounts acc (← collectOramExprAccesses item state)

private partial def collectOramStatementAccesses
  (json : Json)
  (state : List ImportedProofRelevantStateObjectView)
  (loopEnv : List (String × Nat) := []) :
  Except String (List (Nat × Nat)) := do
  if let some inner := taggedPayload? json "Declare" then
    collectOramExprAccesses (← lookupFieldJson inner "value") state
  else if let some inner := taggedPayload? json "Assign" then
    collectOramExprAccesses (← lookupFieldJson inner "value") state
  else if let some inner := taggedPayload? json "Require" then
    collectOramExprAccesses (← lookupFieldJson inner "cond") state
  else if let some inner := taggedPayload? json "AbortIf" then
    collectOramExprAccesses (← lookupFieldJson inner "cond") state
  else if let some inner := taggedPayload? json "If" then
    pure <| mergePairCounts
      (mergePairCounts
        (← collectOramExprAccesses (← lookupFieldJson inner "cond") state)
        (← collectOramStatementAccessesArray (← lookupFieldAs inner "then_body") state loopEnv))
      (← collectOramStatementAccessesArray (← lookupFieldAs inner "else_body") state loopEnv)
  else if let some inner := taggedPayload? json "For" then
    let startExpr ← lookupFieldJson inner "start"
    let endExpr ← lookupFieldJson inner "end"
    let body : List Json ← lookupFieldAs inner "body"
    let indexVar : String ← lookupFieldAs inner "index_var"
    let startCounts ← collectOramExprAccesses startExpr state
    let endCounts ← collectOramExprAccesses endExpr state
    let bodyCounts ←
      match evalLoopBoundJson startExpr loopEnv, evalLoopBoundJson endExpr loopEnv with
      | some startValue, some endValue =>
          let rec go (index : Nat) (acc : List (Nat × Nat)) :
            Except String (List (Nat × Nat)) := do
            if index < endValue then
              let nestedCounts ←
                collectOramStatementAccessesArray body state ((indexVar, index) :: loopEnv)
              go (index + 1) (mergePairCounts acc nestedCounts)
            else
              pure acc
          go startValue []
      | _, _ =>
          let observed ← collectOramStatementAccessesArray body state loopEnv
          if observed.isEmpty then
            pure []
          else
            throw
              "loop contains ORAM accesses but its trip count is not compile-time exact"
    pure <| mergePairCounts (mergePairCounts startCounts endCounts) bodyCounts
  else if let some inner := taggedPayload? json "CellSet" then
    let valueCounts ← collectOramExprAccesses (← lookupFieldJson inner "value") state
    let predicateCounts ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => collectOramExprAccesses predicate state
    pure <| mergePairCounts valueCounts predicateCounts
  else if let some inner := taggedPayload? json "ArraySet" then
    let indexCounts ← collectOramExprAccesses (← lookupFieldJson inner "index") state
    let valueCounts ← collectOramExprAccesses (← lookupFieldJson inner "value") state
    let predicateCounts ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => collectOramExprAccesses predicate state
    pure <| mergePairCounts (mergePairCounts indexCounts valueCounts) predicateCounts
  else if let some inner := taggedPayload? json "MapPut" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    let keyCounts ← collectOramExprAccesses (← lookupFieldJson inner "key") state
    let valueCounts ← collectOramExprAccesses (← lookupFieldJson inner "value") state
    let predicateCounts ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => collectOramExprAccesses predicate state
    match stateObjectById? state objectId with
    | some object =>
        let counts :=
          mergePairCounts (mergePairCounts keyCounts valueCounts) predicateCounts
        if object.backend == "oram" then
          pure <| addPairCount objectId 1 counts
        else
          pure counts
    | none => throw s!"unknown object id {objectId}"
  else if let some inner := taggedPayload? json "Return" then
    match ← lookupOptionalFieldJson inner "value" with
    | none => pure []
    | some value => collectOramExprAccesses value state
  else
    throw "unsupported statement shape in translation bundle"

private partial def collectOramStatementAccessesArray
  (items : List Json)
  (state : List ImportedProofRelevantStateObjectView)
  (loopEnv : List (String × Nat) := []) :
  Except String (List (Nat × Nat)) :=
  items.foldlM (init := ([] : List (Nat × Nat))) fun acc item => do
    pure <| mergePairCounts acc (← collectOramStatementAccesses item state loopEnv)

end

private def accessedObjectIdsInBodyStrings (body : List String) : Except String (List Nat) :=
  body.foldlM (init := ([] : List Nat)) fun acc item => do
    pure <| mergeDistinctNatLists acc (← collectAccessedObjectIdsStatement (← parseJsonString item))

structure PolicySensitivityJson where
  returnSensitive : Bool := false
  statusSensitive : Bool := false
  sensitivePublicWrites : List String := []
  confidentialReads : List String := []
deriving Repr, DecidableEq

private def insertStringSet (value : String) (values : List String) : List String :=
  if values.contains value then values else value :: values

private def mergeStringSets (lhs rhs : List String) : List String :=
  rhs.foldl (fun acc value => insertStringSet value acc) lhs

private def PolicySensitivityJson.merge
  (lhs rhs : PolicySensitivityJson) : PolicySensitivityJson :=
  { returnSensitive := lhs.returnSensitive || rhs.returnSensitive
  , statusSensitive := lhs.statusSensitive || rhs.statusSensitive
  , sensitivePublicWrites :=
      mergeStringSets lhs.sensitivePublicWrites rhs.sensitivePublicWrites
  , confidentialReads := mergeStringSets lhs.confidentialReads rhs.confidentialReads
  }

private def setPolicyTaint
  (name : String) (sensitive : Bool) (tainted : List String) : List String :=
  if sensitive then
    insertStringSet name tainted
  else
    tainted.erase name

private def stateObjectConfidentialById
  (state : List ImportedProofRelevantStateObjectView)
  (objectId : Nat) : Bool :=
  match stateObjectById? state objectId with
  | some object => object.confidential
  | none => true

private def confidentialReadNamesForObjectId
  (state : List ImportedProofRelevantStateObjectView)
  (objectId : Nat) : Except String (List String) :=
  match stateObjectById? state objectId with
  | some object =>
      if object.confidential then
        pure [object.name]
      else
        pure []
  | none => throw s!"unknown object id {objectId}"

mutual

private partial def policyExprSensitive
  (state : List ImportedProofRelevantStateObjectView)
  (tainted : List String)
  (json : Json) : Except String Bool := do
  if taggedPayload? json "Literal" |>.isSome then
    pure false
  else if let some payload := taggedPayload? json "Var" then
    let name : String ← fromJson? payload
    pure (tainted.contains name)
  else if let some inner := taggedPayload? json "Unary" then
    policyExprSensitive state tainted (← lookupFieldJson inner "expr")
  else if let some inner := taggedPayload? json "Binary" then
    pure ((← policyExprSensitive state tainted (← lookupFieldJson inner "lhs")) ||
      (← policyExprSensitive state tainted (← lookupFieldJson inner "rhs")))
  else if let some inner := taggedPayload? json "Select" then
    pure ((← policyExprSensitive state tainted (← lookupFieldJson inner "cond")) ||
      (← policyExprSensitive state tainted (← lookupFieldJson inner "when_true")) ||
      (← policyExprSensitive state tainted (← lookupFieldJson inner "when_false")))
  else if let some inner := taggedPayload? json "CellGet" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    pure (stateObjectConfidentialById state objectId)
  else if let some inner := taggedPayload? json "ArrayGet" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    pure (stateObjectConfidentialById state objectId ||
      (← policyExprSensitive state tainted (← lookupFieldJson inner "index")))
  else if let some inner := taggedPayload? json "MapGet" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    pure (stateObjectConfidentialById state objectId ||
      (← policyExprSensitive state tainted (← lookupFieldJson inner "key")))
  else if let some inner := taggedPayload? json "StructField" then
    policyExprSensitive state tainted (← lookupFieldJson inner "base")
  else if let some inner := taggedPayload? json "ArrayIndex" then
    pure ((← policyExprSensitive state tainted (← lookupFieldJson inner "base")) ||
      (← policyExprSensitive state tainted (← lookupFieldJson inner "index")))
  else if let some inner := taggedPayload? json "Keccak256" then
    policyExprListSensitive state tainted (← lookupFieldAs inner "parts")
  else
    throw "unsupported expression shape in translation bundle"

private partial def policyExprListSensitive
  (state : List ImportedProofRelevantStateObjectView)
  (tainted : List String)
  (items : List Json) : Except String Bool :=
  items.foldlM (init := false) fun acc item => do
    if acc then
      pure true
    else
      policyExprSensitive state tainted item

end

mutual

private partial def policyExprConfidentialReads
  (state : List ImportedProofRelevantStateObjectView)
  (json : Json) : Except String (List String) := do
  if taggedPayload? json "Literal" |>.isSome then
    pure []
  else if taggedPayload? json "Var" |>.isSome then
    pure []
  else if let some inner := taggedPayload? json "Unary" then
    policyExprConfidentialReads state (← lookupFieldJson inner "expr")
  else if let some inner := taggedPayload? json "Binary" then
    pure <| mergeStringSets
      (← policyExprConfidentialReads state (← lookupFieldJson inner "lhs"))
      (← policyExprConfidentialReads state (← lookupFieldJson inner "rhs"))
  else if let some inner := taggedPayload? json "Select" then
    let condReads ← policyExprConfidentialReads state (← lookupFieldJson inner "cond")
    let trueReads ← policyExprConfidentialReads state (← lookupFieldJson inner "when_true")
    let falseReads ← policyExprConfidentialReads state (← lookupFieldJson inner "when_false")
    pure <| mergeStringSets (mergeStringSets condReads trueReads) falseReads
  else if let some inner := taggedPayload? json "CellGet" then
    confidentialReadNamesForObjectId state (← lookupFieldAs inner "object_id")
  else if let some inner := taggedPayload? json "ArrayGet" then
    pure <| mergeStringSets
      (← confidentialReadNamesForObjectId state (← lookupFieldAs inner "object_id"))
      (← policyExprConfidentialReads state (← lookupFieldJson inner "index"))
  else if let some inner := taggedPayload? json "MapGet" then
    pure <| mergeStringSets
      (← confidentialReadNamesForObjectId state (← lookupFieldAs inner "object_id"))
      (← policyExprConfidentialReads state (← lookupFieldJson inner "key"))
  else if let some inner := taggedPayload? json "StructField" then
    policyExprConfidentialReads state (← lookupFieldJson inner "base")
  else if let some inner := taggedPayload? json "ArrayIndex" then
    pure <| mergeStringSets
      (← policyExprConfidentialReads state (← lookupFieldJson inner "base"))
      (← policyExprConfidentialReads state (← lookupFieldJson inner "index"))
  else if let some inner := taggedPayload? json "Keccak256" then
    policyExprListConfidentialReads state (← lookupFieldAs inner "parts")
  else
    throw "unsupported expression shape in translation bundle"

private partial def policyExprListConfidentialReads
  (state : List ImportedProofRelevantStateObjectView)
  (items : List Json) : Except String (List String) :=
  items.foldlM (init := []) fun acc item => do
    pure <| mergeStringSets acc (← policyExprConfidentialReads state item)

end

mutual

private partial def markAssignedLocalsJson
  (json : Json) (tainted : List String) : Except String (List String) := do
  if let some inner := taggedPayload? json "Declare" then
    pure <| insertStringSet (← lookupFieldAs inner "name") tainted
  else if let some inner := taggedPayload? json "Assign" then
    pure <| insertStringSet (← lookupFieldAs inner "name") tainted
  else if let some inner := taggedPayload? json "If" then
    let tainted ← markAssignedLocalsJsonArray (← lookupFieldAs inner "then_body") tainted
    markAssignedLocalsJsonArray (← lookupFieldAs inner "else_body") tainted
  else if let some inner := taggedPayload? json "For" then
    markAssignedLocalsJsonArray (← lookupFieldAs inner "body") tainted
  else if (taggedPayload? json "Require").isSome ||
      (taggedPayload? json "AbortIf").isSome ||
      (taggedPayload? json "CellSet").isSome ||
      (taggedPayload? json "ArraySet").isSome ||
      (taggedPayload? json "MapPut").isSome ||
      (taggedPayload? json "Return").isSome then
    pure tainted
  else
    throw "unsupported statement shape in translation bundle"

private partial def markAssignedLocalsJsonArray
  (items : List Json) (tainted : List String) : Except String (List String) :=
  items.foldlM (init := tainted) fun acc item => markAssignedLocalsJson item acc

end

private def recordSensitivePublicWrite
  (state : List ImportedProofRelevantStateObjectView)
  (objectId : Nat)
  (isSensitive : Bool)
  (sensitivity : PolicySensitivityJson) : Except String PolicySensitivityJson := do
  if !isSensitive then
    pure sensitivity
  else
    match stateObjectById? state objectId with
    | some object =>
        if object.confidential then
          pure sensitivity
        else
          pure
            { sensitivity with
              sensitivePublicWrites :=
                insertStringSet object.name sensitivity.sensitivePublicWrites }
    | none => throw s!"unknown object id {objectId}"

private def confidentialReadSensitivity
  (reads : List String) : PolicySensitivityJson :=
  { confidentialReads := reads }

mutual

private partial def collectPolicySensitivityStatement
  (state : List ImportedProofRelevantStateObjectView)
  (json : Json)
  (tainted : List String)
  (controlSensitive : Bool) :
  Except String (List String × PolicySensitivityJson) := do
  if let some inner := taggedPayload? json "Declare" then
    let name : String ← lookupFieldAs inner "name"
    let value ← lookupFieldJson inner "value"
    let reads ← policyExprConfidentialReads state value
    pure
      ( setPolicyTaint name
          (controlSensitive || (← policyExprSensitive state tainted value)) tainted
      , confidentialReadSensitivity reads )
  else if let some inner := taggedPayload? json "Assign" then
    let name : String ← lookupFieldAs inner "name"
    let value ← lookupFieldJson inner "value"
    let reads ← policyExprConfidentialReads state value
    pure
      ( setPolicyTaint name
          (controlSensitive || (← policyExprSensitive state tainted value)) tainted
      , confidentialReadSensitivity reads )
  else if let some inner := taggedPayload? json "Require" then
    let cond ← lookupFieldJson inner "cond"
    let sensitive ← policyExprSensitive state tainted cond
    let reads ← policyExprConfidentialReads state cond
    pure (tainted, { statusSensitive := controlSensitive || sensitive, confidentialReads := reads })
  else if let some inner := taggedPayload? json "AbortIf" then
    let cond ← lookupFieldJson inner "cond"
    let sensitive ← policyExprSensitive state tainted cond
    let reads ← policyExprConfidentialReads state cond
    pure (tainted, { statusSensitive := controlSensitive || sensitive, confidentialReads := reads })
  else if let some inner := taggedPayload? json "If" then
    let cond ← lookupFieldJson inner "cond"
    let condSensitive ← policyExprSensitive state tainted cond
    let condReads ← policyExprConfidentialReads state cond
    let thenBody : List Json ← lookupFieldAs inner "then_body"
    let elseBody : List Json ← lookupFieldAs inner "else_body"
    let thenTainted ←
      if condSensitive then
        markAssignedLocalsJsonArray thenBody tainted
      else
        pure tainted
    let elseTainted ←
      if condSensitive then
        markAssignedLocalsJsonArray elseBody tainted
      else
        pure tainted
    let (thenOut, thenSensitivity) ←
      collectPolicySensitivityStatements
        state thenBody thenTainted (controlSensitive || condSensitive)
    let (elseOut, elseSensitivity) ←
      collectPolicySensitivityStatements
        state elseBody elseTainted (controlSensitive || condSensitive)
    pure
      ( mergeStringSets thenOut elseOut
      , (confidentialReadSensitivity condReads).merge
          (thenSensitivity.merge elseSensitivity) )
  else if let some inner := taggedPayload? json "For" then
    let startExpr ← lookupFieldJson inner "start"
    let endExpr ← lookupFieldJson inner "end"
    let body : List Json ← lookupFieldAs inner "body"
    let boundReads ←
      pure <| mergeStringSets
        (← policyExprConfidentialReads state startExpr)
        (← policyExprConfidentialReads state endExpr)
    let loopSensitive :=
      controlSensitive ||
        (← policyExprSensitive state tainted startExpr) ||
        (← policyExprSensitive state tainted endExpr)
    let (out, bodySensitivity) ←
      collectPolicySensitivityStatements state body tainted loopSensitive
    pure (out, (confidentialReadSensitivity boundReads).merge bodySensitivity)
  else if let some inner := taggedPayload? json "CellSet" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    let value ← lookupFieldJson inner "value"
    let valueSensitive ← policyExprSensitive state tainted value
    let valueReads ← policyExprConfidentialReads state value
    let predicateSensitive ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure false
      | some predicate => policyExprSensitive state tainted predicate
    let predicateReads ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => policyExprConfidentialReads state predicate
    let sensitivity ←
      recordSensitivePublicWrite
        state objectId (controlSensitive || valueSensitive || predicateSensitive) {}
    pure (tainted,
      sensitivity.merge
        (confidentialReadSensitivity (mergeStringSets valueReads predicateReads)))
  else if let some inner := taggedPayload? json "ArraySet" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    let index ← lookupFieldJson inner "index"
    let value ← lookupFieldJson inner "value"
    let indexSensitive ← policyExprSensitive state tainted index
    let valueSensitive ← policyExprSensitive state tainted value
    let indexReads ← policyExprConfidentialReads state index
    let valueReads ← policyExprConfidentialReads state value
    let predicateSensitive ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure false
      | some predicate => policyExprSensitive state tainted predicate
    let predicateReads ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => policyExprConfidentialReads state predicate
    let sensitivity ←
      recordSensitivePublicWrite
        state objectId
        (controlSensitive || indexSensitive || valueSensitive || predicateSensitive)
        {}
    pure (tainted,
      sensitivity.merge
        (confidentialReadSensitivity
          (mergeStringSets (mergeStringSets indexReads valueReads) predicateReads)))
  else if let some inner := taggedPayload? json "MapPut" then
    let objectId : Nat ← lookupFieldAs inner "object_id"
    let key ← lookupFieldJson inner "key"
    let value ← lookupFieldJson inner "value"
    let keySensitive ← policyExprSensitive state tainted key
    let valueSensitive ← policyExprSensitive state tainted value
    let keyReads ← policyExprConfidentialReads state key
    let valueReads ← policyExprConfidentialReads state value
    let predicateSensitive ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure false
      | some predicate => policyExprSensitive state tainted predicate
    let predicateReads ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => policyExprConfidentialReads state predicate
    let sensitivity ←
      recordSensitivePublicWrite
        state objectId
        (controlSensitive || keySensitive || valueSensitive || predicateSensitive)
        {}
    pure (tainted,
      sensitivity.merge
        (confidentialReadSensitivity
          (mergeStringSets (mergeStringSets keyReads valueReads) predicateReads)))
  else if let some inner := taggedPayload? json "Return" then
    let value? ← lookupOptionalFieldJson inner "value"
    let returnSensitive ←
      match value? with
      | none => pure false
      | some value => policyExprSensitive state tainted value
    let reads ←
      match value? with
      | none => pure []
      | some value => policyExprConfidentialReads state value
    pure (tainted, { returnSensitive := controlSensitive || returnSensitive, confidentialReads := reads })
  else
    throw "unsupported statement shape in translation bundle"

private partial def collectPolicySensitivityStatements
  (state : List ImportedProofRelevantStateObjectView)
  (items : List Json)
  (tainted : List String)
  (controlSensitive : Bool) :
  Except String (List String × PolicySensitivityJson) :=
  items.foldlM (init := (tainted, ({} : PolicySensitivityJson))) fun acc item => do
    let (tainted, sensitivity) := acc
    let (tainted, nextSensitivity) ←
      collectPolicySensitivityStatement state item tainted controlSensitive
    pure (tainted, sensitivity.merge nextSensitivity)

end

private def paramNameAt? :
  List ImportedProofRelevantParamView → Nat → Option String
  | [], _ => none
  | param :: _, 0 => some param.name
  | _ :: rest, index + 1 => paramNameAt? rest index

private def policySensitivityBodyStrings
  (state : List ImportedProofRelevantStateObjectView)
  (secretArgs : List Nat)
  (params : List ImportedProofRelevantParamView)
  (body : List String) : Except String PolicySensitivityJson := do
  let tainted :=
    secretArgs.foldl
      (fun acc index =>
        match paramNameAt? params index with
        | some name => insertStringSet name acc
        | none => acc)
      []
  let bodyJson ← body.mapM parseJsonString
  let (_, sensitivity) ←
    collectPolicySensitivityStatements state bodyJson tainted false
  pure sensitivity

private def sensitivePublicWritesDeclared
  (sensitivity : PolicySensitivityJson)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  sensitivity.sensitivePublicWrites.all
    (fun name => entry.public_state_declassifies.contains name)

def publicEntrypointConfidentialReadsWellFormed
  (fn : ImportedProofRelevantFunctionView)
  (sensitivity : PolicySensitivityJson) : Bool :=
  fn.confidential || sensitivity.confidentialReads.isEmpty

theorem publicEntrypointConfidentialReadsWellFormed_no_reads
  {fn : ImportedProofRelevantFunctionView}
  {sensitivity : PolicySensitivityJson}
  (hPolicy : publicEntrypointConfidentialReadsWellFormed fn sensitivity = true)
  (hPublic : fn.confidential = false) :
  sensitivity.confidentialReads.isEmpty = true := by
  unfold publicEntrypointConfidentialReadsWellFormed at hPolicy
  rw [hPublic] at hPolicy
  simp only [Bool.false_or] at hPolicy
  exact hPolicy

private def sensitiveReturnPolicyWellFormed
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView)
  (sensitivity : PolicySensitivityJson) : Bool :=
  if entry.returns == "declassified" then
    entry.declassifies.contains "return" &&
      (fn.confidential || sensitivity.returnSensitive)
  else if sensitivity.returnSensitive then
    entry.returns == "encrypted_to_client" && fn.confidential &&
      !(entry.declassifies.contains "return")
  else
    true

private def sensitiveStatusPolicyWellFormed
  (entry : ImportedProofRelevantEntrypointView)
  (sensitivity : PolicySensitivityJson) : Bool :=
  if entry.status == "declassified" then
    entry.declassifies.contains "success" && sensitivity.statusSensitive
  else if sensitivity.statusSensitive then
    false
  else
    true

private def declassificationLabelUsedByPolicy
  (entry : ImportedProofRelevantEntrypointView) (label : String) : Bool :=
  (label == "return" && entry.returns == "declassified") ||
    (label == "success" && entry.status == "declassified")

private def declaredDeclassificationPoliciesWellFormed
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  (entry.returns != "declassified" || entry.declassifies.contains "return") &&
    (entry.returns != "encrypted_to_client" || !(entry.declassifies.contains "return")) &&
    (entry.status != "declassified" || entry.declassifies.contains "success") &&
    entry.declassifies.all (declassificationLabelUsedByPolicy entry)

private def publicStateDeclassifiesExact
  (sensitivity : PolicySensitivityJson)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  sensitivity.sensitivePublicWrites.all
    (fun name => entry.public_state_declassifies.contains name) &&
    entry.public_state_declassifies.all
      (fun name => sensitivity.sensitivePublicWrites.contains name)

mutual

private partial def statementLoopsHaveExactBounds
  (json : Json)
  (loopEnv : List (String × Nat) := []) : Except String Bool := do
  if let some inner := taggedPayload? json "If" then
    let thenOk ← statementsLoopsHaveExactBounds (← lookupFieldAs inner "then_body") loopEnv
    let elseOk ← statementsLoopsHaveExactBounds (← lookupFieldAs inner "else_body") loopEnv
    pure (thenOk && elseOk)
  else if let some inner := taggedPayload? json "For" then
    let startExpr ← lookupFieldJson inner "start"
    let endExpr ← lookupFieldJson inner "end"
    let body : List Json ← lookupFieldAs inner "body"
    let indexVar : String ← lookupFieldAs inner "index_var"
    match evalLoopBoundJson startExpr loopEnv, evalLoopBoundJson endExpr loopEnv with
    | some startValue, some endValue =>
        let rec go (index : Nat) : Except String Bool := do
          if index < endValue then
            let bodyOk ← statementsLoopsHaveExactBounds body ((indexVar, index) :: loopEnv)
            if bodyOk then
              go (index + 1)
            else
              pure false
          else
            pure true
        go startValue
    | _, _ => pure false
  else
    pure true

private partial def statementsLoopsHaveExactBounds
  (items : List Json)
  (loopEnv : List (String × Nat) := []) : Except String Bool :=
  items.foldlM (init := true) fun acc item => do
    if !acc then
      pure false
    else
      statementLoopsHaveExactBounds item loopEnv

end

private def functionLoopAdmissionWellFormed
  (fn : ImportedProofRelevantFunctionView) : Bool :=
  match fn.body.mapM (fun item => parseJsonString item) with
  | .ok body =>
      match statementsLoopsHaveExactBounds body with
      | .ok ok => ok
      | .error _ => false
  | .error _ => false

private def functionPublicAccessPolicyWellFormed
  (state : List ImportedProofRelevantStateObjectView)
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  match policySensitivityBodyStrings state fn.secret_args fn.params fn.body with
  | .ok sensitivity =>
      publicEntrypointConfidentialReadsWellFormed fn sensitivity &&
        declaredDeclassificationPoliciesWellFormed entry &&
        sensitiveReturnPolicyWellFormed fn entry sensitivity &&
        sensitiveStatusPolicyWellFormed entry sensitivity &&
        publicStateDeclassifiesExact sensitivity entry
  | .error _ => false

theorem functionPublicAccessPolicyWellFormed_public_no_confidential_reads
  {state : List ImportedProofRelevantStateObjectView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  {sensitivity : PolicySensitivityJson}
  (hSensitivity :
    policySensitivityBodyStrings state fn.secret_args fn.params fn.body = .ok sensitivity)
  (hPolicy : functionPublicAccessPolicyWellFormed state fn entry = true)
  (hPublic : fn.confidential = false) :
  sensitivity.confidentialReads.isEmpty = true := by
  unfold functionPublicAccessPolicyWellFormed at hPolicy
  rw [hSensitivity] at hPolicy
  simp only [Bool.and_eq_true] at hPolicy
  exact publicEntrypointConfidentialReadsWellFormed_no_reads hPolicy.1.1.1.1 hPublic

private def functionMetadataWellFormed
  (view : ImportedProofRelevantContractView)
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  functionSecretPolicyWellFormed fn entry &&
    functionLoopAdmissionWellFormed fn &&
    publicStateDeclassifyTargetsWellFormed
      view.state entry.public_state_declassifies &&
    functionPublicAccessPolicyWellFormed view.state fn entry

private def functionsMetadataWellFormed
  (view : ImportedProofRelevantContractView) :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → Bool
  | [], _ => true
  | fn :: rest, entrypoints =>
      match lookupEntrypoint fn.signature entrypoints with
      | none => false
      | some entry =>
          functionMetadataWellFormed view fn entry &&
            functionsMetadataWellFormed view rest entrypoints

def countOramAccessesInBodyStrings
  (body : List String)
  (state : List ImportedProofRelevantStateObjectView) :
  Except String (List (Nat × Nat)) :=
  body.foldlM (init := ([] : List (Nat × Nat))) fun acc item => do
    pure <| mergePairCounts acc
      (← collectOramStatementAccesses (← parseJsonString item) state)

def oramAccessesMatchExpected
  (expected : List (Nat × Nat))
  (actual : List ImportedProofRelevantOramAccessView) : Bool :=
  distinctList (pairCountObjectIds expected) &&
    distinctList (entryOramAccessObjectIds actual) &&
    listedEquivalent (pairCountObjectIds expected) (entryOramAccessObjectIds actual) &&
    expected.all (fun entry => lookupOramAccessCount entry.fst actual == entry.snd) &&
    actual.all (fun entry => lookupPairCount entry.object_id expected == entry.accesses)

def validateImportedOramShape
  (stateObject : ImportedProofRelevantStateObjectView)
  (manifestObject : ImportedProofRelevantManifestObjectView)
  (accesses : Nat) : Bool :=
  match manifestObject.oram with
  | none => false
  | some oram =>
      stateObject.kind == "map" &&
        stateObject.backend == "oram" &&
        manifestObject.kind == "map" &&
        manifestObject.backend == "oram" &&
        oram.scheme == stateObject.oram_scheme &&
        (if accesses > 1 then oram.scheme == translationPathOramScheme else true) &&
        (if oram.scheme == translationSurrogateOramScheme then
          oram.blocks_per_bucket == 2 &&
            oram.bucket_size ==
              translationOramBucketHeaderBytes + oram.blocks_per_bucket * oram.block_size &&
            oram.bucket_count > 0 &&
            oram.metadata_pages_per_access == oram.metadata_pages + 1 &&
            oram.buckets_per_access == max (oram.tree_height + 2) 3 &&
            oram.stash_bound == 0 &&
            oram.recursion_depth == 0 &&
            oram.accesses_per_call == 1
        else if translationIsPathOramScheme oram.scheme then
          let leafCount := (oram.bucket_count + 1) / 2
          oram.bucket_count > 0 &&
            translationPathOramPositionMapShapeWellFormed
              oram.scheme
              (stateObject.capacity.getD 1)
              oram.recursion_depth &&
            oram.bucket_count % 2 == 1 &&
            isPowerOfTwo leafCount &&
            oram.blocks_per_bucket == 5 &&
            oram.bucket_size ==
              translationOramBucketHeaderBytes + oram.blocks_per_bucket * oram.block_size &&
            oram.stash_bound == max (stateObject.capacity.getD 1) 1 &&
            oram.tree_height == log2Ceil leafCount &&
            oram.bucket_count == 2 * leafCount - 1 &&
            oram.metadata_pages_per_access == oram.metadata_pages + 1 &&
            oram.buckets_per_access == oram.tree_height + 1 &&
            oram.accesses_per_call == 1
        else
          false)

private def overCapacityPathOramStateForCheck : ImportedProofRelevantStateObjectView :=
  { id := 1
  , name := "oversized"
  , kind := "map"
  , backend := "oram"
  , oram_scheme := translationPathOramScheme
  , value_type := "\"uint256\""
  , value_type_short_name := "uint256"
  , key_type := some "\"bytes32\""
  , key_type_short_name := some "bytes32"
  , capacity := some (translationPathOramLocalPosmapMaxCapacity + 1)
  , confidential := true
  }

private def overCapacityPathOramManifestForCheck : ImportedProofRelevantManifestObjectView :=
  { id := 1
  , name := "oversized"
  , kind := "map"
  , backend := "oram"
  , capacity := some (translationPathOramLocalPosmapMaxCapacity + 1)
  , value_type := some "uint256"
  , key_type := some "bytes32"
  , oram := some
      { scheme := translationPathOramScheme
      , block_size := 64
      , bucket_size := translationOramBucketHeaderBytes + 5 * 64
      , bucket_count := 511
      , blocks_per_bucket := 5
      , tree_height := 8
      , stash_bound := translationPathOramLocalPosmapMaxCapacity + 1
      , recursion_depth := 0
      , metadata_pages := 1
      , metadata_pages_per_access := 2
      , buckets_per_access := 9
      , accesses_per_call := 1
      }
  }

theorem validateImportedOramShape_rejects_path_oram_capacity_above_local_posmap_cap :
  validateImportedOramShape
      overCapacityPathOramStateForCheck
      overCapacityPathOramManifestForCheck
      1 = false := by
  native_decide

private def privateOverCapacityPathOramStateForCheck : ImportedProofRelevantStateObjectView :=
  { overCapacityPathOramStateForCheck with
    oram_scheme := translationPathOramPrivatePosmapScheme
  }

private def privateOverCapacityPathOramManifestForCheck : ImportedProofRelevantManifestObjectView :=
  { overCapacityPathOramManifestForCheck with
    oram := some
      { scheme := translationPathOramPrivatePosmapScheme
      , block_size := 64
      , bucket_size := translationOramBucketHeaderBytes + 5 * 64
      , bucket_count := 511
      , blocks_per_bucket := 5
      , tree_height := 8
      , stash_bound := translationPathOramLocalPosmapMaxCapacity + 1
      , recursion_depth := 1
      , metadata_pages := 1
      , metadata_pages_per_access := 2
      , buckets_per_access := 9
      , accesses_per_call := 1
      }
  }

theorem validateImportedOramShape_accepts_private_posmap_capacity_above_local_posmap_cap :
  validateImportedOramShape
      privateOverCapacityPathOramStateForCheck
      privateOverCapacityPathOramManifestForCheck
      1 = true := by
  native_decide

def expectedCommitOpsForFunction
  (view : ImportedProofRelevantContractView)
  (fn : ImportedProofRelevantFunctionView) :
  Except String Nat := do
  let accessedObjects ← accessedObjectIdsInBodyStrings fn.body
  let oramAccesses ← countOramAccessesInBodyStrings fn.body view.state
  accessedObjects.foldlM (init := 0) fun acc objectId => do
    let stateObject ←
      match stateObjectById? view.state objectId with
      | some object => pure object
      | none => throw s!"unknown object id {objectId}"
    let addition ←
      if stateObject.kind == "cell" then
        pure 1
      else if stateObject.kind == "array" || stateObject.kind == "map" then
        if stateObject.backend == "oram" then
          match manifestObjectById? view.manifest.objects objectId with
          | some manifestObject =>
              match manifestObject.oram with
              | some oram =>
                  let perAccess := totalCommitOps oram
                  if translationIsPathOramScheme stateObject.oram_scheme then
                    pure <| perAccess * lookupPairCount objectId oramAccesses
                  else
                    pure perAccess
              | none => throw s!"ORAM object {objectId} is missing ORAM manifest data"
          | none => throw s!"manifest is missing object id {objectId}"
        else
          pure <| stateObject.capacity.getD 1
      else
        throw s!"unsupported state object kind for object id {objectId}"
    pure (acc + addition)

private def functionOramManifestReplayMessage
  (view : ImportedProofRelevantContractView)
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : String :=
  match countOramAccessesInBodyStrings fn.body view.state with
  | .error err =>
      s!"{fn.signature}: failed to compute ORAM accesses: {err}"
  | .ok expected =>
      if !(oramAccessesMatchExpected expected entry.oram_accesses) then
        s!"{fn.signature}: expected ORAM accesses {renderPairCounts expected}, manifest has {renderEntrypointOramAccesses entry.oram_accesses}"
      else
        match expected.find? fun access =>
          match stateObjectById? view.state access.fst, manifestObjectById? view.manifest.objects access.fst with
          | some stateObject, some manifestObject =>
              !(validateImportedOramShape stateObject manifestObject access.snd)
          | _, _ => true
        with
        | some (objectId, accesses) =>
            s!"{fn.signature}: ORAM object {objectId} with {accesses} accesses violates theorem-facing ORAM shape"
        | none =>
            ""

private def functionOramAccessesMatchManifest
  (view : ImportedProofRelevantContractView)
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  match countOramAccessesInBodyStrings fn.body view.state with
  | .error _ => false
  | .ok expected =>
      oramAccessesMatchExpected expected entry.oram_accesses &&
        expected.all fun access =>
          match stateObjectById? view.state access.fst, manifestObjectById? view.manifest.objects access.fst with
          | some stateObject, some manifestObject =>
              validateImportedOramShape stateObject manifestObject access.snd
          | _, _ => false

private def functionMaxCommitOpsMismatchMessage
  (view : ImportedProofRelevantContractView)
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : String :=
  match expectedCommitOpsForFunction view fn with
  | .error err =>
      s!"{fn.signature}: failed to compute max_commit_ops: {err}"
  | .ok expected =>
      s!"{fn.signature}: expected max_commit_ops={expected}, manifest has {entry.max_commit_ops}"

private def functionMaxCommitOpsMatchesManifest
  (view : ImportedProofRelevantContractView)
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  match expectedCommitOpsForFunction view fn with
  | .error _ => false
  | .ok expected => entry.max_commit_ops == expected

private def functionCountsMatchManifest
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  match countBodyStrings fn.body with
  | .error _ => false
  | .ok counts =>
      entry.arena_bytes == 4096 + counts.localCount * 64 &&
        entry.max_stack_words == 64 + counts.localCount &&
        entry.uocell_reads == counts.cellReads &&
        entry.uocell_writes == counts.cellWrites &&
        entry.uoarray_reads == counts.arrayReads &&
        entry.uoarray_writes == counts.arrayWrites &&
      entry.uomap_reads == counts.mapReads &&
        entry.uomap_writes == counts.mapWrites

private def renderCountSummary (counts : CountSummary) : String :=
  s!"locals={counts.localCount}, cellReads={counts.cellReads}, cellWrites={counts.cellWrites}, arrayReads={counts.arrayReads}, arrayWrites={counts.arrayWrites}, mapReads={counts.mapReads}, mapWrites={counts.mapWrites}"

private def renderManifestCountSummary
  (entry : ImportedProofRelevantEntrypointView) : String :=
  s!"arena={entry.arena_bytes}, stack={entry.max_stack_words}, cellReads={entry.uocell_reads}, cellWrites={entry.uocell_writes}, arrayReads={entry.uoarray_reads}, arrayWrites={entry.uoarray_writes}, mapReads={entry.uomap_reads}, mapWrites={entry.uomap_writes}"

private def functionCountMismatchMessage
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : String :=
  match countBodyStrings fn.body with
  | .error err =>
      s!"{fn.signature}: failed to count body: {err}"
  | .ok counts =>
      let expectedArena := 4096 + counts.localCount * 64
      let expectedStack := 64 + counts.localCount
      s!"{fn.signature}: computed {renderCountSummary counts}, expected arena={expectedArena}, stack={expectedStack}; manifest has {renderManifestCountSummary entry}"

private def functionsMatchManifestCounts :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → Bool
  | [], _ => true
  | fn :: rest, entrypoints =>
      match lookupEntrypoint fn.signature entrypoints with
      | none => false
      | some entry =>
          functionCountsMatchManifest fn entry &&
            functionsMatchManifestCounts rest entrypoints

private def functionsMatchManifestBoundaryLengths :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → Bool
  | [], _ => true
  | fn :: rest, entrypoints =>
      match lookupEntrypoint fn.signature entrypoints with
      | none => false
      | some entry =>
          functionBoundaryLengthsMatchManifest fn entry &&
            functionsMatchManifestBoundaryLengths rest entrypoints

private def manifestBoundaryLengthMismatchMessages :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → List String
  | [], _ => []
  | fn :: rest, entrypoints =>
      let tail := manifestBoundaryLengthMismatchMessages rest entrypoints
      match lookupEntrypoint fn.signature entrypoints with
      | none => s!"{fn.signature}: missing manifest entrypoint" :: tail
      | some entry =>
          if functionBoundaryLengthsMatchManifest fn entry then
            tail
          else
            functionBoundaryLengthMismatchMessage fn entry :: tail

private def manifestCountMismatchMessages :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → List String
  | [], _ => []
  | fn :: rest, entrypoints =>
      let tail := manifestCountMismatchMessages rest entrypoints
      match lookupEntrypoint fn.signature entrypoints with
      | none => s!"{fn.signature}: missing manifest entrypoint" :: tail
      | some entry =>
          if functionCountsMatchManifest fn entry then
            tail
          else
            functionCountMismatchMessage fn entry :: tail

private def functionsMatchManifestOramAccesses
  (view : ImportedProofRelevantContractView) :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → Bool
  | [], _ => true
  | fn :: rest, entrypoints =>
      match lookupEntrypoint fn.signature entrypoints with
      | none => false
      | some entry =>
          functionOramAccessesMatchManifest view fn entry &&
            functionsMatchManifestOramAccesses view rest entrypoints

private def manifestOramMismatchMessages
  (view : ImportedProofRelevantContractView) :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → List String
  | [], _ => []
  | fn :: rest, entrypoints =>
      let tail := manifestOramMismatchMessages view rest entrypoints
      match lookupEntrypoint fn.signature entrypoints with
      | none => s!"{fn.signature}: missing manifest entrypoint" :: tail
      | some entry =>
          if functionOramAccessesMatchManifest view fn entry then
            tail
          else
            functionOramManifestReplayMessage view fn entry :: tail

private def functionsMatchManifestCommitOps
  (view : ImportedProofRelevantContractView) :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → Bool
  | [], _ => true
  | fn :: rest, entrypoints =>
      match lookupEntrypoint fn.signature entrypoints with
      | none => false
      | some entry =>
          functionMaxCommitOpsMatchesManifest view fn entry &&
            functionsMatchManifestCommitOps view rest entrypoints

private def manifestCommitOpMismatchMessages
  (view : ImportedProofRelevantContractView) :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → List String
  | [], _ => []
  | fn :: rest, entrypoints =>
      let tail := manifestCommitOpMismatchMessages view rest entrypoints
      match lookupEntrypoint fn.signature entrypoints with
      | none => s!"{fn.signature}: missing manifest entrypoint" :: tail
      | some entry =>
          if functionMaxCommitOpsMatchesManifest view fn entry then
            tail
          else
            functionMaxCommitOpsMismatchMessage view fn entry :: tail

private def functionMetadataMismatchMessage
  (view : ImportedProofRelevantContractView)
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : String :=
  let secretPolicyOk := functionSecretPolicyWellFormed fn entry
  let publicTargetsOk :=
    publicStateDeclassifyTargetsWellFormed
      view.state entry.public_state_declassifies
  let loopAdmissionOk := functionLoopAdmissionWellFormed fn
  let publicAccessOk := functionPublicAccessPolicyWellFormed view.state fn
    entry
  let confidentialReadSummary :=
    match policySensitivityBodyStrings view.state fn.secret_args fn.params fn.body with
    | .ok sensitivity => String.intercalate "," sensitivity.confidentialReads
    | .error err => s!"<policy sensitivity error: {err}>"
  s!"{fn.signature}: metadata policy failed (secret policy={secretPolicyOk}, loop admission={loopAdmissionOk}, public_state_declassifies={publicTargetsOk}, public access={publicAccessOk}, confidential_reads=[{confidentialReadSummary}])"

private def metadataMismatchMessages
  (view : ImportedProofRelevantContractView) :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → List String
  | [], _ => []
  | fn :: rest, entrypoints =>
      let tail := metadataMismatchMessages view rest entrypoints
      match lookupEntrypoint fn.signature entrypoints with
      | none => s!"{fn.signature}: missing manifest entrypoint" :: tail
      | some entry =>
          if functionMetadataWellFormed view fn entry then
            tail
          else
            functionMetadataMismatchMessage view fn entry :: tail

private def stateObjectMatchesManifestObject
  (stateObject : ImportedProofRelevantStateObjectView)
  (manifestObject : ImportedProofRelevantManifestObjectView) : Bool :=
  manifestObject.id == stateObject.id &&
    manifestObject.name == stateObject.name &&
    manifestObject.kind == stateObject.kind &&
    manifestObject.backend == stateObject.backend &&
    manifestObject.capacity == stateObject.capacity &&
    manifestObject.value_type == some stateObject.value_type_short_name &&
    manifestObject.key_type == stateObject.key_type_short_name &&
    (if stateObject.backend == "oram" then
      match manifestObject.oram with
      | some oram => oram.scheme == stateObject.oram_scheme
      | none => false
    else
      manifestObject.oram.isNone)

private def stateObjectManifestMismatchMessage
  (stateObject : ImportedProofRelevantStateObjectView)
  (_manifestObject : ImportedProofRelevantManifestObjectView) : String :=
  s!"state object {stateObject.name}: manifest object fields do not match expected state object manifest"

private def stateObjectsMatchManifestObjects
  (view : ImportedProofRelevantContractView) : Bool :=
  view.state.all fun stateObject =>
    match manifestObjectById? view.manifest.objects stateObject.id with
    | some manifestObject => stateObjectMatchesManifestObject stateObject manifestObject
    | none => false

private def stateObjectManifestMismatchMessages
  (view : ImportedProofRelevantContractView) : List String :=
  view.state.foldr (init := []) fun stateObject tail =>
    match manifestObjectById? view.manifest.objects stateObject.id with
    | some manifestObject =>
        if stateObjectMatchesManifestObject stateObject manifestObject then
          tail
        else
          stateObjectManifestMismatchMessage stateObject manifestObject :: tail
    | none =>
        s!"state object {stateObject.name}: missing manifest object" :: tail

private def confidentialObjectsAvoidRawBackends
  (view : ImportedProofRelevantContractView) : Bool :=
  view.state.all fun stateObject =>
    !(stateObject.confidential && stateObject.backend == "raw")

private def confidentialRawBackendMessages
  (view : ImportedProofRelevantContractView) : List String :=
  view.state.foldr (init := []) fun stateObject tail =>
    if stateObject.confidential && stateObject.backend == "raw" then
      s!"confidential state object {stateObject.name} uses raw backend" :: tail
    else
      tail

private def kernelStepTargetsNonRawStateObject
  (state : List ImportedProofRelevantStateObjectView)
  (step : ImportedProofRelevantKernelStepView) : Bool :=
  match step.object_id with
  | none => true
  | some objectId =>
      match stateObjectById? state objectId with
      | some stateObject => stateObject.backend != "raw" && stateObject.confidential
      | none => false

private def kernelStepsTargetNonRawStateObjects
  (state : List ImportedProofRelevantStateObjectView) :
  List ImportedProofRelevantKernelStepView → Bool
  | [] => true
  | step :: rest =>
      kernelStepTargetsNonRawStateObject state step &&
        kernelStepsTargetNonRawStateObjects state rest

private def confidentialEntrypointsAvoidRawKernelTargets :
  ImportedProofRelevantContractView →
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → Bool
  | _, [], _ => true
  | view, fn :: rest, entrypoints =>
      match lookupEntrypoint fn.signature entrypoints with
      | none => false
      | some entry =>
          (if fn.confidential then
            kernelStepsTargetNonRawStateObjects view.state entry.kernel_steps
          else
            true) &&
            confidentialEntrypointsAvoidRawKernelTargets view rest entrypoints

private def kernelStepRawTargetMessages
  (state : List ImportedProofRelevantStateObjectView)
  (signature : String) :
  List ImportedProofRelevantKernelStepView → List String
  | [] => []
  | step :: rest =>
      let tail := kernelStepRawTargetMessages state signature rest
      match step.object_id with
      | none => tail
      | some objectId =>
          match stateObjectById? state objectId with
          | none =>
              s!"{signature}: kernel step {step.opcode}@{objectId} targets unknown state object" ::
                tail
          | some stateObject =>
              if stateObject.backend == "raw" then
                s!"{signature}: kernel step {step.opcode}@{objectId} targets raw backend object {stateObject.name}" ::
                  tail
              else if !stateObject.confidential then
                s!"{signature}: kernel step {step.opcode}@{objectId} targets non-confidential state object {stateObject.name}" ::
                  tail
              else
                tail

private def confidentialRawKernelTargetMessages :
  ImportedProofRelevantContractView →
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → List String
  | _, [], _ => []
  | view, fn :: rest, entrypoints =>
      let tail := confidentialRawKernelTargetMessages view rest entrypoints
      match lookupEntrypoint fn.signature entrypoints with
      | none => s!"{fn.signature}: missing manifest entrypoint" :: tail
      | some entry =>
          if fn.confidential then
            kernelStepRawTargetMessages view.state fn.signature entry.kernel_steps ++ tail
          else
            tail

mutual

private partial def exprContainsKernelAccessJson (json : Json) : Except String Bool := do
  if taggedPayload? json "Literal" |>.isSome then
    pure false
  else if taggedPayload? json "Var" |>.isSome then
    pure false
  else if let some inner := taggedPayload? json "Unary" then
    exprContainsKernelAccessJson (← lookupFieldJson inner "expr")
  else if let some inner := taggedPayload? json "Binary" then
    pure <|
      (← exprContainsKernelAccessJson (← lookupFieldJson inner "lhs")) ||
      (← exprContainsKernelAccessJson (← lookupFieldJson inner "rhs"))
  else if let some inner := taggedPayload? json "Select" then
    pure <|
      (← exprContainsKernelAccessJson (← lookupFieldJson inner "cond")) ||
      (← exprContainsKernelAccessJson (← lookupFieldJson inner "when_true")) ||
      (← exprContainsKernelAccessJson (← lookupFieldJson inner "when_false"))
  else if taggedPayload? json "CellGet" |>.isSome then
    pure true
  else if taggedPayload? json "ArrayGet" |>.isSome then
    pure true
  else if taggedPayload? json "MapGet" |>.isSome then
    pure true
  else if let some inner := taggedPayload? json "StructField" then
    exprContainsKernelAccessJson (← lookupFieldJson inner "base")
  else if let some inner := taggedPayload? json "ArrayIndex" then
    pure <|
      (← exprContainsKernelAccessJson (← lookupFieldJson inner "base")) ||
      (← exprContainsKernelAccessJson (← lookupFieldJson inner "index"))
  else if let some inner := taggedPayload? json "Keccak256" then
    exprContainsKernelAccessListJson (← lookupFieldAs inner "parts")
  else
    throw "unsupported expression shape in translation bundle"

private partial def exprContainsKernelAccessListJson
  (items : List Json) : Except String Bool :=
  items.foldlM (init := false) fun acc item => do
    pure <| acc || (← exprContainsKernelAccessJson item)

private partial def checkConfidentialKernelPureExprJson
  (json : Json) : Except String Unit := do
  if taggedPayload? json "Literal" |>.isSome then
    pure ()
  else if taggedPayload? json "Var" |>.isSome then
    pure ()
  else if let some inner := taggedPayload? json "Unary" then
    checkConfidentialKernelPureExprJson (← lookupFieldJson inner "expr")
  else if let some inner := taggedPayload? json "Binary" then
    checkConfidentialKernelPureExprJson (← lookupFieldJson inner "lhs")
    checkConfidentialKernelPureExprJson (← lookupFieldJson inner "rhs")
  else if let some inner := taggedPayload? json "Select" then
    checkConfidentialKernelPureExprJson (← lookupFieldJson inner "cond")
    checkConfidentialKernelPureExprJson (← lookupFieldJson inner "when_true")
    checkConfidentialKernelPureExprJson (← lookupFieldJson inner "when_false")
  else if let some inner := taggedPayload? json "Keccak256" then
    checkConfidentialKernelPureExprListJson (← lookupFieldAs inner "parts")
  else if taggedPayload? json "CellGet" |>.isSome then
    throw "select arm is outside the branchless fragment"
  else if taggedPayload? json "ArrayGet" |>.isSome then
    throw "select arm is outside the branchless fragment"
  else if taggedPayload? json "MapGet" |>.isSome then
    throw "select arm is outside the branchless fragment"
  else if taggedPayload? json "StructField" |>.isSome then
    throw "confidential struct-field access is not allowed"
  else if taggedPayload? json "ArrayIndex" |>.isSome then
    throw "confidential array indexing is not allowed"
  else
    throw "unsupported expression shape in translation bundle"

private partial def checkConfidentialKernelPureExprListJson
  (items : List Json) : Except String Unit :=
  items.forM fun item => checkConfidentialKernelPureExprJson item

private partial def checkConfidentialKernelExprJson
  (json : Json) : Except String Unit := do
  if taggedPayload? json "Literal" |>.isSome then
    pure ()
  else if taggedPayload? json "Var" |>.isSome then
    pure ()
  else if let some inner := taggedPayload? json "Unary" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "expr")
  else if let some inner := taggedPayload? json "Binary" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "lhs")
    checkConfidentialKernelExprJson (← lookupFieldJson inner "rhs")
  else if let some inner := taggedPayload? json "Select" then
    let whenTrue ← lookupFieldJson inner "when_true"
    let whenFalse ← lookupFieldJson inner "when_false"
    if (← exprContainsKernelAccessJson whenTrue) || (← exprContainsKernelAccessJson whenFalse) then
      throw "select arm contains kernel access"
    checkConfidentialKernelPureExprJson whenTrue
    checkConfidentialKernelPureExprJson whenFalse
    checkConfidentialKernelExprJson (← lookupFieldJson inner "cond")
  else if taggedPayload? json "CellGet" |>.isSome then
    pure ()
  else if let some inner := taggedPayload? json "ArrayGet" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "index")
  else if let some inner := taggedPayload? json "MapGet" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "key")
  else if taggedPayload? json "StructField" |>.isSome then
    throw "confidential struct-field access is not allowed"
  else if taggedPayload? json "ArrayIndex" |>.isSome then
    throw "confidential array indexing is not allowed"
  else if let some inner := taggedPayload? json "Keccak256" then
    checkConfidentialKernelExprListJson (← lookupFieldAs inner "parts")
  else
    throw "unsupported expression shape in translation bundle"

private partial def checkConfidentialKernelExprListJson
  (items : List Json) : Except String Unit :=
  items.forM fun item => checkConfidentialKernelExprJson item

private partial def checkConfidentialKernelStatementJson
  (json : Json) : Except String Unit := do
  if let some inner := taggedPayload? json "Declare" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "value")
  else if let some inner := taggedPayload? json "Assign" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "value")
  else if let some inner := taggedPayload? json "Require" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "cond")
  else if let some inner := taggedPayload? json "AbortIf" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "cond")
  else if taggedPayload? json "If" |>.isSome then
    throw "confidential control flow is not allowed"
  else if taggedPayload? json "For" |>.isSome then
    throw "confidential control flow is not allowed"
  else if let some inner := taggedPayload? json "CellSet" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "value")
    match ← lookupOptionalFieldJson inner "predicate" with
    | none => pure ()
    | some predicate => checkConfidentialKernelExprJson predicate
  else if let some inner := taggedPayload? json "ArraySet" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "index")
    checkConfidentialKernelExprJson (← lookupFieldJson inner "value")
    match ← lookupOptionalFieldJson inner "predicate" with
    | none => pure ()
    | some predicate => checkConfidentialKernelExprJson predicate
  else if let some inner := taggedPayload? json "MapPut" then
    checkConfidentialKernelExprJson (← lookupFieldJson inner "key")
    checkConfidentialKernelExprJson (← lookupFieldJson inner "value")
    match ← lookupOptionalFieldJson inner "predicate" with
    | none => pure ()
    | some predicate => checkConfidentialKernelExprJson predicate
  else if let some inner := taggedPayload? json "Return" then
    match ← lookupOptionalFieldJson inner "value" with
    | none => pure ()
    | some value => checkConfidentialKernelExprJson value
  else
    throw "unsupported statement shape in translation bundle"

end

private def checkConfidentialKernelBodyStrings
  (body : List String) : Except String Unit :=
  body.forM fun item => do
    checkConfidentialKernelStatementJson (← parseJsonString item)

private def renderKernelSteps
  (steps : List ImportedProofRelevantKernelStepView) : String :=
  String.intercalate ", "
    (steps.map fun step =>
      match step.object_id with
      | some objectId => s!"{step.opcode}@{objectId}"
      | none => step.opcode)

mutual

private partial def collectKernelStepsExprJson
  (json : Json) : Except String (List ImportedProofRelevantKernelStepView) := do
  if taggedPayload? json "Literal" |>.isSome then
    pure []
  else if taggedPayload? json "Var" |>.isSome then
    pure []
  else if let some inner := taggedPayload? json "Unary" then
    collectKernelStepsExprJson (← lookupFieldJson inner "expr")
  else if let some inner := taggedPayload? json "Binary" then
    pure <|
      (← collectKernelStepsExprJson (← lookupFieldJson inner "lhs")) ++
      (← collectKernelStepsExprJson (← lookupFieldJson inner "rhs"))
  else if let some inner := taggedPayload? json "Select" then
    collectKernelStepsExprJson (← lookupFieldJson inner "cond")
  else if let some inner := taggedPayload? json "CellGet" then
    pure [{ opcode := "CellGet", object_id := some (← lookupFieldAs inner "object_id") }]
  else if let some inner := taggedPayload? json "ArrayGet" then
    pure <|
      (← collectKernelStepsExprJson (← lookupFieldJson inner "index")) ++
      [{ opcode := "ArrayGet", object_id := some (← lookupFieldAs inner "object_id") }]
  else if let some inner := taggedPayload? json "MapGet" then
    pure <|
      (← collectKernelStepsExprJson (← lookupFieldJson inner "key")) ++
      [{ opcode := "MapGet", object_id := some (← lookupFieldAs inner "object_id") }]
  else if taggedPayload? json "StructField" |>.isSome then
    throw "confidential struct-field access is not allowed"
  else if taggedPayload? json "ArrayIndex" |>.isSome then
    throw "confidential array indexing is not allowed"
  else if let some inner := taggedPayload? json "Keccak256" then
    collectKernelStepsExprListJson (← lookupFieldAs inner "parts")
  else
    throw "unsupported expression shape in translation bundle"

private partial def collectKernelStepsExprListJson
  (items : List Json) : Except String (List ImportedProofRelevantKernelStepView) :=
  items.foldlM (init := ([] : List ImportedProofRelevantKernelStepView)) fun acc item => do
    pure <| acc ++ (← collectKernelStepsExprJson item)

private partial def collectKernelStepsStatementJson
  (json : Json) : Except String (List ImportedProofRelevantKernelStepView) := do
  if let some inner := taggedPayload? json "Declare" then
    collectKernelStepsExprJson (← lookupFieldJson inner "value")
  else if let some inner := taggedPayload? json "Assign" then
    collectKernelStepsExprJson (← lookupFieldJson inner "value")
  else if let some inner := taggedPayload? json "Require" then
    collectKernelStepsExprJson (← lookupFieldJson inner "cond")
  else if let some inner := taggedPayload? json "AbortIf" then
    collectKernelStepsExprJson (← lookupFieldJson inner "cond")
  else if taggedPayload? json "If" |>.isSome then
    throw "confidential control flow is not allowed"
  else if taggedPayload? json "For" |>.isSome then
    throw "confidential control flow is not allowed"
  else if let some inner := taggedPayload? json "CellSet" then
    let valueSteps ← collectKernelStepsExprJson (← lookupFieldJson inner "value")
    let predicateSteps ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => collectKernelStepsExprJson predicate
    pure <|
      valueSteps ++ predicateSteps ++
        [{ opcode := "CellSet", object_id := some (← lookupFieldAs inner "object_id") }]
  else if let some inner := taggedPayload? json "ArraySet" then
    let indexSteps ← collectKernelStepsExprJson (← lookupFieldJson inner "index")
    let valueSteps ← collectKernelStepsExprJson (← lookupFieldJson inner "value")
    let predicateSteps ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => collectKernelStepsExprJson predicate
    pure <|
      indexSteps ++ valueSteps ++ predicateSteps ++
        [{ opcode := "ArraySet", object_id := some (← lookupFieldAs inner "object_id") }]
  else if let some inner := taggedPayload? json "MapPut" then
    let keySteps ← collectKernelStepsExprJson (← lookupFieldJson inner "key")
    let valueSteps ← collectKernelStepsExprJson (← lookupFieldJson inner "value")
    let predicateSteps ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure []
      | some predicate => collectKernelStepsExprJson predicate
    pure <|
      keySteps ++ valueSteps ++ predicateSteps ++
        [{ opcode := "MapPut", object_id := some (← lookupFieldAs inner "object_id") }]
  else if let some inner := taggedPayload? json "Return" then
    match ← lookupOptionalFieldJson inner "value" with
    | none => pure []
    | some value => collectKernelStepsExprJson value
  else
    throw "unsupported statement shape in translation bundle"

end

private def expectedKernelStepsForConfidentialBodyStrings
  (body : List String) : Except String (List ImportedProofRelevantKernelStepView) := do
  checkConfidentialKernelBodyStrings body
  let bodySteps ← body.foldlM (init := ([] : List ImportedProofRelevantKernelStepView)) fun acc item => do
    pure <| acc ++ (← collectKernelStepsStatementJson (← parseJsonString item))
  pure <|
    [{ opcode := "Begin", object_id := none }] ++
      bodySteps ++
      [{ opcode := "Commit", object_id := none }, { opcode := "Wipe", object_id := none }]

mutual

private partial def lowerConfidentialKernelPureExprJson
  (json : Json) : Except String ImportedConfidentialKernelPureExpr := do
  if let some payload := taggedPayload? json "Literal" then
    pure <| .literal payload
  else if let some payload := taggedPayload? json "Var" then
    pure <| .var (← fromJson? payload)
  else if let some inner := taggedPayload? json "Unary" then
    pure <| .unary
      (← lookupFieldJson inner "op")
      (← lowerConfidentialKernelPureExprJson (← lookupFieldJson inner "expr"))
  else if let some inner := taggedPayload? json "Binary" then
    pure <| .binary
      (← lookupFieldJson inner "op")
      (← lowerConfidentialKernelPureExprJson (← lookupFieldJson inner "lhs"))
      (← lowerConfidentialKernelPureExprJson (← lookupFieldJson inner "rhs"))
  else if let some inner := taggedPayload? json "Select" then
    pure <| .select
      (← lowerConfidentialKernelPureExprJson (← lookupFieldJson inner "cond"))
      (← lowerConfidentialKernelPureExprJson (← lookupFieldJson inner "when_true"))
      (← lowerConfidentialKernelPureExprJson (← lookupFieldJson inner "when_false"))
  else if let some inner := taggedPayload? json "Keccak256" then
    let parts : List Json ← lookupFieldAs inner "parts"
    pure <| .keccak256 (← parts.mapM lowerConfidentialKernelPureExprJson)
  else if taggedPayload? json "CellGet" |>.isSome then
    throw "select arm is outside the branchless fragment"
  else if taggedPayload? json "ArrayGet" |>.isSome then
    throw "select arm is outside the branchless fragment"
  else if taggedPayload? json "MapGet" |>.isSome then
    throw "select arm is outside the branchless fragment"
  else if taggedPayload? json "StructField" |>.isSome then
    throw "confidential struct-field access is not allowed"
  else if taggedPayload? json "ArrayIndex" |>.isSome then
    throw "confidential array indexing is not allowed"
  else
    throw "unsupported expression shape in translation bundle"

private partial def lowerConfidentialKernelExprJson
  (json : Json) : Except String ImportedConfidentialKernelExpr := do
  if let some payload := taggedPayload? json "Literal" then
    pure <| .literal payload
  else if let some payload := taggedPayload? json "Var" then
    pure <| .var (← fromJson? payload)
  else if let some inner := taggedPayload? json "Unary" then
    pure <| .unary
      (← lookupFieldJson inner "op")
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "expr"))
  else if let some inner := taggedPayload? json "Binary" then
    pure <| .binary
      (← lookupFieldJson inner "op")
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "lhs"))
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "rhs"))
  else if let some inner := taggedPayload? json "Select" then
    let whenTrue ← lookupFieldJson inner "when_true"
    let whenFalse ← lookupFieldJson inner "when_false"
    if (← exprContainsKernelAccessJson whenTrue) || (← exprContainsKernelAccessJson whenFalse) then
      throw "select arm contains kernel access"
    pure <| .select
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "cond"))
      (← lowerConfidentialKernelPureExprJson whenTrue)
      (← lowerConfidentialKernelPureExprJson whenFalse)
  else if let some inner := taggedPayload? json "CellGet" then
    pure <| .cellGet (← lookupFieldAs inner "object_id")
  else if let some inner := taggedPayload? json "ArrayGet" then
    pure <| .arrayGet
      (← lookupFieldAs inner "object_id")
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "index"))
  else if let some inner := taggedPayload? json "MapGet" then
    pure <| .mapGet
      (← lookupFieldAs inner "object_id")
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "key"))
  else if taggedPayload? json "StructField" |>.isSome then
    throw "confidential struct-field access is not allowed"
  else if taggedPayload? json "ArrayIndex" |>.isSome then
    throw "confidential array indexing is not allowed"
  else if let some inner := taggedPayload? json "Keccak256" then
    let parts : List Json ← lookupFieldAs inner "parts"
    pure <| .keccak256 (← parts.mapM lowerConfidentialKernelExprJson)
  else
    throw "unsupported expression shape in translation bundle"

end

private def lowerConfidentialKernelStatementJson
  (json : Json)
  (index : Nat) : Except String ImportedConfidentialKernelStatement := do
  if let some inner := taggedPayload? json "Declare" then
    pure <| .declare
      (← lookupFieldAs inner "name")
      (← lookupFieldJson inner "ty")
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "value"))
  else if let some inner := taggedPayload? json "Assign" then
    pure <| .assign
      (← lookupFieldAs inner "name")
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "value"))
  else if let some inner := taggedPayload? json "Require" then
    pure <| .require (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "cond"))
  else if let some inner := taggedPayload? json "AbortIf" then
    pure <| .abortIf (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "cond"))
  else if taggedPayload? json "If" |>.isSome then
    throw s!"confidential control flow is not allowed at if[{index}]"
  else if taggedPayload? json "For" |>.isSome then
    throw s!"confidential control flow is not allowed at for[{index}]"
  else if let some inner := taggedPayload? json "CellSet" then
    let predicate ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure none
      | some predicate => some <$> lowerConfidentialKernelExprJson predicate
    pure <| .cellSet
      (← lookupFieldAs inner "object_id")
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "value"))
      predicate
  else if let some inner := taggedPayload? json "ArraySet" then
    let predicate ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure none
      | some predicate => some <$> lowerConfidentialKernelExprJson predicate
    pure <| .arraySet
      (← lookupFieldAs inner "object_id")
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "index"))
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "value"))
      predicate
  else if let some inner := taggedPayload? json "MapPut" then
    let predicate ←
      match ← lookupOptionalFieldJson inner "predicate" with
      | none => pure none
      | some predicate => some <$> lowerConfidentialKernelExprJson predicate
    pure <| .mapPut
      (← lookupFieldAs inner "object_id")
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "key"))
      (← lowerConfidentialKernelExprJson (← lookupFieldJson inner "value"))
      predicate
  else if let some inner := taggedPayload? json "Return" then
    let value ←
      match ← lookupOptionalFieldJson inner "value" with
      | none => pure none
      | some value => some <$> lowerConfidentialKernelExprJson value
    pure <| .ret value
  else
    throw "unsupported statement shape in translation bundle"

private def lowerConfidentialKernelBodyStringsAux
  (index : Nat)
  (body : List String) : Except String (List ImportedConfidentialKernelStatement) :=
  match body with
  | [] => pure []
  | item :: rest => do
      let stmt ← lowerConfidentialKernelStatementJson (← parseJsonString item) index
      let tail ← lowerConfidentialKernelBodyStringsAux (index + 1) rest
      pure (stmt :: tail)

private def lowerConfidentialKernelBodyStrings
  (body : List String) : Except String (List ImportedConfidentialKernelStatement) :=
  lowerConfidentialKernelBodyStringsAux 0 body

def expectedConfidentialKernelProgramForFunction
  (fn : ImportedProofRelevantFunctionView) : Except String ImportedConfidentialKernelProgram := do
  let params ← fn.params.mapM fun param => do
    pure
      { name := param.name
      , ty := ← parseJsonString param.ty
      }
  let returnType ←
    match fn.return_type with
    | none => pure none
    | some ty => pure <| some (← parseJsonString ty)
  pure
    { entrypoint_id := fn.signature
    , params := params
    , return_type := returnType
    , secret_args := fn.secret_args
    , body := ← lowerConfidentialKernelBodyStrings fn.body
    }

private def importedProofRelevantKernelStepViewOfImportedRuntimeKernelStep
  (step : ImportedRuntimeKernelStep) : ImportedProofRelevantKernelStepView :=
  { opcode := step.opcode, object_id := step.object_id }

def importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
  (steps : List ImportedRuntimeKernelStep) : List ImportedProofRelevantKernelStepView :=
  steps.map importedProofRelevantKernelStepViewOfImportedRuntimeKernelStep

def importedConfidentialKernelProgramSchedulesEq
  (lhs rhs : ImportedConfidentialKernelProgram) : Bool :=
  lhs.expectedRuntimeKernelSteps == rhs.expectedRuntimeKernelSteps

theorem importedConfidentialKernelProgramSchedulesEq_eq_true_iff
  (lhs rhs : ImportedConfidentialKernelProgram) :
  importedConfidentialKernelProgramSchedulesEq lhs rhs = true ↔
    lhs.expectedRuntimeKernelSteps = rhs.expectedRuntimeKernelSteps := by
  unfold importedConfidentialKernelProgramSchedulesEq
  exact beq_iff_eq

def parseEntrypointConfidentialProgram
  (entry : ImportedProofRelevantEntrypointView) :
  Except String (Option ImportedConfidentialKernelProgram) := do
  match entry.confidential_program with
  | none => pure none
  | some json => some <$> fromJson? (← parseJsonString json)

def parseEntrypointConfidentialSlotProgram
  (entry : ImportedProofRelevantEntrypointView) :
  Except String (Option ImportedConfidentialKernelSlotProgram) := do
  match entry.confidential_slot_program with
  | none => pure none
  | some json => some <$> fromJson? (← parseJsonString json)

def parseFunctionConfidentialProgram
  (fn : ImportedProofRelevantFunctionView) :
  Except String (Option ImportedConfidentialKernelProgram) := do
  match fn.confidential_program with
  | none => pure none
  | some json => some <$> fromJson? (← parseJsonString json)

def parseFunctionConfidentialSlotProgram
  (fn : ImportedProofRelevantFunctionView) :
  Except String (Option ImportedConfidentialKernelSlotProgram) := do
  match fn.confidential_slot_program with
  | none => pure none
  | some json => some <$> fromJson? (← parseJsonString json)

private abbrev ImportedKernelLenEnv := List (String × Json)

private def importedKernelLenEnvResolve
  (env : ImportedKernelLenEnv)
  (name : String) : Except String Json :=
  match env with
  | [] => throw s!"unknown confidential kernel variable '{name}'"
  | (entryName, ty) :: rest =>
      if entryName = name then
        pure ty
      else
        importedKernelLenEnvResolve rest name

private def importedKernelLenEnvDeclare
  (env : ImportedKernelLenEnv)
  (name : String)
  (ty : Json) : Except String ImportedKernelLenEnv := do
  if env.any (fun entry => entry.fst = name) then
    throw s!"duplicate confidential kernel variable '{name}'"
  else
    pure ((name, ty) :: env)

private def stateObjectValueCanonicalLen
  (state : List ImportedProofRelevantStateObjectView)
  (objectId : Nat) : Except String Nat := do
  match state.find? (fun object => object.id == objectId) with
  | some object => typeCanonicalLenFromRawString object.value_type
  | none => throw s!"unknown state object id {objectId}"

private def stateObjectValueTypeJson
  (state : List ImportedProofRelevantStateObjectView)
  (objectId : Nat) : Except String Json := do
  match state.find? (fun object => object.id == objectId) with
  | some object => parseJsonString object.value_type
  | none => throw s!"unknown state object id {objectId}"

private def scalarTypeJson (payload : Json) : Json :=
  Json.mkObj [("Scalar", payload)]

private def uint256TypeJson : Json :=
  scalarTypeJson (Json.mkObj [("Uint", toJson (256 : Nat))])

private partial def valueTypeFromJson (json : Json) : Except String Json := do
  if taggedPayload? json "Bool" |>.isSome then
    pure (scalarTypeJson (Json.str "Bool"))
  else if taggedPayload? json "Uint" |>.isSome then
    pure uint256TypeJson
  else if taggedPayload? json "Bytes32" |>.isSome then
    pure (scalarTypeJson (Json.str "Bytes32"))
  else if taggedPayload? json "Address" |>.isSome then
    pure (scalarTypeJson (Json.str "Address"))
  else if let some payload := taggedPayload? json "Struct" then
    let fields ← expectJsonArray payload
    let fieldTypes ← fields.mapM fun fieldJson => do
      let items ← expectJsonArray fieldJson
      match items with
      | [Json.str name, valueJson] =>
          pure (Json.mkObj [("name", Json.str name), ("ty", ← valueTypeFromJson valueJson)])
      | _ =>
          throw "unsupported struct value encoding"
    pure (Json.mkObj [("Struct", toJson fieldTypes)])
  else if let some payload := taggedPayload? json "Array" then
    let items ← expectJsonArray payload
    match items with
    | [] =>
        throw "cannot infer empty array literal type"
    | first :: rest =>
        let elementTy ← valueTypeFromJson first
        for item in rest do
          let itemTy ← valueTypeFromJson item
          if itemTy == elementTy then
            pure ()
          else
            throw "array literal has heterogeneous element types"
        pure (Json.mkObj [("Array", toJson [elementTy, toJson items.length])])
  else
    throw "unsupported value encoding"

private partial def structFieldTypeFromJson
  (ty : Json)
  (field : String) : Except String Json := do
  if let some payload := taggedPayload? ty "Struct" then
    let fields ← expectJsonArray payload
    match fields.find? (fun fieldJson =>
        match lookupFieldAs fieldJson "name" with
        | .ok name => name == field
        | .error _ => false) with
    | some fieldJson =>
        lookupFieldJson fieldJson "ty"
    | none =>
        throw s!"unknown struct field {field}"
  else
    throw "struct field canonical length requires struct type"

private def arrayElementTypeFromJson (ty : Json) : Except String Json := do
  if let some payload := taggedPayload? ty "Array" then
    let items ← expectJsonArray payload
    match items with
    | [elementJson, _] => pure elementJson
    | _ => throw "unsupported array type encoding"
  else
    throw "array index canonical length requires array type"

private partial def valueCanonicalLenFromJson (json : Json) : Except String Nat := do
  if taggedPayload? json "Bool" |>.isSome then
    pure 1
  else if taggedPayload? json "Uint" |>.isSome then
    pure 32
  else if taggedPayload? json "Bytes32" |>.isSome then
    pure 32
  else if taggedPayload? json "Address" |>.isSome then
    pure 20
  else if let some payload := taggedPayload? json "Struct" then
    let fields ← expectJsonArray payload
    fields.foldlM (init := 0) fun acc fieldJson => do
      let items ← expectJsonArray fieldJson
      match items with
      | [Json.str name, valueJson] =>
          pure (acc + 4 + name.length + 4 + (← valueCanonicalLenFromJson valueJson))
      | _ =>
          throw "unsupported struct value encoding"
  else if let some payload := taggedPayload? json "Array" then
    let items ← expectJsonArray payload
    items.foldlM (init := 0) fun acc item => do
      pure (acc + 4 + (← valueCanonicalLenFromJson item))
  else
    throw "unsupported value encoding"

private def unaryOpCanonicalLen (op : Json) : Except String Nat :=
  match op with
  | Json.str "Not" => pure 1
  | Json.str "Neg" => pure 32
  | _ => throw "unsupported unary operator encoding"

private def binaryOpCanonicalLen (op : Json) : Except String Nat :=
  match op with
  | Json.str "Eq"
  | Json.str "Neq"
  | Json.str "Lt"
  | Json.str "Lte"
  | Json.str "Gt"
  | Json.str "Gte"
  | Json.str "And"
  | Json.str "Or" => pure 1
  | Json.str "Add"
  | Json.str "Sub"
  | Json.str "Mul"
  | Json.str "Div"
  | Json.str "Mod"
  | Json.str "BitAnd"
  | Json.str "BitOr"
  | Json.str "BitXor" => pure 32
  | _ => throw "unsupported binary operator encoding"

mutual

private partial def importedConfidentialKernelExprType
  (state : List ImportedProofRelevantStateObjectView)
  (env : ImportedKernelLenEnv)
  (expr : ImportedConfidentialKernelExpr) : Except String Json := do
  match expr with
  | .literal value =>
      valueTypeFromJson value
  | .var name =>
      importedKernelLenEnvResolve env name
  | .unary op _ =>
      match op with
      | Json.str "Not" => pure (scalarTypeJson (Json.str "Bool"))
      | Json.str "Neg" => pure uint256TypeJson
      | _ => throw "unsupported unary operator encoding"
  | .binary op _ _ =>
      match op with
      | Json.str "Eq"
      | Json.str "Neq"
      | Json.str "Lt"
      | Json.str "Lte"
      | Json.str "Gt"
      | Json.str "Gte"
      | Json.str "And"
      | Json.str "Or" => pure (scalarTypeJson (Json.str "Bool"))
      | Json.str "Add"
      | Json.str "Sub"
      | Json.str "Mul"
      | Json.str "Div"
      | Json.str "Mod"
      | Json.str "BitAnd"
      | Json.str "BitOr"
      | Json.str "BitXor" => pure uint256TypeJson
      | _ => throw "unsupported binary operator encoding"
  | .select _ whenTrue whenFalse => do
      let whenTrueTy ← importedConfidentialKernelPureExprType env whenTrue
      let whenFalseTy ← importedConfidentialKernelPureExprType env whenFalse
      if whenTrueTy == whenFalseTy then
        pure whenTrueTy
      else
        throw "confidential select arms disagree on result type"
  | .cellGet objectId =>
      stateObjectValueTypeJson state objectId
  | .arrayGet objectId _ =>
      stateObjectValueTypeJson state objectId
  | .mapGet objectId _ =>
      stateObjectValueTypeJson state objectId
  | .structField base field => do
      structFieldTypeFromJson (← importedConfidentialKernelExprType state env base) field
  | .arrayIndex base _ => do
      arrayElementTypeFromJson (← importedConfidentialKernelExprType state env base)
  | .keccak256 _ =>
      pure (scalarTypeJson (Json.str "Bytes32"))

private partial def importedConfidentialKernelPureExprType
  (env : ImportedKernelLenEnv)
  (expr : ImportedConfidentialKernelPureExpr) : Except String Json := do
  match expr with
  | .literal value =>
      valueTypeFromJson value
  | .var name =>
      importedKernelLenEnvResolve env name
  | .unary op _ =>
      match op with
      | Json.str "Not" => pure (scalarTypeJson (Json.str "Bool"))
      | Json.str "Neg" => pure uint256TypeJson
      | _ => throw "unsupported unary operator encoding"
  | .binary op _ _ =>
      match op with
      | Json.str "Eq"
      | Json.str "Neq"
      | Json.str "Lt"
      | Json.str "Lte"
      | Json.str "Gt"
      | Json.str "Gte"
      | Json.str "And"
      | Json.str "Or" => pure (scalarTypeJson (Json.str "Bool"))
      | Json.str "Add"
      | Json.str "Sub"
      | Json.str "Mul"
      | Json.str "Div"
      | Json.str "Mod"
      | Json.str "BitAnd"
      | Json.str "BitOr"
      | Json.str "BitXor" => pure uint256TypeJson
      | _ => throw "unsupported binary operator encoding"
  | .select _ whenTrue whenFalse => do
      let whenTrueTy ← importedConfidentialKernelPureExprType env whenTrue
      let whenFalseTy ← importedConfidentialKernelPureExprType env whenFalse
      if whenTrueTy == whenFalseTy then
        pure whenTrueTy
      else
        throw "confidential select arms disagree on result type"
  | .structField base field => do
      structFieldTypeFromJson (← importedConfidentialKernelPureExprType env base) field
  | .arrayIndex base _ => do
      arrayElementTypeFromJson (← importedConfidentialKernelPureExprType env base)
  | .keccak256 _ =>
      pure (scalarTypeJson (Json.str "Bytes32"))

end

mutual

private partial def importedConfidentialKernelExprCanonicalLen
  (state : List ImportedProofRelevantStateObjectView)
  (env : ImportedKernelLenEnv)
  (expr : ImportedConfidentialKernelExpr) : Except String Nat := do
  match expr with
  | .literal value =>
      valueCanonicalLenFromJson value
  | .var name =>
      typeCanonicalLenFromJson (← importedKernelLenEnvResolve env name)
  | .unary op _ =>
      unaryOpCanonicalLen op
  | .binary op _ _ =>
      binaryOpCanonicalLen op
  | .select _ whenTrue whenFalse => do
      let whenTrueLen ← importedConfidentialKernelPureExprCanonicalLen env whenTrue
      let whenFalseLen ← importedConfidentialKernelPureExprCanonicalLen env whenFalse
      if whenTrueLen == whenFalseLen then
        pure whenTrueLen
      else
        throw s!"confidential select arms disagree on canonical length: {whenTrueLen} != {whenFalseLen}"
  | .cellGet objectId =>
      stateObjectValueCanonicalLen state objectId
  | .arrayGet objectId _ =>
      stateObjectValueCanonicalLen state objectId
  | .mapGet objectId _ =>
      stateObjectValueCanonicalLen state objectId
  | .structField base field => do
      typeCanonicalLenFromJson
        (← structFieldTypeFromJson (← importedConfidentialKernelExprType state env base) field)
  | .arrayIndex base _ => do
      typeCanonicalLenFromJson
        (← arrayElementTypeFromJson (← importedConfidentialKernelExprType state env base))
  | .keccak256 _ =>
      pure 32

private partial def importedConfidentialKernelPureExprCanonicalLen
  (env : ImportedKernelLenEnv)
  (expr : ImportedConfidentialKernelPureExpr) : Except String Nat := do
  match expr with
  | .literal value =>
      valueCanonicalLenFromJson value
  | .var name =>
      typeCanonicalLenFromJson (← importedKernelLenEnvResolve env name)
  | .unary op _ =>
      unaryOpCanonicalLen op
  | .binary op _ _ =>
      binaryOpCanonicalLen op
  | .select _ whenTrue whenFalse => do
      let whenTrueLen ← importedConfidentialKernelPureExprCanonicalLen env whenTrue
      let whenFalseLen ← importedConfidentialKernelPureExprCanonicalLen env whenFalse
      if whenTrueLen == whenFalseLen then
        pure whenTrueLen
      else
        throw s!"confidential select arms disagree on canonical length: {whenTrueLen} != {whenFalseLen}"
  | .structField base field => do
      typeCanonicalLenFromJson
        (← structFieldTypeFromJson (← importedConfidentialKernelPureExprType env base) field)
  | .arrayIndex base _ => do
      typeCanonicalLenFromJson
        (← arrayElementTypeFromJson (← importedConfidentialKernelPureExprType env base))
  | .keccak256 _ =>
      pure 32

private partial def importedConfidentialKernelExprMaxHashPartBytes
  (state : List ImportedProofRelevantStateObjectView)
  (env : ImportedKernelLenEnv)
  (expr : ImportedConfidentialKernelExpr) : Except String Nat := do
  match expr with
  | .literal _ | .var _ | .cellGet _ =>
      pure 0
  | .unary _ expr =>
      importedConfidentialKernelExprMaxHashPartBytes state env expr
  | .binary _ lhs rhs => do
      pure <| Nat.max
        (← importedConfidentialKernelExprMaxHashPartBytes state env lhs)
        (← importedConfidentialKernelExprMaxHashPartBytes state env rhs)
  | .select cond whenTrue whenFalse => do
      pure <| Nat.max
        (← importedConfidentialKernelExprMaxHashPartBytes state env cond)
        (Nat.max
          (← importedConfidentialKernelPureExprMaxHashPartBytes env whenTrue)
          (← importedConfidentialKernelPureExprMaxHashPartBytes env whenFalse))
  | .arrayGet _ index =>
      importedConfidentialKernelExprMaxHashPartBytes state env index
  | .mapGet _ key =>
      importedConfidentialKernelExprMaxHashPartBytes state env key
  | .structField base _ =>
      importedConfidentialKernelExprMaxHashPartBytes state env base
  | .arrayIndex base index => do
      pure <| Nat.max
        (← importedConfidentialKernelExprMaxHashPartBytes state env base)
        (← importedConfidentialKernelExprMaxHashPartBytes state env index)
  | .keccak256 parts =>
      parts.foldlM (init := 0) fun acc part => do
        let partLen ← importedConfidentialKernelExprCanonicalLen state env part
        let nested ← importedConfidentialKernelExprMaxHashPartBytes state env part
        pure <| Nat.max acc (Nat.max partLen nested)

private partial def importedConfidentialKernelPureExprMaxHashPartBytes
  (env : ImportedKernelLenEnv)
  (expr : ImportedConfidentialKernelPureExpr) : Except String Nat := do
  match expr with
  | .literal _ | .var _ =>
      pure 0
  | .unary _ expr =>
      importedConfidentialKernelPureExprMaxHashPartBytes env expr
  | .binary _ lhs rhs => do
      pure <| Nat.max
        (← importedConfidentialKernelPureExprMaxHashPartBytes env lhs)
        (← importedConfidentialKernelPureExprMaxHashPartBytes env rhs)
  | .select cond whenTrue whenFalse => do
      pure <| Nat.max
        (← importedConfidentialKernelPureExprMaxHashPartBytes env cond)
        (Nat.max
          (← importedConfidentialKernelPureExprMaxHashPartBytes env whenTrue)
          (← importedConfidentialKernelPureExprMaxHashPartBytes env whenFalse))
  | .structField base _ =>
      importedConfidentialKernelPureExprMaxHashPartBytes env base
  | .arrayIndex base index => do
      pure <| Nat.max
        (← importedConfidentialKernelPureExprMaxHashPartBytes env base)
        (← importedConfidentialKernelPureExprMaxHashPartBytes env index)
  | .keccak256 parts =>
      parts.foldlM (init := 0) fun acc part => do
        let partLen ← importedConfidentialKernelPureExprCanonicalLen env part
        let nested ← importedConfidentialKernelPureExprMaxHashPartBytes env part
        pure <| Nat.max acc (Nat.max partLen nested)

end

private def importedConfidentialKernelStatementMaxHashPartBytes
  (state : List ImportedProofRelevantStateObjectView)
  (env : ImportedKernelLenEnv)
  (stmt : ImportedConfidentialKernelStatement) :
  Except String (Nat × ImportedKernelLenEnv) := do
  match stmt with
  | .declare name ty value => do
      let env' ← importedKernelLenEnvDeclare env name ty
      pure (← importedConfidentialKernelExprMaxHashPartBytes state env' value, env')
  | .assign _ value =>
      pure (← importedConfidentialKernelExprMaxHashPartBytes state env value, env)
  | .require cond =>
      pure (← importedConfidentialKernelExprMaxHashPartBytes state env cond, env)
  | .abortIf cond =>
      pure (← importedConfidentialKernelExprMaxHashPartBytes state env cond, env)
  | .cellSet _ value predicate => do
      let predicateMax ←
        match predicate with
        | none => pure 0
        | some predicate => importedConfidentialKernelExprMaxHashPartBytes state env predicate
      pure
        (Nat.max
          (← importedConfidentialKernelExprMaxHashPartBytes state env value)
          predicateMax,
         env)
  | .arraySet _ index value predicate => do
      let predicateMax ←
        match predicate with
        | none => pure 0
        | some predicate => importedConfidentialKernelExprMaxHashPartBytes state env predicate
      pure
        (Nat.max
          (← importedConfidentialKernelExprMaxHashPartBytes state env index)
          (Nat.max
            (← importedConfidentialKernelExprMaxHashPartBytes state env value)
            predicateMax),
         env)
  | .mapPut _ key value predicate => do
      let predicateMax ←
        match predicate with
        | none => pure 0
        | some predicate => importedConfidentialKernelExprMaxHashPartBytes state env predicate
      pure
        (Nat.max
          (← importedConfidentialKernelExprMaxHashPartBytes state env key)
          (Nat.max
            (← importedConfidentialKernelExprMaxHashPartBytes state env value)
            predicateMax),
         env)
  | .ret value =>
      match value with
      | none => pure (0, env)
      | some value =>
          pure (← importedConfidentialKernelExprMaxHashPartBytes state env value, env)

def importedConfidentialKernelProgramMaxHashPartBytes
  (state : List ImportedProofRelevantStateObjectView)
  (program : ImportedConfidentialKernelProgram) : Except String Nat := do
  let env ← program.params.foldlM (init := ([] : ImportedKernelLenEnv)) fun env param => do
    importedKernelLenEnvDeclare env param.name param.ty
  let (maxLen, _) ← program.body.foldlM (init := (0, env)) fun accEnv stmt => do
    let (acc, env) := accEnv
    let (stmtMax, env') ← importedConfidentialKernelStatementMaxHashPartBytes state env stmt
    pure (Nat.max acc stmtMax, env')
  pure maxLen

private def listPairwiseEq
  {α β : Type}
  (eqFn : α → β → Bool) : List α → List β → Bool
  | [], [] => true
  | lhsHead :: lhsTail, rhsHead :: rhsTail =>
      eqFn lhsHead rhsHead && listPairwiseEq eqFn lhsTail rhsTail
  | _, _ => false

private def importedConfidentialKernelParamEq
  (lhs rhs : ImportedConfidentialKernelParam) : Bool :=
  lhs.name == rhs.name && lhs.ty == rhs.ty

private def optionPairwiseEq
  {α β : Type}
  (eqFn : α → β → Bool) : Option α → Option β → Bool
  | some lhs, some rhs => eqFn lhs rhs
  | none, none => true
  | _, _ => false

mutual

private partial def importedConfidentialKernelStatementEq
  (lhs rhs : ImportedConfidentialKernelStatement) : Bool :=
  match lhs, rhs with
  | .declare lhsName lhsTy lhsValue, .declare rhsName rhsTy rhsValue =>
      lhsName == rhsName && lhsTy == rhsTy &&
        importedConfidentialKernelExprEq lhsValue rhsValue
  | .assign lhsName lhsValue, .assign rhsName rhsValue =>
      lhsName == rhsName && importedConfidentialKernelExprEq lhsValue rhsValue
  | .require lhsCond, .require rhsCond
  | .abortIf lhsCond, .abortIf rhsCond =>
      importedConfidentialKernelExprEq lhsCond rhsCond
  | .cellSet lhsObject lhsValue lhsPredicate, .cellSet rhsObject rhsValue rhsPredicate =>
      lhsObject == rhsObject &&
        importedConfidentialKernelExprEq lhsValue rhsValue &&
        optionPairwiseEq importedConfidentialKernelExprEq lhsPredicate rhsPredicate
  | .arraySet lhsObject lhsIndex lhsValue lhsPredicate,
      .arraySet rhsObject rhsIndex rhsValue rhsPredicate =>
      lhsObject == rhsObject &&
        importedConfidentialKernelExprEq lhsIndex rhsIndex &&
        importedConfidentialKernelExprEq lhsValue rhsValue &&
        optionPairwiseEq importedConfidentialKernelExprEq lhsPredicate rhsPredicate
  | .mapPut lhsObject lhsKey lhsValue lhsPredicate,
      .mapPut rhsObject rhsKey rhsValue rhsPredicate =>
      lhsObject == rhsObject &&
        importedConfidentialKernelExprEq lhsKey rhsKey &&
        importedConfidentialKernelExprEq lhsValue rhsValue &&
        optionPairwiseEq importedConfidentialKernelExprEq lhsPredicate rhsPredicate
  | .ret lhsValue, .ret rhsValue =>
      optionPairwiseEq importedConfidentialKernelExprEq lhsValue rhsValue
  | _, _ => false

private partial def importedConfidentialKernelExprEq
  (lhs rhs : ImportedConfidentialKernelExpr) : Bool :=
  match lhs, rhs with
  | .literal lhsValue, .literal rhsValue =>
      lhsValue == rhsValue
  | .var lhsName, .var rhsName =>
      lhsName == rhsName
  | .unary lhsOp lhsExpr, .unary rhsOp rhsExpr =>
      lhsOp == rhsOp && importedConfidentialKernelExprEq lhsExpr rhsExpr
  | .binary lhsOp lhsLhs lhsRhs, .binary rhsOp rhsLhs rhsRhs =>
      lhsOp == rhsOp &&
        importedConfidentialKernelExprEq lhsLhs rhsLhs &&
        importedConfidentialKernelExprEq lhsRhs rhsRhs
  | .select lhsCond lhsWhenTrue lhsWhenFalse, .select rhsCond rhsWhenTrue rhsWhenFalse =>
      importedConfidentialKernelExprEq lhsCond rhsCond &&
        importedConfidentialKernelPureExprEq lhsWhenTrue rhsWhenTrue &&
        importedConfidentialKernelPureExprEq lhsWhenFalse rhsWhenFalse
  | .cellGet lhsObject, .cellGet rhsObject =>
      lhsObject == rhsObject
  | .arrayGet lhsObject lhsIndex, .arrayGet rhsObject rhsIndex =>
      lhsObject == rhsObject && importedConfidentialKernelExprEq lhsIndex rhsIndex
  | .mapGet lhsObject lhsKey, .mapGet rhsObject rhsKey =>
      lhsObject == rhsObject && importedConfidentialKernelExprEq lhsKey rhsKey
  | .keccak256 lhsParts, .keccak256 rhsParts =>
      listPairwiseEq importedConfidentialKernelExprEq lhsParts rhsParts
  | _, _ => false

private partial def importedConfidentialKernelPureExprEq
  (lhs rhs : ImportedConfidentialKernelPureExpr) : Bool :=
  match lhs, rhs with
  | .literal lhsValue, .literal rhsValue =>
      lhsValue == rhsValue
  | .var lhsName, .var rhsName =>
      lhsName == rhsName
  | .unary lhsOp lhsExpr, .unary rhsOp rhsExpr =>
      lhsOp == rhsOp && importedConfidentialKernelPureExprEq lhsExpr rhsExpr
  | .binary lhsOp lhsLhs lhsRhs, .binary rhsOp rhsLhs rhsRhs =>
      lhsOp == rhsOp &&
        importedConfidentialKernelPureExprEq lhsLhs rhsLhs &&
        importedConfidentialKernelPureExprEq lhsRhs rhsRhs
  | .select lhsCond lhsWhenTrue lhsWhenFalse, .select rhsCond rhsWhenTrue rhsWhenFalse =>
      importedConfidentialKernelPureExprEq lhsCond rhsCond &&
        importedConfidentialKernelPureExprEq lhsWhenTrue rhsWhenTrue &&
        importedConfidentialKernelPureExprEq lhsWhenFalse rhsWhenFalse
  | .keccak256 lhsParts, .keccak256 rhsParts =>
      listPairwiseEq importedConfidentialKernelPureExprEq lhsParts rhsParts
  | _, _ => false

end

def importedConfidentialKernelProgramEq
  (lhs rhs : ImportedConfidentialKernelProgram) : Bool :=
  lhs.entrypoint_id == rhs.entrypoint_id &&
    listPairwiseEq importedConfidentialKernelParamEq lhs.params rhs.params &&
    lhs.return_type == rhs.return_type &&
    lhs.secret_args == rhs.secret_args &&
    listPairwiseEq importedConfidentialKernelStatementEq lhs.body rhs.body

def functionStoredDslMatchesBody
  (fn : ImportedProofRelevantFunctionView) : Bool :=
  if fn.confidential then
    match
      expectedConfidentialKernelProgramForFunction fn,
      parseFunctionConfidentialProgram fn,
      parseFunctionConfidentialSlotProgram fn with
    | .ok expectedProgram, .ok (some program), .ok (some slotProgram) =>
        importedConfidentialKernelProgramEq program expectedProgram &&
          importedConfidentialKernelProgramSchedulesEq program expectedProgram &&
          checkImportedConfidentialKernelProgramSlotLowering program slotProgram
    | _, _, _ => false
  else
    fn.confidential_program.isNone && fn.confidential_slot_program.isNone

private def functionStoredDslMismatchMessage
  (fn : ImportedProofRelevantFunctionView) : String :=
  if fn.confidential then
    match
      expectedConfidentialKernelProgramForFunction fn,
      parseFunctionConfidentialProgram fn,
      parseFunctionConfidentialSlotProgram fn with
    | .error err, _, _ =>
        s!"{fn.signature}: confidential lowering rejected body: {err}"
    | _, .error err, _
    | _, _, .error err =>
        s!"{fn.signature}: failed to parse stored confidential DSL from function body metadata: {err}"
    | _, .ok none, _ =>
        s!"{fn.signature}: function is missing confidential_program"
    | _, _, .ok none =>
        s!"{fn.signature}: function is missing confidential_slot_program"
    | .ok expectedProgram, .ok (some program), .ok (some slotProgram) =>
        if !importedConfidentialKernelProgramEq program expectedProgram then
          s!"{fn.signature}: stored function confidential_program does not match the exact lowering of the function body"
        else if !checkImportedConfidentialKernelProgramSlotLowering program slotProgram then
          s!"{fn.signature}: stored function confidential_slot_program does not match the stored function confidential_program"
        else
          s!"{fn.signature}: confidential lowering mismatch despite matching stored function DSL"
  else
    s!"{fn.signature}: non-confidential function should not carry stored confidential DSL"

def manifestStoredDslMatchesKernelSchedule
  (view : ImportedProofRelevantContractView)
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  match parseEntrypointConfidentialProgram entry, parseEntrypointConfidentialSlotProgram entry with
  | .ok none, .ok none =>
      (!fn.confidential) && entry.kernel_steps.isEmpty && entry.max_hash_part_bytes == 0
  | .ok (some program), .ok (some slotProgram) =>
      match importedConfidentialKernelProgramMaxHashPartBytes view.state program with
      | .ok expectedHashPartBytes =>
          fn.confidential &&
            program.entrypoint_id == fn.signature &&
            slotProgram.entrypoint_id == fn.signature &&
            program.secret_args == fn.secret_args &&
            slotProgram.secret_args == fn.secret_args &&
            entry.max_hash_part_bytes == expectedHashPartBytes &&
            importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
                program.expectedRuntimeKernelSteps ==
              entry.kernel_steps &&
            importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
                slotProgram.expectedRuntimeKernelSteps ==
              entry.kernel_steps &&
            checkImportedConfidentialKernelProgramSlotLowering program slotProgram
      | .error _ => false
  | _, _ => false

def functionConfidentialLoweringMatchesManifest
  (view : ImportedProofRelevantContractView)
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  if fn.confidential then
    functionStoredDslMatchesBody fn &&
      manifestStoredDslMatchesKernelSchedule view fn entry &&
      match
        parseFunctionConfidentialProgram fn,
        parseFunctionConfidentialSlotProgram fn,
        parseEntrypointConfidentialProgram entry,
        parseEntrypointConfidentialSlotProgram entry with
      | .ok (some fnProgram), .ok (some fnSlotProgram), .ok (some entryProgram), .ok (some entrySlotProgram) =>
            fn.confidential_program == entry.confidential_program &&
              fn.confidential_slot_program == entry.confidential_slot_program &&
              importedConfidentialKernelProgramEq fnProgram entryProgram &&
              importedConfidentialKernelProgramSchedulesEq fnProgram entryProgram &&
              checkImportedConfidentialKernelProgramSlotLowering entryProgram entrySlotProgram &&
              checkImportedConfidentialKernelProgramSlotLowering fnProgram fnSlotProgram
      | _, _, _, _ => false
  else
    entry.kernel_steps.isEmpty &&
      entry.confidential_program.isNone &&
      entry.confidential_slot_program.isNone &&
      entry.max_hash_part_bytes == 0 &&
      fn.confidential_program.isNone &&
      fn.confidential_slot_program.isNone

private def functionConfidentialLoweringMismatchMessage
  (view : ImportedProofRelevantContractView)
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : String :=
  if fn.confidential then
    if !functionStoredDslMatchesBody fn then
      functionStoredDslMismatchMessage fn
    else
      match
        parseFunctionConfidentialProgram fn,
        parseFunctionConfidentialSlotProgram fn,
        parseEntrypointConfidentialProgram entry,
        parseEntrypointConfidentialSlotProgram entry with
      | .error err, _, _, _
      | _, .error err, _, _ =>
          s!"{fn.signature}: failed to parse stored confidential DSL from function body metadata: {err}"
      | _, _, .error err, _
      | _, _, _, .error err =>
          s!"{fn.signature}: failed to parse stored confidential DSL from manifest: {err}"
      | .ok none, _, _, _ =>
          s!"{fn.signature}: function is missing confidential_program"
      | _, .ok none, _, _ =>
          s!"{fn.signature}: function is missing confidential_slot_program"
      | _, _, .ok none, _ =>
          s!"{fn.signature}: manifest is missing confidential_program"
      | _, _, _, .ok none =>
          s!"{fn.signature}: manifest is missing confidential_slot_program"
      | .ok (some fnProgram), .ok (some fnSlotProgram), .ok (some entryProgram), .ok (some entrySlotProgram) =>
          if fn.confidential_program != entry.confidential_program then
            s!"{fn.signature}: function confidential_program and manifest confidential_program do not match"
          else if fn.confidential_slot_program != entry.confidential_slot_program then
            s!"{fn.signature}: function confidential_slot_program and manifest confidential_slot_program do not match"
          else if !importedConfidentialKernelProgramEq fnProgram entryProgram then
            s!"{fn.signature}: function confidential_program and manifest confidential_program do not parse to the same canonical program"
          else if !checkImportedConfidentialKernelProgramSlotLowering fnProgram fnSlotProgram then
            s!"{fn.signature}: function confidential_slot_program does not match the function confidential_program"
          else if !checkImportedConfidentialKernelProgramSlotLowering entryProgram entrySlotProgram then
            s!"{fn.signature}: manifest confidential_slot_program does not match the manifest confidential_program"
          else if !(manifestStoredDslMatchesKernelSchedule view fn entry) then
            let hashPartSummary :=
              match importedConfidentialKernelProgramMaxHashPartBytes view.state entryProgram with
              | .ok expectedHashPartBytes =>
                  s!"expected hash bound {expectedHashPartBytes}, manifest has {entry.max_hash_part_bytes}"
              | .error err =>
                  s!"failed to compute expected hash bound: {err}"
            let programSteps :=
              renderKernelSteps <|
                importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
                  entryProgram.expectedRuntimeKernelSteps
            let slotSteps :=
              renderKernelSteps <|
                importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
                  entrySlotProgram.expectedRuntimeKernelSteps
            s!"{fn.signature}: stored confidential DSL does not align with manifest schedule, slot lowering, or hash bound ({hashPartSummary}; program steps {programSteps}, slot steps {slotSteps}, manifest steps {renderKernelSteps entry.kernel_steps})"
          else
            s!"{fn.signature}: confidential lowering mismatch despite matching stored function DSL and manifest DSL"
  else
    s!"{fn.signature}: non-confidential function or entrypoint should not carry kernel metadata, stored confidential DSL, or a hash bound"

private def functionsMatchConfidentialLowering :
  ImportedProofRelevantContractView →
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → Bool
  | _, [], _ => true
  | view, fn :: rest, entrypoints =>
      match lookupEntrypoint fn.signature entrypoints with
      | none => false
      | some entry =>
          functionConfidentialLoweringMatchesManifest view fn entry &&
            functionsMatchConfidentialLowering view rest entrypoints

private def confidentialLoweringMismatchMessages :
  ImportedProofRelevantContractView →
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → List String
  | _, [], _ => []
  | view, fn :: rest, entrypoints =>
      let tail := confidentialLoweringMismatchMessages view rest entrypoints
      match lookupEntrypoint fn.signature entrypoints with
      | none => s!"{fn.signature}: missing manifest entrypoint" :: tail
      | some entry =>
          if functionConfidentialLoweringMatchesManifest view fn entry then
            tail
          else
            functionConfidentialLoweringMismatchMessage view fn entry :: tail

def ImportedProofRelevantContractView.stateObjectIds
  (view : ImportedProofRelevantContractView) : List Nat :=
  view.state.map ImportedProofRelevantStateObjectView.id

def ImportedProofRelevantContractView.manifestObjectIds
  (view : ImportedProofRelevantContractView) : List Nat :=
  view.manifest.objects.map ImportedProofRelevantManifestObjectView.id

def ImportedProofRelevantContractView.functionSignatures
  (view : ImportedProofRelevantContractView) : List String :=
  view.functions.map ImportedProofRelevantFunctionView.signature

def ImportedProofRelevantContractView.manifestEntrypointSignatures
  (view : ImportedProofRelevantContractView) : List String :=
  view.manifest.entrypoints.map ImportedProofRelevantEntrypointView.signature

def ImportedProofRelevantContractView.checkStructuralValid
  (view : ImportedProofRelevantContractView) : Bool :=
  (view.manifest.contract == view.contract) &&
    (view.manifest.compilation_mode == view.mode) &&
    distinctList view.stateObjectIds &&
    distinctList view.manifestObjectIds &&
    listedEquivalent view.stateObjectIds view.manifestObjectIds &&
    stateObjectsMatchManifestObjects view &&
    confidentialObjectsAvoidRawBackends view &&
    confidentialEntrypointsAvoidRawKernelTargets view view.functions view.manifest.entrypoints &&
    distinctList view.functionSignatures &&
    distinctList view.manifestEntrypointSignatures &&
    (view.functions.length == view.manifest.entrypoints.length) &&
    functionsMatchConfidentialLowering view view.functions view.manifest.entrypoints &&
    functionsMatchManifestSecrets view.functions view.manifest.entrypoints &&
    functionsMatchManifestBoundaryLengths view.functions view.manifest.entrypoints &&
    functionsMatchManifestCounts view.functions view.manifest.entrypoints &&
    functionsMatchManifestOramAccesses view view.functions view.manifest.entrypoints &&
    functionsMatchManifestCommitOps view view.functions view.manifest.entrypoints &&
    functionsMetadataWellFormed view view.functions view.manifest.entrypoints

def ImportedProofRelevantContractView.StructuralValid
  (view : ImportedProofRelevantContractView) : Prop :=
  view.checkStructuralValid = true

def ImportedProofRelevantContractView.validationErrors
  (view : ImportedProofRelevantContractView) : List String :=
  (if view.manifest.contract != view.contract then
      ["manifest contract does not match contract name"]
    else
      []) ++
    (if view.manifest.compilation_mode != view.mode then
      ["manifest compilation_mode does not match contract mode"]
    else
      []) ++
    (if !(distinctList view.stateObjectIds) then
      ["state object ids are not distinct"]
    else
      []) ++
    (if !(distinctList view.manifestObjectIds) then
      ["manifest object ids are not distinct"]
    else
      []) ++
    (if !(listedEquivalent view.stateObjectIds view.manifestObjectIds) then
      ["state object ids and manifest object ids do not match"]
    else
      []) ++
    (if !(stateObjectsMatchManifestObjects view) then
      ["manifest objects do not match expected state object manifests: " ++
        String.intercalate ", " (stateObjectManifestMismatchMessages view)]
    else
      []) ++
    (if !(confidentialObjectsAvoidRawBackends view) then
      ["confidential state objects use raw backends: " ++
        String.intercalate ", " (confidentialRawBackendMessages view)]
    else
      []) ++
    (if !(confidentialEntrypointsAvoidRawKernelTargets view view.functions view.manifest.entrypoints) then
      ["confidential kernel schedules target raw, non-confidential, or unknown state objects: " ++
        String.intercalate ", "
          (confidentialRawKernelTargetMessages view view.functions view.manifest.entrypoints)]
    else
      []) ++
    (if !(distinctList view.functionSignatures) then
      ["function signatures are not distinct"]
    else
      []) ++
    (if !(distinctList view.manifestEntrypointSignatures) then
      ["manifest entrypoint signatures are not distinct"]
    else
      []) ++
    (if view.functions.length != view.manifest.entrypoints.length then
      ["function count and manifest entrypoint count do not match"]
    else
      []) ++
    (if !(functionsMatchConfidentialLowering view view.functions view.manifest.entrypoints) then
      ["confidential lowering / kernel metadata checks failed for: " ++
        String.intercalate ", "
          (confidentialLoweringMismatchMessages view view.functions view.manifest.entrypoints)]
    else
      []) ++
    (if !(functionsMatchManifestSecrets view.functions view.manifest.entrypoints) then
      ["manifest secret_args/param_names do not match function metadata"]
    else
      []) ++
    (if !(functionsMatchManifestBoundaryLengths view.functions view.manifest.entrypoints) then
      ["manifest boundary lengths do not match function ABI metadata for: " ++
        String.intercalate ", "
          (manifestBoundaryLengthMismatchMessages view.functions view.manifest.entrypoints)]
    else
      []) ++
    (if !(functionsMatchManifestCounts view.functions view.manifest.entrypoints) then
      ["manifest resource counts do not match recomputed body counts for: " ++
        String.intercalate ", "
          (manifestCountMismatchMessages view.functions view.manifest.entrypoints)]
    else
      []) ++
    (if !(functionsMatchManifestOramAccesses view view.functions view.manifest.entrypoints) then
      ["manifest ORAM accesses do not match recomputed body accesses for: " ++
        String.intercalate ", "
          (manifestOramMismatchMessages view view.functions view.manifest.entrypoints)]
    else
      []) ++
    (if !(functionsMatchManifestCommitOps view view.functions view.manifest.entrypoints) then
      ["manifest max_commit_ops do not match recomputed body accesses for: " ++
        String.intercalate ", "
          (manifestCommitOpMismatchMessages view view.functions view.manifest.entrypoints)]
    else
      []) ++
    (if !(functionsMetadataWellFormed view view.functions view.manifest.entrypoints) then
      ["metadata policy checks failed for: " ++
        String.intercalate ", "
          (metadataMismatchMessages view view.functions view.manifest.entrypoints)]
    else
      [])

def ImportedProofRelevantTranslationBundle.sourceViewMatchesRawProjection
  (bundle : ImportedProofRelevantTranslationBundle) : Bool :=
  match parseImportedContractViewFromRawContractString bundle.source_contract_json with
  | .ok projected => projected == bundle.source_view
  | .error _ => false

def ImportedProofRelevantTranslationBundle.artifactViewMatchesRawProjection
  (bundle : ImportedProofRelevantTranslationBundle) : Bool :=
  match parseImportedContractViewFromRawContractString bundle.artifact_contract_json with
  | .ok projected => projected == bundle.artifact_view
  | .error _ => false

def ImportedProofRelevantTranslationBundle.admittedPackageIdentityWellFormed
  (bundle : ImportedProofRelevantTranslationBundle) : Prop :=
  match bundle.source_admitted_package with
  | some identity => identity.WellFormed
  | none => False

instance (bundle : ImportedProofRelevantTranslationBundle) :
    Decidable bundle.admittedPackageIdentityWellFormed := by
  unfold ImportedProofRelevantTranslationBundle.admittedPackageIdentityWellFormed
  split
  · infer_instance
  · infer_instance

def ImportedProofRelevantTranslationBundle.checkAdmittedPackageIdentityWellFormed
  (bundle : ImportedProofRelevantTranslationBundle) : Bool :=
  match bundle.source_admitted_package with
  | some identity => identity.checkWellFormed
  | none => false

@[simp] theorem importedProofRelevantTranslationBundle_checkAdmittedPackageIdentityWellFormed_eq_true_iff
  (bundle : ImportedProofRelevantTranslationBundle) :
  bundle.checkAdmittedPackageIdentityWellFormed = true ↔
    bundle.admittedPackageIdentityWellFormed := by
  unfold ImportedProofRelevantTranslationBundle.checkAdmittedPackageIdentityWellFormed
    ImportedProofRelevantTranslationBundle.admittedPackageIdentityWellFormed
  cases bundle.source_admitted_package <;> simp

def ImportedProofRelevantTranslationBundle.Valid
  (bundle : ImportedProofRelevantTranslationBundle) : Prop :=
  bundle.sourceViewMatchesRawProjection = true ∧
    bundle.artifactViewMatchesRawProjection = true ∧
    bundle.source_view = bundle.artifact_view ∧
    bundle.source_view.checkStructuralValid = true ∧
    bundle.artifact_view.checkStructuralValid = true ∧
    bundle.metadata_contract = bundle.source_view.contract ∧
    bundle.metadata_contract = bundle.artifact_view.contract ∧
    bundle.source_admitted_package = bundle.artifact_admitted_package ∧
    bundle.source_admitted_package.isSome = true ∧
    bundle.admittedPackageIdentityWellFormed

instance (bundle : ImportedProofRelevantTranslationBundle) :
    Decidable bundle.Valid := by
  unfold ImportedProofRelevantTranslationBundle.Valid
  infer_instance

def ImportedProofRelevantTranslationBundle.checkValid
  (bundle : ImportedProofRelevantTranslationBundle) : Bool :=
  bundle.sourceViewMatchesRawProjection &&
    bundle.artifactViewMatchesRawProjection &&
    decide (bundle.source_view = bundle.artifact_view) &&
    bundle.source_view.checkStructuralValid &&
    bundle.artifact_view.checkStructuralValid &&
    (bundle.metadata_contract == bundle.source_view.contract) &&
    (bundle.metadata_contract == bundle.artifact_view.contract) &&
    decide (bundle.source_admitted_package = bundle.artifact_admitted_package) &&
    bundle.source_admitted_package.isSome &&
    bundle.checkAdmittedPackageIdentityWellFormed

def ImportedProofRelevantTranslationBundle.ProofGradeValid
  (bundle : ImportedProofRelevantTranslationBundle) : Prop :=
  bundle.Valid

def ImportedProofRelevantTranslationBundle.checkProofGrade
  (bundle : ImportedProofRelevantTranslationBundle) : Bool :=
  bundle.checkValid

def ImportedProofRelevantTranslationBundle.validationErrors
  (bundle : ImportedProofRelevantTranslationBundle) : List String :=
  (match parseImportedContractViewFromRawContractString bundle.source_contract_json with
    | .ok projected =>
        if projected == bundle.source_view then
          []
        else
          ["source_contract_json does not project to source_view"]
    | .error err =>
        [s!"failed to project source_contract_json: {err}"]) ++
    (match parseImportedContractViewFromRawContractString bundle.artifact_contract_json with
    | .ok projected =>
        if projected == bundle.artifact_view then
          []
        else
          ["artifact_contract_json does not project to artifact_view"]
    | .error err =>
        [s!"failed to project artifact_contract_json: {err}"]) ++
    (if bundle.source_view != bundle.artifact_view then
      ["source_view and artifact_view do not match exactly"]
    else
      []) ++
    (if bundle.source_view.checkStructuralValid != true then
      ["source_view: " ++ String.intercalate "; " bundle.source_view.validationErrors]
    else
      []) ++
    (if bundle.artifact_view.checkStructuralValid != true then
      ["artifact_view: " ++ String.intercalate "; " bundle.artifact_view.validationErrors]
    else
      []) ++
    (if bundle.metadata_contract != bundle.source_view.contract then
      ["metadata_contract does not match source_view.contract"]
    else
      []) ++
    (if bundle.metadata_contract != bundle.artifact_view.contract then
      ["metadata_contract does not match artifact_view.contract"]
    else
      []) ++
    (if bundle.source_admitted_package != bundle.artifact_admitted_package then
      ["source and artifact admitted package identities do not match"]
    else
      []) ++
    (if bundle.source_admitted_package.isSome != true then
      ["source admitted package identity is missing"]
    else
      []) ++
    (if bundle.checkAdmittedPackageIdentityWellFormed != true then
      ["source admitted package identity is not schema-v5/raw-metadata/toolchain-bound"]
    else
      [])

def parseImportedProofRelevantTranslationBundle
  (input : String) : Except String ImportedProofRelevantTranslationBundle := do
  let json ← Lean.Json.parse input
  fromJson? json

def parseImportedProofGradeTranslationArtifacts
  (metadataContract sourceArtifactInput artifactInput : String) :
  Except String ImportedProofRelevantTranslationBundle := do
  let sourceArtifactJson ← Lean.Json.parse sourceArtifactInput
  let artifactJson ← Lean.Json.parse artifactInput
  let (sourceContractJson, sourceView) ←
    parseImportedContractViewAndRawContractStringFromArtifactJson sourceArtifactJson
  let (artifactContractJson, artifactView) ←
    parseImportedContractViewAndRawContractStringFromArtifactJson artifactJson
  pure
    { source_path := ""
    , metadata_contract := metadataContract
    , source_admitted_package := ← lookupOptionalFieldAs sourceArtifactJson "admitted_package"
    , artifact_admitted_package := ← lookupOptionalFieldAs artifactJson "admitted_package"
    , source_contract_json := sourceContractJson
    , artifact_contract_json := artifactContractJson
    , source_view := sourceView
    , artifact_view := artifactView
    }

def parseAndCheckImportedProofRelevantTranslationBundle
  (input : String) : Except String ImportedProofRelevantTranslationBundle := do
  let bundle ← parseImportedProofRelevantTranslationBundle input
  if bundle.checkValid then
    pure bundle
  else
    throw <| "imported translation validation bundle does not satisfy Lean validity checks: " ++
      String.intercalate "; " bundle.validationErrors

def parseAndCheckImportedProofGradeTranslationArtifacts
  (metadataContract sourceArtifactInput artifactInput : String) :
  Except String ImportedProofRelevantTranslationBundle := do
  let bundle ←
    parseImportedProofGradeTranslationArtifacts metadataContract sourceArtifactInput artifactInput
  if bundle.checkProofGrade then
    pure bundle
  else
    throw <|
      "imported proof-grade translation artifacts do not satisfy Lean validity checks: " ++
      String.intercalate "; " bundle.validationErrors

def loadImportedProofRelevantTranslationBundle
  (path : System.FilePath) : IO ImportedProofRelevantTranslationBundle := do
  let input ← IO.FS.readFile path
  match parseImportedProofRelevantTranslationBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to parse translation validation bundle: {err}"

def loadAndCheckImportedProofRelevantTranslationBundle
  (path : System.FilePath) : IO ImportedProofRelevantTranslationBundle := do
  let input ← IO.FS.readFile path
  match parseAndCheckImportedProofRelevantTranslationBundle input with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError s!"failed to validate translation validation bundle: {err}"

def loadAndCheckImportedProofGradeTranslationArtifacts
  (metadataContract : String)
  (sourceArtifactPath artifactPath : System.FilePath) :
  IO ImportedProofRelevantTranslationBundle := do
  let sourceArtifactInput ← IO.FS.readFile sourceArtifactPath
  let artifactInput ← IO.FS.readFile artifactPath
  match
      parseAndCheckImportedProofGradeTranslationArtifacts
        metadataContract
        sourceArtifactInput
        artifactInput with
  | .ok bundle => pure bundle
  | .error err =>
      throw <| IO.userError
        s!"failed to validate proof-grade translation artifacts: {err}"

@[simp] theorem importedProofRelevantTranslationBundle_checkValid_eq_true_iff
  (bundle : ImportedProofRelevantTranslationBundle) :
  bundle.checkValid = true ↔ bundle.Valid := by
  unfold ImportedProofRelevantTranslationBundle.checkValid
    ImportedProofRelevantTranslationBundle.Valid
  simp [and_assoc]

@[simp] theorem importedProofRelevantTranslationBundle_sourceViewMatchesRawProjection_eq_true_iff
  (bundle : ImportedProofRelevantTranslationBundle) :
  bundle.sourceViewMatchesRawProjection = true ↔
    parseImportedContractViewFromRawContractString bundle.source_contract_json =
      .ok bundle.source_view := by
  unfold ImportedProofRelevantTranslationBundle.sourceViewMatchesRawProjection
  cases hParse : parseImportedContractViewFromRawContractString bundle.source_contract_json with
  | ok projected =>
      simp
  | error err =>
      simp

@[simp] theorem importedProofRelevantTranslationBundle_artifactViewMatchesRawProjection_eq_true_iff
  (bundle : ImportedProofRelevantTranslationBundle) :
  bundle.artifactViewMatchesRawProjection = true ↔
    parseImportedContractViewFromRawContractString bundle.artifact_contract_json =
      .ok bundle.artifact_view := by
  unfold ImportedProofRelevantTranslationBundle.artifactViewMatchesRawProjection
  cases hParse : parseImportedContractViewFromRawContractString bundle.artifact_contract_json with
  | ok projected =>
      simp
  | error err =>
      simp

@[simp] theorem importedProofRelevantTranslationBundle_checkProofGrade_eq_true_iff
  (bundle : ImportedProofRelevantTranslationBundle) :
  bundle.checkProofGrade = true ↔ bundle.ProofGradeValid := by
  unfold ImportedProofRelevantTranslationBundle.checkProofGrade
    ImportedProofRelevantTranslationBundle.ProofGradeValid
  simp [importedProofRelevantTranslationBundle_checkValid_eq_true_iff]

@[simp] theorem importedProofRelevantContractView_checkStructuralValid_eq_true_iff
  (view : ImportedProofRelevantContractView) :
  view.checkStructuralValid = true ↔ view.StructuralValid := by
  rfl

theorem importedProofRelevantTranslationBundle_source_view_exact_from_raw_contract
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid) :
  parseImportedContractViewFromRawContractString bundle.source_contract_json =
      .ok bundle.source_view := by
  exact
    (importedProofRelevantTranslationBundle_sourceViewMatchesRawProjection_eq_true_iff
      bundle).mp hValid.1

theorem importedProofRelevantTranslationBundle_artifact_view_exact_from_raw_contract
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid) :
  parseImportedContractViewFromRawContractString bundle.artifact_contract_json =
      .ok bundle.artifact_view := by
  exact
    (importedProofRelevantTranslationBundle_artifactViewMatchesRawProjection_eq_true_iff
      bundle).mp hValid.2.1

theorem importedProofRelevantTranslationBundle_views_exact
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid) :
  bundle.source_view = bundle.artifact_view := by
  exact hValid.2.2.1

theorem ImportedProofRelevantTranslationBundle.source_view_structural_valid
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid) :
  bundle.source_view.StructuralValid := by
  exact hValid.2.2.2.1

theorem ImportedProofRelevantTranslationBundle.artifact_view_structural_valid
  (bundle : ImportedProofRelevantTranslationBundle)
  (hValid : bundle.ProofGradeValid) :
  bundle.artifact_view.StructuralValid := by
  exact hValid.2.2.2.2.1

private theorem functionsMatchManifestSecrets_exact_of_lookup
  {functions : List ImportedProofRelevantFunctionView}
  {entrypoints : List ImportedProofRelevantEntrypointView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMatch : functionsMatchManifestSecrets functions entrypoints = true)
  (hMem : fn ∈ functions)
  (hLookup : lookupEntrypoint fn.signature entrypoints = some entry) :
  (entry.secret_args = fn.secret_args ∧
    entry.param_names = fn.params.map ImportedProofRelevantParamView.name) ∧
    entry.public_env = fn.public_env := by
  induction functions generalizing fn entry with
  | nil =>
      cases hMem
  | cons hd tl ih =>
      simp only [List.mem_cons] at hMem
      rcases hMem with hEq | hMem
      · subst hEq
        have hHead := hMatch
        simp [functionsMatchManifestSecrets, hLookup] at hHead
        exact hHead.1
      · cases hHd : lookupEntrypoint hd.signature entrypoints <;>
          simp [functionsMatchManifestSecrets, hHd] at hMatch
        exact ih hMatch.2 hMem hLookup

private theorem functionsMatchConfidentialLowering_exact_of_lookup
  {view : ImportedProofRelevantContractView}
  {functions : List ImportedProofRelevantFunctionView}
  {entrypoints : List ImportedProofRelevantEntrypointView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMatch : functionsMatchConfidentialLowering view functions entrypoints = true)
  (hMem : fn ∈ functions)
  (hLookup : lookupEntrypoint fn.signature entrypoints = some entry) :
  functionConfidentialLoweringMatchesManifest view fn entry = true := by
  induction functions generalizing fn entry with
  | nil =>
      cases hMem
  | cons hd tl ih =>
      simp only [List.mem_cons] at hMem
      rcases hMem with hEq | hMem
      · subst hEq
        have hHead := hMatch
        simp [functionsMatchConfidentialLowering, hLookup] at hHead
        exact hHead.1
      · cases hHd : lookupEntrypoint hd.signature entrypoints <;>
          simp [functionsMatchConfidentialLowering, hHd] at hMatch
        exact ih hMatch.2 hMem hLookup

private theorem functionsMatchManifestBoundaryLengths_exact_of_lookup
  {functions : List ImportedProofRelevantFunctionView}
  {entrypoints : List ImportedProofRelevantEntrypointView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMatch : functionsMatchManifestBoundaryLengths functions entrypoints = true)
  (hMem : fn ∈ functions)
  (hLookup : lookupEntrypoint fn.signature entrypoints = some entry) :
  functionBoundaryLengthsMatchManifest fn entry = true := by
  induction functions generalizing fn entry with
  | nil =>
      cases hMem
  | cons hd tl ih =>
      simp only [List.mem_cons] at hMem
      rcases hMem with hEq | hMem
      · subst hEq
        have hHead := hMatch
        simp [functionsMatchManifestBoundaryLengths, hLookup] at hHead
        exact hHead.1
      · cases hHd : lookupEntrypoint hd.signature entrypoints <;>
          simp [functionsMatchManifestBoundaryLengths, hHd] at hMatch
        exact ih hMatch.2 hMem hLookup

private theorem functionsMatchManifestCounts_exact_of_lookup
  {functions : List ImportedProofRelevantFunctionView}
  {entrypoints : List ImportedProofRelevantEntrypointView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMatch : functionsMatchManifestCounts functions entrypoints = true)
  (hMem : fn ∈ functions)
  (hLookup : lookupEntrypoint fn.signature entrypoints = some entry) :
  functionCountsMatchManifest fn entry = true := by
  induction functions generalizing fn entry with
  | nil =>
      cases hMem
  | cons hd tl ih =>
      simp only [List.mem_cons] at hMem
      rcases hMem with hEq | hMem
      · subst hEq
        have hHead := hMatch
        simp [functionsMatchManifestCounts, hLookup] at hHead
        exact hHead.1
      · cases hHd : lookupEntrypoint hd.signature entrypoints <;>
          simp [functionsMatchManifestCounts, hHd] at hMatch
        exact ih hMatch.2 hMem hLookup

private theorem functionsMatchManifestOramAccesses_exact_of_lookup
  {view : ImportedProofRelevantContractView}
  {functions : List ImportedProofRelevantFunctionView}
  {entrypoints : List ImportedProofRelevantEntrypointView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMatch : functionsMatchManifestOramAccesses view functions entrypoints = true)
  (hMem : fn ∈ functions)
  (hLookup : lookupEntrypoint fn.signature entrypoints = some entry) :
  functionOramAccessesMatchManifest view fn entry = true := by
  induction functions generalizing fn entry with
  | nil =>
      cases hMem
  | cons hd tl ih =>
      simp only [List.mem_cons] at hMem
      rcases hMem with hEq | hMem
      · subst hEq
        have hHead := hMatch
        simp [functionsMatchManifestOramAccesses, hLookup] at hHead
        exact hHead.1
      · cases hHd : lookupEntrypoint hd.signature entrypoints <;>
          simp [functionsMatchManifestOramAccesses, hHd] at hMatch
        exact ih hMatch.2 hMem hLookup

private theorem functionsMatchManifestCommitOps_exact_of_lookup
  {view : ImportedProofRelevantContractView}
  {functions : List ImportedProofRelevantFunctionView}
  {entrypoints : List ImportedProofRelevantEntrypointView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMatch : functionsMatchManifestCommitOps view functions entrypoints = true)
  (hMem : fn ∈ functions)
  (hLookup : lookupEntrypoint fn.signature entrypoints = some entry) :
  functionMaxCommitOpsMatchesManifest view fn entry = true := by
  induction functions generalizing fn entry with
  | nil =>
      cases hMem
  | cons hd tl ih =>
      simp only [List.mem_cons] at hMem
      rcases hMem with hEq | hMem
      · subst hEq
        have hHead := hMatch
        simp [functionsMatchManifestCommitOps, hLookup] at hHead
        exact hHead.1
      · cases hHd : lookupEntrypoint hd.signature entrypoints <;>
          simp [functionsMatchManifestCommitOps, hHd] at hMatch
        exact ih hMatch.2 hMem hLookup

private theorem kernelStepsTargetNonRawStateObjects_exact_of_mem
  {state : List ImportedProofRelevantStateObjectView}
  {steps : List ImportedProofRelevantKernelStepView}
  {step : ImportedProofRelevantKernelStepView}
  (hMatch : kernelStepsTargetNonRawStateObjects state steps = true)
  (hMem : step ∈ steps) :
  kernelStepTargetsNonRawStateObject state step = true := by
  induction steps with
  | nil =>
      cases hMem
  | cons hd tl ih =>
      simp only [List.mem_cons] at hMem
      simp [kernelStepsTargetNonRawStateObjects] at hMatch
      rcases hMem with hEq | hMem
      · subst hEq
        exact hMatch.1
      · exact ih hMatch.2 hMem

private theorem confidentialEntrypointsAvoidRawKernelTargets_exact_of_lookup
  {view : ImportedProofRelevantContractView}
  {functions : List ImportedProofRelevantFunctionView}
  {entrypoints : List ImportedProofRelevantEntrypointView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMatch : confidentialEntrypointsAvoidRawKernelTargets view functions entrypoints = true)
  (hMem : fn ∈ functions)
  (hLookup : lookupEntrypoint fn.signature entrypoints = some entry)
  (hConf : fn.confidential = true) :
  kernelStepsTargetNonRawStateObjects view.state entry.kernel_steps = true := by
  induction functions generalizing fn entry with
  | nil =>
      cases hMem
  | cons hd tl ih =>
      simp only [List.mem_cons] at hMem
      rcases hMem with hEq | hMem
      · subst hEq
        have hHead := hMatch
        simp [confidentialEntrypointsAvoidRawKernelTargets, hLookup, hConf] at hHead
        exact hHead.1
      · cases hHd : lookupEntrypoint hd.signature entrypoints with
        | none =>
            simp [confidentialEntrypointsAvoidRawKernelTargets, hHd] at hMatch
        | some hdEntry =>
            have hTail :
                confidentialEntrypointsAvoidRawKernelTargets view tl entrypoints = true := by
              cases hHdConf : hd.confidential with
              | false =>
                simp [confidentialEntrypointsAvoidRawKernelTargets, hHd, hHdConf] at hMatch
                exact hMatch
              | true =>
                simp [confidentialEntrypointsAvoidRawKernelTargets, hHd, hHdConf] at hMatch
                exact hMatch.2
            exact ih hTail hMem hLookup hConf

private theorem ImportedProofRelevantContractView.structural_exactness_checks
  (view : ImportedProofRelevantContractView)
  (hValid : view.StructuralValid) :
  functionsMatchConfidentialLowering view view.functions view.manifest.entrypoints = true ∧
    functionsMatchManifestSecrets view.functions view.manifest.entrypoints = true ∧
    functionsMatchManifestBoundaryLengths view.functions view.manifest.entrypoints = true ∧
    functionsMatchManifestCounts view.functions view.manifest.entrypoints = true ∧
    functionsMatchManifestOramAccesses view view.functions view.manifest.entrypoints = true ∧
    functionsMatchManifestCommitOps view view.functions view.manifest.entrypoints = true := by
  have hChecks := hValid
  simp [ImportedProofRelevantContractView.StructuralValid,
    ImportedProofRelevantContractView.checkStructuralValid] at hChecks
  rcases hChecks with ⟨hPrefix17, _hMetadata⟩
  rcases hPrefix17 with ⟨hPrefix16, hCommit⟩
  rcases hPrefix16 with ⟨hPrefix15, hOram⟩
  rcases hPrefix15 with ⟨hPrefix14, hCounts⟩
  rcases hPrefix14 with ⟨hPrefix13, hBoundary⟩
  rcases hPrefix13 with ⟨hPrefix12, hSecrets⟩
  rcases hPrefix12 with ⟨_hPrefix11, hLowering⟩
  exact ⟨hLowering, hSecrets, hBoundary, hCounts, hOram, hCommit⟩

private theorem ImportedProofRelevantContractView.structural_confidential_kernel_targets
  (view : ImportedProofRelevantContractView)
  (hValid : view.StructuralValid) :
  confidentialEntrypointsAvoidRawKernelTargets
      view view.functions view.manifest.entrypoints = true := by
  have hChecks := hValid
  simp [ImportedProofRelevantContractView.StructuralValid,
    ImportedProofRelevantContractView.checkStructuralValid] at hChecks
  rcases hChecks with ⟨hPrefix17, _hMetadata⟩
  rcases hPrefix17 with ⟨hPrefix16, _hCommit⟩
  rcases hPrefix16 with ⟨hPrefix15, _hOram⟩
  rcases hPrefix15 with ⟨hPrefix14, _hCounts⟩
  rcases hPrefix14 with ⟨hPrefix13, _hBoundary⟩
  rcases hPrefix13 with ⟨hPrefix12, _hSecrets⟩
  rcases hPrefix12 with ⟨hPrefix11, _hLowering⟩
  rcases hPrefix11 with ⟨hPrefix10, _hLength⟩
  rcases hPrefix10 with ⟨hPrefix9, _hEntrypointSignatures⟩
  rcases hPrefix9 with ⟨hPrefix8, _hFunctionSignatures⟩
  rcases hPrefix8 with ⟨_hPrefix7, hTargets⟩
  exact hTargets

private theorem ImportedProofRelevantContractView.structural_metadata_wellFormed
  (view : ImportedProofRelevantContractView)
  (hValid : view.StructuralValid) :
  functionsMetadataWellFormed view view.functions view.manifest.entrypoints = true := by
  have hChecks := hValid
  simp [ImportedProofRelevantContractView.StructuralValid,
    ImportedProofRelevantContractView.checkStructuralValid] at hChecks
  exact hChecks.2

theorem ImportedProofRelevantContractView.manifest_secrets_exact_of_lookup
  (view : ImportedProofRelevantContractView)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hValid : view.StructuralValid)
  (hMem : fn ∈ view.functions)
  (hLookup : lookupEntrypoint fn.signature view.manifest.entrypoints = some entry) :
  entry.secret_args = fn.secret_args ∧
    entry.param_names = fn.params.map ImportedProofRelevantParamView.name := by
  exact (
    functionsMatchManifestSecrets_exact_of_lookup
      (view.structural_exactness_checks hValid).2.1
      hMem
      hLookup).1

theorem ImportedProofRelevantContractView.manifest_public_env_exact_of_lookup
  (view : ImportedProofRelevantContractView)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hValid : view.StructuralValid)
  (hMem : fn ∈ view.functions)
  (hLookup : lookupEntrypoint fn.signature view.manifest.entrypoints = some entry) :
  entry.public_env = fn.public_env := by
  exact (
    functionsMatchManifestSecrets_exact_of_lookup
      (view.structural_exactness_checks hValid).2.1
      hMem
      hLookup).2

theorem ImportedProofRelevantContractView.confidential_lowering_exact_of_lookup
  (view : ImportedProofRelevantContractView)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hValid : view.StructuralValid)
  (hMem : fn ∈ view.functions)
  (hLookup : lookupEntrypoint fn.signature view.manifest.entrypoints = some entry) :
  functionConfidentialLoweringMatchesManifest view fn entry = true := by
  exact
    functionsMatchConfidentialLowering_exact_of_lookup
      (view.structural_exactness_checks hValid).1
      hMem
      hLookup

theorem ImportedProofRelevantContractView.confidential_kernel_step_targets_non_raw_of_lookup
  (view : ImportedProofRelevantContractView)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hValid : view.StructuralValid)
  (hMem : fn ∈ view.functions)
  (hLookup : lookupEntrypoint fn.signature view.manifest.entrypoints = some entry)
  (hConf : fn.confidential = true)
  {kernelStep : ImportedProofRelevantKernelStepView}
  {objectId : Nat}
  (hStepMem : kernelStep ∈ entry.kernel_steps)
  (hObjectId : kernelStep.object_id = some objectId) :
  ∃ stateObject,
    stateObjectById? view.state objectId = some stateObject ∧
      stateObject.backend ≠ "raw" := by
  have hEntryTargets :
      kernelStepsTargetNonRawStateObjects view.state entry.kernel_steps = true :=
    confidentialEntrypointsAvoidRawKernelTargets_exact_of_lookup
      (view.structural_confidential_kernel_targets hValid)
      hMem
      hLookup
      hConf
  have hStepTarget :
      kernelStepTargetsNonRawStateObject view.state kernelStep = true :=
    kernelStepsTargetNonRawStateObjects_exact_of_mem hEntryTargets hStepMem
  simp [kernelStepTargetsNonRawStateObject, hObjectId] at hStepTarget
  cases hStateObject : stateObjectById? view.state objectId with
  | none =>
      simp [hStateObject] at hStepTarget
  | some stateObject =>
      simp [hStateObject] at hStepTarget
      exact ⟨stateObject, rfl, hStepTarget.1⟩

theorem ImportedProofRelevantContractView.manifest_boundary_lengths_exact_of_lookup
  (view : ImportedProofRelevantContractView)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hValid : view.StructuralValid)
  (hMem : fn ∈ view.functions)
  (hLookup : lookupEntrypoint fn.signature view.manifest.entrypoints = some entry) :
  ∃ inputLen returnLen,
    expectedEntrypointInputLen fn = .ok inputLen ∧
    expectedReturnCanonicalLen fn = .ok returnLen ∧
    entry.entry_input_len = inputLen ∧
    entry.return_canonical_len = returnLen := by
  have hMatch :=
    functionsMatchManifestBoundaryLengths_exact_of_lookup
      (view.structural_exactness_checks hValid).2.2.1
      hMem
      hLookup
  cases hInput : expectedEntrypointInputLen fn with
  | error err =>
      simp [functionBoundaryLengthsMatchManifest, hInput] at hMatch
  | ok inputLen =>
      cases hReturn : expectedReturnCanonicalLen fn with
      | error err =>
          simp [functionBoundaryLengthsMatchManifest, hInput, hReturn] at hMatch
      | ok returnLen =>
          have hFacts := hMatch
          simp [functionBoundaryLengthsMatchManifest, hInput, hReturn] at hFacts
          have hInputLen : entry.entry_input_len = inputLen := hFacts.1
          have hReturnLen : entry.return_canonical_len = returnLen := hFacts.2
          exact ⟨inputLen, returnLen, rfl, rfl, hInputLen, hReturnLen⟩

theorem ImportedProofRelevantContractView.manifest_counts_exact_of_lookup
  (view : ImportedProofRelevantContractView)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hValid : view.StructuralValid)
  (hMem : fn ∈ view.functions)
  (hLookup : lookupEntrypoint fn.signature view.manifest.entrypoints = some entry) :
  ∃ counts,
    countBodyStrings fn.body = .ok counts ∧
    entry.arena_bytes = 4096 + counts.localCount * 64 ∧
    entry.max_stack_words = 64 + counts.localCount ∧
    entry.uocell_reads = counts.cellReads ∧
    entry.uocell_writes = counts.cellWrites ∧
    entry.uoarray_reads = counts.arrayReads ∧
    entry.uoarray_writes = counts.arrayWrites ∧
    entry.uomap_reads = counts.mapReads ∧
    entry.uomap_writes = counts.mapWrites := by
  have hMatch :=
    functionsMatchManifestCounts_exact_of_lookup
      (view.structural_exactness_checks hValid).2.2.2.1
      hMem
      hLookup
  cases hCounts : countBodyStrings fn.body with
  | error err =>
      simp [functionCountsMatchManifest, hCounts] at hMatch
  | ok counts =>
      have hFacts := hMatch
      simp [functionCountsMatchManifest, hCounts] at hFacts
      rcases hFacts with ⟨hPrefix7, hMapWrites⟩
      rcases hPrefix7 with ⟨hPrefix6, hMapReads⟩
      rcases hPrefix6 with ⟨hPrefix5, hArrayWrites⟩
      rcases hPrefix5 with ⟨hPrefix4, hArrayReads⟩
      rcases hPrefix4 with ⟨hPrefix3, hCellWrites⟩
      rcases hPrefix3 with ⟨hPrefix2, hCellReads⟩
      rcases hPrefix2 with ⟨hArena, hStack⟩
      exact
        ⟨counts, rfl, hArena, hStack, hCellReads, hCellWrites, hArrayReads,
          hArrayWrites, hMapReads, hMapWrites⟩

theorem ImportedProofRelevantContractView.manifest_oram_accesses_exact_of_lookup
  (view : ImportedProofRelevantContractView)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hValid : view.StructuralValid)
  (hMem : fn ∈ view.functions)
  (hLookup : lookupEntrypoint fn.signature view.manifest.entrypoints = some entry) :
  ∃ expected,
    countOramAccessesInBodyStrings fn.body view.state = .ok expected ∧
    oramAccessesMatchExpected expected entry.oram_accesses = true ∧
    ∀ objectId accesses,
      (objectId, accesses) ∈ expected →
        (match stateObjectById? view.state objectId, manifestObjectById? view.manifest.objects objectId with
        | some stateObject, some manifestObject =>
            validateImportedOramShape stateObject manifestObject accesses
        | _, _ => false) = true := by
  have hMatch :=
    functionsMatchManifestOramAccesses_exact_of_lookup
      (view.structural_exactness_checks hValid).2.2.2.2.1
      hMem
      hLookup
  cases hCounts : countOramAccessesInBodyStrings fn.body view.state with
  | error err =>
      simp [functionOramAccessesMatchManifest, hCounts] at hMatch
  | ok expected =>
      have hFacts := hMatch
      simp [functionOramAccessesMatchManifest, hCounts] at hFacts
      exact ⟨expected, rfl, hFacts.1, hFacts.2⟩

theorem ImportedProofRelevantContractView.manifest_commit_ops_exact_of_lookup
  (view : ImportedProofRelevantContractView)
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hValid : view.StructuralValid)
  (hMem : fn ∈ view.functions)
  (hLookup : lookupEntrypoint fn.signature view.manifest.entrypoints = some entry) :
  ∃ maxCommitOps,
    expectedCommitOpsForFunction view fn = .ok maxCommitOps ∧
    entry.max_commit_ops = maxCommitOps := by
  have hMatch :=
    functionsMatchManifestCommitOps_exact_of_lookup
      (view.structural_exactness_checks hValid).2.2.2.2.2
      hMem
      hLookup
  cases hCommit : expectedCommitOpsForFunction view fn with
  | error err =>
      simp [functionMaxCommitOpsMatchesManifest, hCommit] at hMatch
  | ok maxCommitOps =>
      have hFact := hMatch
      simp [functionMaxCommitOpsMatchesManifest, hCommit] at hFact
      exact ⟨maxCommitOps, rfl, hFact⟩

theorem functionStoredDslMatchesBody_confidential_exact
  {fn : ImportedProofRelevantFunctionView}
  (hMatch : functionStoredDslMatchesBody fn = true)
  (hConf : fn.confidential = true) :
  ∃ expectedProgram program slotProgram,
    expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
    parseFunctionConfidentialProgram fn = .ok (some program) ∧
    parseFunctionConfidentialSlotProgram fn = .ok (some slotProgram) ∧
    importedConfidentialKernelProgramEq program expectedProgram = true ∧
    program.expectedRuntimeKernelSteps = expectedProgram.expectedRuntimeKernelSteps ∧
    checkImportedConfidentialKernelProgramSlotLowering program slotProgram = true := by
  unfold functionStoredDslMatchesBody at hMatch
  rw [if_pos hConf] at hMatch
  cases hExpected : expectedConfidentialKernelProgramForFunction fn with
  | error err =>
      simp [hExpected] at hMatch
  | ok expectedProgram =>
      cases hProgram : parseFunctionConfidentialProgram fn with
      | error err =>
          simp [hExpected, hProgram] at hMatch
      | ok programOpt =>
          cases programOpt with
          | none =>
              simp [hExpected, hProgram] at hMatch
          | some program =>
              cases hSlot : parseFunctionConfidentialSlotProgram fn with
              | error err =>
                  simp [hExpected, hProgram, hSlot] at hMatch
              | ok slotProgramOpt =>
                  cases slotProgramOpt with
                  | none =>
                      simp [hExpected, hProgram, hSlot] at hMatch
                  | some slotProgram =>
                      have hFacts := hMatch
                      simp [hExpected, hProgram, hSlot] at hFacts
                      have hProgramEq :
                          importedConfidentialKernelProgramEq program expectedProgram = true := hFacts.1.1
                      have hScheduleEq :
                          program.expectedRuntimeKernelSteps =
                            expectedProgram.expectedRuntimeKernelSteps := by
                        exact
                          (importedConfidentialKernelProgramSchedulesEq_eq_true_iff
                            program expectedProgram).mp hFacts.1.2
                      have hSlotLowering :
                          checkImportedConfidentialKernelProgramSlotLowering program slotProgram = true := hFacts.2
                      exact
                        ⟨expectedProgram, program, slotProgram, rfl, rfl, rfl,
                          hProgramEq, hScheduleEq, hSlotLowering⟩

theorem manifestStoredDslMatchesKernelSchedule_confidential_exact
  {view : ImportedProofRelevantContractView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMatch : manifestStoredDslMatchesKernelSchedule view fn entry = true)
  (hConf : fn.confidential = true) :
  ∃ program slotProgram expectedHashPartBytes,
    parseEntrypointConfidentialProgram entry = .ok (some program) ∧
    parseEntrypointConfidentialSlotProgram entry = .ok (some slotProgram) ∧
    importedConfidentialKernelProgramMaxHashPartBytes view.state program = .ok expectedHashPartBytes ∧
    program.entrypoint_id = fn.signature ∧
    slotProgram.entrypoint_id = fn.signature ∧
    program.secret_args = fn.secret_args ∧
    slotProgram.secret_args = fn.secret_args ∧
    entry.max_hash_part_bytes = expectedHashPartBytes ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        program.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        slotProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    checkImportedConfidentialKernelProgramSlotLowering program slotProgram = true := by
  unfold manifestStoredDslMatchesKernelSchedule at hMatch
  cases hProgram : parseEntrypointConfidentialProgram entry with
  | error err =>
      simp [hProgram] at hMatch
  | ok programOpt =>
      cases programOpt with
      | none =>
          cases hSlot : parseEntrypointConfidentialSlotProgram entry with
          | error err =>
              simp [hProgram, hSlot] at hMatch
          | ok slotProgramOpt =>
              cases slotProgramOpt with
              | none =>
                  simp [hProgram, hSlot, hConf] at hMatch
              | some slotProgram =>
                  simp [hProgram, hSlot] at hMatch
      | some program =>
          cases hSlot : parseEntrypointConfidentialSlotProgram entry with
          | error err =>
              simp [hProgram, hSlot] at hMatch
          | ok slotProgramOpt =>
              cases slotProgramOpt with
              | none =>
                  simp [hProgram, hSlot] at hMatch
              | some slotProgram =>
                  cases hHash : importedConfidentialKernelProgramMaxHashPartBytes view.state program with
                  | error err =>
                      simp [hProgram, hSlot, hHash] at hMatch
                  | ok expectedHashPartBytes =>
                      have hFacts := hMatch
                      simp [hProgram, hSlot, hHash] at hFacts
                      rcases hFacts with ⟨hPrefix7, hSlotLowering⟩
                      rcases hPrefix7 with ⟨hPrefix6, hSlotSteps⟩
                      rcases hPrefix6 with ⟨hPrefix5, hSteps⟩
                      rcases hPrefix5 with ⟨hPrefix4, hHashBound⟩
                      rcases hPrefix4 with ⟨hPrefix3, hSlotSecrets⟩
                      rcases hPrefix3 with ⟨hPrefix2, hSecrets⟩
                      rcases hPrefix2 with ⟨hPrefix1, hSlotEntrypoint⟩
                      rcases hPrefix1 with ⟨_hConfTrue, hEntrypoint⟩
                      exact
                        ⟨program, slotProgram, expectedHashPartBytes, rfl, rfl, hHash,
                          hEntrypoint, hSlotEntrypoint, hSecrets, hSlotSecrets,
                          hHashBound, hSteps, hSlotSteps, hSlotLowering⟩

theorem functionConfidentialLoweringMatchesManifest_confidential_exact
  {view : ImportedProofRelevantContractView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMatch : functionConfidentialLoweringMatchesManifest view fn entry = true)
  (hConf : fn.confidential = true) :
  ∃ expectedProgram fnProgram fnSlotProgram entryProgram entrySlotProgram expectedHashPartBytes,
    expectedConfidentialKernelProgramForFunction fn = .ok expectedProgram ∧
    parseFunctionConfidentialProgram fn = .ok (some fnProgram) ∧
    parseFunctionConfidentialSlotProgram fn = .ok (some fnSlotProgram) ∧
    parseEntrypointConfidentialProgram entry = .ok (some entryProgram) ∧
    parseEntrypointConfidentialSlotProgram entry = .ok (some entrySlotProgram) ∧
    importedConfidentialKernelProgramEq fnProgram expectedProgram = true ∧
    fnProgram.expectedRuntimeKernelSteps = expectedProgram.expectedRuntimeKernelSteps ∧
    importedConfidentialKernelProgramEq fnProgram entryProgram = true ∧
    fnProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps ∧
    checkImportedConfidentialKernelProgramSlotLowering fnProgram fnSlotProgram = true ∧
    checkImportedConfidentialKernelProgramSlotLowering entryProgram entrySlotProgram = true ∧
    fn.confidential_program = entry.confidential_program ∧
    fn.confidential_slot_program = entry.confidential_slot_program ∧
    importedConfidentialKernelProgramMaxHashPartBytes view.state entryProgram = .ok expectedHashPartBytes ∧
    entryProgram.entrypoint_id = fn.signature ∧
    entrySlotProgram.entrypoint_id = fn.signature ∧
    entryProgram.secret_args = fn.secret_args ∧
    entrySlotProgram.secret_args = fn.secret_args ∧
    entry.max_hash_part_bytes = expectedHashPartBytes ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        entryProgram.expectedRuntimeKernelSteps = entry.kernel_steps ∧
    importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
        entrySlotProgram.expectedRuntimeKernelSteps = entry.kernel_steps := by
  have hSplit :
    (functionStoredDslMatchesBody fn = true ∧
      manifestStoredDslMatchesKernelSchedule view fn entry = true) ∧
      (match
          parseFunctionConfidentialProgram fn,
          parseFunctionConfidentialSlotProgram fn,
          parseEntrypointConfidentialProgram entry,
          parseEntrypointConfidentialSlotProgram entry with
        | .ok (some fnProgram), .ok (some fnSlotProgram), .ok (some entryProgram), .ok (some entrySlotProgram) =>
            fn.confidential_program == entry.confidential_program &&
              fn.confidential_slot_program == entry.confidential_slot_program &&
              importedConfidentialKernelProgramEq fnProgram entryProgram &&
              importedConfidentialKernelProgramSchedulesEq fnProgram entryProgram &&
              checkImportedConfidentialKernelProgramSlotLowering entryProgram entrySlotProgram &&
              checkImportedConfidentialKernelProgramSlotLowering fnProgram fnSlotProgram
        | _, _, _, _ => false) = true := by
    simpa [functionConfidentialLoweringMatchesManifest, hConf] using hMatch
  rcases
      functionStoredDslMatchesBody_confidential_exact hSplit.1.1 hConf with
    ⟨expectedProgram, fnProgram, fnSlotProgram, hExpected, hFnProgram, hFnSlotProgram,
      hFnProgramExpected, hFnExpectedSchedule, hFnSlotLowering⟩
  rcases
      manifestStoredDslMatchesKernelSchedule_confidential_exact hSplit.1.2 hConf with
    ⟨entryProgram, entrySlotProgram, expectedHashPartBytes, hEntryProgram, hEntrySlotProgram,
      hHash, hEntryEntrypoint, hEntrySlotEntrypoint, hEntrySecrets, hEntrySlotSecrets,
      hEntryHash, hEntrySteps, hEntrySlotSteps, hEntrySlotLowering⟩
  have hCrossFacts :
    ((((fn.confidential_program = entry.confidential_program ∧
        fn.confidential_slot_program = entry.confidential_slot_program) ∧
        importedConfidentialKernelProgramEq fnProgram entryProgram = true) ∧
        importedConfidentialKernelProgramSchedulesEq fnProgram entryProgram = true) ∧
        checkImportedConfidentialKernelProgramSlotLowering entryProgram entrySlotProgram = true) ∧
      checkImportedConfidentialKernelProgramSlotLowering fnProgram fnSlotProgram = true := by
    simpa [hFnProgram, hFnSlotProgram, hEntryProgram, hEntrySlotProgram] using hSplit.2
  rcases hCrossFacts with ⟨hPrefix2, hFnSlotLowering'⟩
  rcases hPrefix2 with ⟨hPrefix1, hEntrySlotLowering⟩
  rcases hPrefix1 with ⟨hPrefix0, hFnEntryScheduleBool⟩
  rcases hPrefix0 with ⟨hJsonPair, hProgramEq⟩
  rcases hJsonPair with ⟨hJsonEq, hSlotJsonEq⟩
  have hFnEntrySchedule :
      fnProgram.expectedRuntimeKernelSteps = entryProgram.expectedRuntimeKernelSteps := by
    exact
      (importedConfidentialKernelProgramSchedulesEq_eq_true_iff
        fnProgram entryProgram).mp hFnEntryScheduleBool
  exact
    ⟨expectedProgram, fnProgram, fnSlotProgram, entryProgram, entrySlotProgram,
      expectedHashPartBytes, hExpected, hFnProgram, hFnSlotProgram, hEntryProgram,
      hEntrySlotProgram, hFnProgramExpected, hFnExpectedSchedule, hProgramEq,
      hFnEntrySchedule, hFnSlotLowering', hEntrySlotLowering, hJsonEq, hSlotJsonEq, hHash, hEntryEntrypoint,
      hEntrySlotEntrypoint, hEntrySecrets, hEntrySlotSecrets, hEntryHash, hEntrySteps,
      hEntrySlotSteps⟩

theorem functionConfidentialLoweringMatchesManifest_nonconfidential_exact
  {view : ImportedProofRelevantContractView}
  {fn : ImportedProofRelevantFunctionView}
  {entry : ImportedProofRelevantEntrypointView}
  (hMatch : functionConfidentialLoweringMatchesManifest view fn entry = true)
  (hConf : fn.confidential = false) :
  entry.kernel_steps = [] ∧
    entry.confidential_program = none ∧
    entry.confidential_slot_program = none ∧
    entry.max_hash_part_bytes = 0 ∧
    fn.confidential_program = none ∧
    fn.confidential_slot_program = none := by
  have hFacts := hMatch
  simp [functionConfidentialLoweringMatchesManifest, hConf] at hFacts
  rcases hFacts with ⟨hPrefix4, hFnSlot⟩
  rcases hPrefix4 with ⟨hPrefix3, hFnProgram⟩
  rcases hPrefix3 with ⟨hPrefix2, hHash⟩
  rcases hPrefix2 with ⟨hPrefix1, hEntrySlot⟩
  rcases hPrefix1 with ⟨hKernelSteps, hEntryProgram⟩
  exact ⟨hKernelSteps, hEntryProgram, hEntrySlot, hHash, hFnProgram, hFnSlot⟩

end UOToolchain
