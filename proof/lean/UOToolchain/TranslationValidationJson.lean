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
  return_type : Option String
  body : List String
  secret_args : List Nat
  confidential : Bool
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
  public_gas_budget : Nat
  arena_bytes : Nat
  max_stack_words : Nat
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

structure ImportedProofRelevantTranslationBundle where
  source_path : String
  metadata_contract : String
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

private def lookupEntrypoint
  (signature : String) :
  List ImportedProofRelevantEntrypointView → Option ImportedProofRelevantEntrypointView
  | [] => none
  | entry :: rest =>
      if entry.signature == signature then
        some entry
      else
        lookupEntrypoint signature rest

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
            functionsMatchManifestSecrets rest entrypoints

private structure CountSummary where
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

private def asUintLiteral? (json : Json) : Option Nat :=
  match taggedPayload? json "Uint" with
  | some payload =>
      match fromJson? payload with
      | .ok value => some value
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

private def stateObjectById?
  (state : List ImportedProofRelevantStateObjectView)
  (objectId : Nat) : Option ImportedProofRelevantStateObjectView :=
  state.find? (fun object => object.id == objectId)

private def manifestObjectById?
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
  pure
    { signature := signature
    , secret_args := ← lookupFieldAs json "secret_args"
    , param_names := ← lookupFieldAs json "param_names"
    , public_gas_budget := ← lookupFieldAs json "public_gas_budget"
    , arena_bytes := ← lookupFieldAs json "arena_bytes"
    , max_stack_words := ← lookupFieldAs json "max_stack_words"
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
    , return_type := returnType?.map Json.compress
    , body := bodyJsons.map Json.compress
    , secret_args := ← lookupFieldAs json "secret_args"
    , confidential := ← lookupFieldAs json "confidential"
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

private def checkedAddU128? (lhs rhs : Nat) : Option Nat :=
  let sum := lhs + rhs
  if sum < 2^128 then
    some sum
  else
    none

private def checkedSubU128? (lhs rhs : Nat) : Option Nat :=
  if rhs ≤ lhs then
    some (lhs - rhs)
  else
    none

private def checkedMulU128? (lhs rhs : Nat) : Option Nat :=
  let product := lhs * rhs
  if product < 2^128 then
    some product
  else
    none

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
                          | some value => checkedSubU128? 0 value
                          | none => none
                      | .ok "Not" =>
                          match evalLoopBoundJson innerExpr loopEnv with
                          | some value => some (if value == 0 then 1 else 0)
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
                                  | some lhs, some rhs => checkedAddU128? lhs rhs
                                  | _, _ => none
                              | .ok "Sub" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => checkedSubU128? lhs rhs
                                  | _, _ => none
                              | .ok "Mul" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => checkedMulU128? lhs rhs
                                  | _, _ => none
                              | .ok "Div" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => if rhs == 0 then none else some (lhs / rhs)
                                  | _, _ => none
                              | .ok "Mod" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => if rhs == 0 then none else some (lhs % rhs)
                                  | _, _ => none
                              | .ok "BitAnd" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (Nat.land lhs rhs)
                                  | _, _ => none
                              | .ok "BitOr" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (Nat.lor lhs rhs)
                                  | _, _ => none
                              | .ok "BitXor" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (Nat.xor lhs rhs)
                                  | _, _ => none
                              | .ok "Eq" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if lhs == rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "Neq" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if lhs != rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "Lt" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if lhs < rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "Lte" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if lhs ≤ rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "Gt" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if lhs > rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "Gte" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs => some (if lhs ≥ rhs then 1 else 0)
                                  | _, _ => none
                              | .ok "And" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs =>
                                      some (if lhs != 0 && rhs != 0 then 1 else 0)
                                  | _, _ => none
                              | .ok "Or" =>
                                  match evalLoopBoundJson lhsExpr loopEnv, evalLoopBoundJson rhsExpr loopEnv with
                                  | some lhs, some rhs =>
                                      some (if lhs != 0 || rhs != 0 then 1 else 0)
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
                                      if cond != 0 then
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

private def countBodyStrings (body : List String) : Except String CountSummary :=
  body.foldlM (init := ({ } : CountSummary)) fun acc item => do
    pure <| acc.add (← countStatementJson (← parseJsonString item))

private def translationPathOramScheme : String := "path_oram_local_posmap_v1"

private def translationSurrogateOramScheme : String := "surrogate_public_schedule_v1"

private def translationOramBucketHeaderBytes : Nat := 24

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

private def countOramAccessesInBodyStrings
  (body : List String)
  (state : List ImportedProofRelevantStateObjectView) :
  Except String (List (Nat × Nat)) :=
  body.foldlM (init := ([] : List (Nat × Nat))) fun acc item => do
    pure <| mergePairCounts acc
      (← collectOramStatementAccesses (← parseJsonString item) state)

private def oramAccessesMatchExpected
  (expected : List (Nat × Nat))
  (actual : List ImportedProofRelevantOramAccessView) : Bool :=
  distinctList (pairCountObjectIds expected) &&
    distinctList (entryOramAccessObjectIds actual) &&
    listedEquivalent (pairCountObjectIds expected) (entryOramAccessObjectIds actual) &&
    expected.all (fun entry => lookupOramAccessCount entry.fst actual == entry.snd) &&
    actual.all (fun entry => lookupPairCount entry.object_id expected == entry.accesses)

private def validateImportedOramShape
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
        else if oram.scheme == translationPathOramScheme then
          let leafCount := (oram.bucket_count + 1) / 2
          oram.bucket_count > 0 &&
            oram.bucket_count % 2 == 1 &&
            isPowerOfTwo leafCount &&
            oram.blocks_per_bucket == 5 &&
            oram.bucket_size ==
              translationOramBucketHeaderBytes + oram.blocks_per_bucket * oram.block_size &&
            oram.stash_bound == max (stateObject.capacity.getD 1) 1 &&
            oram.recursion_depth == 0 &&
            oram.tree_height == log2Ceil leafCount &&
            oram.bucket_count == 2 * leafCount - 1 &&
            oram.metadata_pages_per_access == oram.metadata_pages + 1 &&
            oram.buckets_per_access == oram.tree_height + 1 &&
            oram.accesses_per_call == 1
        else
          false)

private def expectedCommitOpsForFunction
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
                  if stateObject.oram_scheme == translationPathOramScheme then
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

private def importedProofRelevantKernelStepViewOfImportedRuntimeKernelStep
  (step : ImportedRuntimeKernelStep) : ImportedProofRelevantKernelStepView :=
  { opcode := step.opcode, object_id := step.object_id }

private def importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
  (steps : List ImportedRuntimeKernelStep) : List ImportedProofRelevantKernelStepView :=
  steps.map importedProofRelevantKernelStepViewOfImportedRuntimeKernelStep

private def parseEntrypointConfidentialProgram
  (entry : ImportedProofRelevantEntrypointView) :
  Except String (Option ImportedConfidentialKernelProgram) := do
  match entry.confidential_program with
  | none => pure none
  | some json => some <$> fromJson? (← parseJsonString json)

private def parseEntrypointConfidentialSlotProgram
  (entry : ImportedProofRelevantEntrypointView) :
  Except String (Option ImportedConfidentialKernelSlotProgram) := do
  match entry.confidential_slot_program with
  | none => pure none
  | some json => some <$> fromJson? (← parseJsonString json)

private def manifestStoredDslMatchesKernelSchedule
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  match parseEntrypointConfidentialProgram entry, parseEntrypointConfidentialSlotProgram entry with
  | .ok none, .ok none =>
      (!fn.confidential) && entry.kernel_steps.isEmpty
  | .ok (some program), .ok (some slotProgram) =>
      fn.confidential &&
        program.entrypoint_id == fn.signature &&
        slotProgram.entrypoint_id == fn.signature &&
        program.secret_args == fn.secret_args &&
        slotProgram.secret_args == fn.secret_args &&
        importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
            program.expectedRuntimeKernelSteps ==
          entry.kernel_steps &&
        importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
            slotProgram.expectedRuntimeKernelSteps ==
          entry.kernel_steps &&
        checkImportedConfidentialKernelProgramSlotLowering program slotProgram
  | _, _ => false

private def functionConfidentialLoweringMatchesManifest
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : Bool :=
  if fn.confidential then
    match expectedKernelStepsForConfidentialBodyStrings fn.body with
    | .ok expectedSteps =>
        entry.kernel_steps == expectedSteps &&
          manifestStoredDslMatchesKernelSchedule fn entry
    | .error _ => false
  else
    entry.kernel_steps.isEmpty &&
      entry.confidential_program.isNone &&
      entry.confidential_slot_program.isNone

private def functionConfidentialLoweringMismatchMessage
  (fn : ImportedProofRelevantFunctionView)
  (entry : ImportedProofRelevantEntrypointView) : String :=
  if fn.confidential then
    match expectedKernelStepsForConfidentialBodyStrings fn.body with
    | .ok expectedSteps =>
        if entry.kernel_steps != expectedSteps then
          s!"{fn.signature}: expected kernel_steps {renderKernelSteps expectedSteps}, manifest has {renderKernelSteps entry.kernel_steps}"
        else if !(manifestStoredDslMatchesKernelSchedule fn entry) then
          match parseEntrypointConfidentialProgram entry, parseEntrypointConfidentialSlotProgram entry with
          | .error err, _
          | _, .error err =>
              s!"{fn.signature}: failed to parse stored confidential DSL from manifest: {err}"
          | .ok none, _ =>
              s!"{fn.signature}: manifest is missing confidential_program"
          | _, .ok none =>
              s!"{fn.signature}: manifest is missing confidential_slot_program"
          | .ok (some program), .ok (some slotProgram) =>
              let programSteps :=
                renderKernelSteps <|
                  importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
                    program.expectedRuntimeKernelSteps
              let slotSteps :=
                renderKernelSteps <|
                  importedProofRelevantKernelStepViewsOfImportedRuntimeKernelSteps
                    slotProgram.expectedRuntimeKernelSteps
              s!"{fn.signature}: stored confidential DSL does not align with manifest schedule or slot lowering (program steps {programSteps}, slot steps {slotSteps}, manifest steps {renderKernelSteps entry.kernel_steps})"
        else
          s!"{fn.signature}: confidential lowering mismatch despite matching kernel_steps and stored DSL"
    | .error err =>
        s!"{fn.signature}: confidential lowering rejected body: {err}"
  else
    s!"{fn.signature}: non-confidential entrypoint should not carry kernel metadata or stored confidential DSL"

private def functionsMatchConfidentialLowering :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → Bool
  | [], _ => true
  | fn :: rest, entrypoints =>
      match lookupEntrypoint fn.signature entrypoints with
      | none => false
      | some entry =>
          functionConfidentialLoweringMatchesManifest fn entry &&
            functionsMatchConfidentialLowering rest entrypoints

private def confidentialLoweringMismatchMessages :
  List ImportedProofRelevantFunctionView →
  List ImportedProofRelevantEntrypointView → List String
  | [], _ => []
  | fn :: rest, entrypoints =>
      let tail := confidentialLoweringMismatchMessages rest entrypoints
      match lookupEntrypoint fn.signature entrypoints with
      | none => s!"{fn.signature}: missing manifest entrypoint" :: tail
      | some entry =>
          if functionConfidentialLoweringMatchesManifest fn entry then
            tail
          else
            functionConfidentialLoweringMismatchMessage fn entry :: tail

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
    distinctList view.functionSignatures &&
    distinctList view.manifestEntrypointSignatures &&
    (view.functions.length == view.manifest.entrypoints.length) &&
    functionsMatchConfidentialLowering view.functions view.manifest.entrypoints &&
    functionsMatchManifestSecrets view.functions view.manifest.entrypoints &&
    functionsMatchManifestCounts view.functions view.manifest.entrypoints &&
    functionsMatchManifestOramAccesses view view.functions view.manifest.entrypoints &&
    functionsMatchManifestCommitOps view view.functions view.manifest.entrypoints

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
    (if !(functionsMatchConfidentialLowering view.functions view.manifest.entrypoints) then
      ["confidential lowering / kernel metadata checks failed for: " ++
        String.intercalate ", "
          (confidentialLoweringMismatchMessages view.functions view.manifest.entrypoints)]
    else
      []) ++
    (if !(functionsMatchManifestSecrets view.functions view.manifest.entrypoints) then
      ["manifest secret_args/param_names do not match function metadata"]
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

def ImportedProofRelevantTranslationBundle.Valid
  (bundle : ImportedProofRelevantTranslationBundle) : Prop :=
  bundle.sourceViewMatchesRawProjection = true ∧
    bundle.artifactViewMatchesRawProjection = true ∧
    bundle.source_view = bundle.artifact_view ∧
    bundle.source_view.checkStructuralValid = true ∧
    bundle.artifact_view.checkStructuralValid = true ∧
    bundle.metadata_contract = bundle.source_view.contract ∧
    bundle.metadata_contract = bundle.artifact_view.contract

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
    (bundle.metadata_contract == bundle.artifact_view.contract)

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

end UOToolchain
