use serde::{Deserialize, Serialize};
use std::fmt;

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

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum Value {
    Bool(bool),
    Uint(u128),
    Bytes32([u8; 32]),
    Address([u8; 20]),
    Struct(Vec<(String, Value)>),
    Array(Vec<Value>),
}

impl Value {
    pub fn bool(value: bool) -> Self {
        Self::Bool(value)
    }

    pub fn uint(value: u128) -> Self {
        Self::Uint(value)
    }

    pub fn zero_for_type(ty: &Type) -> Self {
        match ty {
            Type::Scalar(ScalarType::Bool) => Value::Bool(false),
            Type::Scalar(ScalarType::Uint(_)) => Value::Uint(0),
            Type::Scalar(ScalarType::Bytes32) => Value::Bytes32([0u8; 32]),
            Type::Scalar(ScalarType::Address) => Value::Address([0u8; 20]),
            Type::Struct(fields) => Value::Struct(
                fields
                    .iter()
                    .map(|field| (field.name.clone(), Value::zero_for_type(&field.ty)))
                    .collect(),
            ),
            Type::Array(element, len) => {
                Value::Array((0..*len).map(|_| Value::zero_for_type(element)).collect())
            }
        }
    }

    pub fn as_bool(&self) -> Option<bool> {
        match self {
            Value::Bool(value) => Some(*value),
            Value::Uint(value) => Some(*value != 0),
            _ => None,
        }
    }

    pub fn as_uint(&self) -> Option<u128> {
        match self {
            Value::Uint(value) => Some(*value),
            Value::Bool(value) => Some(if *value { 1 } else { 0 }),
            _ => None,
        }
    }

    pub fn canonical_bytes(&self) -> Vec<u8> {
        match self {
            Value::Bool(value) => vec![u8::from(*value)],
            Value::Uint(value) => {
                let mut bytes = [0u8; 32];
                bytes[16..].copy_from_slice(&value.to_be_bytes());
                bytes.to_vec()
            }
            Value::Bytes32(bytes) => bytes.to_vec(),
            Value::Address(bytes) => bytes.to_vec(),
            Value::Struct(fields) => {
                let mut out = Vec::new();
                for (name, value) in fields {
                    out.extend_from_slice(&(name.len() as u32).to_be_bytes());
                    out.extend_from_slice(name.as_bytes());
                    let value_bytes = value.canonical_bytes();
                    out.extend_from_slice(&(value_bytes.len() as u32).to_be_bytes());
                    out.extend_from_slice(&value_bytes);
                }
                out
            }
            Value::Array(values) => {
                let mut out = Vec::new();
                for value in values {
                    let value_bytes = value.canonical_bytes();
                    out.extend_from_slice(&(value_bytes.len() as u32).to_be_bytes());
                    out.extend_from_slice(&value_bytes);
                }
                out
            }
        }
    }

    pub fn canonical_key(&self) -> String {
        hex::encode(self.canonical_bytes())
    }

    pub fn is_zero_like(&self) -> bool {
        match self {
            Value::Bool(value) => !value,
            Value::Uint(value) => *value == 0,
            Value::Bytes32(bytes) => bytes.iter().all(|byte| *byte == 0),
            Value::Address(bytes) => bytes.iter().all(|byte| *byte == 0),
            Value::Struct(fields) => fields.iter().all(|(_, value)| value.is_zero_like()),
            Value::Array(values) => values.iter().all(Value::is_zero_like),
        }
    }

    pub fn as_bytes32(&self) -> Option<[u8; 32]> {
        match self {
            Value::Bytes32(bytes) => Some(*bytes),
            Value::Uint(value) => {
                let mut out = [0u8; 32];
                out[16..].copy_from_slice(&value.to_be_bytes());
                Some(out)
            }
            _ => None,
        }
    }
}

impl Type {
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
            Value::Array(vec![
                Value::Struct(vec![
                    ("flag".into(), Value::Bool(false)),
                    ("counter".into(), Value::Uint(0))
                ]),
                Value::Struct(vec![
                    ("flag".into(), Value::Bool(false)),
                    ("counter".into(), Value::Uint(0))
                ]),
            ])
        );
    }
}
