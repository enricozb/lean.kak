use clap::Parser;
use kakoune::{args::KakouneArgs, error::Result};

#[derive(Parser)]
struct Args {
  #[command(flatten)]
  kakoune: KakouneArgs,
}

#[tokio::main]
async fn main() -> Result<()> {
  let args = Args::parse();
  let kakoune = args.kakoune.into_session_with_tracing("lean.kak").await?;

  tracing::trace!("testing a trace message");
  tracing::debug!("testing a debug message");
  tracing::info!("testing a info message");
  tracing::warn!("testing a warn message");
  tracing::error!("testing a error message");

  Ok(())
}
