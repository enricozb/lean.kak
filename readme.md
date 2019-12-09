# kak-lean

A bare-bones kakoune plugin for the Lean Theorem Prover files.

## Keybindings
- **=** format all latex-style input to unicode. For example,
```latex
(\forall x, p x \land q x)
```
will become
````lean
(∀ x, p x ∧ q x)
```
- **,r** runs the file up to the line the cursor is on, and prints the output
of the lean theorem prover. If there is an error, the entire output of lean
is printed.
- **,c** prompts the user for some input and runs `#check <input>`. This can't
depend on any imports in the file unfortunately.

## To Do
See [todo](todo.md).
