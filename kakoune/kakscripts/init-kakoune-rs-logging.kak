# Initializes kakoune-rs logging support.
#
# This file can be sourced multiple times, but its commands will only run once.
#
# Each time a kakoune-rs module initializes logs on a kakoune server, this file
# will be sourced. If this file happens to be in the autoload directory of the
# kakoune server, it will also of course be sourced.
#
# This file is not implemented with provide/require-module commands, since
# providing a module with the same name multiple times raises an error.

try %{
  # Fail if kakoune-rs logging is not yet initialized.
  nop %opt{KAKOUNE_RS_LOGGING_INITIALIZED}
} catch %{
  echo -debug "initializing kakoune-rs logging"

  # global constants
  declare-option -hidden bool KAKOUNE_RS_LOGGING_INITIALIZED true
  declare-option -hidden str  KAKOUNE_RS_LOGS_FILETYPE kakoune-rs-logs
  declare-option -hidden str  KAKOUNE_RS_TEMPDIR %sh{
    mktemp --tmpdir --directory kakoune-rs-XXXXXXXX
  }

  # global vars
  declare-option -hidden str-list kakoune_rs_log_modules

  # local vars
  declare-option -hidden str kakoune_rs_module

  define-command logs -params 1 -docstring 'show the logs for a module' %{
    set-option local kakoune_rs_module %arg{1}

    edit -readonly "%opt{KAKOUNE_RS_TEMPDIR}/%opt{kakoune_rs_module}"

    set-option buffer filetype %opt{KAKOUNE_RS_LOGS_FILETYPE}
  }

  complete-command logs -menu shell-script-candidates %{
    eval "set -- $kak_quoted_opt_kakoune_rs_log_modules" ; printf '%s\n' "$@"
  }

  define-command -hidden register-log-module -params 1 \
    -docstring 'register-log-module <module>' %{

    set-option local kakoune_rs_module %arg{1}

    set-option -add global kakoune_rs_log_modules %opt{kakoune_rs_module}
  }

  hook global -group kakoune-rs-logs WinSetOption "filetype=%opt{KAKOUNE_RS_LOGS_FILETYPE}" %{
    add-highlighter buffer/kakoune-rs-trace regex 'TRACE' 0:cyan
    add-highlighter buffer/kakoune-rs-debug regex 'DEBUG' 0:green
    add-highlighter buffer/kakoune-rs-info  regex 'INFO'  0:blue
    add-highlighter buffer/kakoune-rs-warn  regex 'WARN'  0:yellow
    add-highlighter buffer/kakoune-rs-error regex 'ERROR' 0:red
  }

  hook global -group kakoune-rs-logs KakEnd .* %{
    nop %sh{ rm -r "$kak_opt_KAKOUNE_RS_TEMPDIR" }
  }
}
