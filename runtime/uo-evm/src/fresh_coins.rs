#[cfg(feature = "diagnostics")]
use anyhow::bail;
#[cfg(feature = "diagnostics")]
use anyhow::Result;
#[cfg(feature = "diagnostics")]
use uo_core::{FixedBoxBuilder, RuntimeOramLeafScaffoldWitness};

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
    pub fn insert_object_coins(
        &mut self,
        object_id: u32,
        coins: Box<[usize]>,
    ) -> Result<Option<Box<[usize]>>> {
        let mut old_entries = std::mem::take(&mut self.entries);
        match old_entries.binary_search_by_key(&object_id, |entry| entry.object_id) {
            Ok(index) => {
                let Some(entry) = old_entries.get_mut(index) else {
                    bail!("fresh-coin entry index {index} missing after binary search");
                };
                let previous = std::mem::replace(&mut entry.coins, coins);
                self.entries = old_entries;
                Ok(Some(previous))
            }
            Err(index) => {
                let mut entries = FixedBoxBuilder::new(old_entries.len() + 1);
                let mut pending_coins = Some(coins);
                for (position, entry) in std::iter::IntoIterator::into_iter(old_entries).enumerate()
                {
                    if position == index {
                        let coins = pending_coins
                            .take()
                            .ok_or_else(|| anyhow::anyhow!("fresh-coin insertion repeated"))?;
                        entries.push(PathOramFreshCoinEntry::new(object_id, coins))?;
                    }
                    entries.push(entry)?;
                }
                if let Some(coins) = pending_coins.take() {
                    entries.push(PathOramFreshCoinEntry::new(object_id, coins))?;
                }
                self.entries = entries.finish()?;
                Ok(None)
            }
        }
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
        let mut coin_schedule = FixedBoxBuilder::new(scaffold.len());
        for (step, value) in scaffold.iter().zip(values.iter()) {
            coin_schedule.push((step.object_id, *value))?;
        }
        let mut coin_schedule = coin_schedule.finish()?;
        coin_schedule.sort_by_key(|(object_id, _)| *object_id);

        let mut entry_count = 0usize;
        let mut last_object_id = None;
        for (object_id, _) in coin_schedule.iter().copied() {
            if last_object_id != Some(object_id) {
                entry_count += 1;
                last_object_id = Some(object_id);
            }
        }

        let mut entries = FixedBoxBuilder::new(entry_count);
        let mut index = 0usize;
        while index < coin_schedule.len() {
            let Some((object_id, _)) = coin_schedule.get(index).copied() else {
                bail!("fresh-coin schedule index {index} missing despite length guard");
            };
            let start = index;
            loop {
                match coin_schedule.get(index) {
                    Some((candidate, _)) if *candidate == object_id => {
                        index += 1;
                    }
                    _ => break,
                }
            }
            let mut coins = FixedBoxBuilder::new(index - start);
            for (_, value) in coin_schedule.iter().skip(start).take(index - start) {
                coins.push(*value)?;
            }
            entries.push(PathOramFreshCoinEntry::new(object_id, coins.finish()?))?;
        }
        Ok(Self {
            entries: entries.finish()?,
        })
    }

    pub(in crate::runtime) fn into_entries(mut self) -> Box<[PathOramFreshCoinEntry]> {
        std::mem::take(&mut self.entries)
    }
}
