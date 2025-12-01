pub mod args;
pub mod error;
mod escape;
mod kakscripts;
mod tracing;

use std::fmt::Display;

use nix::sys::stat::Mode;
use tempfile::TempDir;
use tokio::{
  io::{AsyncReadExt, AsyncWriteExt},
  net::unix::pipe::OpenOptions,
  process::{Child, ChildStdin, Command},
};

use crate::{
  error::{Error, Result},
  escape::EscapedString,
};

/// A running kakoune session.
pub struct Kakoune {
  session: String,
}

impl Kakoune {
  /// Returns a new kakoune instance and checks that `session` is an existing
  /// kakoune session.
  ///
  /// # Errors
  ///
  /// This function returns an error if `session` is not an active kakoune
  /// session.
  pub async fn new(session: String) -> Result<Self> {
    let kakoune = Self::new_unchecked(session);
    kakoune.validate_session().await?;

    Ok(kakoune)
  }

  /// Returns a new kakoune instance without validating `session`.
  #[must_use]
  pub fn new_unchecked(session: String) -> Self {
    Self { session }
  }

  #[must_use]
  pub fn session(&self) -> &str {
    &self.session
  }

  /// Returns the value of a global option from the kakoune session.
  ///
  /// # Errors
  ///
  /// This function returns an error if the commands could not be sent to
  /// kakoune for some reason.
  pub async fn get_option(&self, option: impl Display) -> Result<String> {
    self.get_expansion(format!("%opt{{{option}}}")).await
  }

  /// Returns the value of a value expansion from the kakoune session.
  ///
  /// # Errors
  ///
  /// This function returns an error if the commands could not be sent to
  /// kakoune for some reason.
  pub async fn get_value(&self, value: impl Display) -> Result<String> {
    self.get_expansion(format!("%val{{{value}}}")).await
  }

  /// Echo's the provided `messages` to the kakoune server's debug buffer. Each
  /// element in `messages` will be provided as a separate argument to a single
  /// `echo -debug` command.
  ///
  /// # Errors
  ///
  /// This function returns an error if the commands could not be sent to
  /// kakoune for some reason.
  pub async fn debug(&self, messages: impl IntoIterator<Item = &EscapedString>) -> Result<()> {
    let messages = messages
      .into_iter()
      .map(ToString::to_string)
      .collect::<Vec<String>>()
      .join(" ");
    let command = format!("echo -debug {messages}");

    self.send_commands([command]).await
  }

  /// Sends [`commands`] separated by newlines to the kakoune server.
  ///
  /// # Errors
  ///
  /// This function returns an error if the commands could not be sent to
  /// kakoune for some reason.
  pub async fn send_commands(&self, commands: impl IntoIterator<Item = impl AsRef<str>>) -> Result<()> {
    let (mut child, mut stdin) = self.spawn()?;

    for command in commands {
      stdin
        .write_all(command.as_ref().as_bytes())
        .await
        .map_err(Error::Write)?;
      stdin.write_all(b"\n").await.map_err(Error::Write)?;
    }

    drop(stdin);
    child.wait().await.map_err(Error::Wait)?;

    Ok(())
  }

  /// Returns an `Err` if `session` is not an active kakoune session.
  async fn validate_session(&self) -> Result<()> {
    let (mut child, stdin) = self.spawn()?;

    drop(stdin);

    let valid = child.wait().await.map_err(Error::Write)?.success();

    if valid {
      Ok(())
    } else {
      Err(Error::InvalidSession(self.session.clone()))
    }
  }

  /// Returns the value of an expansion from the kakoune session.
  async fn get_expansion(&self, expansion: impl Display) -> Result<String> {
    const FIFO_RECEIVER_FILENAME: &str = "option-receiver";

    let tempdir = TempDir::new().map_err(Error::TempDir)?;
    let fifo_receiver_path = tempdir.path().join(FIFO_RECEIVER_FILENAME);
    let fifo_receiver_str = EscapedString::from(fifo_receiver_path.display().to_string());
    let command = indoc::formatdoc! {
      "try %{{
        echo -to-file {fifo_receiver_str} {expansion}
      }} catch %{{
        echo -to-file {fifo_receiver_str} ''
      }}"
    };

    nix::unistd::mkfifo(&fifo_receiver_path, Mode::S_IRWXU).map_err(Error::CreateFifo)?;
    let mut reader = OpenOptions::new()
      .open_receiver(fifo_receiver_path)
      .map_err(Error::OpenFifo)?;

    self.send_commands([command]).await?;

    let mut option_value = String::new();
    reader
      .read_to_string(&mut option_value)
      .await
      .map_err(Error::ReadFifo)?;

    Ok(option_value)
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
}
