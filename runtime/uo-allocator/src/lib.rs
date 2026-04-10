use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub struct AllocatorPlan {
    pub arena_bytes: usize,
    pub max_stack_words: usize,
    pub scratch_bytes: usize,
}

impl AllocatorPlan {
    pub fn for_entrypoint(arena_bytes: usize, max_stack_words: usize) -> Self {
        Self {
            arena_bytes,
            max_stack_words,
            scratch_bytes: arena_bytes / 4,
        }
    }
}
