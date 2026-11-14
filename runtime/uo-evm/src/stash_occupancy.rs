//! A simulation of the private scheme's stash.
//!
//! Runs the runtime's oblivious AVL map (`tree_get` and `tree_put`, with
//! their eviction and compaction) over an in-memory bucket store, with no
//! cryptography, and counts the blocks the stash holds: after each node
//! access of an operation but its last, when the operation holds the nodes
//! it has read, and after each operation, once it has returned them. A
//! stash that overflows is an error of the operation, as in the runtime, and
//! ends the run.

use super::generated_oram_codecs::{
    clone_tree_node, tree_avl_height, tree_bootstrap_nodes, tree_get, tree_place_nodes, tree_put,
    tree_put_accesses, TreeAccessRecord, TreeHeader, TreeNode, TreePathStore, TreeShape, TreeStash,
};
use anyhow::{anyhow, bail, Result};
use rand::{Rng, SeedableRng};
use rand_chacha::ChaCha20Rng;
use serde::Serialize;
use std::collections::VecDeque;
use uo_core::{ScalarType, Type, Value};

const BLOCKS_PER_BUCKET: usize = 5;

/// What the operations of a run are.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum StashWorkload {
    /// Gets and puts of keys drawn at random from as many keys as the map
    /// holds: inserts, updates and deletes, on a map about half full.
    Random,
    /// A get and an update of one key, over and over, on a map half full.
    RepeatedKey,
    /// Inserts of new keys until the map is nine tenths full, then deletes
    /// of the oldest keys until it is half full, over and over.
    InsertAndDelete,
}

impl StashWorkload {
    pub const ALL: [Self; 3] = [Self::Random, Self::RepeatedKey, Self::InsertAndDelete];

    pub fn label(self) -> &'static str {
        match self {
            Self::Random => "random",
            Self::RepeatedKey => "repeated_key",
            Self::InsertAndDelete => "insert_and_delete",
        }
    }
}

/// What one run counted.
#[derive(Debug, Serialize)]
pub struct StashOccupancyRun {
    pub capacity: usize,
    pub workload: &'static str,
    pub seed: u64,
    pub avl_height: usize,
    /// The nodes an operation may return to the stash: a put's node
    /// accesses, `3h + 1`.
    pub nodes_an_operation_returns: usize,
    /// The stash's size: the Path ORAM cap and those nodes, and at most the
    /// capacity.
    pub stash_bound: usize,
    pub operations: u64,
    pub node_accesses: u64,
    pub stored_keys: usize,
    /// `within_operation[k]`: node accesses, not the last of their
    /// operation, after which the stash held `k` blocks.
    pub within_operation: Vec<u64>,
    /// `after_operation[k]`: operations after which the stash held `k`
    /// blocks.
    pub after_operation: Vec<u64>,
    /// The stash overflowed, which ended the run.
    pub overflowed: bool,
}

struct OccupancyStore {
    buckets: Vec<Box<[TreeNode]>>,
    empty: TreeNode,
    leaf_count: usize,
    coins: ChaCha20Rng,
    /// The next bucket load is the first of its access, and the access is
    /// not the first of its operation.
    sample_next_load: bool,
    node_accesses: u64,
    within_operation: Vec<u64>,
    after_operation: Vec<u64>,
}

fn count(histogram: &mut [u64], occupancy: usize) -> Result<()> {
    let slot = histogram
        .get_mut(occupancy)
        .ok_or_else(|| anyhow!("stash occupancy {occupancy} above the stash's size"))?;
    *slot += 1;
    Ok(())
}

impl TreePathStore for OccupancyStore {
    fn coin(&mut self) -> Result<usize> {
        Ok(self.coins.gen_range(0..self.leaf_count))
    }

    fn begin_access(&mut self, first: bool) -> Result<()> {
        self.node_accesses += 1;
        self.sample_next_load = !first;
        Ok(())
    }

    fn load_bucket(&mut self, index: usize, stash: &mut TreeStash) -> Result<()> {
        if self.sample_next_load {
            // The stash as the access before this one left it.
            self.sample_next_load = false;
            count(&mut self.within_operation, stash.len())?;
        }
        let bucket = self
            .buckets
            .get_mut(index)
            .ok_or_else(|| anyhow!("bucket {index} missing"))?;
        for slot in bucket.iter_mut() {
            stash.append(slot)?;
            *slot = clone_tree_node(&self.empty);
        }
        Ok(())
    }

    fn store_bucket(&mut self, index: usize, blocks: &[TreeNode]) -> Result<()> {
        let bucket = self
            .buckets
            .get_mut(index)
            .ok_or_else(|| anyhow!("bucket {index} missing"))?;
        *bucket = blocks.iter().map(clone_tree_node).collect();
        Ok(())
    }

    fn end_operation(&mut self, _header: &TreeHeader, stash: &TreeStash) -> Result<()> {
        count(&mut self.after_operation, stash.len())
    }

    fn end_access(&mut self, _record: &TreeAccessRecord) -> Result<()> {
        Ok(())
    }
}

struct SimulatedMap {
    shape: TreeShape,
    store: OccupancyStore,
    stash: TreeStash,
    header: TreeHeader,
    operations: u64,
}

fn uint_type() -> Type {
    Type::Scalar(ScalarType::Uint(256))
}

fn is_stash_overflow(error: &anyhow::Error) -> bool {
    error.to_string().contains("stash overflowed its bound")
}

impl SimulatedMap {
    /// An empty map of `capacity` keys, its nodes placed by the runtime's
    /// bootstrap, with the runtime's stash bound.
    fn new(capacity: usize, seed: u64) -> Result<Self> {
        let leaf_count = capacity.max(2).next_power_of_two();
        let levels = leaf_count.trailing_zeros() as usize + 1;
        let avl_height = tree_avl_height(capacity);
        let shape = TreeShape {
            capacity,
            leaf_count,
            blocks_per_bucket: BLOCKS_PER_BUCKET,
            avl_height,
            stash_bound: uo_core::manifest::path_oram_tree_stash_bound(capacity),
            key_type: uint_type(),
            value_type: uint_type(),
            key_width: 32,
            value_width: 32,
        };
        let empty = TreeNode::empty(&uint_type(), &uint_type());
        let working = shape.stash_bound + shape.blocks_per_bucket * levels;
        let mut stash = TreeStash::with_capacity(shape.stash_bound, working, &empty)?;
        let mut rng = ChaCha20Rng::seed_from_u64(seed);
        let mut coins = || Ok(rng.gen_range(0..leaf_count));
        let (header, nodes) = tree_bootstrap_nodes(&shape, &mut coins)?;
        let mut buckets: Vec<Box<[TreeNode]>> = (0..2 * leaf_count - 1)
            .map(|_| {
                (0..BLOCKS_PER_BUCKET)
                    .map(|_| clone_tree_node(&empty))
                    .collect()
            })
            .collect();
        tree_place_nodes(&shape, &nodes, &mut buckets, &mut stash)?;
        let histogram = vec![0u64; shape.stash_bound + 1];
        Ok(Self {
            store: OccupancyStore {
                buckets,
                empty,
                leaf_count,
                coins: ChaCha20Rng::seed_from_u64(seed ^ 0x5eed),
                sample_next_load: false,
                node_accesses: 0,
                within_operation: histogram.clone(),
                after_operation: histogram,
            },
            shape,
            stash,
            header,
            operations: 0,
        })
    }

    /// Whether the key is present.
    fn get(&mut self, key: u64) -> Result<bool> {
        let (_value, found, failed) = tree_get(
            &self.shape,
            &mut self.store,
            &mut self.stash,
            &mut self.header,
            &Value::uint(key),
        )?;
        if failed {
            bail!("a get of {key} found the simulated tree wrong");
        }
        self.operations += 1;
        Ok(found)
    }

    /// Write `value` to `key`; zero deletes.
    fn put(&mut self, key: u64, value: u64) -> Result<()> {
        let (overflow, failed) = tree_put(
            &self.shape,
            &mut self.store,
            &mut self.stash,
            &mut self.header,
            &Value::uint(key),
            &Value::uint(value),
            true,
        )?;
        if failed || overflow {
            bail!("a put of {key} found the simulated tree wrong or the map full");
        }
        self.operations += 1;
        Ok(())
    }
}

/// Run `workload` on a map of `capacity` keys until it has made at least
/// `node_accesses` node accesses, and count the stash after each. The map is
/// filled to half its capacity first, by inserts that count like any other
/// operation.
pub fn simulate_stash_occupancy(
    capacity: usize,
    workload: StashWorkload,
    node_accesses: u64,
    seed: u64,
) -> Result<StashOccupancyRun> {
    if capacity < 4 {
        bail!("the stash simulation needs a capacity of at least 4");
    }
    let mut map = SimulatedMap::new(capacity, seed)?;
    let mut rng = ChaCha20Rng::seed_from_u64(seed ^ 0x57a5);
    let capacity_keys = capacity as u64;
    let half = capacity_keys / 2;
    let mut stored = 0usize;
    let overflowed = match run_workload(
        &mut map,
        &mut rng,
        workload,
        node_accesses,
        capacity_keys,
        half,
        &mut stored,
    ) {
        Ok(()) => false,
        Err(error) if is_stash_overflow(&error) => true,
        Err(error) => return Err(error),
    };
    let trim = |histogram: &[u64]| {
        let used = histogram
            .iter()
            .rposition(|samples| *samples != 0)
            .map_or(0, |last| last + 1);
        histogram.get(..used).unwrap_or(&[]).to_vec()
    };
    Ok(StashOccupancyRun {
        capacity,
        workload: workload.label(),
        seed,
        avl_height: map.shape.avl_height,
        nodes_an_operation_returns: tree_put_accesses(map.shape.avl_height),
        stash_bound: map.shape.stash_bound,
        operations: map.operations,
        node_accesses: map.store.node_accesses,
        stored_keys: stored,
        within_operation: trim(&map.store.within_operation),
        after_operation: trim(&map.store.after_operation),
        overflowed,
    })
}

fn run_workload(
    map: &mut SimulatedMap,
    rng: &mut ChaCha20Rng,
    workload: StashWorkload,
    node_accesses: u64,
    capacity_keys: u64,
    half: u64,
    stored: &mut usize,
) -> Result<()> {
    // Keys 1..=half, in a random order: a map half full.
    let mut keys: Vec<u64> = (1..=half).collect();
    for index in (1..keys.len()).rev() {
        keys.swap(index, rng.gen_range(0..=index));
    }
    for key in &keys {
        map.put(*key, rng.gen_range(1..1_000_000))?;
        *stored += 1;
    }
    // A run makes whole operations, so it may end a put's accesses past its
    // target.
    let done = |map: &SimulatedMap| map.store.node_accesses >= node_accesses;
    match workload {
        StashWorkload::Random => {
            // Present keys by presence bit, so that the stored count follows.
            let mut present = vec![false; capacity_keys as usize + 1];
            for key in &keys {
                present[*key as usize] = true;
            }
            while !done(map) {
                let key = rng.gen_range(1..=capacity_keys);
                if rng.gen_bool(0.5) {
                    let found = map.get(key)?;
                    if found != present[key as usize] {
                        bail!("the simulated map lost or invented key {key}");
                    }
                } else if rng.gen_bool(0.25) {
                    map.put(key, 0)?;
                    if std::mem::replace(&mut present[key as usize], false) {
                        *stored -= 1;
                    }
                } else {
                    map.put(key, rng.gen_range(1..1_000_000))?;
                    if !std::mem::replace(&mut present[key as usize], true) {
                        *stored += 1;
                    }
                }
            }
        }
        StashWorkload::RepeatedKey => {
            let key = keys.first().copied().unwrap_or(1);
            while !done(map) {
                if !map.get(key)? {
                    bail!("the simulated map lost key {key}");
                }
                map.put(key, rng.gen_range(1..1_000_000))?;
            }
        }
        StashWorkload::InsertAndDelete => {
            let high = capacity_keys - capacity_keys / 10;
            let mut live: VecDeque<u64> = keys.iter().copied().collect();
            let mut next_key = half + 1;
            'churn: loop {
                while (live.len() as u64) < high {
                    if done(map) {
                        break 'churn;
                    }
                    map.put(next_key, rng.gen_range(1..1_000_000))?;
                    live.push_back(next_key);
                    next_key += 1;
                    *stored += 1;
                }
                while (live.len() as u64) > half {
                    if done(map) {
                        break 'churn;
                    }
                    let Some(key) = live.pop_front() else {
                        break;
                    };
                    map.put(key, 0)?;
                    *stored -= 1;
                }
            }
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{simulate_stash_occupancy, StashWorkload};

    /// Every workload runs on a small map without an overflow, counts a
    /// stash occupancy for every node access and operation, and repeats from
    /// its seed. A map no larger than the Path ORAM cap has a stash as large
    /// as itself.
    #[test]
    fn the_stash_simulation_counts_every_access_and_repeats_from_its_seed() {
        for workload in StashWorkload::ALL {
            let run = simulate_stash_occupancy(16, workload, 400, 7).unwrap();
            assert!(!run.overflowed);
            assert_eq!(run.stash_bound, 16);
            assert_eq!(run.nodes_an_operation_returns, 3 * run.avl_height + 1);
            assert!(run.node_accesses >= 400);
            let after: u64 = run.after_operation.iter().sum();
            let within: u64 = run.within_operation.iter().sum();
            assert_eq!(after, run.operations);
            // Every access but each operation's last is counted within it.
            assert_eq!(within + after, run.node_accesses);
            assert!(run.within_operation.len() <= run.stash_bound + 1);
            let again = simulate_stash_occupancy(16, workload, 400, 7).unwrap();
            assert_eq!(again.within_operation, run.within_operation);
            assert_eq!(again.after_operation, run.after_operation);
        }
        let one = simulate_stash_occupancy(16, StashWorkload::Random, 400, 7).unwrap();
        let other = simulate_stash_occupancy(16, StashWorkload::Random, 400, 8).unwrap();
        assert_ne!(
            (other.within_operation, other.after_operation),
            (one.within_operation, one.after_operation)
        );
        assert!(simulate_stash_occupancy(2, StashWorkload::Random, 10, 1).is_err());
    }
}
