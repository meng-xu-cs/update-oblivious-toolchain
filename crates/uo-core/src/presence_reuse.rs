//! Which writes to a private-scheme Path ORAM map reuse the presence that a
//! preceding get of the same key found.
//!
//! A write to the private scheme's AVL tree first finds whether its key is
//! present, with a get, so that the map's pending size can decide whether the
//! write overflows the map. The tree is written only when the call commits, so
//! every get of a key during the call finds the same presence. A write
//! therefore reuses the presence of the most recent access to its map when
//! that access is a get under a key expression equal to the write's, built only
//! from variables, literals and pure operators, none of whose variables is
//! bound again in between: both keys then evaluate to the same value. The rule
//! reads only the program, so which writes reuse a presence, and so how many
//! node accesses a call makes, is public.
//!
//! For example, in `x = balances[from]; require(x >= amount);
//! balances[from] = x - amount; balances[to] = balances[to] + amount;` both
//! writes reuse a presence: the first from the get in the declaration, the
//! second from the get in its own value. On a tree of height `h` the two
//! writes make `2(3h + 1)` node accesses instead of `2(4h + 1)`.

use std::collections::BTreeMap;

use crate::confidential_kernel::{
    ConfidentialKernelSlotExpr, ConfidentialKernelSlotProgram, ConfidentialKernelSlotStatement,
};
use crate::ir::{Expr, Statement};

/// A key expression the rule can compare: its canonical text and the
/// variables it reads.
#[derive(Clone, Debug, PartialEq, Eq)]
struct PresenceKey {
    text: String,
    vars: Vec<String>,
}

/// One step of a straight-line program, in evaluation order.
#[derive(Clone, Debug)]
enum PresenceEvent {
    /// A get of a map under a key (`None`: a key the rule cannot compare).
    Get {
        object_id: u32,
        key: Option<PresenceKey>,
    },
    /// A write to a map under a key.
    Put {
        object_id: u32,
        key: Option<PresenceKey>,
    },
    /// A variable bound or bound again.
    Bind { var: String },
}

/// For each map `is_tree` selects, whether each of its writes, in order,
/// reuses a presence.
fn plan_from_events(
    events: &[PresenceEvent],
    is_tree: &dyn Fn(u32) -> bool,
) -> BTreeMap<u32, Vec<bool>> {
    let mut last_get: BTreeMap<u32, PresenceKey> = BTreeMap::new();
    let mut plan: BTreeMap<u32, Vec<bool>> = BTreeMap::new();
    for event in events {
        match event {
            PresenceEvent::Get { object_id, key } => match key {
                Some(key) => {
                    last_get.insert(*object_id, key.clone());
                }
                None => {
                    last_get.remove(object_id);
                }
            },
            PresenceEvent::Put { object_id, key } => {
                if is_tree(*object_id) {
                    let reuses = matches!(
                        (key, last_get.get(object_id)),
                        (Some(key), Some(last)) if key == last
                    );
                    plan.entry(*object_id).or_default().push(reuses);
                }
                last_get.remove(object_id);
            }
            PresenceEvent::Bind { var } => {
                last_get.retain(|_, key| !key.vars.contains(var));
            }
        }
    }
    plan
}

// --- The program's IR -------------------------------------------------------

/// A key built only from variables, literals and pure operators, or `None`.
fn ir_presence_key(expr: &Expr) -> Option<PresenceKey> {
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
    Some(PresenceKey { text, vars })
}

fn ir_expr_events(expr: &Expr, events: &mut Vec<PresenceEvent>) {
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
            events.push(PresenceEvent::Get {
                object_id: *object_id,
                key: ir_presence_key(key),
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
fn ir_body_events(body: &[Statement]) -> Option<Vec<PresenceEvent>> {
    let mut events = Vec::new();
    for statement in body {
        match statement {
            Statement::Declare { name, value, .. } | Statement::Assign { name, value } => {
                ir_expr_events(value, &mut events);
                events.push(PresenceEvent::Bind { var: name.clone() });
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
                events.push(PresenceEvent::Put {
                    object_id: *object_id,
                    key: ir_presence_key(key),
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

/// How many writes to each map `is_tree` selects reuse a presence, in a
/// confidential entrypoint's linearized body. A body that still branches or
/// loops reuses none.
pub fn tree_presence_reuses(
    body: &[Statement],
    is_tree: &dyn Fn(u32) -> bool,
) -> BTreeMap<u32, usize> {
    let Some(events) = ir_body_events(body) else {
        return BTreeMap::new();
    };
    plan_from_events(&events, is_tree)
        .into_iter()
        .map(|(object_id, flags)| (object_id, flags.iter().filter(|reuses| **reuses).count()))
        .filter(|(_, count)| *count > 0)
        .collect()
}

// --- The kernel's slot program ---------------------------------------------

fn slot_var(slot: usize) -> String {
    format!("slot:{slot}")
}

fn slot_presence_key(expr: &ConfidentialKernelSlotExpr) -> Option<PresenceKey> {
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
    Some(PresenceKey { text, vars })
}

fn slot_expr_events(expr: &ConfidentialKernelSlotExpr, events: &mut Vec<PresenceEvent>) {
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
            events.push(PresenceEvent::Get {
                object_id: *object_id,
                key: slot_presence_key(key),
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

/// For each map `is_tree` selects, whether each of its writes in a slot
/// program, in order, reuses a presence. A slot program is straight-line.
pub fn slot_program_tree_presence_plan(
    program: &ConfidentialKernelSlotProgram,
    is_tree: &dyn Fn(u32) -> bool,
) -> BTreeMap<u32, Vec<bool>> {
    let mut events = Vec::new();
    for statement in program.body.iter() {
        match statement {
            ConfidentialKernelSlotStatement::Declare { slot, value }
            | ConfidentialKernelSlotStatement::Assign { slot, value } => {
                slot_expr_events(value, &mut events);
                events.push(PresenceEvent::Bind {
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
                events.push(PresenceEvent::Put {
                    object_id: *object_id,
                    key: slot_presence_key(key),
                });
            }
            ConfidentialKernelSlotStatement::Return { value } => {
                if let Some(value) = value {
                    slot_expr_events(value, &mut events);
                }
            }
        }
    }
    plan_from_events(&events, is_tree)
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

    fn add(lhs: Expr, rhs: Expr) -> Expr {
        Expr::Binary {
            op: BinaryOp::Add,
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

    fn tree(object_id: u32) -> bool {
        object_id == 1
    }

    /// ERC20Lite's `transfer`, linearized: both writes reuse a presence.
    #[test]
    fn transfer_writes_reuse_the_reads_presence() {
        let body = vec![
            declare("fromBalance", get(1, var("from"))),
            Statement::AbortIf {
                cond: Expr::Literal(Value::Bool(false)),
            },
            put(1, var("from"), add(var("fromBalance"), var("amount"))),
            put(1, var("to"), add(get(1, var("to")), var("amount"))),
        ];
        assert_eq!(
            tree_presence_reuses(&body, &tree),
            BTreeMap::from([(1u32, 2usize)])
        );
    }

    /// No reuse after the key's variable is bound again, after another
    /// access to the map, for a different key, for a key read from storage,
    /// or on a map that is not a tree.
    #[test]
    fn writes_without_a_matching_get_make_their_own() {
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
        let expected = [Some(0), Some(0), Some(1), Some(0), Some(0), None];
        for (body, expected) in cases.iter().zip(expected) {
            assert_eq!(
                tree_presence_reuses(body, &tree).get(&1).copied(),
                expected.filter(|count| *count > 0),
                "{body:?}"
            );
        }
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
        assert!(tree_presence_reuses(&body, &tree).is_empty());
    }
}
