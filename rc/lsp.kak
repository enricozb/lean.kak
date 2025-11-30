# ---------------------------------- mappings ----------------------------------

declare-user-mode lean

map global lean h -docstring 'hover' ': lean-lsp-hover<ret>'

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

    (
      # TODO(enricozb): this needs to inform kak if it ever exits
      /home/enricozb/projects/personal/lean-lsp/target/release/lean-lsp serve >"$lean_lsp_out_dir/out" 2>"$lean_lsp_out_dir/err"
    ) &
    lean_lsp_pid=$!

    printf "%s\n" "set-option global lean_lsp_pid $lean_lsp_pid"
  }

  lean-lsp new --enrich-utf16-positions

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

declare-option -docstring 'lines currently being processed' \
  line-specs lean_lsp_processing_lines

declare-option -docstring 'lines with errors during processing' \
  line-specs lean_lsp_processing_error_lines

declare-option -docstring 'diagnostic highlighter range-specs' \
  range-specs lean_lsp_diagnostics_range_specs

declare-option -docstring 'latest diagnostic json notification' \
  str lean_lsp_diagnostics_json


# ------------------------------ hidden commands -------------------------------

define-command -hidden lean-lsp -params .. %{
  nop %sh{ /home/enricozb/projects/personal/lean-lsp/target/release/lean-lsp "$@" }
}

define-command -hidden lean-lsp-hover %{
  evaluate-commands %sh{
    # required env vars:
    #   $kak_buffile $kak_cursor_line $kak_cursor_column $kak_cursor_char_column
    #   $kak_opt_lean_lsp_diagnostics_json
    nu -c '
      let file = $env.kak_buffile
      let line = ($env.kak_cursor_line | into int) - 1
      let character = ($env.kak_cursor_char_column | into int) - 1
      let goals = lean-lsp info-view get-plain-goals $file --line $line --character $character | from json
      let hover = lean-lsp file hover $file --line $line --character $character | from json
      let diagnostics = $env.kak_opt_lean_lsp_diagnostics_json
        | from json
        | where { |diagnostic|
          let range = $diagnostic.range
          let start = $range.start
          let end = $range.end
          (
            ($line > $start.line or ($line == $start.line and $character >= $start.character_utf8))
            and
            ($line < $end.line or ($line == $end.line and $character < $end.character_utf8))
          )
        }
        | get message
        | str join "\n\n-----\n\n"

      mut contents = []
      if $diagnostics != "" {
        $contents ++= [$"# Diagnostics\n\n($diagnostics)"]
      }
      if $goals.result != null {
        $contents ++= [$"# Goals\n\n($goals.result.rendered)"]
      }
      if $hover.result != null {
        $contents ++= [$"# Hover\n\n($hover.result.contents.value)"]
      }
      let contents = $contents | str join "\n\n"

      $"info %{($contents)}"
    '
  }
}

define-command -hidden lean-lsp-process-notifications %{
  nop %sh{
    (
      # required env vars: $kak_session
      nu --commands '
        lean-lsp notifications
        | lines
        | each { |line|
          let notification = $line | from json

          match $notification.method {
            "$/lean/fileProgress" => {
              let file = ($notification.params.textDocument.uri | url parse).path
              let processing_char = "║"

              let info_line_specs = $notification.params.processing
                | where kind == 1 # info
                | each { |block|
                  let range = $block.range.start.line..$block.range.end.line
                  $range | each { |line| $"($line)|($processing_char)" }
                }
                | flatten
                | str join " "

              let error_line_specs = $notification.params.processing
                | where kind == 2 # info
                | each { |block|
                  let range = $block.range.start.line..$block.range.end.line
                  $range | each { |line| $"($line)|($processing_char)" }
                }
                | flatten
                | str join " "

                $"
                  edit -existing %{($file)}
                  set-option buffer lean_lsp_processing_lines %val{timestamp} ($info_line_specs)
                  set-option buffer lean_lsp_processing_error_lines %val{timestamp} ($error_line_specs)
                " | kak -p $env.kak_session
            }

            "textDocument/publishDiagnostics" => {
              let file = ($notification.params.uri | url parse).path

              let diagnostics_json = $notification.params.diagnostics | to json
              let diagnostics_range_specs = $notification.params.diagnostics
                | default false isSilent
                | where not isSilent
                | each { |diagnostic|
                  let range = $diagnostic.range
                  let start = $"($range.start.line + 1).($range.start.character_bytes + 1)"
                  let end = if $range.end.character_bytes == 0 {
                    $"($range.end.line).($range.end.previous_line_length_bytes)"
                  } else {
                    $"($range.end.line + 1).($range.end.character_bytes)"
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
                set-option buffer lean_lsp_diagnostics_json %§($diagnostics_json)§
                set-option buffer lean_lsp_diagnostics_range_specs %val{timestamp} ($diagnostics_range_specs)
              " | kak -p $env.kak_session
            }
          }
        }
      '
    ) >/dev/null 2>/dev/null &
  }
}

define-command -hidden lean-lsp-buffer-mappings %{
  map buffer normal <c-l> ': enter-user-mode lean<ret>'
}

define-command -hidden lean-lsp-buffer-highlighters %{
  add-highlighter buffer/lean-lsp group -passes colorize|move

  add-highlighter buffer/lean-lsp/processing-info flag-lines yellow lean_lsp_processing_lines
  add-highlighter buffer/lean-lsp/processing-error flag-lines red lean_lsp_processing_error_lines
  add-highlighter buffer/lean-lsp/diagnostics ranges lean_lsp_diagnostics_range_specs
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
    lean-lsp-buffer-mappings
  }

  hook -always -group lean-lsp global BufNewFile .*\.lean %{
    lean-lsp file open %val{hook_param}

    lean-lsp-buffer-hooks
    lean-lsp-buffer-highlighters
    lean-lsp-buffer-mappings
  }

  hook -once -always -group lean-lsp global KakEnd .* lean-lsp-stop
}
