//! Evaluate one binary operator of the confidential kernel on one class of
//! operands, for `scripts/measure_kernel_operator_instructions.sh`.
//!
//!     kernel_operator_classes list
//!     kernel_operator_classes <operator> <class>
//!
//! `list` prints every operator with every class of operands it is measured
//! on, one pair per line. With an operator and a class, the program builds
//! the kernel program `return slot0 <operator> slot1` (for `index`, `return
//! array[slot0]`), puts the class's operands in the slots as a call's
//! arguments are, and runs the slot interpreter on it `EVALUATIONS` times.
//! Each run is one call of `evaluate_operator`, which the script tells
//! callgrind to count instructions in. The operator and the class are public;
//! the operands are what a confidential call would keep secret, so the count
//! must not depend on the class.

use anyhow::{anyhow, bail, Result};
use std::hint::black_box;
use uo_core::{
    execute_confidential_kernel_slot_program, BinaryOp, ConfidentialKernelExecutionOutcome,
    ConfidentialKernelSlotExpr, ConfidentialKernelSlotProgram, ConfidentialKernelSlotRuntime,
    ConfidentialKernelSlotStatement, Uint256, Value,
};

/// How many times the interpreter runs the program in one process.
const EVALUATIONS: usize = 16;

/// The operators measured on 256-bit operands.
const UINT_OPERATORS: [(&str, BinaryOp); 14] = [
    ("add", BinaryOp::Add),
    ("sub", BinaryOp::Sub),
    ("mul", BinaryOp::Mul),
    ("div", BinaryOp::Div),
    ("mod", BinaryOp::Mod),
    ("bitand", BinaryOp::BitAnd),
    ("bitor", BinaryOp::BitOr),
    ("bitxor", BinaryOp::BitXor),
    ("eq", BinaryOp::Eq),
    ("neq", BinaryOp::Neq),
    ("lt", BinaryOp::Lt),
    ("lte", BinaryOp::Lte),
    ("gt", BinaryOp::Gt),
    ("gte", BinaryOp::Gte),
];

/// The operators measured on boolean operands.
const BOOL_OPERATORS: [(&str, BinaryOp); 4] = [
    ("and_bool", BinaryOp::And),
    ("or_bool", BinaryOp::Or),
    ("eq_bool", BinaryOp::Eq),
    ("neq_bool", BinaryOp::Neq),
];

/// The conversion of a 256-bit array index, measured through an array read.
const INDEX_OPERATOR: &str = "index";

fn limbs(limbs: [u64; 4]) -> Uint256 {
    let mut bytes = [0u8; 32];
    for (index, limb) in limbs.iter().enumerate() {
        let start = 32 - 8 * (index + 1);
        bytes[start..start + 8].copy_from_slice(&limb.to_be_bytes());
    }
    Uint256::from_be_bytes(bytes)
}

/// Classes of 256-bit operand pairs: every way the operators with branches
/// told operands apart. Zero or not, equal or not, the limb in which two
/// operands first differ, which of them is larger, and a borrow that runs
/// through every limb.
fn uint_classes() -> Vec<(&'static str, Uint256, Uint256)> {
    let full = limbs([
        0x0123_4567_89ab_cdef,
        0xfedc_ba98_7654_3210,
        0x0f1e_2d3c_4b5a_6978,
        0x8796_a5b4_c3d2_e1f0,
    ]);
    let low_above = limbs([
        0x0123_4567_89ab_cdf0,
        0xfedc_ba98_7654_3210,
        0x0f1e_2d3c_4b5a_6978,
        0x8796_a5b4_c3d2_e1f0,
    ]);
    let high_above = limbs([
        0x0123_4567_89ab_cdef,
        0xfedc_ba98_7654_3210,
        0x0f1e_2d3c_4b5a_6978,
        0x8796_a5b4_c3d2_e1f1,
    ]);
    vec![
        ("zero_zero", Uint256::ZERO, Uint256::ZERO),
        ("zero_rhs", full, Uint256::ZERO),
        ("zero_lhs", Uint256::ZERO, full),
        ("equal", full, full),
        ("low_limb_above", low_above, full),
        ("low_limb_below", full, low_above),
        ("high_limb_above", high_above, full),
        ("high_limb_below", full, high_above),
        ("borrow_chain", limbs([0, 0, 0, 1]), Uint256::ONE),
        ("small", Uint256::from_u64(97), Uint256::from_u64(7)),
        ("max_max", Uint256::MAX, Uint256::MAX),
        ("max_one", Uint256::MAX, Uint256::ONE),
        ("one_max", Uint256::ONE, Uint256::MAX),
    ]
}

fn bool_classes() -> Vec<(&'static str, bool, bool)> {
    vec![
        ("false_false", false, false),
        ("false_true", false, true),
        ("true_false", true, false),
        ("true_true", true, true),
    ]
}

/// Classes of array index: whether it fits the lowest limb.
fn index_classes() -> Vec<(&'static str, Uint256)> {
    vec![
        ("zero", Uint256::ZERO),
        ("small", Uint256::from_u64(3)),
        ("low_limb_max", Uint256::from_u64(u64::MAX)),
        ("second_limb", limbs([0, 1, 0, 0])),
        ("top_limb", limbs([5, 0, 0, 1])),
        ("max", Uint256::MAX),
    ]
}

/// A runtime with the call's slots and one array whose reads return a fixed
/// value whatever the index: the measured work is the kernel's own.
struct SlotRuntime {
    slots: Vec<Value>,
}

impl ConfidentialKernelSlotRuntime for SlotRuntime {
    fn load_slot(&self, slot: usize) -> Result<Value> {
        self.slots
            .get(slot)
            .cloned()
            .ok_or_else(|| anyhow!("slot {slot} is not a slot of the program"))
    }

    fn store_slot(&mut self, slot: usize, value: Value) -> Result<()> {
        let target = self
            .slots
            .get_mut(slot)
            .ok_or_else(|| anyhow!("slot {slot} is not a slot of the program"))?;
        *target = value;
        Ok(())
    }

    fn cell_get(&mut self, object_id: u32) -> Result<Value> {
        bail!("the program reads no cell, and asked for {object_id}")
    }

    fn cell_set(&mut self, object_id: u32, _value: Value, _predicate: Option<bool>) -> Result<()> {
        bail!("the program writes no cell, and asked for {object_id}")
    }

    fn array_get(&mut self, _object_id: u32, index: usize) -> Result<Value> {
        // Keep the converted index alive without acting on it.
        black_box(index);
        Ok(Value::uint(0))
    }

    fn array_set(
        &mut self,
        object_id: u32,
        _index: usize,
        _value: Value,
        _predicate: Option<bool>,
    ) -> Result<()> {
        bail!("the program writes no array, and asked for {object_id}")
    }

    fn map_get(&mut self, object_id: u32, _key: &Value) -> Result<(Value, bool)> {
        bail!("the program reads no map, and asked for {object_id}")
    }

    fn map_put(
        &mut self,
        object_id: u32,
        _key: Value,
        _value: Value,
        _predicate: Option<bool>,
    ) -> Result<bool> {
        bail!("the program writes no map, and asked for {object_id}")
    }

    fn keccak256(&mut self, _parts: Box<[Value]>) -> Result<Value> {
        bail!("the program hashes nothing")
    }
}

/// One evaluation of the program by the kernel's slot interpreter: what
/// callgrind counts.
#[inline(never)]
fn evaluate_operator(
    runtime: &mut SlotRuntime,
    program: &ConfidentialKernelSlotProgram,
) -> Result<ConfidentialKernelExecutionOutcome> {
    execute_confidential_kernel_slot_program(runtime, program)
}

fn program(value: ConfidentialKernelSlotExpr, slot_count: usize) -> ConfidentialKernelSlotProgram {
    ConfidentialKernelSlotProgram {
        entrypoint_id: "operator()".into(),
        param_count: slot_count,
        return_type: None,
        secret_args: (0..slot_count).collect(),
        slot_count,
        body: vec![ConfidentialKernelSlotStatement::Return { value: Some(value) }]
            .into_boxed_slice(),
    }
}

fn binary_program(op: BinaryOp) -> ConfidentialKernelSlotProgram {
    program(
        ConfidentialKernelSlotExpr::Binary {
            op,
            lhs: Box::new(ConfidentialKernelSlotExpr::Slot { slot: 0 }),
            rhs: Box::new(ConfidentialKernelSlotExpr::Slot { slot: 1 }),
        },
        2,
    )
}

fn index_program() -> ConfidentialKernelSlotProgram {
    program(
        ConfidentialKernelSlotExpr::ArrayGet {
            object_id: 0,
            index: Box::new(ConfidentialKernelSlotExpr::Slot { slot: 0 }),
        },
        1,
    )
}

/// The program and the operands of an operator on a class, or `None`.
fn case(operator: &str, class: &str) -> Option<(ConfidentialKernelSlotProgram, Vec<Value>)> {
    if let Some((_, op)) = UINT_OPERATORS.iter().find(|(name, _)| *name == operator) {
        let (_, lhs, rhs) = uint_classes()
            .into_iter()
            .find(|(name, _, _)| *name == class)?;
        return Some((
            binary_program(op.clone()),
            vec![Value::uint(lhs), Value::uint(rhs)],
        ));
    }
    if let Some((_, op)) = BOOL_OPERATORS.iter().find(|(name, _)| *name == operator) {
        let (_, lhs, rhs) = bool_classes()
            .into_iter()
            .find(|(name, _, _)| *name == class)?;
        return Some((
            binary_program(op.clone()),
            vec![Value::Bool(lhs), Value::Bool(rhs)],
        ));
    }
    if operator == INDEX_OPERATOR {
        let (_, index) = index_classes()
            .into_iter()
            .find(|(name, _)| *name == class)?;
        return Some((index_program(), vec![Value::uint(index)]));
    }
    None
}

fn list() {
    for (operator, _) in UINT_OPERATORS.iter() {
        for (class, _, _) in uint_classes() {
            println!("{operator} {class}");
        }
    }
    for (operator, _) in BOOL_OPERATORS.iter() {
        for (class, _, _) in bool_classes() {
            println!("{operator} {class}");
        }
    }
    for (class, _) in index_classes() {
        println!("{INDEX_OPERATOR} {class}");
    }
}

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    match args.as_slice() {
        [command] if command == "list" => {
            list();
            Ok(())
        }
        [operator, class] => {
            let (program, operands) = case(operator, class)
                .ok_or_else(|| anyhow!("no operator `{operator}` on class `{class}`"))?;
            let mut runtime = SlotRuntime { slots: operands };
            let mut last = None;
            for _ in 0..EVALUATIONS {
                let outcome = evaluate_operator(black_box(&mut runtime), black_box(&program))?;
                last = Some(black_box(outcome));
            }
            let (aborted, value) = last
                .ok_or_else(|| anyhow!("no evaluation ran"))?
                .into_parts();
            if aborted {
                bail!("the evaluation aborted");
            }
            let value = value.ok_or_else(|| anyhow!("the evaluation returned no value"))?;
            println!("{operator} {class} {EVALUATIONS} {value:?}");
            Ok(())
        }
        _ => bail!("usage: kernel_operator_classes list | <operator> <class>"),
    }
}
