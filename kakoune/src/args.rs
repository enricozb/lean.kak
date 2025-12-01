use clap::Args;

use crate::{Kakoune, error::Result, tracing::TracingArgs};

#[derive(Args)]
pub struct KakouneArgs {
  #[arg(long)]
  kakoune_session: String,

  #[command(flatten)]
  tracing_args: TracingArgs,
}

impl KakouneArgs {
  /// Returns the kakoune session, without any tracing support.
  ///
  /// # Errors
  ///
  /// This function returns an error if [`kakoune_session`] is not a valid
  /// kakoune session.
  pub async fn into_session(self) -> Result<Kakoune> {
    Kakoune::new(self.kakoune_session).await
  }

  /// Returns the kakoune session, with tracing support scoped under `module`.
  ///
  /// # Errors
  ///
  /// This function returns an error if [`kakoune_session`] is not a valid
  /// kakoune session.
  pub async fn into_session_with_tracing(self, module: &'static str) -> Result<Kakoune> {
    let kakoune = Kakoune::new(self.kakoune_session).await?;
    let tracing_initializer = self.tracing_args.into_initializer(&kakoune);

    tracing_initializer.init_tracing(module).await?;

    Ok(kakoune)
  }
}
