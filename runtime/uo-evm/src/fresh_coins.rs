#[cfg(feature = "diagnostics")]
use anyhow::bail;
#[cfg(feature = "diagnostics")]
use anyhow::Result;
use std::collections::BTreeMap;
#[cfg(feature = "diagnostics")]
use uo_core::RuntimeOramLeafScaffoldWitness;

#[derive(Debug, Default)]
pub struct PathOramFreshCoinPlan {
    by_object: BTreeMap<u32, Vec<usize>>,
}

impl Drop for PathOramFreshCoinPlan {
    fn drop(&mut self) {
        for coins in self.by_object.values_mut() {
            for coin in coins.iter_mut() {
                *coin = 0;
            }
        }
    }
}

impl PathOramFreshCoinPlan {
    #[cfg(feature = "diagnostics")]
    pub fn new() -> Self {
        Self::default()
    }

    #[cfg(feature = "diagnostics")]
    pub fn insert_object_coins(&mut self, object_id: u32, coins: Vec<usize>) -> Option<Vec<usize>> {
        self.by_object.insert(object_id, coins)
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
        let mut plan = Self::new();
        for (step, value) in scaffold.iter().zip(values.iter()) {
            plan.by_object
                .entry(step.object_id)
                .or_default()
                .push(*value);
        }
        Ok(plan)
    }

    pub(in crate::runtime) fn into_by_object(mut self) -> BTreeMap<u32, Vec<usize>> {
        std::mem::take(&mut self.by_object)
    }
}
