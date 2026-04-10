use serde::{Deserialize, Serialize};
use std::collections::hash_map::DefaultHasher;
use std::collections::BTreeMap;
use std::hash::{Hash, Hasher};

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq, Hash)]
pub enum WriteClass {
    Set,
    Clear,
    Same,
    Update,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct PhysicalWriteEvent {
    pub object: String,
    pub location: String,
    pub old: Vec<u8>,
    pub new: Vec<u8>,
    pub class: WriteClass,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct PhysicalReadEvent {
    pub object: String,
    pub location: String,
    pub len: usize,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct LogicalEvent {
    pub kind: String,
    pub object: String,
    pub detail: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq, Default)]
pub struct TraceHashBundle {
    pub opcode_trace_hash: String,
    pub logical_access_trace_hash: String,
    pub logical_write_trace_hash: String,
    pub physical_read_trace_hash: String,
    pub physical_write_trace_hash: String,
    pub physical_access_trace_hash: String,
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Default)]
pub struct ExecutionTrace {
    #[serde(default)]
    pub opcode_trace: Vec<String>,
    #[serde(default)]
    pub logical_accesses: Vec<LogicalEvent>,
    #[serde(default)]
    pub logical_writes: Vec<LogicalEvent>,
    #[serde(default)]
    pub physical_reads: Vec<PhysicalReadEvent>,
    #[serde(default)]
    pub physical_writes: Vec<PhysicalWriteEvent>,
    #[serde(default)]
    pub host_proxy_metrics: BTreeMap<String, f64>,
    #[serde(default)]
    pub gas_used: u64,
}

impl ExecutionTrace {
    pub fn hashes(&self) -> TraceHashBundle {
        let normalized_physical = self
            .physical_writes
            .iter()
            .map(|event| {
                (
                    event.object.clone(),
                    event.location.clone(),
                    event.class,
                    event.new.len(),
                )
            })
            .collect::<Vec<_>>();
        let normalized_reads = self
            .physical_reads
            .iter()
            .map(|event| (event.object.clone(), event.location.clone(), event.len))
            .collect::<Vec<_>>();
        TraceHashBundle {
            opcode_trace_hash: hash_json(&self.opcode_trace),
            logical_access_trace_hash: hash_json(&self.logical_accesses),
            logical_write_trace_hash: hash_json(&self.logical_writes),
            physical_read_trace_hash: hash_json(&normalized_reads),
            physical_write_trace_hash: hash_json(&normalized_physical),
            physical_access_trace_hash: hash_json(&(normalized_reads, normalized_physical)),
        }
    }
}

pub fn classify_write(old: &[u8], new: &[u8]) -> WriteClass {
    let old_zero = old.iter().all(|byte| *byte == 0);
    let new_zero = new.iter().all(|byte| *byte == 0);
    if old == new {
        WriteClass::Same
    } else if old_zero && !new_zero {
        WriteClass::Set
    } else if !old_zero && new_zero {
        WriteClass::Clear
    } else {
        WriteClass::Update
    }
}

fn hash_json<T: Serialize>(value: &T) -> String {
    let payload = serde_json::to_vec(value).expect("trace hashing requires serialization");
    let mut hasher = DefaultHasher::new();
    payload.hash(&mut hasher);
    format!("{:016x}", hasher.finish())
}

#[cfg(test)]
mod tests {
    use super::{classify_write, WriteClass};

    #[test]
    fn write_classifier_matches_m_plus_partition() {
        assert_eq!(classify_write(&[0, 0], &[0, 0]), WriteClass::Same);
        assert_eq!(classify_write(&[0, 0], &[1, 2]), WriteClass::Set);
        assert_eq!(classify_write(&[1, 2], &[0, 0]), WriteClass::Clear);
        assert_eq!(classify_write(&[1, 2], &[2, 3]), WriteClass::Update);
    }
}
