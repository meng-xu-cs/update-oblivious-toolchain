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
    let metadata: uo_core::ContractMetadata =
        serde_yaml::from_slice(&std::fs::read(&cli.metadata)?)?;
    let artifact = uo_solc::compile(&cli.source, &metadata, cli.mode.into())?;
    std::fs::write(cli.out, serde_json::to_vec_pretty(&artifact)?)?;
    Ok(())
}
