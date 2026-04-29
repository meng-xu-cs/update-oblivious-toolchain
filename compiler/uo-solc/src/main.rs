use anyhow::Result;
use clap::{Parser, ValueEnum};

#[derive(Clone, Debug, ValueEnum)]
enum ModeArg {
    Raw,
    Uo,
}

impl From<ModeArg> for uo_core::ProgramMode {
    fn from(value: ModeArg) -> Self {
        match value {
            ModeArg::Raw => Self::Raw,
            ModeArg::Uo => Self::Uo,
        }
    }
}

#[derive(Debug, Parser)]
struct Cli {
    #[arg(long)]
    source: String,
    #[arg(long)]
    metadata: String,
    #[arg(long, value_enum)]
    mode: ModeArg,
    #[arg(long)]
    out: String,
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    let metadata_bytes = std::fs::read(&cli.metadata)?;
    let metadata: uo_core::ContractMetadata = serde_yaml::from_slice(&metadata_bytes)?;
    let artifact = uo_solc::compile_with_metadata_bytes(
        &cli.source,
        &metadata,
        &metadata_bytes,
        cli.mode.into(),
    )?;
    std::fs::write(cli.out, serde_json::to_vec_pretty(&artifact)?)?;
    Ok(())
}
