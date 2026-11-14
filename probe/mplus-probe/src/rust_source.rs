//! Reading Rust source text for the source checks.
//!
//! A source check reads the production part of a Rust file: the file
//! without its test items, the modules and functions marked `#[cfg(test)]`.
//! Where an item ends is found by matching braces, and a brace, a quote or
//! an attribute counts only where it is code: not inside a string, byte
//! string, raw string or character literal, and not inside a comment. A
//! `#[cfg(test)]` on anything else than a module or a function is left in
//! place, so that a slice never loses production text, and
//! `misplaced_cfg_test_lines` names it, for the check that rejects it.
//!
//! `productionSource` in `proof/lean/UOToolchain/RuntimeImplementationInterface.lean`
//! is the same slicer in Lean, and the implementation-interface report
//! checks that the two slice every pinned file alike.

/// The attribute that marks a test item.
const CFG_TEST: &str = "#[cfg(test)]";

/// What a byte of Rust source is.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum ByteKind {
    Code,
    /// Inside a literal, its quotes and prefix included.
    Literal,
    Comment,
}

fn is_ident_byte(byte: u8) -> bool {
    byte.is_ascii_alphanumeric() || byte == b'_' || byte >= 0x80
}

/// The index just past a literal that `quote` opens at `start`, escapes
/// skipped. An unterminated literal runs to the end.
fn quoted_end(bytes: &[u8], start: usize, quote: u8) -> usize {
    let mut j = start + 1;
    while j < bytes.len() {
        if bytes[j] == b'\\' {
            j += 2;
        } else if bytes[j] == quote {
            return j + 1;
        } else {
            j += 1;
        }
    }
    bytes.len()
}

/// The index just past a raw string literal (`r"…"`, `r#"…"#`, `br"…"`,
/// `cr"…"`) that starts at `i`, if one does.
fn raw_string_end(bytes: &[u8], i: usize) -> Option<usize> {
    let mut k = i;
    if matches!(bytes.get(k), Some(b'b' | b'c')) {
        k += 1;
    }
    if bytes.get(k) != Some(&b'r') {
        return None;
    }
    k += 1;
    let mut hashes = 0;
    while bytes.get(k + hashes) == Some(&b'#') {
        hashes += 1;
    }
    if bytes.get(k + hashes) != Some(&b'"') {
        return None;
    }
    let mut j = k + hashes + 1;
    while j < bytes.len() {
        if bytes[j] == b'"' && (1..=hashes).all(|h| bytes.get(j + h) == Some(&b'#')) {
            return Some(j + 1 + hashes);
        }
        j += 1;
    }
    Some(bytes.len())
}

/// The length of the UTF-8 character whose first byte is `byte`.
fn utf8_len(byte: u8) -> usize {
    match byte {
        0x00..=0x7f => 1,
        0xc0..=0xdf => 2,
        0xe0..=0xef => 3,
        _ => 4,
    }
}

/// The index just past a character literal that opens at `i`, if the
/// quote there opens one and not a lifetime or a label.
fn char_literal_end(bytes: &[u8], i: usize) -> Option<usize> {
    let first = *bytes.get(i + 1)?;
    if first == b'\\' {
        // An escape: the escaped character, then up to the closing quote
        // (`'\''`, `'\n'`, `'\x41'`, `'\u{1F600}'`).
        let mut j = i + 3;
        while j < bytes.len() && j <= i + 12 {
            if bytes[j] == b'\'' {
                return Some(j + 1);
            }
            j += 1;
        }
        return None;
    }
    let after = i + 1 + utf8_len(first);
    (first != b'\'' && bytes.get(after) == Some(&b'\'')).then_some(after + 1)
}

/// The kind of every byte of `source`.
fn byte_kinds(source: &str) -> Vec<ByteKind> {
    let bytes = source.as_bytes();
    let mut kinds = vec![ByteKind::Code; bytes.len()];
    let mark = |kinds: &mut Vec<ByteKind>, from: usize, to: usize, kind: ByteKind| {
        for slot in &mut kinds[from..to] {
            *slot = kind;
        }
    };
    let mut i = 0;
    while i < bytes.len() {
        let byte = bytes[i];
        let starts_token = i == 0 || !is_ident_byte(bytes[i - 1]);
        if byte == b'/' && bytes.get(i + 1) == Some(&b'/') {
            let end = source[i..].find('\n').map_or(bytes.len(), |at| i + at);
            mark(&mut kinds, i, end, ByteKind::Comment);
            i = end;
        } else if byte == b'/' && bytes.get(i + 1) == Some(&b'*') {
            // Block comments nest.
            let mut depth = 1;
            let mut j = i + 2;
            while j < bytes.len() && depth > 0 {
                if bytes[j] == b'/' && bytes.get(j + 1) == Some(&b'*') {
                    depth += 1;
                    j += 2;
                } else if bytes[j] == b'*' && bytes.get(j + 1) == Some(&b'/') {
                    depth -= 1;
                    j += 2;
                } else {
                    j += 1;
                }
            }
            mark(&mut kinds, i, j, ByteKind::Comment);
            i = j;
        } else if let Some(end) = starts_token.then(|| raw_string_end(bytes, i)).flatten() {
            mark(&mut kinds, i, end, ByteKind::Literal);
            i = end;
        } else if starts_token && matches!(byte, b'b' | b'c') && bytes.get(i + 1) == Some(&b'"') {
            let end = quoted_end(bytes, i + 1, b'"');
            mark(&mut kinds, i, end, ByteKind::Literal);
            i = end;
        } else if starts_token && byte == b'b' && bytes.get(i + 1) == Some(&b'\'') {
            match char_literal_end(bytes, i + 1) {
                Some(end) => {
                    mark(&mut kinds, i, end, ByteKind::Literal);
                    i = end;
                }
                None => i += 1,
            }
        } else if byte == b'"' {
            let end = quoted_end(bytes, i, b'"');
            mark(&mut kinds, i, end, ByteKind::Literal);
            i = end;
        } else if byte == b'\'' {
            match char_literal_end(bytes, i) {
                Some(end) => {
                    mark(&mut kinds, i, end, ByteKind::Literal);
                    i = end;
                }
                // A lifetime or a label is code.
                None => i += 1,
            }
        } else {
            i += 1;
        }
    }
    kinds
}

/// The source with every literal and comment blanked to spaces, newlines
/// kept: the text a check counts code in, so that a needle a check holds
/// in a string does not count as code, its own included.
pub(crate) fn rust_code_text(source: &str) -> String {
    let kinds = byte_kinds(source);
    let bytes: Vec<u8> = source
        .bytes()
        .zip(kinds)
        .map(|(byte, kind)| {
            if kind == ByteKind::Code || byte == b'\n' {
                byte
            } else {
                b' '
            }
        })
        .collect();
    // Literals and comments are blanked whole, so the text stays UTF-8.
    String::from_utf8(bytes).unwrap_or_default()
}

/// Whether `word` is at `at` and ends there as a word.
fn word_at(bytes: &[u8], at: usize, word: &str) -> bool {
    bytes[at..].starts_with(word.as_bytes())
        && !bytes
            .get(at + word.len())
            .copied()
            .is_some_and(is_ident_byte)
}

/// The index of the next code byte from `at` that is not whitespace, with
/// comments and attributes skipped.
fn skip_trivia_and_attributes(bytes: &[u8], kinds: &[ByteKind], mut at: usize) -> usize {
    loop {
        while at < bytes.len()
            && (kinds[at] == ByteKind::Comment || bytes[at].is_ascii_whitespace())
        {
            at += 1;
        }
        if at + 1 < bytes.len()
            && kinds[at] == ByteKind::Code
            && bytes[at] == b'#'
            && bytes[at + 1] == b'['
        {
            let mut depth = 0usize;
            let mut j = at + 1;
            while j < bytes.len() {
                if kinds[j] == ByteKind::Code {
                    match bytes[j] {
                        b'[' => depth += 1,
                        b']' => {
                            depth -= 1;
                            if depth == 0 {
                                break;
                            }
                        }
                        _ => {}
                    }
                }
                j += 1;
            }
            at = j + 1;
        } else {
            return at;
        }
    }
}

/// Where the item a `#[cfg(test)]` at `attribute` marks ends, if it is a
/// module or a function: just past its closing brace, or past its `;`.
fn test_item_end(bytes: &[u8], kinds: &[ByteKind], attribute: usize) -> Option<usize> {
    let mut at = skip_trivia_and_attributes(bytes, kinds, attribute + CFG_TEST.len());
    let skip_space = |mut at: usize| {
        while at < bytes.len() && bytes[at].is_ascii_whitespace() {
            at += 1;
        }
        at
    };
    if at < bytes.len() && word_at(bytes, at, "pub") {
        at = skip_space(at + 3);
        if bytes.get(at) == Some(&b'(') {
            while at < bytes.len() && bytes[at] != b')' {
                at += 1;
            }
            at = skip_space(at + 1);
        }
    }
    // A function's qualifiers.
    loop {
        if at >= bytes.len() {
            return None;
        }
        if let Some(word) = ["const", "async", "unsafe"]
            .into_iter()
            .find(|word| word_at(bytes, at, word))
        {
            at = skip_space(at + word.len());
        } else if word_at(bytes, at, "extern") {
            at = skip_space(at + "extern".len());
            if kinds.get(at) == Some(&ByteKind::Literal) {
                while kinds.get(at) == Some(&ByteKind::Literal) {
                    at += 1;
                }
                at = skip_space(at);
            }
        } else {
            break;
        }
    }
    if !(word_at(bytes, at, "fn") || word_at(bytes, at, "mod")) {
        return None;
    }
    // The first `{` or `;` outside brackets and parentheses: a signature
    // may hold `;` in an array type.
    let mut nesting = 0usize;
    while at < bytes.len() {
        if kinds[at] == ByteKind::Code {
            match bytes[at] {
                b'(' | b'[' => nesting += 1,
                b')' | b']' => nesting = nesting.saturating_sub(1),
                b';' if nesting == 0 => return Some(at + 1),
                b'{' if nesting == 0 => break,
                _ => {}
            }
        }
        at += 1;
    }
    let mut depth = 0usize;
    while at < bytes.len() {
        if kinds[at] == ByteKind::Code {
            match bytes[at] {
                b'{' => depth += 1,
                b'}' => {
                    depth -= 1;
                    if depth == 0 {
                        return Some(at + 1);
                    }
                }
                _ => {}
            }
        }
        at += 1;
    }
    Some(bytes.len())
}

/// The code positions of `#[cfg(test)]` in `source`.
fn cfg_test_attributes(bytes: &[u8], kinds: &[ByteKind]) -> Vec<usize> {
    let needle = CFG_TEST.as_bytes();
    (0..bytes.len().saturating_sub(needle.len() - 1))
        .filter(|&at| kinds[at] == ByteKind::Code && bytes[at..].starts_with(needle))
        .collect()
}

fn all_ascii_whitespace(text: &str) -> bool {
    text.bytes().all(|byte| byte.is_ascii_whitespace())
}

/// The test items of a source: the byte ranges a slice cuts, and the code
/// positions of the `#[cfg(test)]` attributes that mark something other
/// than a module or a function. An attribute inside a cut item counts as
/// neither.
struct TestItems {
    cuts: Vec<(usize, usize)>,
    misplaced: Vec<usize>,
}

fn test_items(source: &str) -> TestItems {
    let bytes = source.as_bytes();
    let kinds = byte_kinds(source);
    let mut items = TestItems {
        cuts: Vec::new(),
        misplaced: Vec::new(),
    };
    let mut cursor = 0;
    for attribute in cfg_test_attributes(bytes, &kinds) {
        if attribute < cursor {
            continue;
        }
        let Some(end) = test_item_end(bytes, &kinds, attribute) else {
            items.misplaced.push(attribute);
            continue;
        };
        // Whole lines where the item fills them.
        let line_start = source[..attribute].rfind('\n').map_or(0, |at| at + 1);
        let start = if all_ascii_whitespace(&source[line_start..attribute]) {
            line_start.max(cursor)
        } else {
            attribute
        };
        let line_end = source[end..].find('\n').map_or(bytes.len(), |at| end + at);
        let end = if all_ascii_whitespace(&source[end..line_end]) {
            (line_end + 1).min(bytes.len())
        } else {
            end
        };
        items.cuts.push((start, end));
        cursor = end;
    }
    items
}

/// The production part of a Rust source file: the file without the
/// modules and functions marked `#[cfg(test)]`. A test item is cut from its
/// attribute to its end, and whole lines where it fills them.
pub(crate) fn production_source_slice(source: &str) -> String {
    let mut out = String::with_capacity(source.len());
    let mut cursor = 0;
    for (start, end) in test_items(source).cuts {
        out.push_str(&source[cursor..start]);
        cursor = end;
    }
    out.push_str(&source[cursor..]);
    out
}

/// The lines (from 1) on which `#[cfg(test)]` marks something other than a
/// module or a function, outside the test items. The slicer leaves such an
/// item in place, and a check rejects it.
pub(crate) fn misplaced_cfg_test_lines(source: &str) -> Vec<usize> {
    test_items(source)
        .misplaced
        .into_iter()
        .map(|attribute| source[..attribute].matches('\n').count() + 1)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_test_function_and_a_test_module_are_cut_whole() {
        let source = "fn before() {}\n\n#[cfg(test)]\nfn helper() {\n    hidden();\n}\n\nfn after() {\n    visible();\n}\n\n#[cfg(test)]\n#[allow(dead_code)]\nmod tests {\n    fn nested() {\n        hidden_mod();\n    }\n}\n";
        assert_eq!(
            production_source_slice(source),
            "fn before() {}\n\n\nfn after() {\n    visible();\n}\n\n"
        );
    }

    #[test]
    fn braces_in_literals_and_comments_do_not_count() {
        // The test module holds unbalanced braces in a string, a raw
        // string, a byte string, a character and two comments.
        let source = concat!(
            "fn production() {}\n",
            "#[cfg(test)]\n",
            "mod tests {\n",
            "    const A: &str = \"}}\";\n",
            "    const B: &str = r#\"}\"# ;\n",
            "    const C: &[u8] = b\"{{{\";\n",
            "    const D: char = '}';\n",
            "    // }\n",
            "    /* } /* nested } */ } */\n",
            "    fn f<'a>(x: &'a str) -> &'a str { x }\n",
            "}\n",
            "fn after() { let brace = '{'; }\n",
        );
        assert_eq!(
            production_source_slice(source),
            "fn production() {}\nfn after() { let brace = '{'; }\n"
        );
    }

    #[test]
    fn an_attribute_in_a_literal_or_a_comment_is_not_an_attribute() {
        let source = "const CFG: &str = \"#[cfg(test)]\";\n// #[cfg(test)]\nfn kept() {}\n";
        assert_eq!(production_source_slice(source), source);
        assert!(misplaced_cfg_test_lines(source).is_empty());
    }

    #[test]
    fn a_misplaced_attribute_cuts_nothing_and_is_named() {
        let source = "struct S {\n    #[cfg(test)]\n    field: u8,\n    other: u8,\n}\nfn f() {\n    #[cfg(test)]\n    {\n        count();\n    }\n}\n#[cfg(test)]\nuse std::fmt;\n#[cfg(test)]\nconst X: u8 = 1;\n#[cfg(test)]\nmod tests;\n#[cfg(test)]\npub(crate) const fn g(x: [u8; 2]) -> u8 { x[0] }\n";
        let slice = production_source_slice(source);
        assert!(slice.contains("    #[cfg(test)]\n    field: u8,\n    other: u8,"));
        assert!(slice.contains("        count();"));
        assert!(slice.contains("use std::fmt;"));
        assert!(slice.contains("const X: u8 = 1;"));
        assert!(!slice.contains("mod tests;"));
        assert!(!slice.contains("fn g("));
        assert_eq!(misplaced_cfg_test_lines(source), vec![2, 7, 12, 14]);
    }

    #[test]
    fn an_attribute_inside_a_test_item_is_neither_cut_again_nor_named() {
        let source =
            "#[cfg(test)]\nmod tests {\n    #[cfg(test)]\n    use std::fmt;\n}\nfn kept() {}\n";
        assert_eq!(production_source_slice(source), "fn kept() {}\n");
        assert!(misplaced_cfg_test_lines(source).is_empty());
    }

    #[test]
    fn code_text_blanks_literals_and_comments() {
        let source = "let a = \"x(\"; // y(\nlet b = 'z'; let c: &'static str = r#\"w(\"#;\n";
        let code = rust_code_text(source);
        assert_eq!(code.len(), source.len());
        assert!(!code.contains("x(") && !code.contains("y(") && !code.contains("w("));
        assert!(code.contains("let b =") && code.contains("&'static str"));
        assert_eq!(code.matches('\n').count(), 2);
    }

    #[test]
    fn raw_identifiers_and_lifetimes_are_code() {
        let source =
            "fn r#type<'a>(x: &'a u8) -> u8 { *x }\n#[cfg(test)]\nfn t() { let _ = 'a'; }\n";
        assert_eq!(
            production_source_slice(source),
            "fn r#type<'a>(x: &'a u8) -> u8 { *x }\n"
        );
    }
}
