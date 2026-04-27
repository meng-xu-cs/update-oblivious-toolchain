use anyhow::{anyhow, Result};
use std::env;

fn main() -> Result<()> {
    let out_dir = env::args()
        .nth(1)
        .ok_or_else(|| anyhow!("usage: regenerate-reproducibility-manifest <out_dir>"))?;
    mplus_probe::write_reproducibility_manifest(&out_dir)?;
    println!("regenerated {}/reproducibility_manifest.json", out_dir);
    Ok(())
}
