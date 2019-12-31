# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*[.](lean) %{
  set-option buffer filetype lean

  map buffer normal = \
    ': lean-unicode-replace %val{cursor_line} %val{cursor_char_column}<ret>' \
    -docstring 'lean unicode replace'

  map buffer user r ': lean-line-eval<ret>' \
    -docstring 'run lean code up to current line'
  map buffer user c ': prompt "function: " lean-check<ret>' \
    -docstring 'check lean function and show type'

  # LaTeX / Unicode support
  set-option buffer formatcmd %{
    python3 -c "
import sys

replacements = [('∣', r'\mid'), ('≤', r'\le'), ('≥', r'\ge'), ('≡', r'\equiv'),
                ('≈', r'\approx'), ('≠', r'\ne'), ('¬', r'\lnot'),
                ('∧', r'\land'), ('∨', r'\lor'), ('∩', r'\cap'),
                ('∪', r'\cup'), ('∘', r'\circ'), ('→', r'\to'),
                ('→', r'\implies'), ('↔', r'\iff'), ('∀', r'\forall'),
                ('∃', r'\exists'), ('λ', r'\lambda'), ('Π', r'\Pi'),
                ('Σ', r'\Sigma'), ('×', r'\times'), ('⊎', r'\union'),
                ('ℕ', r'\N'), ('ℤ', r'\Z'), ('ℚ', r'\Q'), ('ℝ', r'\R'),
                ('⟨', r'\<'), ('⟩', r'\>'), ('α', r'\alpha'),
                ('₀', r'\0'), ('₁', r'\1'), ('₂', r'\2'), ('₃', r'\3'),
                ('₄', r'\4'), ('₅', r'\5'), ('₆', r'\6'), ('₇', r'\7')]

for line in sys.stdin:
  for unicode, ascii in replacements:
    line = line.replace(ascii, unicode)

  print(line, end='')
    "
  }
}

# Initialization
# ‾‾‾‾‾‾‾‾‾‾‾‾‾‾

hook global WinSetOption filetype=lean %{
  require-module lean

  set-option window static_words %opt{lean_static_words}

  hook -once -always window WinSetOption filetype=.* %{ remove-hooks window lean-.+ }
}

hook -group lean-highlight global WinSetOption filetype=lean %{
    add-highlighter window/lean ref lean
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/lean }
}


provide-module lean %{ evaluate-commands -no-hooks %{

  # Highlighters & Completion
  # ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

  add-highlighter shared/lean regions
  add-highlighter shared/lean/code default-region group

  add-highlighter shared/lean/onelinecomment region '--' '$' fill comment
  add-highlighter shared/lean/multilinecomment region -recurse /- /- -/ fill comment
  add-highlighter shared/lean/string region '"'   (?<!\\)(\\\\)*"  fill string

  evaluate-commands %sh{
    operators='≠|<|>|≤|≥|¬|<=|>=|∣|⁻¹|⬝|▸|\+|\*|-|/|\^|&|\||λ|fun|→|×|∃|∀|Π|←|#|@|->|∼|↔|/|=|<->|/\\|\\/|∧|∨|>>=|>>'
    types='Type Sort Prop'
    commands='print exit eval check reduce'
    keywords='import prelude protected private noncomputable
              def definition renaming hiding parameter parameters begin
              conjecture constant constants lemma variable variables theory
              theorem notation example open axiom inductive instance class
              with structure record universe universes alias help reserve
              match infix infixl infixr notation postfix prefix meta run_cmd
              do end this suppose using namespace section fields attribute
              local set_option extends include omit calc have show suffices
              by in at let if then else assume assert take obtain from'

    join() { sep=$2; eval set -- $1; IFS="$sep"; echo "$*"; }

    printf "%s\n" "declare-option str-list lean_static_words '$(join "${keywords}" " ")'"

    printf "%s\n" "
        add-highlighter shared/lean/code/ regex '\b($(join "${keywords}" '|'))\b' 0:keyword
        add-highlighter shared/lean/code/ regex '#($(join "${commands}" '|'))\b' 0:keyword
        add-highlighter shared/lean/code/ regex '\b($(join "${types}" '|'))\b' 0:value
        add-highlighter shared/lean/code/ regex '(${operators})' 0:operator
        add-highlighter shared/lean/code/ regex '(:=)' 0:rgb:ff4444
    "
  }

  define-command lean-unicode-replace -params 2 %{
    format
    # return to line and highlight it
    execute-keys "%arg{1}gx"
    execute-keys %sh{
      if [ ${#kak_reg_dot} -lt ${2} ]; then
        echo ";"
      else
        echo ";gh${2}lh"
      fi
    }
  }

  # Inline evaluation
  define-command lean-line-eval %{
    # clean up previous invocation
    evaluate-commands -draft %{
      try %{
        set-register / buffer "\n/-~.*~-/"
        execute-keys nd
      }
    }
    evaluate-commands -no-hooks %{
      execute-keys glGk
      execute-keys %sh{
        tmpfile_input=$(mktemp);
        tmpfile_output=$(mktemp);
        echo "$kak_reg_dot" > $tmpfile_input;
        echo "o/-~<ret>~-/<esc>kl"
        if lean $tmpfile_input >$tmpfile_output 2>/dev/null; then
          echo "<a-!>cat $tmpfile_output | tail -1<ret>"
        else
          echo "<a-!>cat $tmpfile_output<ret>"
          echo "<esc>: echo -markup '{red} [error]'<ret>"
        fi
      }
    }
  }

  # Inline evaluation
  define-command lean-check %{
    evaluate-commands -no-hooks %sh{
      tmpfile_input=$(mktemp);
      tmpfile_output=$(mktemp);
      echo "#check $kak_text" > $tmpfile_input;
      if lean $tmpfile_input >$tmpfile_output 2>/dev/null; then
        echo "echo '$(cat $tmpfile_output | tail -1)'"
      else
        echo "echo -markup {red}'lean error'"
      fi
    }
  }
}}
