use thiserror::Error as ThisError;

pub type Result<T> = std::result::Result<T, Error>;

#[derive(Debug, ThisError)]
pub enum Error {
  #[error("failed to run kak -p: {0}")]
  Spawn(std::io::Error),
  #[error("failed to open child stdin")]
  ChildStdin,
  #[error("failed to write to kak -p process: {0}")]
  Write(std::io::Error),
  #[error("kak -p process did not exit successfully: {0}")]
  Wait(std::io::Error),
}
