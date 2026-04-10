use anyhow::Result;
use clap::Parser;

#[derive(Debug, Parser)]
struct Cli {
    #[arg(long, default_value = "results")]
    out_dir: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let report = mplus_probe::run_probe()?;
    mplus_probe::write_results(&cli.out_dir, &report)?;
    println!("{}", serde_json::to_string_pretty(&report)?);
    Ok(())
}
