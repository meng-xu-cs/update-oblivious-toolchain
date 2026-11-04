import Lean.Data.Json
import UOToolchain.KernelPaperMain

namespace UOToolchain.IR

/-!
# Admission of compiled kernel programs

`paperMain_admittedKernelRun_exact_noninterference_moduloReleases` asks four
things of an entrypoint's program, its state layout, and its declared policies:
the program is well typed over the layout, returns only as its last statement,
writes only confidential objects, and its declared status and return policies
agree with the information-flow analysis. `KernelProgram.admissionCheck` decides
all four with the same definitions the theorem quantifies over, so a passing
check discharges them (`KernelProgram.admissionCheck_sound`), and every run over
the layout that the runtime sets up is an admitted run
(`AdmittedKernelRun.ofCheck`).

The second half of the module decodes `uo-solc` artifacts (the contract's state
layout and each manifest entrypoint's confidential program and policies) into
these definitions and reports the check per entrypoint; `checkKernelAdmission`
runs it over an artifact.
-/

/-! ## The check -/

/-- Decides `PolicyAgreesWithFlow`. -/
def policyAgreesWithFlowB (kp : KernelProgram) (policy : EntrypointPublicPolicy) : Bool :=
  (policy.statusPolicy == "declassified" || !kp.flowSummary.statusSecret) &&
    (policy.returnPolicy == "declassified" || !kp.flowSummary.returnSecret) &&
    policy.returnPolicy != "encrypted_to_client"

theorem policyAgreesWithFlow_of_check {kp : KernelProgram} {policy : EntrypointPublicPolicy}
    (h : policyAgreesWithFlowB kp policy = true) : PolicyAgreesWithFlow kp policy := by
  simp only [policyAgreesWithFlowB, Bool.and_eq_true, Bool.or_eq_true, beq_iff_eq,
    Bool.not_eq_true', bne_iff_ne, ne_eq] at h
  obtain ⟨⟨hStatus, hReturn⟩, hEncrypted⟩ := h
  exact
    { statusPublic := fun hNot => hStatus.resolve_left hNot
      returnPublic := fun hNot => hReturn.resolve_left hNot
      notEncrypted := hEncrypted }

/-- The program-side premises of the paper-main theorem for admitted kernel
programs. -/
def KernelProgram.admissionCheck (kp : KernelProgram) (state : List StateObject)
    (policy : EntrypointPublicPolicy) : Bool :=
  kp.wellTyped state && KernelStatement.returnsOnlyLast kp.body &&
    kp.writesOnlyConfidential state && policyAgreesWithFlowB kp policy

/-- The facts a passing admission check establishes. -/
structure KernelAdmission (kp : KernelProgram) (state : List StateObject)
    (policy : EntrypointPublicPolicy) : Prop where
  wellTyped : kp.wellTyped state = true
  returnsLast : KernelStatement.returnsOnlyLast kp.body = true
  writesConfidential : kp.writesOnlyConfidential state = true
  policyAgrees : PolicyAgreesWithFlow kp policy

theorem KernelProgram.admissionCheck_sound {kp : KernelProgram} {state : List StateObject}
    {policy : EntrypointPublicPolicy} (h : kp.admissionCheck state policy = true) :
    KernelAdmission kp state policy := by
  simp only [KernelProgram.admissionCheck, Bool.and_eq_true] at h
  obtain ⟨⟨⟨hTy, hRet⟩, hWrites⟩, hPolicy⟩ := h
  exact ⟨hTy, hRet, hWrites, policyAgreesWithFlow_of_check hPolicy⟩

/-- A run of an admitted program over its layout is an admitted run once the
runtime supplies arguments of the parameter types, a conforming store, the
declared argument layout, and a public store that holds only public objects. -/
def AdmittedKernelRun.ofAdmission {kp : KernelProgram} {state : List StateObject}
    {policy : EntrypointPublicPolicy} (hAdmitted : KernelAdmission kp state policy)
    (cfg : OperationalConfig) (hState : cfg.contract.state = state)
    (hArgs : ArgsConform kp.params cfg.declaredArgs) (hStore : StoreConforms cfg)
    (hLayout : KernelArgumentLayout kp cfg) (hOwned : cfg.publicStoreAgreesWithObjectMap) :
    AdmittedKernelRun kp :=
  { cfg := cfg
    wellTyped := by rw [hState]; exact hAdmitted.wellTyped
    returnsLast := hAdmitted.returnsLast
    args := hArgs
    store := hStore
    layout := hLayout
    publicStoreOwned := hOwned
    writesConfidential := by rw [hState]; exact hAdmitted.writesConfidential }

end UOToolchain.IR

namespace UOToolchain

/-- The paper-main theorem modulo declared releases for an entrypoint whose
program passes the admission check: any two runs over the checked layout that
the runtime sets up (conforming arguments and store, the declared argument
layout, a public store of public objects) and that agree on contract,
entrypoint, public arguments, public environment, and public store have the
same `View_SGX ∖ rel`. -/
theorem paperMain_checkedKernel_exact_noninterference_moduloReleases
    {kp : IR.KernelProgram} {state : List IR.StateObject} {policy : IR.EntrypointPublicPolicy}
    (hCheck : kp.admissionCheck state policy = true)
    (encodeRun : List IR.KernelStatement → Trace)
    (render : IR.Value → String) (renderEnv : String × IR.Value → String)
    (digest : IR.ObjectStore → String) (deltaDigest : List Nat → String)
    (controllerShape : SGXControllerShape) (releaseFunctions : PaperMainDeclaredReleaseFunctions)
    {a₁ a₂ : IR.AdmittedKernelRun kp} (hPublic : a₁.samePublic a₂) :
    (paperMainViewOfRun
        (fun a : IR.AdmittedKernelRun kp => IR.kernelExactTrace encodeRun policy.gas kp a.cfg)
        (fun a => IR.kernelPublicOutcome policy render renderEnv kp a.cfg)
        (fun a => IR.kernelBoundarySchedule policy
          (IR.kernelPublicOutcome policy render renderEnv kp a.cfg))
        (fun _ => controllerShape)
        (fun a => IR.kernelFinalPublicState digest deltaDigest kp a.cfg)
        (fun _ => releaseFunctions)
        a₁).withoutReleases =
      (paperMainViewOfRun
        (fun a : IR.AdmittedKernelRun kp => IR.kernelExactTrace encodeRun policy.gas kp a.cfg)
        (fun a => IR.kernelPublicOutcome policy render renderEnv kp a.cfg)
        (fun a => IR.kernelBoundarySchedule policy
          (IR.kernelPublicOutcome policy render renderEnv kp a.cfg))
        (fun _ => controllerShape)
        (fun a => IR.kernelFinalPublicState digest deltaDigest kp a.cfg)
        (fun _ => releaseFunctions)
        a₂).withoutReleases :=
  paperMain_admittedKernelRun_exact_noninterference_moduloReleases kp policy
    (IR.KernelProgram.admissionCheck_sound hCheck).policyAgrees encodeRun render renderEnv
    digest deltaDigest controllerShape releaseFunctions hPublic

end UOToolchain

namespace UOToolchain.IR.ArtifactJson

/-! ## Decoding `uo-solc` artifacts

The decoders follow `serde`'s encoding of the `uo-core` types: enums are
externally tagged (`{"Scalar": {"Uint": 256}}`, `"Bytes32"`), kernel statements
and expressions are internally tagged by `kind`, and `uint256` values are
decimal strings. -/

abbrev Decode := Except String

def field (json : Lean.Json) (name : String) : Decode Lean.Json :=
  match json.getObjVal? name with
  | .ok value => pure value
  | .error _ => throw s!"missing field `{name}` in {json.compress}"

/-- An optional field: absent and `null` both decode to `none`. -/
def optField (json : Lean.Json) (name : String) : Option Lean.Json :=
  match json.getObjVal? name with
  | .ok .null => none
  | .ok value => some value
  | .error _ => none

def natField (json : Lean.Json) (name : String) : Decode Nat := do
  match (← field json name).getNat? with
  | .ok value => pure value
  | .error _ => throw s!"field `{name}` is not a natural number in {json.compress}"

def strField (json : Lean.Json) (name : String) : Decode String := do
  match (← field json name).getStr? with
  | .ok value => pure value
  | .error _ => throw s!"field `{name}` is not a string in {json.compress}"

def arrField (json : Lean.Json) (name : String) : Decode (List Lean.Json) := do
  match (← field json name).getArr? with
  | .ok value => pure value.toList
  | .error _ => throw s!"field `{name}` is not an array in {json.compress}"

/-- The single `tag` of an externally tagged enum value. -/
def variant (json : Lean.Json) : Decode (String × Lean.Json) :=
  match json with
  | .str tag => pure (tag, .null)
  | .obj fields =>
      match fields.toList with
      | [(tag, payload)] => pure (tag, payload)
      | _ => throw s!"expected one enum variant in {json.compress}"
  | _ => throw s!"expected an enum value, found {json.compress}"

def scalarType (json : Lean.Json) : Decode ScalarType := do
  match ← variant json with
  | ("Bool", _) => pure .bool
  | ("Bytes32", _) => pure .bytes32
  | ("Address", _) => pure .address
  | ("Uint", width) =>
      match width.getNat? with
      | .ok width => pure (.uint width)
      | .error _ => throw s!"bad uint width {width.compress}"
  | (tag, _) => throw s!"unknown scalar type {tag}"

partial def ty (json : Lean.Json) : Decode Ty := do
  match ← variant json with
  | ("Scalar", scalar) => return .scalar (← scalarType scalar)
  | ("Struct", fields) =>
      match fields.getArr? with
      | .ok fields =>
          return .structTy (← fields.toList.mapM fun entry => do
            return (← strField entry "name", ← ty (← field entry "ty")))
      | .error _ => throw s!"bad struct type {json.compress}"
  | ("Array", payload) =>
      match payload.getArr? with
      | .ok #[elem, size] =>
          match size.getNat? with
          | .ok size => return .array (← ty elem) size
          | .error _ => throw s!"bad array size {size.compress}"
      | _ => throw s!"bad array type {json.compress}"
  | (tag, _) => throw s!"unknown type {tag}"

def bytes (json : Lean.Json) (len : Nat) : Decode (List UInt8) := do
  match json.getArr? with
  | .ok entries =>
      if entries.size != len then
        throw s!"expected {len} bytes, found {entries.size}"
      entries.toList.mapM fun entry =>
        match entry.getNat? with
        | .ok byte => if byte < 256 then pure byte.toUInt8 else throw s!"bad byte {byte}"
        | .error _ => throw s!"bad byte {entry.compress}"
  | .error _ => throw s!"expected a byte array, found {json.compress}"

partial def value (json : Lean.Json) : Decode Value := do
  match ← variant json with
  | ("Bool", payload) =>
      match payload.getBool? with
      | .ok b => return .bool b
      | .error _ => throw s!"bad bool {payload.compress}"
  | ("Uint", payload) =>
      match payload with
      | .str digits =>
          match digits.toNat? with
          | some n => return .uint n
          | none => throw s!"bad uint256 literal {digits}"
      | _ =>
          match payload.getNat? with
          | .ok n => return .uint n
          | .error _ => throw s!"bad uint256 literal {payload.compress}"
  | ("Bytes32", payload) => return .bytes32 (← bytes payload 32)
  | ("Address", payload) => return .address (← bytes payload 20)
  | ("Struct", payload) =>
      match payload.getArr? with
      | .ok entries =>
          return .structValue (← entries.toList.mapM fun entry =>
            match entry.getArr? with
            | .ok #[name, fieldValue] =>
                match name.getStr? with
                | .ok name => return (name, ← value fieldValue)
                | .error _ => throw s!"bad struct field name {name.compress}"
            | _ => throw s!"bad struct field {entry.compress}")
      | .error _ => throw s!"bad struct value {payload.compress}"
  | ("Array", payload) =>
      match payload.getArr? with
      | .ok entries => return .array (← entries.toList.mapM value)
      | .error _ => throw s!"bad array value {payload.compress}"
  | (tag, _) => throw s!"unknown value {tag}"

def unaryOp (json : Lean.Json) : Decode UnaryOp := do
  match ← variant json with
  | ("Not", _) => pure .not
  | ("Neg", _) => pure .neg
  | (tag, _) => throw s!"unknown unary operator {tag}"

def binaryOp (json : Lean.Json) : Decode BinaryOp := do
  match ← variant json with
  | ("Add", _) => pure .add
  | ("Sub", _) => pure .sub
  | ("Mul", _) => pure .mul
  | ("Div", _) => pure .div
  | ("Mod", _) => pure .mod
  | ("BitAnd", _) => pure .bitAnd
  | ("BitOr", _) => pure .bitOr
  | ("BitXor", _) => pure .bitXor
  | ("Eq", _) => pure .eq
  | ("Neq", _) => pure .neq
  | ("Lt", _) => pure .lt
  | ("Lte", _) => pure .lte
  | ("Gt", _) => pure .gt
  | ("Gte", _) => pure .gte
  | ("And", _) => pure .logicAnd
  | ("Or", _) => pure .logicOr
  | (tag, _) => throw s!"unknown binary operator {tag}"

partial def pureExpr (json : Lean.Json) : Decode KernelPureExpr := do
  match ← strField json "kind" with
  | "literal" => return .literal (← value (← field json "value"))
  | "var" => return .var (← strField json "name")
  | "unary" => return .unary (← unaryOp (← field json "op")) (← pureExpr (← field json "expr"))
  | "binary" =>
      return .binary (← binaryOp (← field json "op")) (← pureExpr (← field json "lhs"))
        (← pureExpr (← field json "rhs"))
  | "select" =>
      return .select (← pureExpr (← field json "cond")) (← pureExpr (← field json "when_true"))
        (← pureExpr (← field json "when_false"))
  | "struct_field" => return .structField (← pureExpr (← field json "base")) (← strField json "field")
  | "array_index" =>
      return .arrayIndex (← pureExpr (← field json "base")) (← pureExpr (← field json "index"))
  | "keccak256" => return .keccak256 (← (← arrField json "parts").mapM pureExpr)
  | kind => throw s!"unknown pure expression kind {kind}"

partial def expr (json : Lean.Json) : Decode KernelExpr := do
  match ← strField json "kind" with
  | "literal" => return .literal (← value (← field json "value"))
  | "var" => return .var (← strField json "name")
  | "unary" => return .unary (← unaryOp (← field json "op")) (← expr (← field json "expr"))
  | "binary" =>
      return .binary (← binaryOp (← field json "op")) (← expr (← field json "lhs"))
        (← expr (← field json "rhs"))
  | "select" =>
      return .select (← expr (← field json "cond")) (← pureExpr (← field json "when_true"))
        (← pureExpr (← field json "when_false"))
  | "cell_get" => return .cellGet (← natField json "object_id")
  | "array_get" => return .arrayGet (← natField json "object_id") (← expr (← field json "index"))
  | "map_get" => return .mapGet (← natField json "object_id") (← expr (← field json "key"))
  | "struct_field" => return .structField (← expr (← field json "base")) (← strField json "field")
  | "array_index" => return .arrayIndex (← expr (← field json "base")) (← expr (← field json "index"))
  | "keccak256" => return .keccak256 (← (← arrField json "parts").mapM expr)
  | kind => throw s!"unknown expression kind {kind}"

def optExpr (json : Lean.Json) (name : String) : Decode (Option KernelExpr) :=
  match optField json name with
  | some value => some <$> expr value
  | none => pure none

def statement (json : Lean.Json) : Decode KernelStatement := do
  match ← strField json "kind" with
  | "declare" =>
      return .declare (← strField json "name") (← ty (← field json "ty")) (← expr (← field json "value"))
  | "assign" => return .assign (← strField json "name") (← expr (← field json "value"))
  | "require" => return .require (← expr (← field json "cond"))
  | "abort_if" => return .abortIf (← expr (← field json "cond"))
  | "cell_set" =>
      return .cellSet (← natField json "object_id") (← expr (← field json "value"))
        (← optExpr json "predicate")
  | "array_set" =>
      return .arraySet (← natField json "object_id") (← expr (← field json "index"))
        (← expr (← field json "value")) (← optExpr json "predicate")
  | "map_put" =>
      return .mapPut (← natField json "object_id") (← expr (← field json "key"))
        (← expr (← field json "value")) (← optExpr json "predicate")
  | "return" => return .retStmt (← optExpr json "value")
  | kind => throw s!"unknown statement kind {kind}"

def program (json : Lean.Json) : Decode KernelProgram := do
  let params ← (← arrField json "params").mapM fun param => do
    return ({ name := ← strField param "name", ty := ← ty (← field param "ty") } : Param)
  let returnType ← match optField json "return_type" with
    | some returnType => some <$> ty returnType
    | none => pure none
  let secretArgs ← (← arrField json "secret_args").mapM fun index =>
    match index.getNat? with
    | .ok index => pure index
    | .error _ => throw s!"bad secret argument index {index.compress}"
  return { entrypointId := ← strField json "entrypoint_id"
           params := params
           returnType := returnType
           secretArgs := secretArgs
           body := ← (← arrField json "body").mapM statement }

def containerKind (json : Lean.Json) : Decode ContainerKind := do
  match ← variant json with
  | ("Cell", _) => pure .cell
  | ("Array", _) => pure .arrayKind
  | ("Map", _) => pure .mapKind
  | (tag, _) => throw s!"unknown container kind {tag}"

def backendKind (json : Lean.Json) : Decode BackendKind := do
  match ← variant json with
  | ("Raw", _) => pure .raw
  | ("FullScan", _) => pure .fullScan
  | ("Oram", _) => pure .oram
  | (tag, _) => throw s!"unknown backend {tag}"

def stateObject (json : Lean.Json) : Decode StateObject := do
  return { id := ← natField json "id"
           name := ← strField json "name"
           kind := ← containerKind (← field json "kind")
           backend := ← backendKind (← field json "backend")
           oramScheme := (optField json "oram_scheme").bind (·.getStr?.toOption) |>.getD
             "surrogate_public_schedule_v1"
           valueType := ← ty (← field json "value_type")
           keyType := ← match optField json "key_type" with
             | some keyType => some <$> ty keyType
             | none => pure none
           capacity := ← match optField json "capacity" with
             | some capacity =>
                 match capacity.getNat? with
                 | .ok capacity => pure (some capacity)
                 | .error _ => throw s!"bad capacity {capacity.compress}"
             | none => pure none
           confidential := (optField json "confidential").bind (·.getBool?.toOption) |>.getD
             false }

/-- An entrypoint's policies from its manifest entry. -/
def policy (entrypointId : String) (json : Lean.Json) : Decode EntrypointPublicPolicy := do
  let declassifies ← (← arrField json "declassifies").mapM fun kind =>
    match kind.getStr? with
    | .ok kind => pure kind
    | .error _ => throw s!"bad declassification {kind.compress}"
  return { entrypointId := entrypointId
           statusPolicy := ← strField json "status"
           returnPolicy := ← strField json "returns"
           declassifies := declassifies
           returnLength := (optField json "return_canonical_len").bind (·.getNat?.toOption)
             |>.getD 0
           entryInputLen := ← natField json "entry_input_len"
           gas := ← natField json "public_gas_budget" }

/-! ## The per-entrypoint report -/

/-- The trace route of an entrypoint: `exact` when every object it accesses is
on an exact backend, `path_oram` when it accesses an ORAM map, and
`unsupported` otherwise (an access to a raw object, whose trace reveals the
slot). The exact paper-main theorem covers the `exact` route; the program-side
premises the check decides do not depend on the route. -/
def traceRoute (state : List StateObject) (kp : KernelProgram) : String :=
  let backends := (kp.body.flatMap KernelStatement.accesses).map fun access =>
    (stateObjectOf? state access.objectId).map (·.backend)
  if backends.all (· == some .fullScan) then "exact"
  else if backends.all (fun backend => backend == some .fullScan || backend == some .oram)
  then "path_oram"
  else "unsupported"

structure EntrypointReport where
  entrypoint : String
  traceRoute : String
  statusPolicy : String
  returnPolicy : String
  statusSecret : Bool
  returnSecret : Bool
  wellTyped : Bool
  returnsOnlyLast : Bool
  writesOnlyConfidential : Bool
  policyAgreesWithFlow : Bool
  secretArgsMatchManifest : Bool
  programMatchesFunction : Bool
  admitted : Bool

/-- The flow analysis's label, as a string so that a public result is not a
`false` leaf of the report. -/
def flowLabel (secret : Bool) : String :=
  if secret then "secret" else "public"

def EntrypointReport.toJson (report : EntrypointReport) : Lean.Json :=
  Lean.Json.mkObj
    [ ("entrypoint", report.entrypoint)
    , ("trace_route", report.traceRoute)
    , ("status_policy", report.statusPolicy)
    , ("return_policy", report.returnPolicy)
    , ("flow_status", flowLabel report.statusSecret)
    , ("flow_return", flowLabel report.returnSecret)
    , ("well_typed", report.wellTyped)
    , ("returns_only_last", report.returnsOnlyLast)
    , ("writes_only_confidential", report.writesOnlyConfidential)
    , ("policy_agrees_with_flow", report.policyAgreesWithFlow)
    , ("secret_args_match_manifest", report.secretArgsMatchManifest)
    , ("program_matches_function", report.programMatchesFunction)
    , ("admitted", report.admitted) ]

/-- Check one manifest entrypoint: decode its program and policies, and decide
the admission premises over the contract's state layout. The manifest's program
is the one the runtime executes; it must equal the compiled function's. -/
def checkEntrypoint (state : List StateObject) (functions : List Lean.Json)
    (entrypointId : String) (entry : Lean.Json) (programJson : Lean.Json) :
    Decode EntrypointReport := do
  let kp ← program programJson
  let declared ← policy entrypointId entry
  let manifestSecretArgs ← (← arrField entry "secret_args").mapM fun index =>
    match index.getNat? with
    | .ok index => pure index
    | .error _ => throw s!"bad secret argument index {index.compress}"
  let functionProgram := functions.findSome? fun function =>
    match function.getObjValAs? String "signature" with
    | .ok signature => if signature == entrypointId then optField function "confidential_program"
        else none
    | .error _ => none
  let wellTyped := kp.wellTyped state
  let returnsOnlyLast := KernelStatement.returnsOnlyLast kp.body
  let writesOnlyConfidential := kp.writesOnlyConfidential state
  let policyAgrees := policyAgreesWithFlowB kp declared
  let secretArgsMatch := manifestSecretArgs == kp.secretArgs
  let programMatches := functionProgram == some programJson
  let route := traceRoute state kp
  return { entrypoint := entrypointId
           traceRoute := route
           statusPolicy := declared.statusPolicy
           returnPolicy := declared.returnPolicy
           statusSecret := kp.flowSummary.statusSecret
           returnSecret := kp.flowSummary.returnSecret
           wellTyped := wellTyped
           returnsOnlyLast := returnsOnlyLast
           writesOnlyConfidential := writesOnlyConfidential
           policyAgreesWithFlow := policyAgrees
           secretArgsMatchManifest := secretArgsMatch
           programMatchesFunction := programMatches
           admitted := kp.admissionCheck state declared && kp.entrypointId == entrypointId &&
             secretArgsMatch && programMatches && route != "unsupported" }

/-- Check every confidential entrypoint of an artifact. -/
def checkArtifact (artifact : Lean.Json) : Decode (String × List EntrypointReport) := do
  let contract ← field artifact "contract"
  let state ← (← arrField contract "state").mapM stateObject
  let functions ← arrField contract "functions"
  let manifest ← field contract "manifest"
  let entrypoints ← match (← field manifest "entrypoints") with
    | .obj entries => pure entries.toList
    | other => throw s!"manifest entrypoints is not an object: {other.compress}"
  let reports ← entrypoints.filterMapM fun (entrypointId, entry) =>
    match optField entry "confidential_program" with
    | some programJson => some <$> checkEntrypoint state functions entrypointId entry programJson
    | none => pure none
  return (← strField contract "contract", reports)

end UOToolchain.IR.ArtifactJson
