use kakoune::logging::Level;

#[tokio::main]
async fn main() {
  let session = String::from("207050");

  kakoune::init_logging!(session, Level::Trace, "testing");

  kakoune::trace!("hello, world!");
  kakoune::debug!("hello, world!");
  kakoune::info!("hello, world!");
  kakoune::warn!("hello, world!");
  kakoune::error!("hello, world!");
}
