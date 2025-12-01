use std::{
  borrow::Cow,
  path::{Path, PathBuf},
  str::FromStr,
};

use clap::Args;
use derive_more::Constructor;
use tokio::fs::File;
use tracing::Level;

use crate::{
  Kakoune,
  error::{Error, Result},
};

/// Arguments related to kakoune-rs tracing support.
#[derive(Args)]
pub struct TracingArgs {
  /// The maximum level to capture tracing logs for.
  ///
  /// If this is not provided, it is requested from the kakoune session through
  /// the `kakoune_rs_log_level` option.
  #[arg(long = "log-level")]
  tracing_level: Option<Level>,

  /// The temporary directory storing kakoune-rs logs.
  ///
  /// This must match the value of the global option `%opt{KAKOUNE_RS_TEMPDIR}`
  /// in the kakoune session. If the provided value is an empty string, it is
  /// considered equivalent to not providing a value at all.
  #[arg(long)]
  kakoune_rs_tempdir: Option<PathBuf>,
}

impl TracingArgs {
  pub(crate) fn into_initializer(self, kakoune: &Kakoune) -> TracingInitializer<'_> {
    TracingInitializer::new(kakoune, self)
  }
}

#[derive(Constructor)]
pub(crate) struct TracingInitializer<'kak> {
  kakoune: &'kak Kakoune,
  tracing_args: TracingArgs,
}

impl TracingInitializer<'_> {
  const KAKOUNE_RS_TEMPDIR_OPTION: &'static str = "KAKOUNE_RS_TEMPDIR";
  const KAKOUNE_RS_TRACING_LEVEL_OPTION: &'static str = "kakoune_rs_log_level";

  pub(crate) async fn init_tracing(self, module: &'static str) -> Result<Self> {
    self.run_init_kakoune_rs_logging_kakscript().await?;

    let tracing_level = self.tracing_level().await?;

    println!("using tracing-level:{tracing_level}");

    let kakoune_rs_tempdir = self.kakoune_rs_tempdir().await?;
    let kakoune_rs_logpath = kakoune_rs_tempdir.join(module);
    let kakoune_rs_logfile = File::options()
      .create(true)
      .append(true)
      .open(kakoune_rs_logpath)
      .await
      .map_err(Error::OpenLogFile)?
      .into_std()
      .await;

    self.register_log_module(module).await?;

    tracing_subscriber::fmt()
      .with_max_level(tracing_level)
      .with_writer(kakoune_rs_logfile)
      .json()
      .init();

    Ok(self)
  }

  /// Returns the tracing level.
  ///
  /// If it was not provided via [`tracing_level`], it will be retrieved
  /// from the kakoune session. In this case,
  /// [`Self::run_init_kakoune_rs_logging_kakscript`] must have been called
  /// before this function was called.
  async fn tracing_level(&self) -> Result<Level> {
    if let Some(tracing_level) = &self.tracing_args.tracing_level {
      Ok(*tracing_level)
    } else {
      let tracing_level = self.kakoune.get_option(Self::KAKOUNE_RS_TRACING_LEVEL_OPTION).await?;
      let tracing_level = Level::from_str(&tracing_level).map_err(Error::LevelFromStr)?;

      Ok(tracing_level)
    }
  }

  /// Returns the temporary directory storing kakoune-rs logs.
  ///
  /// If it was not provided via [`kakoune_rs_tempdir`], it will be retrieved
  /// from the kakoune session. In this case,
  /// [`Self::run_init_kakoune_rs_logging_kakscript`] must have been called
  /// before this function was called.
  async fn kakoune_rs_tempdir(&self) -> Result<Cow<'_, Path>> {
    if let Some(kakoune_rs_tempdir) = &self.tracing_args.kakoune_rs_tempdir
      && kakoune_rs_tempdir != ""
    {
      Ok(Cow::Borrowed(kakoune_rs_tempdir))
    } else {
      let kakoune_rs_tempdir = self.kakoune.get_option(Self::KAKOUNE_RS_TEMPDIR_OPTION).await?;

      Ok(Cow::Owned(PathBuf::from(kakoune_rs_tempdir)))
    }
  }

  /// Runs an initialization script on the kakoune server necessary for using
  /// logging functionality.
  async fn run_init_kakoune_rs_logging_kakscript(&self) -> Result<()> {
    self
      .kakoune
      .send_commands(&[crate::kakscripts::INIT_KAKOUNE_RS_LOGGING_KAKSCRIPT])
      .await
  }

  async fn register_log_module(&self, module: &'static str) -> Result<()> {
    let command = format!("register-log-module {module}");

    self.kakoune.send_commands(&[command]).await?;

    Ok(())
  }
}
