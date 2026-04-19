use crate::artifact::CompiledArtifact;
use crate::confidential_kernel::lower_confidential_kernel_pure_expr;
use crate::ir::{CompiledFunction, Expr, Statement};
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize, PartialEq, Eq)]
pub struct ConfidentialFragmentStats {
    pub select_count: usize,
    pub struct_field_count: usize,
    pub array_index_count: usize,
    pub non_branchless_select_arm_count: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ConfidentialFragmentEntrypointWitness {
    pub entrypoint_id: String,
    pub select_count: usize,
    pub struct_field_count: usize,
    pub array_index_count: usize,
    pub non_branchless_select_arm_count: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct ConfidentialFragmentWitness {
    pub contract: String,
    #[serde(default)]
    pub entrypoints: Vec<ConfidentialFragmentEntrypointWitness>,
}

impl ConfidentialFragmentEntrypointWitness {
    pub fn valid(&self) -> bool {
        self.struct_field_count == 0
            && self.array_index_count == 0
            && self.non_branchless_select_arm_count == 0
    }
}

impl ConfidentialFragmentWitness {
    pub fn valid(&self) -> bool {
        self.entrypoints
            .iter()
            .all(ConfidentialFragmentEntrypointWitness::valid)
    }

    pub fn entrypoint(
        &self,
        entrypoint_id: &str,
    ) -> Option<&ConfidentialFragmentEntrypointWitness> {
        self.entrypoints
            .iter()
            .find(|entrypoint| entrypoint.entrypoint_id == entrypoint_id)
    }

    pub fn valid_for_entrypoint(&self, entrypoint_id: &str) -> bool {
        self.entrypoint(entrypoint_id)
            .is_some_and(ConfidentialFragmentEntrypointWitness::valid)
    }
}

impl CompiledFunction {
    pub fn confidential_fragment_entrypoint_witness(
        &self,
    ) -> Option<ConfidentialFragmentEntrypointWitness> {
        if !self.confidential {
            return None;
        }
        let stats = confidential_fragment_stats_of_statements(&self.body);
        Some(ConfidentialFragmentEntrypointWitness {
            entrypoint_id: self.signature.clone(),
            select_count: stats.select_count,
            struct_field_count: stats.struct_field_count,
            array_index_count: stats.array_index_count,
            non_branchless_select_arm_count: stats.non_branchless_select_arm_count,
        })
    }
}

impl CompiledArtifact {
    pub fn confidential_fragment_witness(&self) -> ConfidentialFragmentWitness {
        ConfidentialFragmentWitness {
            contract: self.contract.contract.clone(),
            entrypoints: self
                .contract
                .functions
                .iter()
                .filter_map(CompiledFunction::confidential_fragment_entrypoint_witness)
                .collect(),
        }
    }
}

fn confidential_fragment_stats_of_statements(
    statements: &[Statement],
) -> ConfidentialFragmentStats {
    let mut stats = ConfidentialFragmentStats::default();
    for statement in statements {
        match statement {
            Statement::Declare { value, .. } | Statement::Assign { value, .. } => {
                confidential_fragment_stats_of_expr(value, &mut stats);
            }
            Statement::Require { cond } | Statement::AbortIf { cond } => {
                confidential_fragment_stats_of_expr(cond, &mut stats);
            }
            Statement::If {
                cond,
                then_body,
                else_body,
            } => {
                confidential_fragment_stats_of_expr(cond, &mut stats);
                stats = merge_fragment_stats(
                    stats,
                    confidential_fragment_stats_of_statements(then_body),
                );
                stats = merge_fragment_stats(
                    stats,
                    confidential_fragment_stats_of_statements(else_body),
                );
            }
            Statement::For {
                start, end, body, ..
            } => {
                confidential_fragment_stats_of_expr(start, &mut stats);
                confidential_fragment_stats_of_expr(end, &mut stats);
                stats =
                    merge_fragment_stats(stats, confidential_fragment_stats_of_statements(body));
            }
            Statement::CellSet {
                value, predicate, ..
            } => {
                confidential_fragment_stats_of_expr(value, &mut stats);
                if let Some(predicate) = predicate {
                    confidential_fragment_stats_of_expr(predicate, &mut stats);
                }
            }
            Statement::ArraySet {
                index,
                value,
                predicate,
                ..
            } => {
                confidential_fragment_stats_of_expr(index, &mut stats);
                confidential_fragment_stats_of_expr(value, &mut stats);
                if let Some(predicate) = predicate {
                    confidential_fragment_stats_of_expr(predicate, &mut stats);
                }
            }
            Statement::MapPut {
                key,
                value,
                predicate,
                ..
            } => {
                confidential_fragment_stats_of_expr(key, &mut stats);
                confidential_fragment_stats_of_expr(value, &mut stats);
                if let Some(predicate) = predicate {
                    confidential_fragment_stats_of_expr(predicate, &mut stats);
                }
            }
            Statement::Return { value } => {
                if let Some(value) = value {
                    confidential_fragment_stats_of_expr(value, &mut stats);
                }
            }
        }
    }
    stats
}

fn confidential_fragment_stats_of_expr(expr: &Expr, stats: &mut ConfidentialFragmentStats) {
    match expr {
        Expr::Literal(_) | Expr::Var(_) => {}
        Expr::Unary { expr, .. } => confidential_fragment_stats_of_expr(expr, stats),
        Expr::Binary { lhs, rhs, .. } => {
            confidential_fragment_stats_of_expr(lhs, stats);
            confidential_fragment_stats_of_expr(rhs, stats);
        }
        Expr::Select {
            cond,
            when_true,
            when_false,
        } => {
            stats.select_count += 1;
            if !select_arm_is_branchless_pure(when_true)
                || !select_arm_is_branchless_pure(when_false)
            {
                stats.non_branchless_select_arm_count += 1;
            }
            confidential_fragment_stats_of_expr(cond, stats);
            confidential_fragment_stats_of_expr(when_true, stats);
            confidential_fragment_stats_of_expr(when_false, stats);
        }
        Expr::CellGet { .. } => {}
        Expr::ArrayGet { index, .. } => confidential_fragment_stats_of_expr(index, stats),
        Expr::MapGet { key, .. } => confidential_fragment_stats_of_expr(key, stats),
        Expr::StructField { base, .. } => {
            stats.struct_field_count += 1;
            confidential_fragment_stats_of_expr(base, stats);
        }
        Expr::ArrayIndex { base, index } => {
            stats.array_index_count += 1;
            confidential_fragment_stats_of_expr(base, stats);
            confidential_fragment_stats_of_expr(index, stats);
        }
        Expr::Keccak256 { parts } => {
            for part in parts {
                confidential_fragment_stats_of_expr(part, stats);
            }
        }
    }
}

fn merge_fragment_stats(
    mut lhs: ConfidentialFragmentStats,
    rhs: ConfidentialFragmentStats,
) -> ConfidentialFragmentStats {
    lhs.select_count += rhs.select_count;
    lhs.struct_field_count += rhs.struct_field_count;
    lhs.array_index_count += rhs.array_index_count;
    lhs.non_branchless_select_arm_count += rhs.non_branchless_select_arm_count;
    lhs
}

fn select_arm_is_branchless_pure(expr: &Expr) -> bool {
    lower_confidential_kernel_pure_expr(expr, "<confidential-fragment>").is_ok()
}

#[cfg(test)]
mod tests {
    use super::ConfidentialFragmentEntrypointWitness;
    use crate::{
        CompiledArtifact, CompiledContract, CompiledFunction, Expr, ProgramMode, Statement, Type,
        Value,
    };

    fn sample_artifact(functions: Vec<CompiledFunction>) -> CompiledArtifact {
        CompiledArtifact {
            compiler_version: "test".into(),
            contract: CompiledContract {
                contract: "Sample".into(),
                mode: ProgramMode::Uo,
                source_file: "sample.sol".into(),
                state: vec![],
                functions,
                manifest: serde_json::from_str(
                    "{\"contract\":\"Sample\",\"compilation_mode\":\"uo\",\"objects\":[],\"entrypoints\":{}}",
                )
                .unwrap(),
            },
            diagnostics: vec![],
            transformed_source: None,
            disassembly: vec![],
        }
    }

    #[test]
    fn witness_accepts_branchless_select_entrypoint() {
        let artifact = sample_artifact(vec![CompiledFunction {
            signature: "auth(bytes32)".into(),
            params: vec![],
            return_type: Some(Type::Scalar(crate::ScalarType::Uint(256))),
            body: vec![Statement::Return {
                value: Some(Expr::Select {
                    cond: Box::new(Expr::CellGet { object_id: 1 }),
                    when_true: Box::new(Expr::Literal(Value::Uint(1))),
                    when_false: Box::new(Expr::Literal(Value::Uint(0))),
                }),
            }],
            secret_args: vec![0],
            confidential: true,
            confidential_program: None,
            confidential_slot_program: None,
        }]);
        let witness = artifact.confidential_fragment_witness();
        assert!(witness.valid());
        assert_eq!(
            witness.entrypoint("auth(bytes32)"),
            Some(&ConfidentialFragmentEntrypointWitness {
                entrypoint_id: "auth(bytes32)".into(),
                select_count: 1,
                struct_field_count: 0,
                array_index_count: 0,
                non_branchless_select_arm_count: 0,
            })
        );
    }

    #[test]
    fn witness_rejects_struct_and_array_projection_forms() {
        let artifact = sample_artifact(vec![CompiledFunction {
            signature: "bad()".into(),
            params: vec![],
            return_type: None,
            body: vec![
                Statement::Declare {
                    name: "x".into(),
                    ty: Type::Scalar(crate::ScalarType::Uint(256)),
                    value: Expr::StructField {
                        base: Box::new(Expr::Literal(Value::Struct(vec![(
                            "flag".into(),
                            Value::Bool(true),
                        )]))),
                        field: "flag".into(),
                    },
                },
                Statement::Return {
                    value: Some(Expr::ArrayIndex {
                        base: Box::new(Expr::Literal(Value::Array(vec![Value::Uint(1)]))),
                        index: Box::new(Expr::Literal(Value::Uint(0))),
                    }),
                },
            ],
            secret_args: vec![0],
            confidential: true,
            confidential_program: None,
            confidential_slot_program: None,
        }]);
        let witness = artifact.confidential_fragment_witness();
        let entrypoint = witness.entrypoint("bad()").unwrap();
        assert_eq!(entrypoint.struct_field_count, 1);
        assert_eq!(entrypoint.array_index_count, 1);
        assert!(!entrypoint.valid());
        assert!(!witness.valid());
    }

    #[test]
    fn witness_rejects_non_branchless_select_arms() {
        let artifact = sample_artifact(vec![CompiledFunction {
            signature: "badSelect()".into(),
            params: vec![],
            return_type: None,
            body: vec![Statement::Return {
                value: Some(Expr::Select {
                    cond: Box::new(Expr::Literal(Value::Bool(true))),
                    when_true: Box::new(Expr::MapGet {
                        object_id: 7,
                        key: Box::new(Expr::Literal(Value::Uint(1))),
                    }),
                    when_false: Box::new(Expr::Literal(Value::Uint(0))),
                }),
            }],
            secret_args: vec![0],
            confidential: true,
            confidential_program: None,
            confidential_slot_program: None,
        }]);
        let witness = artifact.confidential_fragment_witness();
        let entrypoint = witness.entrypoint("badSelect()").unwrap();
        assert_eq!(entrypoint.select_count, 1);
        assert_eq!(entrypoint.non_branchless_select_arm_count, 1);
        assert!(!entrypoint.valid());
    }
}
