use std::{
  borrow::Cow,
  path::{Path, PathBuf},
};

use clap::Args;
use derive_more::Constructor;
use tokio::fs::File;
use tracing::Level;

use crate::{
  Kakoune,
  error::{Error, Result},
};

#[derive(Args)]
pub struct KakouneArgs {
  #[arg(long)]
  kakoune_session: String,

  #[command(flatten)]
  logging_args: LoggingArgs,
}

#[derive(Args)]
pub struct LoggingArgs {
  #[arg(long = "log-level", default_value_t = Level::INFO)]
  tracing_level: Level,

  /// The temporary directory storing kakoune-rs logs.
  ///
  /// This must match the value of the global option `%opt{KAKOUNE_RS_TEMPDIR}`
  /// in the kakoune session. If the provided value is an empty string, it is
  /// considered equivalent to not providing a value at all.
  #[arg(long)]
  kakoune_rs_tempdir: Option<PathBuf>,
}

impl KakouneArgs {
  pub async fn connect(self) -> Result<KakouneConnection> {
    let kakoune = Kakoune::new(self.kakoune_session).await?;
    let connection = KakouneConnection::new(kakoune, self.logging_args);

    Ok(connection)
  }
}

#[derive(Constructor)]
pub struct KakouneConnection {
  kakoune: Kakoune,
  logging_args: LoggingArgs,
}

impl KakouneConnection {
  const KAKOUNE_RS_TEMPDIR_OPTION: &str = "KAKOUNE_RS_TEMPDIR";

  /// Returns the kakoune session, without any tracing initialization.
  pub fn into_session(self) -> Kakoune {
    self.kakoune
  }

  pub async fn with_tracing(self, module: &'static str) -> Result<Self> {
    self.run_init_kakoune_rs_logging_kakscript().await?;

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
      .with_max_level(self.logging_args.tracing_level)
      .with_writer(kakoune_rs_logfile)
      .json()
      .init();

    Ok(self)
  }

  /// Returns the temporary directory storing kakoune-rs logs.
  ///
  /// If it was not provided via [`kakoune_rs_tempdir`], it will be retrieved
  /// from the kakoune session. In this case,
  /// [Self::run_init_kakoune_rs_logging_kakscript`] must have been called
  /// before this function was called.
  async fn kakoune_rs_tempdir(&self) -> Result<Cow<'_, Path>> {
    if let Some(kakoune_rs_tempdir) = &self.logging_args.kakoune_rs_tempdir
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
