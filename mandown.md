# `zshctl`
<!-- CLI framework for Zsh: argument parsing, man-formatted help, completions, and utility library -->

`zshctl` in a framework for creating command-line programs in Zsh.

**Argumentitive**: An alternative argument parser that handles advanced argument types like negations and key values that creates variables with the appropriate Zsh type, integer, scalar, array or associative array.

**Helpful**: Create man-formatted help using a subset of Markdown.

**Zsh completions**: Completions for Zsh driven by the command heirarchy and argument parser. Completions can be generated from the command heirarchy, the argument parser for options, the help markup, or through a completion function or all othe above.

**Cached completions**: Networked completions can be cached for a short time, the cache can be invalidated, long running cached completions will display a spinner for the entertainment of the user.

**Bash completions**: Almost as good as the Zsh completions with caching and spinners and all the `readline` foibles addressed.

**Zshctl library**: Indented `heredoc` with optional `printf` formatting, `abend` and `warn` for `printf` or `heredoc` based errors, `pocket` to scoop up standard input and output of process or function, `tactac` for a more managable alternative to `|` pipes, `struct` for nested associative arrays, `block` for tool-native error reporting.

**Shebangable**: Create a program `fooctl` using `#!/usr/bin/env zshctl` and you can in turn create programs using `#!/usr/bin/env fooctl`.

**Extensible**: Link new commands into your program using `zshctl extend link`.

## Help authoring
<!-- MAN DOWN! format: Markdown subset for man pages with backtick-bold, italic, two heading levels, definition lists -->

`zshctl` includes a help system that will display man formatted context sensitive help.

Help is written using a subset of Markdown simpilfied to support the formatting available in man pages. I call the language MAN DOWN!

MAN DOWN! only supports bold, which expressed as backticks instead of asterisks, italic, and two heading levels, and definition lists instead of bullet or numbered lists.

Bold is a backtick because bold is used to indicate program or command names, which is what the backtick generally does, so really it's the same as Markdown, backticks means inline keywords, but that means that there is no room for bold. If you want to emphasize something, you should use italics.

Heading 1 is used to divide the sections of the MAN DOWN! file. Heading 4 is used for an inclusion mechanism. This is much like the Markdown-as-XML format that is so popular with today's AI slopmentation.

MAN DOWN! does not supprt bullet lists nor numbered lists. These are rarely used in `man` pages. When you see them, someone has used a tool like Pandoc to generate a `man` page that is mostly roff. Bullet lists and numbered lists are not part of `man(7)`.

MAN DOWN! does supports definition lists which are common in man pages. Nesting is not univeral, yet. A definition list in an argument description will nest, but there's no way to create that double nesteing in the main body.

What follows is a complete MAN DOWN! file definition.

````markdown
# terse
display version
# verbose
Display the current version of `zshctl`.
# arg format -- < terse | verbose | shell | json >
Display a verbose version as test, JSON, or shell escaped.
    * terse -- Display version number only.
    * verbose -- Display version number and release date.
    * shell -- Display shell esacped version number and release date as UNIX epoch.
    * json -- Display version number and release date as UNIX epoch as JSON.
# arg help
Help for `zshctl`.
# man
## DESCRIPTION
Displays the current version of `zshctl`.

The version can be formatted for programmatic consumption from shell or a JSON
parser like `jq`.

Consuming the version as JSON.

```shell
acrectl version --format json | jq -r '.release_date'
```

Consuming the version as shell escaped variables in Zsh.

```
typeset -A version=( "${(@QA)${(z)$(acrectl version --format shell)}}" )
print $version[release_date]
```
## OPTIONS
### options
````
## Help authoring style
<!-- branch commands get full rationale in DESCRIPTION, leaf commands get focused help -->

`zshctl` programs have a command path where real operations take place at the leaves of the commands. You're going to find that at branch commands you tend to write general purpose documentation and users are going to have to scroll past it to see the available commands. This bothers you and you think you want to have a shorter description and then an addendum, but that goes against the recommendations of [`man-page(7)`](https://man7.org/linux/man-pages/man7/man-pages.7.html). Describe your program, it's purpose, it's rationale, and it's caveats with some examples in the *DESCRIPTION*. Use sub-sections for outlining.

For the leaves, the commands that actually do something, you can get straght to the point and keep the *DESCRIPTION* focused having covered the reasoning in the branch command help.

When the user is using completion, they can get the gist from the completion system. The user ought to be able to tab complete and run any command to see the help. For mutating commands, display help. If a command is a listing or report then display the listing or report, which may be all the discovery the user needs.

## Standard library
<!-- utility functions: args, warn, catch/pocket, struct, splat, heredoc, block, tactac -->

### `args`
<!-- argument parser: generates eval-able code for typed variables, supports scalars, arrays, maps, booleans, counters, toggles, negatable, execute-on-match -->

The `args` function is the argument parser at the core of every `zshctl` command. It generates eval-able Zsh code that declares typed variables from command-line flags. When you see the incantation `eval "$(args ... -- "$@")"`, you are looking at option parsing.

The standard pattern for a branch command that supports completions and shows usage when invoked without arguments looks like this:

```
function :args:secret {
    eval "$(args -CU -bx h,help -- "$@")"
}
```

The global flags `-C` enables completion support and `-U` displays usage when no arguments are given. The `-bx h,help` defines a boolean (`-b`) help flag with both short (`h`) and long (`help`) forms that triggers an execute handler (`-x`) when provided. The double-dash separates the flag definitions from `$@`.

A leaf command that does real work will typically add scalar options for its parameters:

```
function :args:secret:get {
    typeset o_format=json
    eval "$(args -UC -bx h,help a,any -ds f,format -- "$@")"
}
```

Here `-ds f,format` defines a scalar (`-s`) for `--format` or `-f` that preserves the predeclared default (`-d`) when not provided. The variable will be `o_format` and it will be `json` unless the user provides `--format xml` or `-f xml`.

The `args` function generates `typeset` statements and assignments that declare variables with the `o_` prefix. A flag `--verbose` or `-v` becomes `o_verbose`. A flag `--dry-run` becomes `o_dry_run` with hyphens converted to underscores.

---

Type Flags

The type flags determine what kind of variable is created and how repeated uses of the flag are handled.

A scalar (`-s`) holds a single string value. The flag `--format json` or `--format=json` or `-f json` all assign `o_format='json'`. If not provided, the variable is unset unless you use the defined modifier (`-d`) to preserve a predeclared value.

A boolean (`-b`) is an integer that starts at 0 and becomes 1 when the flag is present. The flag `--verbose` sets `o_verbose=1`. Booleans support short flag clustering, so `-vqd` expands to `-v -q -d` and sets all three.

An array (`-a`) accumulates values across multiple uses. The flags `-i foo -i bar -i baz` produce `o_include=(foo bar baz)`. Each use appends to the array.

A map (`-A`) collects key-value pairs. The flags `--config user=alice --config role=admin` produce an associative array where `o_config[user]` is `alice` and `o_config[role]` is `admin`. The key and value can be separated by equals or space.

A counter (`-c`) is an integer that increments with each use. The flags `-vvv` produce `o_verbose=3`. This is useful for verbosity levels.

A toggle (`-t`) is an integer that flips between 0 and 1 with each use. The flags `--toggle --toggle` end at 0 because it flipped twice.

A negatable (`-!`) boolean supports `--no-` prefix for explicit negation. Define it as `-!b c,color` and the user can say `--color` to set 1 or `--no-color` to set 0. Short negation uses uppercase: `-c` sets, `-C` clears.

---

Behavior Modifiers

The behavior modifiers change how options are processed rather than what type they produce.

Defined (`-d`) preserves a predeclared default. Without it, scalars are unset when not provided. With it, the `args` function skips the declaration and only assigns if the user provides a value. Predeclare your default, add `-d`, and the variable keeps its value unless overridden.

Required (`-r`) causes an error if the option is not provided. Use sparingly; positional arguments or sensible defaults are usually better.

Execute (`-x`) triggers a handler when the flag is matched. This is for `--help` which should display help and exit rather than continue parsing. The handler is `args_error` with the function name and the word `execute`.

Interspersed (`-@`) allows flags to appear after positional arguments. Without it, the first non-flag stops parsing and everything after goes into `$@`. With it, flags are extracted wherever they appear.

---

Global Flags

The global flags affect the parser itself rather than individual options.

Completion mode (`-C`) enables the completion infrastructure. Branch commands that have subcommands need this.

Usage mode (`-U`) shows the command's usage when invoked with no arguments. This is conventional for branch commands that dispatch to subcommands.

Delegated mode (`-D`) is used by the framework internals when a command delegates to subcommands.

---

Syntax Variations

Flag definitions use the format `short,long` where short is a single character and long is the full name. The short is optional: `,verbose` defines only `--verbose` with no short form.

Values can be attached with equals (`--format=json`), separated by space (`--format json`), or attached to short flags (`-fjson`).

The double-dash (`--`) stops flag processing. Everything after it becomes positional arguments in `$@`. The pattern `-- --` means passthrough: don't parse anything, pass all arguments through.

```
function :args:rag:rg {
    eval "$(args -- -- "$@")"
}
```

This command does nothing with its arguments except make them available for the execute function to pass along.

---

For the complete reference of all patterns and the generated code for each, run `zshctl etude args`. The etude demonstrates every type, modifier, and syntax variation with actual output showing exactly what code `args` generates.

### `warn`
<!-- printf or heredoc formatted messages to stderr, three modes: single-quoted, printf-formatted, double-quoted -->

Warn will print a formatted message to standard error. It does not prefix the message with `warn:` or `warning:`, that's up to you. We prefer the format:

```
warn: message type: message details.
```

For example:

```
warn: invalid argument: `abend -c` requires an argument.
```

The message is either printf formatted or heredoc formatted based on the arguments.

When called with no arguments or `-`, it is a single-quoted heredoc.

```
function {
    warn <<'    EOF'
        warn: greeting: hello, world.
    EOF
}
```

When called with -f it is printf formatted `heredoc`.

```
function {
    warn -f hello <<'    EOF'
        warn: greeting: %s, world.
    EOF
}
```

When called with -f it is a double-quoted `heredoc`.

```
function {
    typeset greeting=hello
    warn -q <<'    EOF'
        warn: greeting: %s, world.
    EOF
}
```

When called without one of the above switches or with `--` the arguments are `printf`  formatted.

```
function {
    typeset greeting=hello
    warn -q <<'    EOF'
        warn: greeting: %s, world.
    EOF
}
```

Caveat: Like `heredoc`, you cannot use the positional array parameters in the double-quoted heredoc.

### `catch`
<!-- gather stdout/stderr into caller-provided variables using coproc, explicit contract pattern -->

The `catch` function will gather the standard out and standard err of a command into variables specified by the user. In doing so, it will use `coproc` so you must make sure that you have duplicated any `coproc` handles you'll need after the call, because the `coproc` redirection operators `>&p` and `<&p` will be closed when `catch` returns.

```
function {
    typeset out err
    catch out err echo 1
    [[ $out = 1 ]] && echo woot || echo bummer
}
```

This is useful when working with an external utility translating its error messages into known error states.

```
function docker_login {
    typeset out err
    if catch out err op read op://my_vault/my_item/my_field; then
        printf '%s' $out |
            docker login --username alan --password-stdin harbor.flatheadmill.com
    elif [[ $err = *'You are not currently signed in.'* ]]; then
        abend -c 2 'fatal: not signed in: unable to connect to 1Password'
    elif [[ $err = '"'*'" isn'\''t a vault in this account. Specify'* ]]; then
        abend -c 3 'fatal: no such vault: vault does not exist in this account'
    elif [[ $err = *'"'*'" isn'\''t an item in the "'*'" vault.'* ]]; then
        abend -c 4 'fatal: no such item: item does not exist'
    else
        abend -q <<'        EOF'
            fatal: exception: unknown 1Password error

            $(sed 's/^/  /' <<< "$err")
        EOF
    fi
}
```

It's also useful for simply panicking on an unknown error.

```
function {
    [[ -t 0 && -t 1 ]] || abend -c 2 'fatal: not a tty: must be run from the termainal'
    typeset greeting=hello out err
    catch out err vared "Edit greeting: " -p greeting ||
        abend -q <<'        EOF'
            fatal: exception: did the terminal disappear?

            $(sed 's/^/  /' <<< "$err")
        EOF
    printf '%s, world\n' $greeting
}
```

*Caveat*: The `catch` function will use `coproc` so you must make sure that you have duplicated any `coproc` handles you'll need after the call, because the `coproc` redirection operators `>&p` and `<&p` will be closed when `catch` returns.

Note: In for a penny, in for a pound. On occasion you think you should just capture standard error and have standard out work normally, but you wouldn't be able to encapsulate that into a function. If you gather standard out into a variable, you fork a subshell and that subshell is unable to write to a variable in the parent process. This example prints `>><<`:

```
function {
    typeset err
    typeset out=$(catch err print -u 2 warning)
    print ">>$err<<"
}
```

### `struct`
<!-- nested associative arrays using shell quoting as wire format, serializable between processes -->

The `struct` function adds shell escaped arrays and associative arrays to an associative array creating a struct of sorts, you can even create trees of structs.

```
function {
    typeset -A struct assoc
    struct put struct child first 1 second 2 third 3
    struct get struct child assoc
    print -r -- "${(@kv)assoc}" # prints: third 3 first 1 second 2
    struct push struct child fourth 4
    struct get struct child assoc
    print -r -- "${(@kv)assoc}" # prints: third 3 first 1 fourth 4 second 2
}
```

Internally, `struct` maintains these arrays using shell quoting.

```
function {
    typeset array=( one "two three" four )
    typeset wired="${(@qq)array}"
    typeset unwired=( "${(@QA)${(z)wired}}" )
    print ${#unwired} # prints: 3
    print -r -- "${(@q)unwired}" # prints: one two\ three four
}
```

The `struct` function can be used as a wire format. You can create structured messages that include arrays and associative arrays and then serialize them using shell quoting. You can deserialize them with word splitting.

```
function {
    coproc {
        typeset wired array=()
        typeset -A struct child
        coproc :
        struct=$( "${(@QA)${(z)$(cat)}}" )
        struct get struct child
        print -r -- $child[greeting] # prints: hello
        struct get child array
        print -r -- "${(@q)array}" # prints: one two\ three four
    }
    typeset -A struct child
    struct put child array one 'two three' four
    child[greeting]=hello
    struct put struct child "${(@kv)child}"
    print -whatever "${(@kvqq)struct}"
    coproc :
}
```

The shell escaping can be used elsewhere in your code if you need to pass arrays around, but don't want to build an associative array as a tree root.

### `splat`
<!-- construct command invocations with options pulled from dynamic scope, avoids manual argument list building -->

When you get into the habit of using the `zshctl` argument parser in your program functions, you run into the annoyance of calling one function from another and having to build complicated argument lists. It's nice to be able to call the functions with options, but it's no fun trying to pass those arguments onto another function programmatically.

`splat` will construct a command invocation with options where the option values are pulled from the current dynamic scope.

Caveat: As with the other utilities that expand variables in the current dynamic scope, you cannot use the the positional arguments `$1`, `$2`, `$3`, etc. nor `$@.`

## Zsh-isms
<!-- Zsh patterns: slurp, REPLY, autoload, frame pattern, wire format, jq tapes, subshell avoidance, eval -->

Here are some Zsh-isms for used by `zshctl` that you can use in your own `zshctl` and Zsh programs.

Pending outline.

 * slurp &mdash; 8 kilobyte buffered reads of files and pipes.
 * `REPLY`/`reply` &mdash; generic replies.
 * `[[ -v result ]]` &mdash; required return values.
 * `autoload -zU` &mdash; lazy loading functions from `fpath`.
 *  `__utility_N__` &mdash; dynamic variable naming for safe eval.
 * `"${(@QA)${$(z)frozen}}"` &mdash; serialization between processes
 * `jq` tapes &mdash; why `jq` makes Zsh my go-to for JSON
 * Subshell avoidance &mdash; why Zsh programmers contort themselves to stay in-process
 * `eval` considered helpful &mdash; contrary to general shell wisdom, Zsh makes eval useful with proper quoting
 * `${(e)}` expansion &mdash; parameter expansion with evaluation (the alternative to eval)

### Preface
<!-- no typeset -n in Zsh, avoid subshells, dynamic scope is what matters, resign to named functions -->

Returning values from functions, how nice it would be to have `typeset -n` but Zsh does not. Zsh programmers avoid forks and especially avoid subshells.

I don't, because I love `coproc` best of all. I do avoid command substitution and process substitution, though.

#### What does level four look like?
<!-- doctor it hurts pattern, dynamic scope visualization, accept named functions with global scope -->

"Doctor is hurts when I do this." You can put aside whatever safety fetishes you're carrying from the language you last saw. The dynamic scope, you can see it in your mind's eye, that's all that matters.

You will write functions. There is no way to pass an anonymous function around, so you're going to find yourself writing named functions with throw away names and global scope. You will resign yourself to this.

#### `autoload -zU`
<!-- lazy loading from fpath, one file per function enables dependency mechanism, treat as tiny programs -->

I can understand an aversion to `autoload -zU`. Every little function, even one liners, in their own file. It doesn't seem worth it, but it is.

It is worth it because then you get a dependency mechanism. In the case of `zshctl`, `pocket` uses `slurp` now, whereas before there was an aversion to loading `slurp` just for `pocket` so it used `$(...)`. Don't have to think about it.

Consider them to be programs, if that helps, and recall all the shell programs you wrote that were just a one liner you got tired of fishing out of shell history.

### `zslurp`
<!-- 8KB buffered reads via sysread, 70x faster than IFS= read -rd '' for pipes -->

8 kilobyte buffer reads and pipes.

### `REPLY/reply`
<!-- convention for function returns, but typeset -g sets least-local not global, scope chain gotchas -->

One way of many to return from a function.

### Scope Assertions
<!-- assert reserved variables won't shadow caller with [[ -v _foo ]], defensive dynamic scope -->

Just like result assertions, just assert that local variables used by your program will not be shadowed by the caller.

```
function foo {
    [[ -v _foo ]] && print -u 2 'warn: "_foo" is reserved for "foo" in the dynamic scope"
}
```

### `coproc`
<!-- bidirectional IPC without forking to Perl, handles close after use, duplicate before catch -->

Why I no longer go running off to Perl for child process handling.

### Indirection
<!-- write to arrays/associative arrays with printf and typeset, (P) expansion for indirect access -->

Show that you can write to arrays and associative arrays with printf, and how to set associative array values with `typeset` and how to read them all with

#### `${(e)}`
<!-- parameter expansion with evaluation, alternative to eval for template expansion -->

#### `eval` considered helpful
<!-- contrary to shell wisdom, Zsh quoting makes eval safe and useful, avoiding eval achieves nothing -->

I'd gotten some JavaScript through `XMLHttpRequest` and I wanted to `eval` it, but no, you're not supposed to do that, so instead I created a dynamic endpoint and added `<script>` to the DOM that would call the endpoint and source that. (Please don't think this is what I do for a living today.) Upon completion I was kind of bewildered to what safety I had achived. After meditating on it a bit, this much younger version of me realized I had achived nothing in regards to safety other than to keep from having to explain an `eval`.

### Day-to-day
<!-- practical patterns: printf for newline control, wire format serialization, jq for JSON munging -->

#### `printf`
<!-- newline control: <<< always appends, print appends by default, use printf %s when in doubt -->

I've lost track of all the ways in which the shell will append a newline when you don't want one.

 * `<<<` &mdash; Always appends a new line to the string value.
 * `print` &mdash; Appends a newline by default.
 * `echo` &mdash; Appends a newline by default, `echo -n` will suppress.

When in doubt, use `printf %s $value`.

#### `${(j: :)${(@qq)}}` wire format
<!-- shell quoting as serialization: ${(@qq)} to encode, ${(@QA)${(z)}} to decode, passes through pipes -->

#### `jq` tapes
<!-- filter JSON into shell words with jq, six-of-one to JavaScript switch statements, jo for output -->

Used to be that whenever I'd set out to munge JSON, I'd reach for `node` because JSON is becomes JavaScript and I could just write recursive descent to get through it all. Whatever objets I created I could just `JSON.stringify` them back to the caller.

But, for these programs I'd want to use the synchronous input/output and when you look at that it looks I don't know how to asynchronous programming in Node.js, but that's not the case. I do know how, I just don't like Node.js.

As far as serialization goes, `jo` is going to require more typeing that `JSON.stringify`, but it does not require more reasoning, which is what matters.

As far as deserialization goes, once you have your JSON object in Node.js, you have to prune it, switch on it, and so on, and that usually means writing a handleThing, handleChildOfThing, handleChildOfTheThingThatIsAChildOfThing where each of those may filter or reject.

I'm here to tell you, that unless your JSON is an abstract syntax tree, if it just ordinary objects coming off the wire, then using `jq` to filter and structure JSON into shell escaped words is six-of-one to the half-dozen-the-other of switch statements and if/else if ladders in JavaScript.

The tape pattern is this: build one honkin' long flat array in `jq`, serialize it with `@sh`, deserialize it in Zsh with `${(@QA)${(z)...}}`, then eat it like Pacman with a while loop and shifting.

The naive approach outputs JSONL, one array per line:

```jq
# WRONG - outputs JSONL, now you're parsing line-by-line in Zsh
.[] | [.n, .role, .content] | @sh
```

This fights the shell. You end up doing multiple `jq` calls or reading JSONL line-by-line, which is what you were trying to avoid by not using Node.js.

The Pacman approach builds one array and eats it whole:

```jq
# RIGHT - one array, serialize whole, consume by shifting
[
    length,
    (.[] | .n, .role, .content, (.links | length), .links[])
] | @sh
```

One array. One `@sh`. One `${(@QA)${(z)...}}`. Then shift through it:

```zsh
tape=( "${(@QA)${(z)$(jq -r '...' $jsonl)}}" )
set -- "${(@)tape}"
integer total=$1; shift

while (( $# )); do
    n=$1 role=$2 content=$3 link_count=$4
    shift 4
    links=( "${(@)@[1,$link_count]}" )
    shift $link_count
    # ... process entry
done
```

Variable-length records work because you embed the count before the items. Read count, shift that many, repeat. Wakka wakka through the tape until it's empty.

For a working example, see `claudectl chat transcript` which parses Grok and Gemini API responses into conversation turns with variable-length citation arrays.

## Opportunities
<!-- potential additions: logging library for logfmt/JSON, undecided opinion about logging -->

Considering adding a logging library. There is one `barnyard` but it is probably overreach, or else I need to develop an appreciation for `journalctl`, as it attempts to log structured Linux messages, but what goods is that to OS X? Real world use is greping container logs. A logging library would simply log to standard out as logfmt or JSON, but I've never really had a once and for all opinion about logging.

## Outgoing
<!-- features not being pursued: compile to single file, wait for desire before fulfilling -->

Compiling, for one. Used to imagine that you could have a `zshctl` program compile and it probably is still possible, but as an extension. There are places where it is nice to have a complicated multi-command program in a single file. And yet, with all the installers, I don't see why you wouldn't just install `zshctl` and make it a single file `zshctl` program. Let us wait for the desire before fulfilling it.

## Incoming
<!-- pending additions: trim function for whitespace stripping -->

Notes for `trim`. `trim` because it's so common and so annoying to write out the pattern substitution.

https://stackoverflow.com/questions/68259691/trimming-whitespace-from-the-ends-of-a-string-in-zsh

```
trimmed=${(*)${(*)var/#[[:space:]]#}/%[[:space:]]#}
```
