**Authoring Notes**

Gotchas and idioms found while writing zshctl commands, captured as they burn so the next window does not rediscover them the hard way.

---

**A zshctl boolean flag is always declared, so test its value with `(( ))`, not `[[ -v ]]`.** `args` emits `typeset o_document` for every `-bx` flag whether or not it was passed, so `[[ -v o_document ]]` reads true even when the flag is absent and the branch fires on every run. Arithmetic truth is the test, matching how zshctl's own `completion.zsh` reads its booleans. Reserve `[[ -v o_x ]]` for `-s` string options, which are declared only when a value is actually parsed.

```zsh
if (( o_document )); then     # right: 1 when passed, 0/empty otherwise
if [[ -v o_document ]]; then  # wrong: always true, args pre-declared it
```

---

**One `args` type flag carries many specs; repeating the flag silently drops the later ones.** Group every boolean under a single `-bx` and every string under a single `-s`, the way `acrectl sbom` writes `-s o,output c,container`. Repeat the flag and only the first group registers &mdash; the second flag's options become unknown directives at parse time.

```zsh
args -bx h,help d,document -s c,channel t,thread         # right
args -bx h,help -bx d,document -s c,channel -s t,thread  # wrong: --document unknown
```
