pub const INIT: &str = indoc::indoc!{r#"
  try %{
    # this will fail if logging is not initialized
    nop %opt{kakoune_rs_logging_initialized}
  } catch %{
    declare-option -hidden bool kakoune_rs_logging_initialized true
    echo -debug "initializing kakoune-rs logging"
    evaluate-commands -buffer *debug* %{
      add-highlighter buffer/kakoune-rs-trace regex '^(TRACE):' 1:green
      add-highlighter buffer/kakoune-rs-debug regex '^(DEBUG):' 1:cyan
      add-highlighter buffer/kakoune-rs-info  regex '^(INFO):'  1:blue
      add-highlighter buffer/kakoune-rs-warn  regex '^(WARN):'  1:yellow
      add-highlighter buffer/kakoune-rs-error regex '^(ERROR):' 1:red
    }
  }
"#};
