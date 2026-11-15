//! Which lookups of a Path ORAM map reuse a fact an earlier lookup found.
//!
//! A call on a Path ORAM map writes the map only when it commits: its writes
//! are pending, and a read applies them over what its lookup found. What a
//! lookup finds about the committed map, a key's value and, on the private
//! scheme, its presence, is therefore the same at every lookup of that key
//! during the call. A lookup is a get of a Path ORAM map, or the get that a
//! write to a private-scheme map makes to find whether its key is present, so
//! that the map's pending size can decide whether the write overflows the map.
//!
//! A lookup reuses the fact an earlier lookup of the same map found when the
//! program shows the two keys equal: equal key expressions, built only from
//! variables, literals and pure operators, none of whose variables is bound
//! again in between. Both keys then evaluate to the same value, which the
//! runtime checks. Facts survive the call's writes, which reach the map at
//! commit, and its accesses to other keys; a lookup reuses the latest fact
//! that may serve it. The rule reads only the program, so which lookups
//! reuse a fact, and so how many ORAM accesses a call makes, is public.
//! `UOToolchain/FactReuse.lean` states the rule and proves that a run's
//! lookups are the plan's whatever the run's values (`run_plan`) and that a
//! lookup that reuses a fact has the key the fact was found under
//! (`run_reuse_sound`).
//!
//! For example, in `x = m[a]; y = m[b]; m[a] = y; m[b] = x;` on the private
//! scheme each write reuses the presence the get of its key found, where the
//! rule before it, which asked the map's last access to be a get of the
//! write's key, reused neither; and in `require(m[k] > 0); m[k] = m[k] -
//! 1;` the second get reuses the first's value on either scheme, and on the
//! private scheme the write its presence.

use std::collections::BTreeMap;

use crate::confidential_kernel::{
    ConfidentialKernelSlotExpr, ConfidentialKernelSlotProgram, ConfidentialKernelSlotStatement,
};
use crate::ir::{BackendKind, ContainerKind, Expr, StateObject, Statement};
use crate::manifest::{PATH_ORAM_PRIVATE_POSMAP_SCHEME, PATH_ORAM_SCHEME};

/// How a map's operations look it up. A get of a local-scheme map is a
/// lookup; on the private scheme a get is one, and so is the get a write
/// makes to find whether its key is present.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LookupScheme {
    Local,
    Tree,
}

/// How a state object is looked up, if it is a Path ORAM map.
pub fn lookup_scheme(object: &StateObject) -> Option<LookupScheme> {
    if object.backend != BackendKind::Oram || object.kind != ContainerKind::Map {
        return None;
    }
    match object.oram_scheme.as_str() {
        PATH_ORAM_PRIVATE_POSMAP_SCHEME => Some(LookupScheme::Tree),
        PATH_ORAM_SCHEME => Some(LookupScheme::Local),
        _ => None,
    }
}

/// For each map, for each of its lookups in order: the index, among the
/// map's lookups that are made, of the one whose fact it reuses, or `None`
/// if it is made itself.
pub type FactReusePlan = BTreeMap<u32, Vec<Option<usize>>>;

/// A key expression the rule can compare: its canonical text and the
/// variables it reads.
#[derive(Clone, Debug, PartialEq, Eq)]
struct FactKey {
    text: String,
    vars: Vec<String>,
}

/// One step of a straight-line program, in evaluation order.
#[derive(Clone, Debug)]
enum FactEvent {
    /// A get of a map under a key (`None`: a key the rule cannot compare).
    Get {
        object_id: u32,
        key: Option<FactKey>,
    },
    /// A write to a map under a key.
    Put {
        object_id: u32,
        key: Option<FactKey>,
    },
    /// A variable bound or bound again.
    Bind { var: String },
}

/// A fact a made lookup found: its key, and whether every variable of the
/// key is still bound as it was at the lookup.
struct Fact {
    key: Option<FactKey>,
    valid: bool,
}

/// The plan of a straight-line program's events: `FactReuse.plan`, each
/// index counted among the facts of the lookup's own map.
fn plan_from_events(
    events: &[FactEvent],
    scheme: &dyn Fn(u32) -> Option<LookupScheme>,
) -> FactReusePlan {
    let mut facts: BTreeMap<u32, Vec<Fact>> = BTreeMap::new();
    let mut plan = FactReusePlan::new();
    for event in events {
        let (object_id, key) = match event {
            FactEvent::Get { object_id, key } if scheme(*object_id).is_some() => (*object_id, key),
            FactEvent::Put { object_id, key } if scheme(*object_id) == Some(LookupScheme::Tree) => {
                (*object_id, key)
            }
            FactEvent::Bind { var } => {
                for fact in facts.values_mut().flatten() {
                    if fact.key.as_ref().is_some_and(|key| key.vars.contains(var)) {
                        fact.valid = false;
                    }
                }
                continue;
            }
            _ => continue,
        };
        let known = facts.entry(object_id).or_default();
        let reused = key.as_ref().and_then(|key| {
            known
                .iter()
                .rposition(|fact| fact.valid && fact.key.as_ref() == Some(key))
        });
        if reused.is_none() {
            known.push(Fact {
                key: key.clone(),
                valid: key.is_some(),
            });
        }
        plan.entry(object_id).or_default().push(reused);
    }
    plan
}

/// How many lookups of each map reuse a fact.
fn reuse_counts(plan: &FactReusePlan) -> BTreeMap<u32, usize> {
    plan.iter()
        .map(|(object_id, lookups)| (*object_id, lookups.iter().flatten().count()))
        .filter(|(_, count)| *count > 0)
        .collect()
}

// --- The program's IR -------------------------------------------------------

/// A key built only from variables, literals and pure operators, or `None`.
fn ir_fact_key(expr: &Expr) -> Option<FactKey> {
    fn stable(expr: &Expr, vars: &mut Vec<String>) -> bool {
        match expr {
            Expr::Literal(_) => true,
            Expr::Var(name) => {
                if !vars.contains(name) {
                    vars.push(name.clone());
                }
                true
            }
            Expr::Unary { expr, .. } => stable(expr, vars),
            Expr::Binary { lhs, rhs, .. } => stable(lhs, vars) && stable(rhs, vars),
            Expr::Keccak256 { parts } => parts.iter().all(|part| stable(part, vars)),
            Expr::Select { .. }
            | Expr::CellGet { .. }
            | Expr::ArrayGet { .. }
            | Expr::MapGet { .. }
            | Expr::StructField { .. }
            | Expr::ArrayIndex { .. } => false,
        }
    }
    let mut vars = Vec::new();
    if !stable(expr, &mut vars) {
        return None;
    }
    let text = serde_json::to_string(expr).ok()?;
    Some(FactKey { text, vars })
}

fn ir_expr_events(expr: &Expr, events: &mut Vec<FactEvent>) {
    match expr {
        Expr::Literal(_) | Expr::Var(_) | Expr::CellGet { .. } => {}
        Expr::Unary { expr, .. } => ir_expr_events(expr, events),
        Expr::Binary { lhs, rhs, .. } => {
            ir_expr_events(lhs, events);
            ir_expr_events(rhs, events);
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            ir_expr_events(cond, events);
            ir_expr_events(when_true, events);
            ir_expr_events(when_false, events);
        }
        Expr::ArrayGet { index, .. } => ir_expr_events(index, events),
        Expr::MapGet { object_id, key } => {
            ir_expr_events(key, events);
            events.push(FactEvent::Get {
                object_id: *object_id,
                key: ir_fact_key(key),
            });
        }
        Expr::StructField { base, .. } => ir_expr_events(base, events),
        Expr::ArrayIndex { base, index } => {
            ir_expr_events(base, events);
            ir_expr_events(index, events);
        }
        Expr::Keccak256 { parts } => {
            for part in parts {
                ir_expr_events(part, events);
            }
        }
    }
}

/// The events of a straight-line body, or `None` if it branches or loops.
fn ir_body_events(body: &[Statement]) -> Option<Vec<FactEvent>> {
    let mut events = Vec::new();
    for statement in body {
        match statement {
            Statement::Declare { name, value, .. } | Statement::Assign { name, value } => {
                ir_expr_events(value, &mut events);
                events.push(FactEvent::Bind { var: name.clone() });
            }
            Statement::Require { cond } | Statement::AbortIf { cond } => {
                ir_expr_events(cond, &mut events)
            }
            Statement::CellSet {
                value, predicate, ..
            } => {
                ir_expr_events(value, &mut events);
                if let Some(predicate) = predicate {
                    ir_expr_events(predicate, &mut events);
                }
            }
            Statement::ArraySet {
                index,
                value,
                predicate,
                ..
            } => {
                ir_expr_events(index, &mut events);
                ir_expr_events(value, &mut events);
                if let Some(predicate) = predicate {
                    ir_expr_events(predicate, &mut events);
                }
            }
            Statement::MapPut {
                object_id,
                key,
                value,
                predicate,
            } => {
                ir_expr_events(key, &mut events);
                ir_expr_events(value, &mut events);
                if let Some(predicate) = predicate {
                    ir_expr_events(predicate, &mut events);
                }
                events.push(FactEvent::Put {
                    object_id: *object_id,
                    key: ir_fact_key(key),
                });
            }
            Statement::Return { value } => {
                if let Some(value) = value {
                    ir_expr_events(value, &mut events);
                }
            }
            Statement::If { .. } | Statement::For { .. } => return None,
        }
    }
    Some(events)
}

/// How many lookups of each map reuse a fact, in a confidential entrypoint's
/// linearized body; `scheme` says how each map is looked up. A body that
/// still branches or loops reuses none.
pub fn fact_reuses(
    body: &[Statement],
    scheme: &dyn Fn(u32) -> Option<LookupScheme>,
) -> BTreeMap<u32, usize> {
    let Some(events) = ir_body_events(body) else {
        return BTreeMap::new();
    };
    reuse_counts(&plan_from_events(&events, scheme))
}

// --- The kernel's slot program ---------------------------------------------

fn slot_var(slot: usize) -> String {
    format!("slot:{slot}")
}

fn slot_fact_key(expr: &ConfidentialKernelSlotExpr) -> Option<FactKey> {
    fn stable(expr: &ConfidentialKernelSlotExpr, vars: &mut Vec<String>) -> bool {
        match expr {
            ConfidentialKernelSlotExpr::Literal { .. } => true,
            ConfidentialKernelSlotExpr::Slot { slot } => {
                let var = slot_var(*slot);
                if !vars.contains(&var) {
                    vars.push(var);
                }
                true
            }
            ConfidentialKernelSlotExpr::Unary { expr, .. } => stable(expr, vars),
            ConfidentialKernelSlotExpr::Binary { lhs, rhs, .. } => {
                stable(lhs, vars) && stable(rhs, vars)
            }
            ConfidentialKernelSlotExpr::Keccak256 { parts } => {
                parts.iter().all(|part| stable(part, vars))
            }
            ConfidentialKernelSlotExpr::Select { .. }
            | ConfidentialKernelSlotExpr::CellGet { .. }
            | ConfidentialKernelSlotExpr::ArrayGet { .. }
            | ConfidentialKernelSlotExpr::MapGet { .. }
            | ConfidentialKernelSlotExpr::StructField { .. }
            | ConfidentialKernelSlotExpr::ArrayIndex { .. } => false,
        }
    }
    let mut vars = Vec::new();
    if !stable(expr, &mut vars) {
        return None;
    }
    let text = serde_json::to_string(expr).ok()?;
    Some(FactKey { text, vars })
}

fn slot_expr_events(expr: &ConfidentialKernelSlotExpr, events: &mut Vec<FactEvent>) {
    match expr {
        ConfidentialKernelSlotExpr::Literal { .. }
        | ConfidentialKernelSlotExpr::Slot { .. }
        | ConfidentialKernelSlotExpr::CellGet { .. } => {}
        ConfidentialKernelSlotExpr::Unary { expr, .. } => slot_expr_events(expr, events),
        ConfidentialKernelSlotExpr::Binary { lhs, rhs, .. } => {
            slot_expr_events(lhs, events);
            slot_expr_events(rhs, events);
        }
        // The arms of a select read no storage.
        ConfidentialKernelSlotExpr::Select { cond, .. } => slot_expr_events(cond, events),
        ConfidentialKernelSlotExpr::ArrayGet { index, .. } => slot_expr_events(index, events),
        ConfidentialKernelSlotExpr::MapGet { object_id, key } => {
            slot_expr_events(key, events);
            events.push(FactEvent::Get {
                object_id: *object_id,
                key: slot_fact_key(key),
            });
        }
        ConfidentialKernelSlotExpr::StructField { base, .. } => slot_expr_events(base, events),
        ConfidentialKernelSlotExpr::ArrayIndex { base, index } => {
            slot_expr_events(base, events);
            slot_expr_events(index, events);
        }
        ConfidentialKernelSlotExpr::Keccak256 { parts } => {
            for part in parts.iter() {
                slot_expr_events(part, events);
            }
        }
    }
}

/// The fact-reuse plan of a slot program, which is straight-line: for each
/// map `scheme` looks up, for each of its lookups in order, the made lookup
/// whose fact it reuses, or none.
pub fn slot_program_fact_reuse_plan(
    program: &ConfidentialKernelSlotProgram,
    scheme: &dyn Fn(u32) -> Option<LookupScheme>,
) -> FactReusePlan {
    let mut events = Vec::new();
    for statement in program.body.iter() {
        match statement {
            ConfidentialKernelSlotStatement::Declare { slot, value }
            | ConfidentialKernelSlotStatement::Assign { slot, value } => {
                slot_expr_events(value, &mut events);
                events.push(FactEvent::Bind {
                    var: slot_var(*slot),
                });
            }
            ConfidentialKernelSlotStatement::Require { cond }
            | ConfidentialKernelSlotStatement::AbortIf { cond } => {
                slot_expr_events(cond, &mut events)
            }
            ConfidentialKernelSlotStatement::CellSet {
                value, predicate, ..
            } => {
                slot_expr_events(value, &mut events);
                if let Some(predicate) = predicate {
                    slot_expr_events(predicate, &mut events);
                }
            }
            ConfidentialKernelSlotStatement::ArraySet {
                index,
                value,
                predicate,
                ..
            } => {
                slot_expr_events(index, &mut events);
                slot_expr_events(value, &mut events);
                if let Some(predicate) = predicate {
                    slot_expr_events(predicate, &mut events);
                }
            }
            ConfidentialKernelSlotStatement::MapPut {
                object_id,
                key,
                value,
                predicate,
            } => {
                slot_expr_events(key, &mut events);
                slot_expr_events(value, &mut events);
                if let Some(predicate) = predicate {
                    slot_expr_events(predicate, &mut events);
                }
                events.push(FactEvent::Put {
                    object_id: *object_id,
                    key: slot_fact_key(key),
                });
            }
            ConfidentialKernelSlotStatement::Return { value } => {
                if let Some(value) = value {
                    slot_expr_events(value, &mut events);
                }
            }
        }
    }
    plan_from_events(&events, scheme)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ir::BinaryOp;
    use crate::types::{ScalarType, Type, Value};

    fn var(name: &str) -> Expr {
        Expr::Var(name.into())
    }

    fn get(object_id: u32, key: Expr) -> Expr {
        Expr::MapGet {
            object_id,
            key: Box::new(key),
        }
    }

    fn put(object_id: u32, key: Expr, value: Expr) -> Statement {
        Statement::MapPut {
            object_id,
            key,
            value,
            predicate: Some(Expr::Literal(Value::Bool(true))),
        }
    }

    fn binary(op: BinaryOp, lhs: Expr, rhs: Expr) -> Expr {
        Expr::Binary {
            op,
            lhs: Box::new(lhs),
            rhs: Box::new(rhs),
        }
    }

    fn declare(name: &str, value: Expr) -> Statement {
        Statement::Declare {
            name: name.into(),
            ty: Type::Scalar(ScalarType::Uint(256)),
            value,
        }
    }

    /// Map 1 is a tree, map 3 a local-scheme map; map 2 is neither.
    fn scheme(object_id: u32) -> Option<LookupScheme> {
        match object_id {
            1 => Some(LookupScheme::Tree),
            3 => Some(LookupScheme::Local),
            _ => None,
        }
    }

    fn reuses_of(body: &[Statement], object_id: u32) -> usize {
        fact_reuses(body, &scheme)
            .get(&object_id)
            .copied()
            .unwrap_or(0)
    }

    /// ERC20Lite's `transfer`, linearized: both writes reuse a fact.
    #[test]
    fn transfer_writes_reuse_the_reads_presence() {
        let body = vec![
            declare("fromBalance", get(1, var("from"))),
            Statement::AbortIf {
                cond: Expr::Literal(Value::Bool(false)),
            },
            put(
                1,
                var("from"),
                binary(BinaryOp::Add, var("fromBalance"), var("amount")),
            ),
            put(
                1,
                var("to"),
                binary(BinaryOp::Add, get(1, var("to")), var("amount")),
            ),
        ];
        assert_eq!(
            fact_reuses(&body, &scheme),
            BTreeMap::from([(1u32, 2usize)])
        );
    }

    /// A lookup reuses a fact found under an equal key whatever the call did
    /// in between, unless a variable of the key is bound again: after a get
    /// of another key, and after a write, where the rule of the map's last
    /// get reused nothing. It reuses none for another key, for a key read
    /// from storage, or on a map that is not a Path ORAM map.
    #[test]
    fn lookups_reuse_facts_across_the_calls_other_accesses() {
        let cases = [
            vec![
                declare("x", get(1, var("k"))),
                Statement::Assign {
                    name: "k".into(),
                    value: var("j"),
                },
                put(1, var("k"), var("x")),
            ],
            vec![
                declare("x", get(1, var("k"))),
                declare("y", get(1, var("j"))),
                put(1, var("k"), var("x")),
            ],
            vec![
                declare("x", get(1, var("k"))),
                put(1, var("k"), var("x")),
                put(1, var("k"), var("x")),
            ],
            vec![declare("x", get(1, var("k"))), put(1, var("j"), var("x"))],
            vec![
                declare("x", get(1, get(2, var("k")))),
                put(1, get(2, var("k")), var("x")),
            ],
            vec![declare("x", get(2, var("k"))), put(2, var("k"), var("x"))],
        ];
        let expected = [0, 1, 2, 0, 0, 0];
        for (body, expected) in cases.iter().zip(expected) {
            assert_eq!(reuses_of(body, 1), expected, "{body:?}");
            assert_eq!(reuses_of(body, 2), 0, "{body:?}");
        }
    }

    /// A swap: on the tree each write reuses the get of its key; on the local
    /// scheme a write looks nothing up, and the gets are of two keys.
    #[test]
    fn a_swap_reuses_both_gets_on_the_tree() {
        for (object_id, expected) in [(1u32, 2usize), (3, 0)] {
            let body = vec![
                declare("x", get(object_id, var("a"))),
                declare("y", get(object_id, var("b"))),
                put(object_id, var("a"), var("y")),
                put(object_id, var("b"), var("x")),
            ];
            assert_eq!(reuses_of(&body, object_id), expected);
        }
    }

    /// A key read twice: the second get reuses the first's value on either
    /// scheme, and on the tree the write reuses its presence too.
    #[test]
    fn a_repeated_get_reuses_the_value_on_either_scheme() {
        for (object_id, expected) in [(1u32, 2usize), (3, 1)] {
            let body = vec![
                Statement::Require {
                    cond: binary(
                        BinaryOp::Gt,
                        get(object_id, var("k")),
                        Expr::Literal(Value::uint(0)),
                    ),
                },
                put(
                    object_id,
                    var("k"),
                    binary(
                        BinaryOp::Sub,
                        get(object_id, var("k")),
                        Expr::Literal(Value::uint(1)),
                    ),
                ),
            ];
            assert_eq!(reuses_of(&body, object_id), expected);
        }
    }

    /// The plan names, for each lookup that reuses, the index of the made
    /// lookup of its own map, and a bound variable forgets only the facts
    /// whose keys read it.
    #[test]
    fn the_plan_indexes_each_maps_made_lookups() {
        let key = |text: &str, vars: &[&str]| {
            Some(FactKey {
                text: text.into(),
                vars: vars.iter().map(|var| var.to_string()).collect(),
            })
        };
        let events = vec![
            FactEvent::Get {
                object_id: 1,
                key: key("a", &["a"]),
            },
            FactEvent::Get {
                object_id: 3,
                key: key("a", &["a"]),
            },
            FactEvent::Get {
                object_id: 1,
                key: key("b", &["b"]),
            },
            FactEvent::Put {
                object_id: 3,
                key: key("a", &["a"]),
            },
            FactEvent::Get {
                object_id: 3,
                key: key("a", &["a"]),
            },
            FactEvent::Bind { var: "a".into() },
            FactEvent::Put {
                object_id: 1,
                key: key("b", &["b"]),
            },
            FactEvent::Put {
                object_id: 1,
                key: key("a", &["a"]),
            },
            FactEvent::Get {
                object_id: 1,
                key: None,
            },
            FactEvent::Put {
                object_id: 1,
                key: key("a", &["a"]),
            },
        ];
        let plan = plan_from_events(&events, &scheme);
        assert_eq!(plan[&1], vec![None, None, Some(1), None, None, Some(2)]);
        assert_eq!(plan[&3], vec![None, Some(0)]);
    }

    /// A body that still branches reuses nothing.
    #[test]
    fn branching_bodies_reuse_nothing() {
        let body = vec![
            declare("x", get(1, var("k"))),
            Statement::If {
                cond: Expr::Literal(Value::Bool(true)),
                then_body: vec![],
                else_body: vec![],
            },
            put(1, var("k"), var("x")),
        ];
        assert!(fact_reuses(&body, &scheme).is_empty());
    }
}
