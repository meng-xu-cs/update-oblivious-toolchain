use anyhow::Result;

fn main() -> Result<()> {
    let report = mplus_probe::run_probe()?;
    println!("{}", serde_json::to_string_pretty(&report)?);
    Ok(())
}
