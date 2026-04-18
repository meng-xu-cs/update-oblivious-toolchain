use anyhow::{anyhow, bail, Result};
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

    pub fn visit_canonical_chunks<F: FnMut(&[u8])>(&self, visitor: &mut F) {
        match self {
            Value::Bool(value) => {
                let byte = [u8::from(*value)];
                visitor(&byte);
            }
            Value::Uint(value) => {
                let mut bytes = [0u8; 32];
                bytes[16..].copy_from_slice(&value.to_be_bytes());
                visitor(&bytes);
            }
            Value::Bytes32(bytes) => visitor(bytes),
            Value::Address(bytes) => visitor(bytes),
            Value::Struct(fields) => {
                for (name, value) in fields {
                    let name_len = u32::try_from(name.len())
                        .expect("canonical field name length exceeds u32")
                        .to_be_bytes();
                    visitor(&name_len);
                    visitor(name.as_bytes());
                    let value_len = u32::try_from(value.canonical_len())
                        .expect("canonical value length exceeds u32")
                        .to_be_bytes();
                    visitor(&value_len);
                    value.visit_canonical_chunks(visitor);
                }
            }
            Value::Array(values) => {
                for value in values {
                    let value_len = u32::try_from(value.canonical_len())
                        .expect("canonical array element length exceeds u32")
                        .to_be_bytes();
                    visitor(&value_len);
                    value.visit_canonical_chunks(visitor);
                }
            }
        }
    }

    pub fn canonical_bytes(&self) -> Vec<u8> {
        let mut out = Vec::with_capacity(self.canonical_len());
        self.visit_canonical_chunks(&mut |chunk| out.extend_from_slice(chunk));
        out
    }

    pub fn decode_canonical(ty: &Type, bytes: &[u8]) -> Result<Self> {
        let (value, used) = Self::decode_canonical_prefix(ty, bytes)?;
        if used != bytes.len() {
            bail!(
                "canonical decode for {} consumed {} bytes, but {} were provided",
                ty.short_name(),
                used,
                bytes.len()
            );
        }
        Ok(value)
    }

    pub fn wipe_secrets(&mut self) {
        match self {
            Value::Bool(value) => *value = false,
            Value::Uint(value) => *value = 0,
            Value::Bytes32(bytes) => bytes.fill(0),
            Value::Address(bytes) => bytes.fill(0),
            Value::Struct(fields) => {
                for (_, value) in fields.iter_mut() {
                    value.wipe_secrets();
                }
            }
            Value::Array(values) => {
                for value in values.iter_mut() {
                    value.wipe_secrets();
                }
            }
        }
    }

    pub fn canonical_len(&self) -> usize {
        match self {
            Value::Bool(_) => 1,
            Value::Uint(_) => 32,
            Value::Bytes32(_) => 32,
            Value::Address(_) => 20,
            Value::Struct(fields) => fields
                .iter()
                .map(|(name, value)| 4 + name.len() + 4 + value.canonical_len())
                .sum(),
            Value::Array(values) => values.iter().map(|value| 4 + value.canonical_len()).sum(),
        }
    }

    pub fn canonical_key(&self) -> String {
        hex::encode(self.canonical_bytes())
    }

    pub fn confidential_select(
        cond: bool,
        mut when_true: Value,
        mut when_false: Value,
    ) -> Result<Self> {
        match (&mut when_true, &mut when_false) {
            (Value::Bool(when_true), Value::Bool(when_false)) => Ok(Value::Bool(
                masked_select_u8(cond, u8::from(*when_true), u8::from(*when_false)) != 0,
            )),
            (Value::Uint(when_true), Value::Uint(when_false)) => Ok(Value::Uint(
                masked_select_u128(cond, *when_true, *when_false),
            )),
            (Value::Bytes32(when_true), Value::Bytes32(when_false)) => Ok(Value::Bytes32(
                masked_select_bytes(cond, *when_true, *when_false),
            )),
            (Value::Address(when_true), Value::Address(when_false)) => Ok(Value::Address(
                masked_select_bytes(cond, *when_true, *when_false),
            )),
            (Value::Struct(when_true_fields), Value::Struct(when_false_fields)) => {
                if when_true_fields.len() != when_false_fields.len() {
                    bail!(
                        "confidential select mismatched struct arity: {} != {}",
                        when_true_fields.len(),
                        when_false_fields.len()
                    );
                }
                let when_true_fields = std::mem::take(when_true_fields);
                let when_false_fields = std::mem::take(when_false_fields);
                let mut selected = Vec::with_capacity(when_true_fields.len());
                for ((true_name, true_value), (false_name, false_value)) in when_true_fields
                    .into_iter()
                    .zip(when_false_fields.into_iter())
                {
                    if true_name != false_name {
                        bail!(
                            "confidential select mismatched struct fields: {} != {}",
                            true_name,
                            false_name
                        );
                    }
                    selected.push((
                        true_name,
                        Value::confidential_select(cond, true_value, false_value)?,
                    ));
                }
                Ok(Value::Struct(selected))
            }
            (Value::Array(when_true_values), Value::Array(when_false_values)) => {
                if when_true_values.len() != when_false_values.len() {
                    bail!(
                        "confidential select mismatched array length: {} != {}",
                        when_true_values.len(),
                        when_false_values.len()
                    );
                }
                let when_true_values = std::mem::take(when_true_values);
                let when_false_values = std::mem::take(when_false_values);
                let mut selected = Vec::with_capacity(when_true_values.len());
                for (true_value, false_value) in when_true_values
                    .into_iter()
                    .zip(when_false_values.into_iter())
                {
                    selected.push(Value::confidential_select(cond, true_value, false_value)?);
                }
                Ok(Value::Array(selected))
            }
            _ => bail!(
                "confidential select mismatched value variants: {} vs {}",
                when_true.kind_name(),
                when_false.kind_name()
            ),
        }
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

    fn decode_canonical_prefix(ty: &Type, bytes: &[u8]) -> Result<(Self, usize)> {
        match ty {
            Type::Scalar(ScalarType::Bool) => {
                let byte = *bytes
                    .first()
                    .ok_or_else(|| anyhow!("canonical bool is missing its payload byte"))?;
                Ok((Value::Bool(byte != 0), 1))
            }
            Type::Scalar(ScalarType::Uint(_)) => {
                if bytes.len() < 32 {
                    bail!("canonical uint requires 32 bytes, got {}", bytes.len());
                }
                if bytes[..16].iter().any(|byte| *byte != 0) {
                    bail!("canonical uint exceeds the runtime u128 decoding domain");
                }
                let mut out = [0u8; 16];
                out.copy_from_slice(&bytes[16..32]);
                Ok((Value::Uint(u128::from_be_bytes(out)), 32))
            }
            Type::Scalar(ScalarType::Bytes32) => {
                if bytes.len() < 32 {
                    bail!("canonical bytes32 requires 32 bytes, got {}", bytes.len());
                }
                let mut out = [0u8; 32];
                out.copy_from_slice(&bytes[..32]);
                Ok((Value::Bytes32(out), 32))
            }
            Type::Scalar(ScalarType::Address) => {
                if bytes.len() < 20 {
                    bail!("canonical address requires 20 bytes, got {}", bytes.len());
                }
                let mut out = [0u8; 20];
                out.copy_from_slice(&bytes[..20]);
                Ok((Value::Address(out), 20))
            }
            Type::Struct(fields) => {
                let mut offset = 0usize;
                let mut decoded = Vec::with_capacity(fields.len());
                for field in fields {
                    let name_len = read_u32_be(bytes, &mut offset)? as usize;
                    let name_end = offset + name_len;
                    let encoded_name = bytes.get(offset..name_end).ok_or_else(|| {
                        anyhow!(
                            "canonical struct field {} name overruns payload",
                            field.name
                        )
                    })?;
                    if encoded_name != field.name.as_bytes() {
                        bail!(
                            "canonical struct field mismatch: expected {}, got {}",
                            field.name,
                            String::from_utf8_lossy(encoded_name)
                        );
                    }
                    offset = name_end;
                    let value_len = read_u32_be(bytes, &mut offset)? as usize;
                    let value_end = offset + value_len;
                    let value_bytes = bytes.get(offset..value_end).ok_or_else(|| {
                        anyhow!(
                            "canonical struct field {} value overruns payload",
                            field.name
                        )
                    })?;
                    let (value, used) = Self::decode_canonical_prefix(&field.ty, value_bytes)?;
                    if used != value_len {
                        bail!(
                            "canonical struct field {} consumed {} bytes, expected {}",
                            field.name,
                            used,
                            value_len
                        );
                    }
                    decoded.push((field.name.clone(), value));
                    offset = value_end;
                }
                Ok((Value::Struct(decoded), offset))
            }
            Type::Array(element, len) => {
                let mut offset = 0usize;
                let mut decoded = Vec::with_capacity(*len);
                for index in 0..*len {
                    let value_len = read_u32_be(bytes, &mut offset)? as usize;
                    let value_end = offset + value_len;
                    let value_bytes = bytes.get(offset..value_end).ok_or_else(|| {
                        anyhow!("canonical array element {} overruns payload", index)
                    })?;
                    let (value, used) = Self::decode_canonical_prefix(element, value_bytes)?;
                    if used != value_len {
                        bail!(
                            "canonical array element {} consumed {} bytes, expected {}",
                            index,
                            used,
                            value_len
                        );
                    }
                    decoded.push(value);
                    offset = value_end;
                }
                Ok((Value::Array(decoded), offset))
            }
        }
    }

    fn kind_name(&self) -> &'static str {
        match self {
            Value::Bool(_) => "bool",
            Value::Uint(_) => "uint",
            Value::Bytes32(_) => "bytes32",
            Value::Address(_) => "address",
            Value::Struct(_) => "struct",
            Value::Array(_) => "array",
        }
    }
}

fn masked_select_u8(cond: bool, when_true: u8, when_false: u8) -> u8 {
    let mask = 0u8.wrapping_sub(u8::from(cond));
    (when_true & mask) | (when_false & !mask)
}

fn masked_select_u128(cond: bool, when_true: u128, when_false: u128) -> u128 {
    let mask = 0u128.wrapping_sub(u128::from(cond));
    (when_true & mask) | (when_false & !mask)
}

fn masked_select_bytes<const N: usize>(
    cond: bool,
    when_true: [u8; N],
    when_false: [u8; N],
) -> [u8; N] {
    let mask = 0u8.wrapping_sub(u8::from(cond));
    let mut selected = [0u8; N];
    for index in 0..N {
        selected[index] = (when_true[index] & mask) | (when_false[index] & !mask);
    }
    selected
}

fn read_u32_be(bytes: &[u8], offset: &mut usize) -> Result<u32> {
    let end = *offset + 4;
    let word = bytes
        .get(*offset..end)
        .ok_or_else(|| anyhow!("canonical payload ended early while reading length word"))?;
    let mut out = [0u8; 4];
    out.copy_from_slice(word);
    *offset = end;
    Ok(u32::from_be_bytes(out))
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

    #[test]
    fn canonical_bytes_match_chunk_visitor() {
        let value = Value::Struct(vec![
            ("flag".into(), Value::Bool(true)),
            (
                "items".into(),
                Value::Array(vec![
                    Value::Uint(7),
                    Value::Struct(vec![("addr".into(), Value::Address([9u8; 20]))]),
                ]),
            ),
        ]);
        let expected = value.canonical_bytes();
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
        let value = Value::Struct(vec![
            ("flag".into(), Value::Bool(true)),
            (
                "items".into(),
                Value::Array(vec![Value::Uint(7), Value::Uint(9)]),
            ),
        ]);
        let encoded = value.canonical_bytes();
        assert_eq!(Value::decode_canonical(&ty, &encoded).unwrap(), value);
    }

    #[test]
    fn wipe_secrets_zeroes_nested_values() {
        let mut value = Value::Struct(vec![
            ("flag".into(), Value::Bool(true)),
            (
                "items".into(),
                Value::Array(vec![
                    Value::Uint(7),
                    Value::Struct(vec![
                        ("addr".into(), Value::Address([9u8; 20])),
                        ("bytes".into(), Value::Bytes32([4u8; 32])),
                    ]),
                ]),
            ),
        ]);
        value.wipe_secrets();
        assert_eq!(
            value,
            Value::Struct(vec![
                ("flag".into(), Value::Bool(false)),
                (
                    "items".into(),
                    Value::Array(vec![
                        Value::Uint(0),
                        Value::Struct(vec![
                            ("addr".into(), Value::Address([0u8; 20])),
                            ("bytes".into(), Value::Bytes32([0u8; 32])),
                        ]),
                    ]),
                ),
            ])
        );
    }

    #[test]
    fn confidential_select_recurses_without_shape_drift() {
        let selected = Value::confidential_select(
            true,
            Value::Struct(vec![
                ("flag".into(), Value::Bool(true)),
                (
                    "items".into(),
                    Value::Array(vec![Value::Uint(7), Value::Bytes32([9u8; 32])]),
                ),
            ]),
            Value::Struct(vec![
                ("flag".into(), Value::Bool(false)),
                (
                    "items".into(),
                    Value::Array(vec![Value::Uint(1), Value::Bytes32([2u8; 32])]),
                ),
            ]),
        )
        .unwrap();
        assert_eq!(
            selected,
            Value::Struct(vec![
                ("flag".into(), Value::Bool(true)),
                (
                    "items".into(),
                    Value::Array(vec![Value::Uint(7), Value::Bytes32([9u8; 32])]),
                ),
            ])
        );
    }

    #[test]
    fn confidential_select_rejects_mismatched_shapes() {
        let err = Value::confidential_select(
            false,
            Value::Array(vec![Value::Uint(1)]),
            Value::Struct(vec![("flag".into(), Value::Bool(false))]),
        )
        .unwrap_err();
        assert!(err
            .to_string()
            .contains("confidential select mismatched value variants"));
    }
}
