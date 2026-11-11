//! A replay of the private scheme's AVL map for its Lean model.
//!
//! Runs random operations on the runtime's oblivious AVL map (`tree_get` and
//! `tree_put`) over an in-memory bucket store and records, for each, its
//! result, the kind of each node access (real or dummy), the map's size, and
//! the tree it leaves: every node's key, value and the height its parent's
//! pointer records, in preorder. `checkPathOramAvlMapReplay` replays the same
//! operations on the Lean model (`UOToolchain/PathOramAvlMap.lean`) and
//! compares all of them. The pointer level the model does not have is checked
//! here after every operation: every block is on its leaf's path and stored
//! once, every pointer names its node's current leaf, the free list and the
//! tree together hold every node, and the stash is within its bound.

use super::generated_oram_codecs::{
    bucket_on_leaf_path, clone_tree_node, tree_avl_height, tree_bootstrap_nodes, tree_get,
    tree_place_nodes, tree_put, tree_put_accesses, TreeAccessRecord, TreeHeader, TreeLink,
    TreeNode, TreePathStore, TreeShape, TreeStash,
};
use anyhow::{anyhow, bail, Result};
use rand::{Rng, SeedableRng};
use rand_chacha::ChaCha20Rng;
use serde::Serialize;
use std::collections::BTreeMap;
use uo_core::{ScalarType, Type, Value};

/// The replay's schema tag, which the Lean checker requires.
pub const PATH_ORAM_AVL_MAP_REPLAY_SCHEMA: &str = "uo-path-oram-avl-map-replay-v1";

const BLOCKS_PER_BUCKET: usize = 5;

/// One operation and what the runtime did.
#[derive(Debug, Serialize)]
pub struct AvlMapReplayOperation {
    /// A get (`true`) or a put.
    pub get: bool,
    pub key: u64,
    /// The put's value; zero deletes.
    pub value: u64,
    /// Whether the put applies (a masked put walks but changes nothing).
    pub apply: bool,
    /// A get's value, zero if absent.
    pub result_value: u64,
    /// Whether a get found the key.
    pub found: bool,
    /// Whether a put found the map full.
    pub overflow: bool,
    /// Each node access, in order: real or dummy.
    pub real: Vec<bool>,
    /// The map's size afterwards.
    pub size: usize,
    /// The tree afterwards, in preorder: `[key, value, height]` per node and
    /// `null` per absent child.
    pub tree: Vec<Option<[u64; 3]>>,
}

/// The operations of one map, from empty.
#[derive(Debug, Serialize)]
pub struct AvlMapReplayRun {
    pub capacity: usize,
    pub seed: u64,
    pub avl_height: usize,
    pub operations: Vec<AvlMapReplayOperation>,
}

#[derive(Debug, Serialize)]
pub struct AvlMapReplay {
    pub schema: &'static str,
    pub runs: Vec<AvlMapReplayRun>,
}

struct ReplayStore {
    buckets: Vec<Box<[TreeNode]>>,
    empty: TreeNode,
    leaf_count: usize,
    coins: ChaCha20Rng,
    real: Vec<bool>,
}

impl TreePathStore for ReplayStore {
    fn coin(&mut self) -> Result<usize> {
        Ok(self.coins.gen_range(0..self.leaf_count))
    }

    fn begin_access(&mut self, _first: bool) -> Result<()> {
        Ok(())
    }

    fn load_bucket(&mut self, index: usize, stash: &mut TreeStash) -> Result<()> {
        let bucket = self
            .buckets
            .get_mut(index)
            .ok_or_else(|| anyhow!("replay bucket {index} missing"))?;
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
            .ok_or_else(|| anyhow!("replay bucket {index} missing"))?;
        *bucket = blocks.iter().map(clone_tree_node).collect();
        Ok(())
    }

    fn end_operation(&mut self, _header: &TreeHeader, _stash: &TreeStash) -> Result<()> {
        Ok(())
    }

    fn end_access(&mut self, record: &TreeAccessRecord) -> Result<()> {
        self.real.push(record.real);
        Ok(())
    }
}

struct ReplayMap {
    shape: TreeShape,
    store: ReplayStore,
    stash: TreeStash,
    header: TreeHeader,
}

fn uint_type() -> Type {
    Type::Scalar(ScalarType::Uint(256))
}

fn small_uint(value: &Value) -> Result<u64> {
    let bytes = value
        .as_uint()
        .ok_or_else(|| anyhow!("replay entry is not a uint"))?
        .to_be_bytes();
    let (high, low) = bytes.split_at(24);
    if high.iter().any(|byte| *byte != 0) {
        bail!("replay entry exceeds 64 bits");
    }
    let mut word = [0u8; 8];
    word.copy_from_slice(low);
    Ok(u64::from_be_bytes(word))
}

impl ReplayMap {
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
            stash_bound: capacity.clamp(1, 114 + tree_put_accesses(avl_height)),
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
        Ok(Self {
            shape,
            store: ReplayStore {
                buckets,
                empty,
                leaf_count,
                coins: ChaCha20Rng::seed_from_u64(seed ^ 0x5eed),
                real: Vec::new(),
            },
            stash,
            header,
        })
    }

    /// The tree in preorder, after checking the pointer level.
    fn snapshot(&self) -> Result<Vec<Option<[u64; 3]>>> {
        let shape = &self.shape;
        let mut nodes: BTreeMap<usize, &TreeNode> = BTreeMap::new();
        for (index, bucket) in self.store.buckets.iter().enumerate() {
            for block in bucket.iter().filter(|block| block.occupied) {
                if !bucket_on_leaf_path(shape.leaf_count, index, block.leaf) {
                    bail!("node {} is off its leaf's path", block.id);
                }
                if nodes.insert(block.id, block).is_some() {
                    bail!("node {} is stored twice", block.id);
                }
            }
        }
        for block in self
            .stash
            .blocks
            .iter()
            .take(self.stash.persistent)
            .filter(|block| block.occupied)
        {
            if nodes.insert(block.id, block).is_some() {
                bail!("node {} is stored twice", block.id);
            }
        }
        if nodes.len() != shape.capacity {
            bail!("{} of {} nodes are stored", nodes.len(), shape.capacity);
        }
        if self.stash.len() > shape.stash_bound {
            bail!("the stash is over its bound");
        }
        let mut free = 0usize;
        let mut link = self.header.free.duplicate();
        while link.present {
            let node = nodes
                .get(&link.id)
                .ok_or_else(|| anyhow!("free-list pointer to missing node {}", link.id))?;
            if node.leaf != link.leaf || node.in_tree {
                bail!("free-list pointer to node {} is wrong", link.id);
            }
            free += 1;
            if free > shape.capacity {
                bail!("the free list cycles");
            }
            link = node.left.duplicate();
        }
        let mut tree = Vec::new();
        let mut in_tree = 0usize;
        preorder(
            &nodes,
            &self.header.root,
            shape.capacity,
            &mut tree,
            &mut in_tree,
        )?;
        if free + in_tree != shape.capacity {
            bail!(
                "the tree ({in_tree}) and the free list ({free}) do not hold every node ({})",
                shape.capacity
            );
        }
        Ok(tree)
    }
}

fn preorder(
    nodes: &BTreeMap<usize, &TreeNode>,
    link: &TreeLink,
    capacity: usize,
    out: &mut Vec<Option<[u64; 3]>>,
    count: &mut usize,
) -> Result<()> {
    if !link.present {
        out.push(None);
        return Ok(());
    }
    let node = nodes
        .get(&link.id)
        .ok_or_else(|| anyhow!("tree pointer to missing node {}", link.id))?;
    if node.leaf != link.leaf {
        bail!("tree pointer to node {} has a stale leaf", link.id);
    }
    if !node.in_tree {
        bail!("tree pointer to free node {}", link.id);
    }
    *count += 1;
    if *count > capacity {
        bail!("the tree cycles");
    }
    out.push(Some([
        small_uint(&node.key)?,
        small_uint(&node.value)?,
        u64::try_from(link.height)?,
    ]));
    preorder(nodes, &node.left, capacity, out, count)?;
    preorder(nodes, &node.right, capacity, out, count)
}

fn replay_run(capacity: usize, seed: u64, operations: usize) -> Result<AvlMapReplayRun> {
    let mut map = ReplayMap::new(capacity, seed)?;
    let mut rng = ChaCha20Rng::seed_from_u64(seed.wrapping_mul(0x9e37_79b9_7f4a_7c15) ^ 0xa11);
    let key_space = 2 * capacity as u64 + 3;
    let mut recorded = Vec::with_capacity(operations);
    for _ in 0..operations {
        let key = rng.gen_range(1..=key_space);
        let roll: f64 = rng.gen();
        map.store.real.clear();
        let operation = if roll < 0.3 {
            let (value, found, failed) = tree_get(
                &map.shape,
                &mut map.store,
                &mut map.stash,
                &mut map.header,
                &Value::uint(key),
            )?;
            if failed {
                bail!("a get failed at capacity {capacity}");
            }
            AvlMapReplayOperation {
                get: true,
                key,
                value: 0,
                apply: false,
                result_value: small_uint(&value)?,
                found,
                overflow: false,
                real: std::mem::take(&mut map.store.real),
                size: map.header.size,
                tree: map.snapshot()?,
            }
        } else {
            let value = if roll < 0.55 {
                0
            } else {
                rng.gen_range(1..1000u64)
            };
            let apply = rng.gen::<f64>() < 0.9;
            let (overflow, failed) = tree_put(
                &map.shape,
                &mut map.store,
                &mut map.stash,
                &mut map.header,
                &Value::uint(key),
                &Value::uint(value),
                apply,
            )?;
            if failed {
                bail!("a put failed at capacity {capacity}");
            }
            AvlMapReplayOperation {
                get: false,
                key,
                value,
                apply,
                result_value: 0,
                found: false,
                overflow,
                real: std::mem::take(&mut map.store.real),
                size: map.header.size,
                tree: map.snapshot()?,
            }
        };
        recorded.push(operation);
    }
    Ok(AvlMapReplayRun {
        capacity,
        seed,
        avl_height: map.shape.avl_height,
        operations: recorded,
    })
}

/// Replay `operations` random operations on an empty map of each capacity,
/// once per seed.
pub fn path_oram_avl_map_replay(
    capacities: &[usize],
    seeds: &[u64],
    operations: usize,
) -> Result<AvlMapReplay> {
    let mut runs = Vec::with_capacity(capacities.len() * seeds.len());
    for &capacity in capacities {
        for &seed in seeds {
            runs.push(replay_run(capacity, seed, operations)?);
        }
    }
    Ok(AvlMapReplay {
        schema: PATH_ORAM_AVL_MAP_REPLAY_SCHEMA,
        runs,
    })
}
