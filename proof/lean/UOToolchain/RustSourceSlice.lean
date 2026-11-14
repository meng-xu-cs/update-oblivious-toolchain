/-!
# The production part of a Rust source file

The source checks of the runtime implementation interface read the
production part of a Rust file: the file without the modules and functions
marked `#[cfg(test)]`. Where an item ends is found by matching braces, and a
brace, a quote or an attribute counts only where it is code: not inside a
string, byte-string, raw-string or character literal, and not inside a
comment. A `#[cfg(test)]` on anything else than a module or a function is
left in place, so that a slice never loses production text, and
`misplacedCfgTestLines` names it.

`probe/mplus-probe/src/rust_source.rs` is the same slicer in Rust, and the
implementation-interface report checks that the two slice every pinned file
alike (`checkRustSourceSlices`). This file reads characters where the Rust
slicer reads bytes; the syntax it looks for is ASCII, so the two agree.
-/

namespace UOToolchain
namespace RustSource

/-- The attribute that marks a test item. -/
def cfgTest : List Char := "#[cfg(test)]".toList

def isIdentChar (c : Char) : Bool :=
  c.isAlphanum || c == '_' || 128 ≤ c.toNat

/-- ASCII whitespace, as Rust's `u8::is_ascii_whitespace` has it. -/
def isAsciiWhitespace (c : Char) : Bool :=
  c == ' ' || c == '\t' || c == '\n' || c == '\r' || c.toNat == 12

/-- What a character of the source is. -/
def kindCode : UInt8 := 0
/-- Inside a literal, its quotes and prefix included. -/
def kindLiteral : UInt8 := 1
def kindComment : UInt8 := 2

/-- The index just past a literal that `quote` opens before `j`, escapes
skipped. An unterminated literal runs to the end. -/
def quotedEndFuel (cs : Array Char) (quote : Char) : Nat → Nat → Nat
  | 0, _ => cs.size
  | fuel + 1, j =>
    match cs[j]? with
    | none => cs.size
    | some c =>
      if c == '\\' then quotedEndFuel cs quote fuel (j + 2)
      else if c == quote then j + 1
      else quotedEndFuel cs quote fuel (j + 1)

def quotedEnd (cs : Array Char) (start : Nat) (quote : Char) : Nat :=
  quotedEndFuel cs quote cs.size (start + 1)

def countHashesFuel (cs : Array Char) : Nat → Nat → Nat → Nat
  | 0, _, n => n
  | fuel + 1, j, n => if cs[j]? == some '#' then countHashesFuel cs fuel (j + 1) (n + 1) else n

def rawCloseFuel (cs : Array Char) (hashes : Nat) : Nat → Nat → Nat
  | 0, _ => cs.size
  | fuel + 1, j =>
    match cs[j]? with
    | none => cs.size
    | some c =>
      if c == '"' && (List.range hashes).all (fun h => cs[j + 1 + h]? == some '#') then
        j + 1 + hashes
      else
        rawCloseFuel cs hashes fuel (j + 1)

/-- The index just past a raw string literal (`r"…"`, `r#"…"#`, `br"…"`,
`cr"…"`) that starts at `i`, if one does. -/
def rawStringEnd? (cs : Array Char) (i : Nat) : Option Nat :=
  let k := if cs[i]? == some 'b' || cs[i]? == some 'c' then i + 1 else i
  if cs[k]? != some 'r' then
    none
  else
    let hashes := countHashesFuel cs cs.size (k + 1) 0
    if cs[k + 1 + hashes]? != some '"' then
      none
    else
      some (rawCloseFuel cs hashes cs.size (k + 2 + hashes))

def escapeCloseFuel (cs : Array Char) (limit : Nat) : Nat → Nat → Option Nat
  | 0, _ => none
  | fuel + 1, j =>
    if limit < j then
      none
    else
      match cs[j]? with
      | none => none
      | some c => if c == '\'' then some (j + 1) else escapeCloseFuel cs limit fuel (j + 1)

/-- The index just past a character literal that opens at `i`, if the quote
there opens one and not a lifetime or a label. -/
def charLiteralEnd? (cs : Array Char) (i : Nat) : Option Nat :=
  match cs[i + 1]? with
  | none => none
  | some first =>
    if first == '\\' then
      -- An escape: the escaped character, then up to the closing quote.
      escapeCloseFuel cs (i + 12) 10 (i + 3)
    else if first != '\'' && cs[i + 2]? == some '\'' then
      some (i + 3)
    else
      none

def lineEndFuel (cs : Array Char) : Nat → Nat → Nat
  | 0, _ => cs.size
  | fuel + 1, j =>
    match cs[j]? with
    | none => cs.size
    | some c => if c == '\n' then j else lineEndFuel cs fuel (j + 1)

/-- The index just past a block comment, whose opening ends before `j`.
Block comments nest. -/
def blockCommentEndFuel (cs : Array Char) : Nat → Nat → Nat → Nat
  | 0, _, _ => cs.size
  | fuel + 1, j, depth =>
    if depth == 0 then
      j
    else
      match cs[j]? with
      | none => cs.size
      | some c =>
        if c == '/' && cs[j + 1]? == some '*' then blockCommentEndFuel cs fuel (j + 2) (depth + 1)
        else if c == '*' && cs[j + 1]? == some '/' then blockCommentEndFuel cs fuel (j + 2) (depth - 1)
        else blockCommentEndFuel cs fuel (j + 1) depth

def markFuel (kind : UInt8) : Nat → Nat → Array UInt8 → Array UInt8
  | 0, _, kinds => kinds
  | fuel + 1, j, kinds => markFuel kind fuel (j + 1) (kinds.set! j kind)

def mark (kinds : Array UInt8) (start stop : Nat) (kind : UInt8) : Array UInt8 :=
  markFuel kind (stop - start) start kinds

def charKindsFuel (cs : Array Char) : Nat → Nat → Array UInt8 → Array UInt8
  | 0, _, kinds => kinds
  | fuel + 1, i, kinds =>
    match cs[i]? with
    | none => kinds
    | some c =>
      let startsToken := i == 0 || !isIdentChar (cs[i - 1]?.getD ' ')
      if c == '/' && cs[i + 1]? == some '/' then
        let stop := lineEndFuel cs cs.size i
        charKindsFuel cs fuel stop (mark kinds i stop kindComment)
      else if c == '/' && cs[i + 1]? == some '*' then
        let stop := blockCommentEndFuel cs cs.size (i + 2) 1
        charKindsFuel cs fuel stop (mark kinds i stop kindComment)
      else
        match (if startsToken then rawStringEnd? cs i else none) with
        | some stop => charKindsFuel cs fuel stop (mark kinds i stop kindLiteral)
        | none =>
          if startsToken && (c == 'b' || c == 'c') && cs[i + 1]? == some '"' then
            let stop := quotedEnd cs (i + 1) '"'
            charKindsFuel cs fuel stop (mark kinds i stop kindLiteral)
          else if startsToken && c == 'b' && cs[i + 1]? == some '\'' then
            match charLiteralEnd? cs (i + 1) with
            | some stop => charKindsFuel cs fuel stop (mark kinds i stop kindLiteral)
            | none => charKindsFuel cs fuel (i + 1) kinds
          else if c == '"' then
            let stop := quotedEnd cs i '"'
            charKindsFuel cs fuel stop (mark kinds i stop kindLiteral)
          else if c == '\'' then
            match charLiteralEnd? cs i with
            | some stop => charKindsFuel cs fuel stop (mark kinds i stop kindLiteral)
            -- A lifetime or a label is code.
            | none => charKindsFuel cs fuel (i + 1) kinds
          else
            charKindsFuel cs fuel (i + 1) kinds

/-- The kind of every character of the source. -/
def charKinds (cs : Array Char) : Array UInt8 :=
  charKindsFuel cs cs.size 0 (Array.replicate cs.size kindCode)

def kindAt (kinds : Array UInt8) (i : Nat) : UInt8 :=
  kinds[i]?.getD kindCode

/-- Whether `word` is at `at` and ends there as a word. -/
def wordAt (cs : Array Char) (at_ : Nat) (word : String) : Bool :=
  let w := word.toList
  (List.range w.length).all (fun d => cs[at_ + d]? == w[d]?) &&
    !isIdentChar (cs[at_ + w.length]?.getD ' ')

def skipSpaceFuel (cs : Array Char) : Nat → Nat → Nat
  | 0, j => j
  | fuel + 1, j =>
    match cs[j]? with
    | some c => if isAsciiWhitespace c then skipSpaceFuel cs fuel (j + 1) else j
    | none => j

def skipSpace (cs : Array Char) (j : Nat) : Nat :=
  skipSpaceFuel cs cs.size j

/-- The index of the `]` that closes the bracket opened before `j`, counting
code brackets; the end if there is none. -/
def closeBracketFuel (cs : Array Char) (kinds : Array UInt8) : Nat → Nat → Nat → Nat
  | 0, _, _ => cs.size
  | fuel + 1, j, depth =>
    match cs[j]? with
    | none => cs.size
    | some c =>
      if kindAt kinds j == kindCode && c == '[' then
        closeBracketFuel cs kinds fuel (j + 1) (depth + 1)
      else if kindAt kinds j == kindCode && c == ']' then
        if depth - 1 == 0 then j else closeBracketFuel cs kinds fuel (j + 1) (depth - 1)
      else
        closeBracketFuel cs kinds fuel (j + 1) depth

def skipCommentAndSpaceFuel (cs : Array Char) (kinds : Array UInt8) : Nat → Nat → Nat
  | 0, j => j
  | fuel + 1, j =>
    match cs[j]? with
    | some c =>
      if kindAt kinds j == kindComment || isAsciiWhitespace c then
        skipCommentAndSpaceFuel cs kinds fuel (j + 1)
      else
        j
    | none => j

/-- The index of the next code character from `at_` that is not whitespace,
with comments and attributes skipped. -/
def skipTriviaAndAttributesFuel (cs : Array Char) (kinds : Array UInt8) : Nat → Nat → Nat
  | 0, at_ => at_
  | fuel + 1, at_ =>
    let at_ := skipCommentAndSpaceFuel cs kinds cs.size at_
    if at_ + 1 < cs.size && kindAt kinds at_ == kindCode && cs[at_]? == some '#' &&
        cs[at_ + 1]? == some '[' then
      skipTriviaAndAttributesFuel cs kinds fuel (closeBracketFuel cs kinds cs.size (at_ + 1) 0 + 1)
    else
      at_

def findCharFuel (cs : Array Char) (target : Char) : Nat → Nat → Nat
  | 0, _ => cs.size
  | fuel + 1, j =>
    match cs[j]? with
    | none => cs.size
    | some c => if c == target then j else findCharFuel cs target fuel (j + 1)

def skipLiteralFuel (kinds : Array UInt8) : Nat → Nat → Nat
  | 0, j => j
  | fuel + 1, j => if kindAt' kinds j then skipLiteralFuel kinds fuel (j + 1) else j
where
  kindAt' (kinds : Array UInt8) (j : Nat) : Bool := kinds[j]? == some kindLiteral

/-- Skip a function's qualifiers (`const`, `async`, `unsafe`, `extern` and
its ABI); `none` at the end of the source. -/
def skipQualifiersFuel (cs : Array Char) (kinds : Array UInt8) : Nat → Nat → Option Nat
  | 0, at_ => some at_
  | fuel + 1, at_ =>
    if cs.size ≤ at_ then
      none
    else
      match ["const", "async", "unsafe"].find? (fun word => wordAt cs at_ word) with
      | some word => skipQualifiersFuel cs kinds fuel (skipSpace cs (at_ + word.length))
      | none =>
        if wordAt cs at_ "extern" then
          let at_ := skipSpace cs (at_ + 6)
          let at_ :=
            if kinds[at_]? == some kindLiteral then
              skipSpace cs (skipLiteralFuel kinds cs.size at_)
            else
              at_
          skipQualifiersFuel cs kinds fuel at_
        else
          some at_

/-- The first `{` or `;` from `j` outside brackets and parentheses: `.inl`
the index past a `;`, `.inr` the index of a `{`; `none` if there is
neither. -/
def bodyStartFuel (cs : Array Char) (kinds : Array UInt8) : Nat → Nat → Nat → Option (Nat ⊕ Nat)
  | 0, _, _ => none
  | fuel + 1, j, nesting =>
    match cs[j]? with
    | none => none
    | some c =>
      if kindAt kinds j != kindCode then
        bodyStartFuel cs kinds fuel (j + 1) nesting
      else if c == '(' || c == '[' then
        bodyStartFuel cs kinds fuel (j + 1) (nesting + 1)
      else if c == ')' || c == ']' then
        bodyStartFuel cs kinds fuel (j + 1) (nesting - 1)
      else if c == ';' && nesting == 0 then
        some (.inl (j + 1))
      else if c == '{' && nesting == 0 then
        some (.inr j)
      else
        bodyStartFuel cs kinds fuel (j + 1) nesting

/-- The index just past the `}` that closes the brace at `j`, counting code
braces; the end if there is none. -/
def closeBraceFuel (cs : Array Char) (kinds : Array UInt8) : Nat → Nat → Nat → Nat
  | 0, _, _ => cs.size
  | fuel + 1, j, depth =>
    match cs[j]? with
    | none => cs.size
    | some c =>
      if kindAt kinds j == kindCode && c == '{' then
        closeBraceFuel cs kinds fuel (j + 1) (depth + 1)
      else if kindAt kinds j == kindCode && c == '}' then
        if depth - 1 == 0 then j + 1 else closeBraceFuel cs kinds fuel (j + 1) (depth - 1)
      else
        closeBraceFuel cs kinds fuel (j + 1) depth

/-- Where the item that a `#[cfg(test)]` at `attr` marks ends, if it is a
module or a function: just past its closing brace, or past its `;`. -/
def testItemEnd? (cs : Array Char) (kinds : Array UInt8) (attr : Nat) : Option Nat :=
  let at_ := skipTriviaAndAttributesFuel cs kinds cs.size (attr + cfgTest.length)
  let at_ :=
    if at_ < cs.size && wordAt cs at_ "pub" then
      let at_ := skipSpace cs (at_ + 3)
      if cs[at_]? == some '(' then skipSpace cs (findCharFuel cs ')' cs.size at_ + 1) else at_
    else
      at_
  match skipQualifiersFuel cs kinds cs.size at_ with
  | none => none
  | some at_ =>
    if !(wordAt cs at_ "fn" || wordAt cs at_ "mod") then
      none
    else
      match bodyStartFuel cs kinds cs.size at_ 0 with
      | some (.inl stop) => some stop
      | some (.inr brace) => some (closeBraceFuel cs kinds cs.size brace 0)
      | none => some cs.size

/-- Whether the attribute is at `at_`, in code. -/
def cfgTestAt (cs : Array Char) (kinds : Array UInt8) (at_ : Nat) : Bool :=
  kindAt kinds at_ == kindCode &&
    (List.range cfgTest.length).all (fun d => cs[at_ + d]? == cfgTest[d]?)

/-- The test items of a source: the ranges a slice cuts, and the positions
of the `#[cfg(test)]` attributes that mark something other than a module or
a function. An attribute inside a cut item counts as neither. -/
structure TestItems where
  cuts : List (Nat × Nat) := []
  misplaced : List Nat := []

def allAsciiWhitespace (cs : Array Char) (start stop : Nat) : Bool :=
  (List.range (stop - start)).all (fun d => isAsciiWhitespace (cs[start + d]?.getD ' '))

/-- The start of the line that holds `at_`. -/
def lineStartFuel (cs : Array Char) : Nat → Nat → Nat
  | 0, _ => 0
  | fuel + 1, at_ =>
    if at_ == 0 then 0
    else if cs[at_ - 1]? == some '\n' then at_
    else lineStartFuel cs fuel (at_ - 1)

def testItemsFuel (cs : Array Char) (kinds : Array UInt8) :
    Nat → Nat → Nat → TestItems → TestItems
  | 0, _, _, items => items
  | fuel + 1, at_, cursor, items =>
    if cs.size < at_ + cfgTest.length then
      items
    else if at_ < cursor || !cfgTestAt cs kinds at_ then
      testItemsFuel cs kinds fuel (at_ + 1) cursor items
    else
      match testItemEnd? cs kinds at_ with
      | none =>
        testItemsFuel cs kinds fuel (at_ + 1) cursor
          { items with misplaced := items.misplaced ++ [at_] }
      | some stop =>
        -- Whole lines where the item fills them.
        let lineStart := lineStartFuel cs cs.size at_
        let start := if allAsciiWhitespace cs lineStart at_ then max lineStart cursor else at_
        let lineEnd := lineEndFuel cs cs.size stop
        let stop := if allAsciiWhitespace cs stop lineEnd then min (lineEnd + 1) cs.size else stop
        testItemsFuel cs kinds fuel (at_ + 1) stop
          { items with cuts := items.cuts ++ [(start, stop)] }

def testItems (cs : Array Char) : TestItems :=
  testItemsFuel cs (charKinds cs) cs.size 0 0 {}

def keptFuel (cs : Array Char) : Nat → Nat → List (Nat × Nat) → List Char → List Char
  | 0, _, _, acc => acc
  | _ + 1, cursor, [], acc => acc ++ (cs.extract cursor cs.size).toList
  | fuel + 1, cursor, (start, stop) :: rest, acc =>
    keptFuel cs fuel stop rest (acc ++ (cs.extract cursor start).toList)

end RustSource

/-- The production part of a Rust source file: the file without the modules
and functions marked `#[cfg(test)]`. A test item is cut from its attribute
to its end, and whole lines where it fills them. -/
def productionSource (source : String) : String :=
  let cs := source.toList.toArray
  let cuts := (RustSource.testItems cs).cuts
  String.ofList (RustSource.keptFuel cs (cuts.length + 1) 0 cuts [])

/-- The lines (from 1) on which `#[cfg(test)]` marks something other than a
module or a function, outside the test items. The slicer leaves such an item
in place. -/
def misplacedCfgTestLines (source : String) : List Nat :=
  let cs := source.toList.toArray
  (RustSource.testItems cs).misplaced.map fun at_ =>
    ((cs.extract 0 at_).toList.filter (· == '\n')).length + 1

end UOToolchain
