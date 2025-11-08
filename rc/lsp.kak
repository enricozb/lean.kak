# ---------------------------------- commands ----------------------------------

define-command lean-lsp-start %{
  evaluate-commands %sh{
    if [ -n "$kak_opt_lean_lsp_pid" ]; then
      printf "%s\n" "fail 'lean-lsp already running, pid=$kak_opt_lean_lsp_pid'"
      exit
    fi

    lean_lsp_out_dir=$(mktemp -d "/tmp/lean-lsp.XXXXXX")

    if [ -z "$lean_lsp_out_dir" ]; then
      printf "%s\n" "fail 'failed to create lean-lsp output directory'"
      exit
    fi

    printf "%s\n" "set-option global lean_lsp_out_dir %{$lean_lsp_out_dir}"

    ( lean-lsp serve >"$lean_lsp_out_dir/out" 2>"$lean_lsp_out_dir/err" ) &
    lean_lsp_pid=$!

    printf "%s\n" "set-option global lean_lsp_pid $lean_lsp_pid"
  }

  lean-lsp new

  lean-lsp-process-notifications
  lean-lsp-global-hooks
}

define-command lean-lsp-stop %{
  evaluate-commands %sh{
    if [ -z "$kak_opt_lean_lsp_pid" ]; then
      printf "%s\n" "fail 'lean-lsp not running'"
      exit
    fi

    kill "$kak_opt_lean_lsp_pid"

    rm -r "$kak_opt_lean_lsp_out_dir"
  }

  remove-hooks global lean-lsp
}


# ------------------------------- hidden options -------------------------------

declare-option \
  -docstring 'process id of the lean-lsp, empty if lean-lsp is not running' \
  str lean_lsp_pid

declare-option \
  -docstring 'directory of lean-lsp output, empty if lean-lsp is not running' \
  str lean_lsp_out_dir

declare-option -docstring 'processing state of lines' \
  line-specs lean_lsp_processing_lines

declare-option -docstring 'diagnostic information to show in the buffers' \
  range-specs lean_lsp_diagnostics


# ------------------------------ hidden commands -------------------------------

define-command -hidden lean-lsp -params .. %{
  nop %sh{ lean-lsp "$@" }
}

define-command -hidden lean-lsp-process-notifications %{
  nop %sh{
    (
      # required env vars: $kak_session
      nu --commands '
        lean-lsp notifications
        | lines
        | each {|line|
          let notification = $line | from json

          match $notification.method {
            "$/lean/fileProgress" => {
              let file = ($notification.params.textDocument.uri | url parse).path

              let line_specs = $notification.params.processing
                | each {|block|
                  let range = $block.range.start.line..$block.range.end.line
                  $range | each {|line| $"($line)|│"}
                }
                | flatten
                | str join " "

                $"
                  edit -existing %{($file)}
                  set-option buffer lean_lsp_processing_lines %val{timestamp} ($line_specs)
                " | kak -p $env.kak_session
            }

            "textDocument/publishDiagnostics" => {
              let file = ($notification.params.uri | url parse).path

              let diagnostics = $notification.params.diagnostics
                | each {|diagnostic|
                  let range = $diagnostic.range
                  let start = $"($range.start.line + 1).($range.start.character + 1)"
                  let end = if $range.end.character == 0 {
                    $"($range.end.line).9999"
                  } else {
                    $"($range.end.line + 1).($range.end.character)"
                  }

                  let face = match $diagnostic.severity {
                    # error
                    1 => ",,red+c"
                    # warning
                    2 => ",,yellow+c"
                    # information
                    3 => ",,cyan+c"
                    # hint
                    4 => ",,magenta+c"
                  }

                  $"($start),($end)|($face)"
                }
                | str join " "

              $"
                edit -existing %{($file)}
                set-option buffer lean_lsp_diagnostics %val{timestamp} ($diagnostics)
              " | kak -p $env.kak_session
            }
          }
        }
      '
    ) >/dev/null 2>/dev/null &
  }
}

define-command -hidden lean-lsp-buffer-highlighters %{
  add-highlighter buffer/lean-lsp group -passes colorize|move

  add-highlighter buffer/lean-lsp/processing flag-lines yellow lean_lsp_processing_lines
  add-highlighter buffer/lean-lsp/diagnostics ranges lean_lsp_diagnostics
}

define-command -hidden lean-lsp-buffer-hooks %{
  hook -group lean-lsp buffer NormalIdle .* %{
    write -force "%opt{lean_lsp_out_dir}/scratch"

    lean-lsp file change %val{buffile} --input-filepath "%opt{lean_lsp_out_dir}/scratch"
  }

  hook -group lean-lsp buffer InsertIdle .* %{
    evaluate-commands -draft echo -to-file "%opt{lean_lsp_out_dir}/scratch"

    lean-lsp file change %val{buffile} --input-filepath "%opt{lean_lsp_out_dir}/scratch"
  }
}

define-command -hidden lean-lsp-global-hooks %{
  hook -always -group lean-lsp global BufOpenFile .*\.lean %{
    lean-lsp file open %val{hook_param}

    lean-lsp-buffer-hooks
    lean-lsp-buffer-highlighters
  }

  hook -always -group lean-lsp global BufNewFile .*\.lean %{
    lean-lsp file open %val{hook_param}

    lean-lsp-buffer-hooks
    lean-lsp-buffer-highlighters
  }

  hook -once -always -group lean-lsp global KakEnd .* lean-lsp-stop
}
