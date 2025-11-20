use derive_more::{Deref, Display};

/// A string that is guaranteed to be parsed by kakoune as a single argument to
/// a command.
///
/// Some valid examples are:
/// - `abc`
/// - `%{a b c}`
/// - `"a ""b c"`
#[derive(Display, Deref)]
pub struct EscapedString(String);

impl EscapedString {
  const ESCAPE_CHAR: char = '§';
  const ESCAPE_DOUBLE_CHAR: &str = "§§";

  /// Creates a new escaped string by replacing all instances of
  /// [`Self::ESCAPE_CHAR`] with [`Self::ESCAPE_DOUBLE_CHAR`], and by wrapping
  /// the escaped string with `%{ESCAPE_CHAR}...{ESCAPE_CHAR}`.
  pub fn new(s: &str) -> Self {
    Self::new_unchecked(format!(
      "%{}{}{}",
      Self::ESCAPE_CHAR,
      s.replace(Self::ESCAPE_CHAR, Self::ESCAPE_DOUBLE_CHAR),
      Self::ESCAPE_CHAR,
    ))
  }

  /// Creates a new escaped string by asserting that `s` contains no instances
  /// of [`ESCAPE_DOUBLE_CHAR`].
  pub fn new_unchecked(s: String) -> Self {
    Self(s)
  }
}

impl<S: AsRef<String>> From<S> for EscapedString {
  fn from(s: S) -> Self {
    Self::new(s.as_ref())
  }
}
