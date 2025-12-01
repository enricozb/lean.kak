use thiserror::Error as ThisError;

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, ThisError)]
pub enum Error {
  #[error("invalid session: {0}")]
  InvalidSession(String),
  #[error("failed to run kak -p: {0}")]
  Spawn(std::io::Error),
  #[error("failed to open child stdin")]
  ChildStdin,
  #[error("failed to write to kak -p process: {0}")]
  Write(std::io::Error),
  #[error("kak -p process did not exit successfully: {0}")]
  Wait(std::io::Error),

  #[error("failed to parse log level from str: {0}")]
  LevelFromStr(tracing::metadata::ParseLevelError),

  #[error("failed to create temporary directory: {0}")]
  TempDir(std::io::Error),

  #[error("failed to open log file: {0}")]
  OpenLogFile(std::io::Error),
  #[error("failed to set tracing global default: {0}")]
  SetGlobalDefault(#[from] tracing::dispatcher::SetGlobalDefaultError),

  #[error("failed to create fifo for option: {0}")]
  CreateFifo(nix::errno::Errno),
  #[error("failed to open fifo for option: {0}")]
  OpenFifo(std::io::Error),
  #[error("failed to read fifo for option: {0}")]
  ReadFifo(std::io::Error),

  #[error("kakoune logging was already initialized")]
  LoggingAlreadyInitialized,
  #[error("kakoune logging was not initialized")]
  LoggingUninitialized,
}
