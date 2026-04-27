use anyhow::{anyhow, Result};
use std::env;
use std::fs;
use std::path::Path;

fn main() -> Result<()> {
    let mut args = env::args().skip(1);
    let summary_path = args
        .next()
        .ok_or_else(|| anyhow!("usage: render-reviewer-summary-md <reviewer_summary.json> [out_dir]"))?;
    let out_dir = args.next().unwrap_or_else(|| {
        Path::new(&summary_path)
            .parent()
            .unwrap_or_else(|| Path::new("."))
            .to_string_lossy()
            .into_owned()
    });
    let summary: serde_json::Value =
        serde_json::from_slice(&fs::read(&summary_path)?)?;
    mplus_probe::write_reviewer_summary_markdown(&out_dir, &summary)?;
    println!("rendered {}/reviewer_summary.md", out_dir);
    Ok(())
}
