hook global BufCreate .*[.](lean) %{
  set-option buffer filetype lean
}

hook global WinSetOption filetype=lean %{
  require-module lean

  set-option window static_words %opt{lean_static_words}

  add-highlighter window/lean ref lean
}

provide-module lean %§

declare-option -hidden str-list lean_static_words

add-highlighter shared/lean regions
add-highlighter shared/lean/code default-region group

add-highlighter shared/lean/onelinecomment region '--' '$' fill comment
add-highlighter shared/lean/multilinecomment region -recurse /- /- -/ fill comment
add-highlighter shared/lean/string region '"'   (?<!\\)(\\\\)*"  fill string

add-highlighter shared/lean/code/number regex [\d]+(\.\d*)? 0:value
add-highlighter shared/lean/code/sorry regex \bsorry\b 0:red

declare-option -hidden str lean_highlighters_nushell_script %{
  let types = [Type, Sort, Prop]
  let commands = [print, exit, eval, check, reduce]
  let keywords = [
    import, prelude, protected, private, noncomputable, def, definition,
    renaming, hiding, parameter, parameters, begin, conjecture, constant,
    constants, lemma, variable, variables, theory, theorem, notation,
    example, open, axiom, inductive, instance, class, with, structure,
    record, universe, universes, alias, help, reserve, match, infix,
    infixl, infixr, notation, postfix, prefix, meta, run_cmd, do, end,
    this, suppose, using, namespace, section, fields, attribute, local,
    set_option, extends, include, omit, calc, have, show, suffices, by,
    in, at, let, if, then, else, assume, assert, take, obtain, from
  ]

  print $"set-option global lean_static_words ($keywords | str join ' ')"

  print $"add-highlighter shared/lean/code/command regex '#\(($commands | str join '|')\)\\b' 0:meta"
  print $"add-highlighter shared/lean/code/keyword regex '\\b\(($keywords | str join '|')\)\\b' 0:keyword"
  print $"add-highlighter shared/lean/code/type regex '\\b\(($types | str join '|')\)\\b' 0:type"
}

evaluate-commands %sh{ nu -c "$kak_opt_lean_highlighters_nushell_script" }

§
