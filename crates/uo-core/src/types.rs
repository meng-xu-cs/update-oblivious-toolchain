use crate::fixed_buffer;
use anyhow::{bail, Result};
use serde::de::{self, Deserializer, Visitor};
use serde::{Deserialize, Serialize};
use std::{
    cmp::Ordering,
    fmt,
    mem::MaybeUninit,
    ops::{BitAnd, BitOr, BitXor},
};

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

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Hash)]
pub struct Uint256([u64; 4]);

impl Uint256 {
    pub const ZERO: Self = Self([0, 0, 0, 0]);
    pub const ONE: Self = Self([1, 0, 0, 0]);
    pub const MAX: Self = Self([u64::MAX; 4]);

    pub const fn from_u64(value: u64) -> Self {
        Self([value, 0, 0, 0])
    }

    pub const fn from_u128(value: u128) -> Self {
        Self([value as u64, (value >> 64) as u64, 0, 0])
    }

    pub const fn from_bool(value: bool) -> Self {
        Self::from_u64(value as u64)
    }

    pub fn from_be_bytes(bytes: [u8; 32]) -> Self {
        let mut limbs = [0u64; 4];
        for (idx, limb) in limbs.iter_mut().enumerate() {
            let start = (3 - idx) * 8;
            let mut chunk = [0u8; 8];
            chunk.copy_from_slice(&bytes[start..start + 8]);
            *limb = u64::from_be_bytes(chunk);
        }
        Self(limbs)
    }

    pub fn to_be_bytes(self) -> [u8; 32] {
        let mut out = [0u8; 32];
        for (idx, limb) in self.0.iter().enumerate() {
            let start = (3 - idx) * 8;
            out[start..start + 8].copy_from_slice(&limb.to_be_bytes());
        }
        out
    }

    pub fn from_dec_str(input: &str) -> Result<Self> {
        if input.is_empty() {
            bail!("uint256 decimal literal is empty");
        }
        let mut value = Self::ZERO;
        for byte in input.bytes() {
            if !byte.is_ascii_digit() {
                bail!("uint256 decimal literal contains non-digit byte");
            }
            value = value
                .checked_mul_u32(10)
                .and_then(|value| value.checked_add_u32((byte - b'0') as u32))
                .ok_or_else(|| anyhow::anyhow!("uint256 literal exceeds 2^256 - 1"))?;
        }
        Ok(value)
    }

    pub fn from_hex_str(input: &str) -> Result<Self> {
        let input = input
            .strip_prefix("0x")
            .or_else(|| input.strip_prefix("0X"))
            .unwrap_or(input);
        if input.is_empty() {
            bail!("uint256 hex literal is empty");
        }
        if input.len() > 64 {
            bail!("uint256 hex literal exceeds 32 bytes");
        }
        let mut padded = [b'0'; 64];
        padded[64 - input.len()..].copy_from_slice(input.as_bytes());
        let mut bytes = [0u8; 32];
        for (idx, slot) in bytes.iter_mut().enumerate() {
            let high = hex_nibble(padded[idx * 2])?;
            let low = hex_nibble(padded[idx * 2 + 1])?;
            *slot = (high << 4) | low;
        }
        Ok(Self::from_be_bytes(bytes))
    }

    pub fn is_zero(self) -> bool {
        self.0.iter().all(|limb| *limb == 0)
    }

    pub fn as_bool(self) -> bool {
        !self.is_zero()
    }

    pub fn checked_to_usize(self) -> Option<usize> {
        if self.0[1] != 0 || self.0[2] != 0 || self.0[3] != 0 {
            return None;
        }
        usize::try_from(self.0[0]).ok()
    }

    pub fn to_usize_saturating(self) -> usize {
        self.checked_to_usize().unwrap_or(usize::MAX)
    }

    pub fn wrapping_add(self, rhs: Self) -> Self {
        let mut out = [0u64; 4];
        let mut carry = 0u128;
        for (idx, slot) in out.iter_mut().enumerate() {
            let sum = self.0[idx] as u128 + rhs.0[idx] as u128 + carry;
            *slot = sum as u64;
            carry = sum >> 64;
        }
        Self(out)
    }

    pub fn wrapping_sub(self, rhs: Self) -> Self {
        let mut out = [0u64; 4];
        let mut borrow = 0u128;
        for (idx, slot) in out.iter_mut().enumerate() {
            let lhs = self.0[idx] as u128;
            let subtrahend = rhs.0[idx] as u128 + borrow;
            if lhs >= subtrahend {
                *slot = (lhs - subtrahend) as u64;
                borrow = 0;
            } else {
                *slot = ((1u128 << 64) + lhs - subtrahend) as u64;
                borrow = 1;
            }
        }
        Self(out)
    }

    pub fn wrapping_neg(self) -> Self {
        Self::ZERO.wrapping_sub(self)
    }

    pub fn wrapping_mul(self, rhs: Self) -> Self {
        let mut out = [0u64; 4];
        for i in 0..4 {
            let mut carry = 0u128;
            for j in 0..(4 - i) {
                let k = i + j;
                let acc = out[k] as u128 + (self.0[i] as u128 * rhs.0[j] as u128) + carry;
                out[k] = acc as u64;
                carry = acc >> 64;
            }
        }
        Self(out)
    }

    pub fn div_rem(self, divisor: Self) -> (Self, Self) {
        if divisor.is_zero() {
            return (Self::ZERO, self);
        }
        let mut quotient = Self::ZERO;
        let mut remainder = Self::ZERO;
        for bit in (0..256).rev() {
            remainder = remainder.shl1();
            if self.bit(bit) {
                remainder.0[0] |= 1;
            }
            if remainder >= divisor {
                remainder = remainder.wrapping_sub(divisor);
                quotient.set_bit(bit);
            }
        }
        (quotient, remainder)
    }

    #[allow(clippy::should_implement_trait)]
    pub fn bitand(self, rhs: Self) -> Self {
        <Self as BitAnd>::bitand(self, rhs)
    }

    #[allow(clippy::should_implement_trait)]
    pub fn bitor(self, rhs: Self) -> Self {
        <Self as BitOr>::bitor(self, rhs)
    }

    #[allow(clippy::should_implement_trait)]
    pub fn bitxor(self, rhs: Self) -> Self {
        <Self as BitXor>::bitxor(self, rhs)
    }

    fn shl1(self) -> Self {
        let mut out = [0u64; 4];
        let mut carry = 0u64;
        for (idx, slot) in out.iter_mut().enumerate() {
            *slot = (self.0[idx] << 1) | carry;
            carry = self.0[idx] >> 63;
        }
        Self(out)
    }

    fn bit(self, bit: usize) -> bool {
        let limb = bit / 64;
        let offset = bit % 64;
        ((self.0[limb] >> offset) & 1) != 0
    }

    fn set_bit(&mut self, bit: usize) {
        let limb = bit / 64;
        let offset = bit % 64;
        self.0[limb] |= 1u64 << offset;
    }

    fn checked_mul_u32(self, rhs: u32) -> Option<Self> {
        let mut out = [0u64; 4];
        let mut carry = 0u128;
        for (idx, slot) in out.iter_mut().enumerate() {
            let product = self.0[idx] as u128 * rhs as u128 + carry;
            *slot = product as u64;
            carry = product >> 64;
        }
        (carry == 0).then_some(Self(out))
    }

    fn checked_add_u32(self, rhs: u32) -> Option<Self> {
        let mut out = self.0;
        let (value, overflow) = out[0].overflowing_add(rhs as u64);
        out[0] = value;
        let mut carry = overflow;
        for slot in out.iter_mut().skip(1) {
            if !carry {
                break;
            }
            let (value, overflow) = slot.overflowing_add(1);
            *slot = value;
            carry = overflow;
        }
        (!carry).then_some(Self(out))
    }

    fn div_rem_u32(self, divisor: u32) -> (Self, u32) {
        let mut out = [0u64; 4];
        let mut remainder = 0u128;
        for idx in (0..4).rev() {
            let current = (remainder << 64) | self.0[idx] as u128;
            out[idx] = (current / divisor as u128) as u64;
            remainder = current % divisor as u128;
        }
        (Self(out), remainder as u32)
    }
}

impl BitAnd for Uint256 {
    type Output = Self;

    fn bitand(self, rhs: Self) -> Self::Output {
        Self([
            self.0[0] & rhs.0[0],
            self.0[1] & rhs.0[1],
            self.0[2] & rhs.0[2],
            self.0[3] & rhs.0[3],
        ])
    }
}

impl BitOr for Uint256 {
    type Output = Self;

    fn bitor(self, rhs: Self) -> Self::Output {
        Self([
            self.0[0] | rhs.0[0],
            self.0[1] | rhs.0[1],
            self.0[2] | rhs.0[2],
            self.0[3] | rhs.0[3],
        ])
    }
}

impl BitXor for Uint256 {
    type Output = Self;

    fn bitxor(self, rhs: Self) -> Self::Output {
        Self([
            self.0[0] ^ rhs.0[0],
            self.0[1] ^ rhs.0[1],
            self.0[2] ^ rhs.0[2],
            self.0[3] ^ rhs.0[3],
        ])
    }
}

impl Ord for Uint256 {
    fn cmp(&self, other: &Self) -> Ordering {
        for idx in (0..4).rev() {
            match self.0[idx].cmp(&other.0[idx]) {
                Ordering::Equal => {}
                ordering => return ordering,
            }
        }
        Ordering::Equal
    }
}

impl PartialOrd for Uint256 {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl fmt::Display for Uint256 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.is_zero() {
            return f.write_str("0");
        }
        let mut value = *self;
        let mut digits = Vec::new();
        while !value.is_zero() {
            let (next, digit) = value.div_rem_u32(10);
            digits.push((b'0' + digit as u8) as char);
            value = next;
        }
        for digit in digits.iter().rev() {
            write!(f, "{digit}")?;
        }
        Ok(())
    }
}

impl Serialize for Uint256 {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: serde::Serializer,
    {
        serializer.serialize_str(&self.to_string())
    }
}

struct Uint256Visitor;

impl<'de> Visitor<'de> for Uint256Visitor {
    type Value = Uint256;

    fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str("a uint256 decimal string or JSON number")
    }

    fn visit_str<E>(self, value: &str) -> Result<Self::Value, E>
    where
        E: de::Error,
    {
        Uint256::from_dec_str(value).map_err(E::custom)
    }

    fn visit_string<E>(self, value: String) -> Result<Self::Value, E>
    where
        E: de::Error,
    {
        self.visit_str(&value)
    }

    fn visit_u64<E>(self, value: u64) -> Result<Self::Value, E>
    where
        E: de::Error,
    {
        Ok(Uint256::from_u64(value))
    }

    fn visit_u128<E>(self, value: u128) -> Result<Self::Value, E>
    where
        E: de::Error,
    {
        Ok(Uint256::from_u128(value))
    }
}

impl<'de> Deserialize<'de> for Uint256 {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        if deserializer.is_human_readable() {
            let value = serde_json::Value::deserialize(deserializer)?;
            match value {
                serde_json::Value::String(value) => {
                    Uint256::from_dec_str(&value).map_err(de::Error::custom)
                }
                serde_json::Value::Number(number) => {
                    Uint256::from_dec_str(&number.to_string()).map_err(de::Error::custom)
                }
                other => Err(de::Error::custom(format!(
                    "expected uint256 string or number, got {other}"
                ))),
            }
        } else {
            deserializer.deserialize_any(Uint256Visitor)
        }
    }
}

impl From<bool> for Uint256 {
    fn from(value: bool) -> Self {
        Self::from_bool(value)
    }
}

macro_rules! impl_uint256_from_unsigned {
    ($($ty:ty),* $(,)?) => {
        $(
            impl From<$ty> for Uint256 {
                fn from(value: $ty) -> Self {
                    Self::from_u128(value as u128)
                }
            }
        )*
    };
}

impl_uint256_from_unsigned!(u8, u16, u32, u64, u128, usize);

macro_rules! impl_uint256_from_signed {
    ($($ty:ty),* $(,)?) => {
        $(
            impl From<$ty> for Uint256 {
                fn from(value: $ty) -> Self {
                    if value < 0 {
                        Self::ZERO
                    } else {
                        Self::from_u128(value as u128)
                    }
                }
            }
        )*
    };
}

impl_uint256_from_signed!(i8, i16, i32, i64, i128, isize);

fn hex_nibble(byte: u8) -> Result<u8> {
    match byte {
        b'0'..=b'9' => Ok(byte - b'0'),
        b'a'..=b'f' => Ok(byte - b'a' + 10),
        b'A'..=b'F' => Ok(byte - b'A' + 10),
        _ => bail!("invalid hex digit in uint256 literal"),
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum Value {
    Bool(bool),
    Uint(Uint256),
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
    use super::{ScalarType, Type, Uint256, Value};

    const UINT256_MAX_DECIMAL: &str =
        "115792089237316195423570985008687907853269984665640564039457584007913129639935";
    const UINT256_OVERFLOW_DECIMAL: &str =
        "115792089237316195423570985008687907853269984665640564039457584007913129639936";
    const UINT256_MAX_HEX: &str =
        "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff";

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
                            ("counter".into(), Value::uint(0))
                        ]
                        .into_boxed_slice(),
                    ),
                    Value::Struct(
                        vec![
                            ("flag".into(), Value::Bool(false)),
                            ("counter".into(), Value::uint(0))
                        ]
                        .into_boxed_slice(),
                    ),
                ]
                .into_boxed_slice()
            )
        );
    }

    #[test]
    fn uint256_decimal_display_and_json_roundtrip_at_full_width() {
        let value = Uint256::from_dec_str(UINT256_MAX_DECIMAL).unwrap();
        assert_eq!(value, Uint256::MAX);
        assert_eq!(value.to_string(), UINT256_MAX_DECIMAL);

        let encoded = serde_json::to_vec(&Value::uint(value)).unwrap();
        let decoded: Value = serde_json::from_slice(&encoded).unwrap();
        assert_eq!(decoded, Value::uint(Uint256::MAX));
    }

    #[test]
    fn uint256_parsing_rejects_values_above_evm_width() {
        assert!(Uint256::from_dec_str(UINT256_OVERFLOW_DECIMAL).is_err());
        assert!(Uint256::from_hex_str(&format!("1{UINT256_MAX_HEX}")).is_err());
    }

    #[test]
    fn uint256_canonical_encoding_preserves_high_payload_bytes() {
        let high_bit = Uint256::from_hex_str(
            "8000000000000000000000000000000000000000000000000000000000000000",
        )
        .unwrap();
        let value = Value::uint(high_bit);
        let bytes = value.canonical_bytes().unwrap();

        assert_eq!(bytes[0], 0x80);
        assert_eq!(
            Value::decode_canonical(&Type::Scalar(ScalarType::Uint(256)), &bytes).unwrap(),
            value
        );
        assert_eq!(value.as_bytes32().unwrap(), high_bit.to_be_bytes());
    }

    #[test]
    fn uint256_arithmetic_wraps_at_256_bits() {
        let high_bit = Uint256::from_hex_str(
            "8000000000000000000000000000000000000000000000000000000000000000",
        )
        .unwrap();

        assert_eq!(Uint256::MAX.wrapping_add(Uint256::ONE), Uint256::ZERO);
        assert_eq!(Uint256::ZERO.wrapping_sub(Uint256::ONE), Uint256::MAX);
        assert_eq!(high_bit.wrapping_mul(Uint256::from_u64(2)), Uint256::ZERO);

        let (quotient, remainder) =
            Uint256::from_dec_str("100000000000000000000000000000000000000")
                .unwrap()
                .div_rem(Uint256::from_u64(97));
        assert_eq!(
            quotient.to_string(),
            "1030927835051546391752577319587628865"
        );
        assert_eq!(remainder, Uint256::from_u64(95));
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
                            Value::uint(7),
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
                    Value::Array(vec![Value::uint(7), Value::uint(9)].into_boxed_slice()),
                ),
            ]
            .into_boxed_slice(),
        );
        let encoded = value.canonical_bytes().unwrap();
        assert_eq!(Value::decode_canonical(&ty, &encoded).unwrap(), value);
    }

    #[test]
    fn serde_json_roundtrips_large_uint_values() {
        let value = Value::uint((1u128 << 100) + 7);
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
                            Value::uint(7),
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
                                Value::uint(0),
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
                            vec![Value::uint(7), Value::Bytes32([9u8; 32])].into_boxed_slice(),
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
                            vec![Value::uint(1), Value::Bytes32([2u8; 32])].into_boxed_slice(),
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
                            vec![Value::uint(7), Value::Bytes32([9u8; 32])].into_boxed_slice(),
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
            Value::Array(vec![Value::uint(1)].into_boxed_slice()),
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
                        vec![Value::uint(7), Value::Bytes32([9u8; 32])].into_boxed_slice(),
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
                        vec![Value::uint(7), Value::Bytes32([9u8; 32])].into_boxed_slice(),
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
                        vec![Value::uint(8), Value::Bytes32([9u8; 32])].into_boxed_slice(),
                    ),
                ),
            ]
            .into_boxed_slice(),
        );
        assert!(Value::confidential_eq(&lhs, &rhs));
        assert!(!Value::confidential_eq(&lhs, &different));
    }
}
