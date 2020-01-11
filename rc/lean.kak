# Detection
# ‾‾‾‾‾‾‾‾‾

hook global BufCreate .*[.](lean) %{
  set-option buffer filetype lean

  map buffer normal = ': lean-unicode-replace<ret>' \
    -docstring 'lean unicode replace'

  map buffer user r ': lean-line-eval<ret>' \
    -docstring 'run lean code up to current line'
  map buffer user c ': prompt "function: " lean-check<ret>' \
    -docstring 'check lean function and show type'
  map buffer user q ': lean-clear-outputs<ret>' \
    -docstring 'clear any lean outputs'

  # LaTeX / Unicode support
  set-option buffer formatcmd %{
    python3 -c "
import sys

replacements = [('∣', 'mid'), ('≤', 'le'), ('≥', 'ge'), ('≡', 'equiv'),
                ('≈', 'approx'), ('≠', 'ne'), ('¬', 'lnot'), ('∧', 'land'),
                ('∨', 'lor'), ('∩', 'cap'), ('∪', 'cup'),
                ('∘', 'circ'), ('→', 'to'), ('→', 'implies'), ('↔', 'iff'),
                ('∀', 'forall'), ('∃', 'exists'), ('λ', 'lambda'),
                ('Π', 'Pi'), ('Σ', 'Sigma'), ('×', 'times'), ('⊎', 'union'),
                ('ℕ', 'N'), ('ℤ', 'Z'), ('ℚ', 'Q'), ('ℝ', 'R'),
                ('⟨', '<'), ('⟩', '>'), ('α', 'alpha'), ('β', 'beta'),
                ('∅', 'empty'), ('⊆', 'subseteq'), ('∈', 'in'), ('∉', 'notin'),
                ('γ', 'gamma'), ('▸', 'subst'), ('₀', '0'), ('₁', '1'), ('₂', '2'),
                ('₃', '3'), ('₄', '4'), ('₅', '5'), ('₆', '6'), ('₇', '7')]

content = sys.stdin.read()

def replace(content):
  for unicode, ascii in replacements:
    # this is a '\\' in python, since kak replaces this to a double slash
    content = content.replace('\\\\' + ascii, unicode)
  return content

s_1 = replace(content)
s_2 = s_1.replace('/-~kak-lean-saving-cursor~-/', '')
s_3 = replace(s_2)

# if s_1 != s_3 then a replacement was possible after removing
# /-~kak-lean-saving-cursor~-/ this means that the cursor is inside a
# replacement. we find the index of the first difference between the two
# strings, and add back the /-~kak...~-/ string to s_3
if s_1 != s_3:
  diff_i = [(i, c1, c2) for i, (c1, c2) in enumerate(zip(s_1, s_3)) if c1 != c2][0]
  s_3 = s_3[:diff_i[0]] + '/-~kak-lean-saving-cursor~-/' + s_3[diff_i[0]:]
  print(s_3, end='')

else:
  print(s_1, end='')
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
    operators='≠|<|>|≤|≥|¬|<=|>=|∣|⁻¹|⬝|▸|\+|\*|-|/|\^|&|\||λ|fun |→|×|∃|∀|Π|←|#|@|->|∼|↔|/|=|<->|/\\|\\/|∧|∨|>>=|>>'
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

  define-command lean-unicode-replace %{
    execute-keys 'i/-~kak-lean-saving-cursor~-/<esc>'
    format
    set-register / buffer "/-~kak-lean-saving-cursor~-/"
    execute-keys nd
  }

  define-command lean-clear-outputs %{
    try %{
      evaluate-commands -save-regs '/' -draft %{
        set-register / buffer "\n/-~.*~-/"
        execute-keys nd
      }
    }
  }

  # Inline evaluation
  define-command lean-line-eval %{
    # clean up previous invocation
    evaluate-commands -draft %{
      lean-clear-outputs

      # comment out rest of file & save
      execute-keys o/-<esc>gjo-/<esc>
      execute-keys :w<ret>
    }
    evaluate-commands -no-hooks %{
      # clean up commented section without moving cursor
      execute-keys -draft j<a-x>dgj<a-x>d<ret>

      execute-keys %sh{
        tmpfile_output=$(mktemp)

        # populate output
        if lean "$kak_buffile" >$tmpfile_output 2>/dev/null; then
          if [ -s $tmpfile_output ]; then
            echo "o/-~<ret>~-/<esc>kl"
            echo "<a-!>cat $tmpfile_output | tail -1<ret>"
          else
            echo "<a-;>;<esc>: echo -markup '{green} [ran with no errors]'<ret>"
          fi
        else
          echo "o/-~<ret>~-/<esc>kl"
          echo "<a-!>cat $tmpfile_output<ret>"
          echo "<esc>: echo -markup '{red} [error: see log]'<ret>"
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
        echo "echo -markup {red}[error: does '''$kak_text''' exist?]"
      fi
    }
  }
}}
