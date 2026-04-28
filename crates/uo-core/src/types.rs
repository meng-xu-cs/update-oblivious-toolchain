use crate::fixed_buffer;
use anyhow::{bail, Result};
use serde::de::{self, DeserializeSeed, Deserializer, EnumAccess, VariantAccess, Visitor};
use serde::{Deserialize, Serialize};
use serde_json::Number;
use std::{fmt, marker::PhantomData, mem::MaybeUninit};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum ScalarType {
    Bool,
    Uint(u16),
    Bytes32,
    Address,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub struct StructField {
    pub name: String,
    pub ty: Type,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum Type {
    Scalar(ScalarType),
    Struct(Vec<StructField>),
    Array(Box<Type>, usize),
}

#[derive(Clone, Debug, Serialize, PartialEq, Eq, Hash)]
pub enum Value {
    Bool(bool),
    Uint(u128),
    Bytes32([u8; 32]),
    Address([u8; 20]),
    Struct(Box<[(String, Value)]>),
    Array(Box<[Value]>),
}

#[path = "generated_value_ops.rs"]
mod generated_value_ops;

pub(crate) use generated_value_ops::masked_select_bool;

const CANONICAL_LENGTH_PREFIX_BYTES: usize = 8;

pub struct FixedBoxBuilder<T> {
    entries: Box<[MaybeUninit<T>]>,
    initialized: usize,
}

impl<T> FixedBoxBuilder<T> {
    pub fn new(len: usize) -> Self {
        Self {
            entries: Box::<[T]>::new_uninit_slice(len),
            initialized: 0,
        }
    }

    pub fn from_fn<F>(len: usize, mut make: F) -> Box<[T]>
    where
        F: FnMut(usize) -> T,
    {
        let mut builder = Self::new(len);
        for (index, slot) in builder.entries.iter_mut().enumerate() {
            slot.write(make(index));
            builder.initialized += 1;
        }
        let entries = std::mem::take(&mut builder.entries);
        builder.initialized = 0;
        fixed_buffer::assume_init_boxed_slice(entries)
    }

    pub fn push(&mut self, value: T) -> Result<()> {
        if self.initialized >= self.entries.len() {
            bail!(
                "fixed value buffer overflow: initialized {} exceeds capacity {}",
                self.initialized,
                self.entries.len()
            );
        }
        let slot = self
            .entries
            .get_mut(self.initialized)
            .ok_or_else(|| anyhow::anyhow!("fixed value buffer slot unavailable"))?;
        slot.write(value);
        self.initialized += 1;
        Ok(())
    }

    pub fn finish(mut self) -> Result<Box<[T]>> {
        if self.initialized != self.entries.len() {
            bail!(
                "fixed value buffer underfilled: initialized {} of {} slots",
                self.initialized,
                self.entries.len()
            );
        }
        let entries = std::mem::take(&mut self.entries);
        self.initialized = 0;
        Ok(fixed_buffer::assume_init_boxed_slice(entries))
    }
}

impl<T> Drop for FixedBoxBuilder<T> {
    fn drop(&mut self) {
        fixed_buffer::drop_initialized_prefix(&mut self.entries, self.initialized);
    }
}

#[derive(Deserialize)]
enum ValueVariant {
    Bool,
    Uint,
    Bytes32,
    Address,
    Struct,
    Array,
}

struct U128Seed;

impl<'de> DeserializeSeed<'de> for U128Seed {
    type Value = u128;

    fn deserialize<D>(self, deserializer: D) -> Result<Self::Value, D::Error>
    where
        D: Deserializer<'de>,
    {
        let number = Number::deserialize(deserializer)?;
        number
            .as_u128()
            .ok_or_else(|| de::Error::custom(format!("JSON number {number} does not fit in u128")))
    }
}

struct ValueVisitor {
    marker: PhantomData<Value>,
}

impl<'de> Visitor<'de> for ValueVisitor {
    type Value = Value;

    fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("a Value enum")
    }

    fn visit_enum<A>(self, data: A) -> Result<Self::Value, A::Error>
    where
        A: EnumAccess<'de>,
    {
        let (variant, variant_access) = data.variant::<ValueVariant>()?;
        match variant {
            ValueVariant::Bool => Ok(Value::Bool(variant_access.newtype_variant()?)),
            ValueVariant::Uint => Ok(Value::Uint(variant_access.newtype_variant_seed(U128Seed)?)),
            ValueVariant::Bytes32 => Ok(Value::Bytes32(variant_access.newtype_variant()?)),
            ValueVariant::Address => Ok(Value::Address(variant_access.newtype_variant()?)),
            ValueVariant::Struct => Ok(Value::Struct(variant_access.newtype_variant()?)),
            ValueVariant::Array => Ok(Value::Array(variant_access.newtype_variant()?)),
        }
    }
}

impl<'de> Deserialize<'de> for Value {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        deserializer.deserialize_enum(
            "Value",
            &["Bool", "Uint", "Bytes32", "Address", "Struct", "Array"],
            ValueVisitor {
                marker: PhantomData,
            },
        )
    }
}

impl Type {
    pub fn canonical_len(&self) -> usize {
        match self {
            Type::Scalar(ScalarType::Bool) => 1,
            Type::Scalar(ScalarType::Uint(_)) => 32,
            Type::Scalar(ScalarType::Bytes32) => 32,
            Type::Scalar(ScalarType::Address) => 20,
            Type::Struct(fields) => fields
                .iter()
                .map(|field| {
                    CANONICAL_LENGTH_PREFIX_BYTES
                        + field.name.len()
                        + CANONICAL_LENGTH_PREFIX_BYTES
                        + field.ty.canonical_len()
                })
                .sum(),
            Type::Array(element, size) => {
                size * (CANONICAL_LENGTH_PREFIX_BYTES + element.canonical_len())
            }
        }
    }

    pub fn short_name(&self) -> String {
        match self {
            Type::Scalar(ScalarType::Bool) => "bool".into(),
            Type::Scalar(ScalarType::Uint(bits)) => format!("uint{bits}"),
            Type::Scalar(ScalarType::Bytes32) => "bytes32".into(),
            Type::Scalar(ScalarType::Address) => "address".into(),
            Type::Struct(fields) => {
                let joined = fields
                    .iter()
                    .map(|field| format!("{}:{}", field.name, field.ty.short_name()))
                    .collect::<Vec<_>>()
                    .join(",");
                format!("struct{{{joined}}}")
            }
            Type::Array(element, size) => format!("{}[{size}]", element.short_name()),
        }
    }
}

impl fmt::Display for Value {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Value::Bool(value) => write!(f, "{value}"),
            Value::Uint(value) => write!(f, "{value}"),
            Value::Bytes32(bytes) => write!(f, "0x{}", hex::encode(bytes)),
            Value::Address(bytes) => write!(f, "0x{}", hex::encode(bytes)),
            Value::Struct(fields) => {
                write!(f, "{{")?;
                for (idx, (name, value)) in fields.iter().enumerate() {
                    if idx > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{name}: {value}")?;
                }
                write!(f, "}}")
            }
            Value::Array(values) => {
                write!(f, "[")?;
                for (idx, value) in values.iter().enumerate() {
                    if idx > 0 {
                        write!(f, ", ")?;
                    }
                    write!(f, "{value}")?;
                }
                write!(f, "]")
            }
        }
    }
}

impl Drop for Value {
    fn drop(&mut self) {
        self.wipe_secrets();
    }
}

#[cfg(test)]
mod tests {
    use super::{ScalarType, Type, Value};
    #[test]
    fn zero_values_match_type_shape() {
        let ty = Type::Array(
            Box::new(Type::Struct(vec![
                super::StructField {
                    name: "flag".into(),
                    ty: Type::Scalar(ScalarType::Bool),
                },
                super::StructField {
                    name: "counter".into(),
                    ty: Type::Scalar(ScalarType::Uint(256)),
                },
            ])),
            2,
        );
        let value = Value::zero_for_type(&ty);
        assert_eq!(
            value,
            Value::Array(
                vec![
                    Value::Struct(
                        vec![
                            ("flag".into(), Value::Bool(false)),
                            ("counter".into(), Value::Uint(0))
                        ]
                        .into_boxed_slice(),
                    ),
                    Value::Struct(
                        vec![
                            ("flag".into(), Value::Bool(false)),
                            ("counter".into(), Value::Uint(0))
                        ]
                        .into_boxed_slice(),
                    ),
                ]
                .into_boxed_slice()
            )
        );
    }

    #[test]
    fn canonical_bytes_match_chunk_visitor() {
        let value = Value::Struct(
            vec![
                ("flag".into(), Value::Bool(true)),
                (
                    "items".into(),
                    Value::Array(
                        vec![
                            Value::Uint(7),
                            Value::Struct(
                                vec![("addr".into(), Value::Address([9u8; 20]))].into_boxed_slice(),
                            ),
                        ]
                        .into_boxed_slice(),
                    ),
                ),
            ]
            .into_boxed_slice(),
        );
        let expected = value.canonical_bytes().unwrap();
        let mut streamed = Vec::with_capacity(value.canonical_len());
        value.visit_canonical_chunks(&mut |chunk| streamed.extend_from_slice(chunk));
        assert_eq!(streamed, expected);
        assert_eq!(streamed.len(), value.canonical_len());
    }

    #[test]
    fn canonical_decode_roundtrips_nested_values() {
        let ty = Type::Struct(vec![
            super::StructField {
                name: "flag".into(),
                ty: Type::Scalar(ScalarType::Bool),
            },
            super::StructField {
                name: "items".into(),
                ty: Type::Array(Box::new(Type::Scalar(ScalarType::Uint(256))), 2),
            },
        ]);
        let value = Value::Struct(
            vec![
                ("flag".into(), Value::Bool(true)),
                (
                    "items".into(),
                    Value::Array(vec![Value::Uint(7), Value::Uint(9)].into_boxed_slice()),
                ),
            ]
            .into_boxed_slice(),
        );
        let encoded = value.canonical_bytes().unwrap();
        assert_eq!(Value::decode_canonical(&ty, &encoded).unwrap(), value);
    }

    #[test]
    fn serde_json_roundtrips_large_uint_values() {
        let value = Value::Uint((1u128 << 100) + 7);
        let encoded = serde_json::to_vec(&value).unwrap();
        let decoded: Value = serde_json::from_slice(&encoded).unwrap();
        assert_eq!(decoded, value);
    }

    #[test]
    fn type_canonical_len_matches_zero_value_shape() {
        let ty = Type::Array(
            Box::new(Type::Struct(vec![
                super::StructField {
                    name: "flag".into(),
                    ty: Type::Scalar(ScalarType::Bool),
                },
                super::StructField {
                    name: "counter".into(),
                    ty: Type::Scalar(ScalarType::Uint(256)),
                },
            ])),
            3,
        );
        let value = Value::zero_for_type(&ty);
        assert_eq!(ty.canonical_len(), value.canonical_len());
    }

    #[test]
    fn wipe_secrets_zeroes_nested_values() {
        let mut value = Value::Struct(
            vec![
                ("flag".into(), Value::Bool(true)),
                (
                    "items".into(),
                    Value::Array(
                        vec![
                            Value::Uint(7),
                            Value::Struct(
                                vec![
                                    ("addr".into(), Value::Address([9u8; 20])),
                                    ("bytes".into(), Value::Bytes32([4u8; 32])),
                                ]
                                .into_boxed_slice(),
                            ),
                        ]
                        .into_boxed_slice(),
                    ),
                ),
            ]
            .into_boxed_slice(),
        );
        value.wipe_secrets();
        assert_eq!(
            value,
            Value::Struct(
                vec![
                    ("flag".into(), Value::Bool(false)),
                    (
                        "items".into(),
                        Value::Array(
                            vec![
                                Value::Uint(0),
                                Value::Struct(
                                    vec![
                                        ("addr".into(), Value::Address([0u8; 20])),
                                        ("bytes".into(), Value::Bytes32([0u8; 32])),
                                    ]
                                    .into_boxed_slice(),
                                ),
                            ]
                            .into_boxed_slice(),
                        ),
                    ),
                ]
                .into_boxed_slice(),
            )
        );
    }

    #[test]
    fn confidential_select_recurses_without_shape_drift() {
        let selected = Value::confidential_select(
            true,
            Value::Struct(
                vec![
                    ("flag".into(), Value::Bool(true)),
                    (
                        "items".into(),
                        Value::Array(
                            vec![Value::Uint(7), Value::Bytes32([9u8; 32])].into_boxed_slice(),
                        ),
                    ),
                ]
                .into_boxed_slice(),
            ),
            Value::Struct(
                vec![
                    ("flag".into(), Value::Bool(false)),
                    (
                        "items".into(),
                        Value::Array(
                            vec![Value::Uint(1), Value::Bytes32([2u8; 32])].into_boxed_slice(),
                        ),
                    ),
                ]
                .into_boxed_slice(),
            ),
        )
        .unwrap();
        assert_eq!(
            selected,
            Value::Struct(
                vec![
                    ("flag".into(), Value::Bool(true)),
                    (
                        "items".into(),
                        Value::Array(
                            vec![Value::Uint(7), Value::Bytes32([9u8; 32])].into_boxed_slice(),
                        ),
                    ),
                ]
                .into_boxed_slice()
            )
        );
    }

    #[test]
    fn confidential_select_rejects_mismatched_shapes() {
        let err = Value::confidential_select(
            false,
            Value::Array(vec![Value::Uint(1)].into_boxed_slice()),
            Value::Struct(vec![("flag".into(), Value::Bool(false))].into_boxed_slice()),
        )
        .unwrap_err();
        assert!(err
            .to_string()
            .contains("confidential select mismatched value variants"));
    }

    #[test]
    fn confidential_eq_recurses_without_shape_drift() {
        let lhs = Value::Struct(
            vec![
                ("flag".into(), Value::Bool(true)),
                (
                    "items".into(),
                    Value::Array(
                        vec![Value::Uint(7), Value::Bytes32([9u8; 32])].into_boxed_slice(),
                    ),
                ),
            ]
            .into_boxed_slice(),
        );
        let rhs = Value::Struct(
            vec![
                ("flag".into(), Value::Bool(true)),
                (
                    "items".into(),
                    Value::Array(
                        vec![Value::Uint(7), Value::Bytes32([9u8; 32])].into_boxed_slice(),
                    ),
                ),
            ]
            .into_boxed_slice(),
        );
        let different = Value::Struct(
            vec![
                ("flag".into(), Value::Bool(true)),
                (
                    "items".into(),
                    Value::Array(
                        vec![Value::Uint(8), Value::Bytes32([9u8; 32])].into_boxed_slice(),
                    ),
                ),
            ]
            .into_boxed_slice(),
        );
        assert!(Value::confidential_eq(&lhs, &rhs));
        assert!(!Value::confidential_eq(&lhs, &different));
    }
}
