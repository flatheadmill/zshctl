## Free Synopsis with Every Set of Options
<!-- # opt/# arg declarations are the source of truth for OPTIONS, completions, and the default SYNOPSIS -->

Most commands do not need a hand-written synopsis. Write the options and arguments clearly, and `zshctl` can assemble the SYNOPSIS from the same markup it already uses for the OPTIONS section and completions.

A leaf command usually has three bits of help before the MAN DOWN! body: a short description, positional arguments, and options. Here is the shape of `acrectl secret get`, a command that extracts a 1Password item as JSON, YAML, or shell-escaped values.

```markdown
# desc -- extract infrastructure secrets as JSON, YAML or shell
Extract one or more fields from one or more `acrectl` managed 1Password vault
items.

Write them to standard out as JSON or YAML as well as various shell compatible
formats.
# arg -- <vault/item>
# opt help
Display help for `acrectl secret get`.
# opt any
Allow extracting values from any 1Password item, not only items tagged as
infrastructure secrets.
# opt format -- <format>
Specify the export format for the extracted secrets.
    * json -- Write the extracted secrets to standard out as a single JSON object.
    * yaml -- Write the extracted secrets to standard out as a single YAML object.
    * sh -- Write the extracted secrets to standard out as shell escaped values.
# man
## DESCRIPTION
`acrectl secret get` prints a single infrastructure secret to standard out.

## OPTIONS
> options
```

The `# arg` line names what the command consumes. The `# opt` lines name the switches the parser already knows how to take. A bare option like `any` is a flag; an option with a tail like `format -- <format>` hands the synopsis a value to show.

The angle-bracket value is not groff and it is not prose. It is a small value notation. You can write a plain placeholder:

```markdown
# opt output -- <file>
```

Or you can show common values:

```markdown
# opt format -- <json | yaml | sh>
```

Angle brackets make a placeholder, and the parser does not look inside them for structure. `<json | yaml | sh>` is a single label, its interior rendered as you wrote it save for the padding trimmed against the brackets, not three alternatives the parser pulled apart — the pipe is only punctuation because the angle brackets made the whole thing opaque. Parentheses are a different matter, one the next section gets to.

The list beneath the option body is still the better place to explain what the values mean; the value notation only says what kind of thing goes there. So prefer a plain `<format>` and let the list carry the meaning, reaching for `<json | yaml | sh>` only when the values are short enough that showing them reads clearer than naming them. The list also feeds fallback completions, because the help file is already the source of truth. We try not to make the user repeat themselves. Users have other hobbies.

From the declarations above, `zshctl` assembles this SYNOPSIS:

```text
SYNOPSIS
       acrectl secret get [-a | --any] [-f | --format <format>] <vault/item>

       acrectl secret get [-h | --help]
```

The command name comes from the framework. The short option names come from the argument parser. The long option names, value tails, and positional arguments come from the help declarations. The option descriptions still render in the OPTIONS section, and the list terms still feed completions when the command has no better answer.

That is the ordinary path. You write good declarations and get a correct synopsis for free. Correct is not the same as literary. It is only correct. Sometimes that is exactly what you want.

## Bring Your Own Synopsis
<!-- explicit synopsis fences let authors make editorial choices in MAN DOWN! -->

The synopsis is an editorial surface, not a complete specification of the parser.

`git commit` does not try to show every possible invocation in its synopsis. It shows the shapes a reader needs first. It may show `-a` and not `--all`. It may omit an option from SYNOPSIS entirely while still documenting it in OPTIONS. Those are not parser facts. They are writing choices.

The generated synopsis cannot make those choices for you. It sees declarations and assembles a faithful shape from them. When you want to choose what the reader sees first, write the synopsis yourself inside the MAN DOWN! body.

Use a fenced `synopsis` block:

````markdown
# man
## SYNOPSIS
```synopsis
[-a | --any] [-f | --format <format>] <vault/item>
[-h | --help]
```

## DESCRIPTION
`acrectl secret get` prints a single infrastructure secret to standard out.
````

The command name is supplied by `zshctl`. Do not write it in the block. Each line is one form of the invocation. The block above renders as:

```text
SYNOPSIS
       acrectl secret get [-a | --any] [-f | --format <format>] <vault/item>

       acrectl secret get [-h | --help]
```

Put nothing but forms in the block. The SYNOPSIS is the invocation and nothing else — a paragraph that wanders into a `## SYNOPSIS` section, around the block or in place of it, is ignored, and prose finds its home in DESCRIPTION.

The notation is the one Git uses in its own documentation, and it is mostly four shapes.

Square brackets make a piece optional:

```synopsis
[-a]
```

Parentheses group syntax — here an optional prefix of `amend` or `reword`, a colon, then a commit:

```synopsis
[(amend|reword):]<commit>
```

Angle brackets make a placeholder, a stand-in for a value the reader supplies:

```synopsis
<file>
```

Three dots repeat whatever they touch:

```synopsis
<file>...
```

That is the rule worth carrying out of both sections: the container decides how hard the parser looks. Parentheses and brackets hold structure the parser reads; angle brackets hold a label it leaves alone. So `(json | yaml | sh)` is grammar, three alternatives, while `<json | yaml | sh>` is one placeholder with a pipe in its name.

The vertical bar separates alternatives, and the space around it is yours to set. Let them breathe when they are options a reader chooses between:

```synopsis
-q | --quiet
```

Pack them tight when they are a value grammar that reads as one piece:

```synopsis
--track[=(direct|inherit)]
```

That tightness is not a mode you switch on; it is just adjacency. `amend|reword` renders tight because you typed it tight, `-q | --quiet` renders open because you typed it open. The shape you wrote is the shape that renders, so `zshctl` never has to guess what you meant by a space, and you never have to wonder what it did with one.

When a MAN DOWN! body contains an explicit `synopsis` block, it replaces the auto-generated synopsis. The OPTIONS section remains exhaustive. This is the split to remember: SYNOPSIS is what you choose to show first; OPTIONS is where you tell the whole story.

MAN DOWN! hosts the synopsis notation the same way Perl hosts a regular expression. The notation has its own rules and its own parser, but it belongs where the author is already writing the page.
