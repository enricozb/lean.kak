use std::{fmt::Display, sync::OnceLock};

use derive_more::{Constructor, Display};

use crate::{
  Kakoune,
  error::{Error, Result},
  escape::EscapedString,
};

pub static KAKOUNE_LOGGER: OnceLock<Logger> = OnceLock::new();

/// A logger which logs messages along with a module string to a kakoune
/// session. These logs will appear in the `*debug*` buffer.
///
/// Only logs at level `level` or above will be sent to kakoune.
#[derive(Constructor)]
pub struct Logger {
  kakoune: Kakoune,
  level: Level,
  module: EscapedString,
}

impl Logger {
  /// Logs the `message` with log level `level` using to this logger.
  ///
  /// # Errors
  ///
  /// This function will return an error if commands could not be sent to
  /// kakoune for some reason.
  pub async fn log(&self, level: Level, message: &EscapedString) -> Result<()> {
    if level < self.level {
      return Ok(());
    }

    let level = EscapedString::new_unchecked(format!("{level}:"));

    self.kakoune.debug([&level, &self.module, message]).await
  }
}

#[derive(PartialEq, Eq, PartialOrd, Ord, Display)]
pub enum Level {
  #[display("TRACE")]
  Trace,
  #[display("DEBUG")]
  Debug,
  #[display("INFO")]
  Info,
  #[display("WARN")]
  Warn,
  #[display("ERROR")]
  Error,
}

/// Initializes logging to a kakoune `session`, with a `module` string to print
/// alongside any logs. This must be called before any of the logging macros
/// are called.
///
/// Only logs at level `level` or above will be sent to kakoune.
///
/// # Errors
///
/// This function returns an error if it is called more than once.
pub async fn init<S: Display>(session: String, level: Level, module: S) -> Result<()> {
  if KAKOUNE_LOGGER.get().is_some() {
    return Err(Error::LoggingAlreadyInitialized);
  }

  let kakoune = Kakoune::new(session);
  let module = EscapedString::from(format!("({module})"));
  let logger = Logger::new(kakoune, level, module);

  logger.kakoune.init().await?;
  KAKOUNE_LOGGER.get_or_init(|| logger);

  Ok(())
}

/// Logs the `message` with log level `level` using the global kakoune logger.
///
/// [`init`] must be called first before calling this function.
///
/// # Errors
///
/// This function will return an error if commands could not be sent to
/// kakoune for some reason.
pub async fn log<S: Into<EscapedString>>(level: Level, message: S) -> Result<()> {
  let logger = KAKOUNE_LOGGER.get().ok_or(Error::LoggingUninitialized)?;
  let message = message.into();

  logger.log(level, &message).await
}
