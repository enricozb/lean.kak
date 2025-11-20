mod error;
mod escape;
mod kakscripts;
mod macros;

use tokio::{
  io::AsyncWriteExt,
  process::{Child, ChildStdin, Command},
};

use crate::{
  error::{Error, Result},
  escape::EscapedString,
};

pub struct Kakoune {
  session: String,
}

impl Kakoune {
  /// Sends [`commands`] separated by newlines to the kakoune server.
  pub async fn send_commands(&self, commands: impl IntoIterator<Item = impl AsRef<str>>) -> Result<()> {
    let (mut child, mut stdin) = self.spawn()?;

    for command in commands {
      stdin
        .write_all(command.as_ref().as_bytes())
        .await
        .map_err(Error::Write)?;
      stdin.write_all(b"\n").await.map_err(Error::Write)?;
    }

    child.wait().await.map_err(Error::Wait)?;

    Ok(())
  }

  /// Returns a newly spawned instance of `kak -p` and its stdin handle.
  fn spawn(&self) -> Result<(Child, ChildStdin)> {
    let mut child = Command::new("kak")
      .arg("-p")
      .arg(&self.session)
      .stdin(std::process::Stdio::piped())
      .stdout(std::process::Stdio::null())
      .stderr(std::process::Stdio::null())
      .spawn()
      .map_err(Error::Spawn)?;
    let stdin = child.stdin.take().ok_or(Error::ChildStdin)?;

    Ok((child, stdin))
  }

  /// Runs an initialization script on the kakoune server necessary for using
  /// logging functionality.
  pub async fn init(&self) -> Result<()> {
    self.send_commands(&[crate::kakscripts::INIT]).await
  }

  /// Prints the provided message to the kakoune server's debug buffer.
  pub async fn debug(&self, message: &EscapedString) -> Result<()> {
    let command = format!("echo -debug {message}");

    self.send_commands(&[command]).await
  }
}
