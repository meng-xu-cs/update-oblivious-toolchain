#[cfg(feature = "diagnostics")]
use anyhow::bail;
#[cfg(feature = "diagnostics")]
use anyhow::Result;
#[cfg(feature = "diagnostics")]
use uo_core::RuntimeOramLeafScaffoldWitness;

#[derive(Debug, Default)]
pub struct PathOramFreshCoinPlan {
    entries: Box<[PathOramFreshCoinEntry]>,
}

impl Drop for PathOramFreshCoinPlan {
    fn drop(&mut self) {
        for entry in self.entries.iter_mut() {
            for coin in entry.coins.iter_mut() {
                *coin = 0;
            }
        }
    }
}

#[derive(Debug)]
pub(in crate::runtime) struct PathOramFreshCoinEntry {
    object_id: u32,
    coins: Box<[usize]>,
}

impl Drop for PathOramFreshCoinEntry {
    fn drop(&mut self) {
        for coin in self.coins.iter_mut() {
            *coin = 0;
        }
    }
}

impl PathOramFreshCoinEntry {
    #[cfg(feature = "diagnostics")]
    fn new(object_id: u32, coins: Box<[usize]>) -> Self {
        Self { object_id, coins }
    }

    pub(in crate::runtime) fn into_parts(mut self) -> (u32, Box<[usize]>) {
        (self.object_id, std::mem::take(&mut self.coins))
    }
}

impl PathOramFreshCoinPlan {
    #[cfg(feature = "diagnostics")]
    pub fn new() -> Self {
        Self::default()
    }

    #[cfg(feature = "diagnostics")]
    pub fn insert_object_coins(&mut self, object_id: u32, coins: Vec<usize>) -> Option<Vec<usize>> {
        let mut entries = std::mem::take(&mut self.entries).into_vec();
        let replacement = coins.into_boxed_slice();
        let previous = match entries.binary_search_by_key(&object_id, |entry| entry.object_id) {
            Ok(index) => Some(std::mem::replace(&mut entries[index].coins, replacement).into_vec()),
            Err(index) => {
                entries.insert(index, PathOramFreshCoinEntry::new(object_id, replacement));
                None
            }
        };
        self.entries = entries.into_boxed_slice();
        previous
    }

    #[cfg(feature = "diagnostics")]
    pub fn from_scaffold_and_values(
        scaffold: &[RuntimeOramLeafScaffoldWitness],
        values: &[usize],
    ) -> Result<Self> {
        if scaffold.len() != values.len() {
            bail!(
                "path-ORAM fresh-coin scaffold length {} does not match value length {}",
                scaffold.len(),
                values.len()
            );
        }
        let mut coin_schedule = scaffold
            .iter()
            .zip(values.iter())
            .map(|(step, value)| (step.object_id, *value))
            .collect::<Vec<_>>();
        coin_schedule.sort_by_key(|(object_id, _)| *object_id);
        let mut entries = Vec::new();
        let mut current_object_id = None;
        let mut current_coins = Vec::new();
        for (object_id, value) in coin_schedule {
            match current_object_id {
                Some(active_object_id) if active_object_id == object_id => {
                    current_coins.push(value);
                }
                Some(active_object_id) => {
                    entries.push(PathOramFreshCoinEntry::new(
                        active_object_id,
                        std::mem::take(&mut current_coins).into_boxed_slice(),
                    ));
                    current_object_id = Some(object_id);
                    current_coins.push(value);
                }
                None => {
                    current_object_id = Some(object_id);
                    current_coins.push(value);
                }
            }
        }
        if let Some(active_object_id) = current_object_id {
            entries.push(PathOramFreshCoinEntry::new(
                active_object_id,
                current_coins.into_boxed_slice(),
            ));
        }
        Ok(Self {
            entries: entries.into_boxed_slice(),
        })
    }

    pub(in crate::runtime) fn into_entries(mut self) -> Box<[PathOramFreshCoinEntry]> {
        std::mem::take(&mut self.entries)
    }
}
