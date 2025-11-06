# `zshctl`

`zshctl` in a framework for creating command-line programs in Zsh.

**Argumentitive**: An alternative argument parser that handles advanced
argument types like negations and key values that creates variables with the
appropriate Zsh type, integer, scalar, array or associative array.

**Helpful**: Create man-formatted help using a subset of Markdown.

**Zsh completions**: Completions for Zsh driven by the command heirarchy and
argument parser. Completions can be generated from the command heirarchy, the
argument parser for options, the help markup, or through a completion function
or all othe above.

**Cached completions**: Networked completions can be cached for a short time,
the cache can be invalidated, long running cached completions will display a
spinner for the entertainment of the user.

**Bash completions**: Almost as good as the Zsh completions with caching and
spinners and all the `readline` foibles addressed.

**Zshctl library**: Indented `heredoc` with optional `printf` formatting,
`abend` and `warn` for `printf` or `heredoc` based errors, `pocket` to scoop
up standard input and output of process or function, `tactac` for a more
managable alternative to `|` pipes, `struct` for nested associative arrays,
`block` for tool-native error reporting.

**Shebangable**: Create a program `fooctl` using `#!/usr/bin/env zshctl` and
you can in turn create programs using `#!/usr/bin/env fooctl`.

**Extensible**: Link new commands into your program using `zshctl extend
link`.

## Help authoring
`zshctl` includes a help system that will display man formatted context
sensitive help.

Help is written using a subset of Markdown simpilfied to support the
formatting available in man pages. I call the language MAN DOWN!

MAN DOWN! only supports bold, which expressed as backticks instead of
asterisks, italic, and two heading levels, and definition lists instead of
bullet or numbered lists.

Bold is a backtick because bold is used to indicate program or command names,
which is what the backtick generally does, so really it's the same as
Markdown, backticks means inline keywords, but that means that there is no
room for bold. If you want to emphasize something, you should use italics.

Heading 1 is used to divide the sections of the MAN DOWN! file. Heading 4 is
used for an inclusion mechanism. This is much like the Markdown-as-XML format
that is so popular with today's AI slopmentation.

MAN DOWN! does not supprt bullet lists nor numbered lists. These are rarely
used in `man` pages. When you see them, someone has used a tool like Pandoc to
generate a `man` page that is mostly roff. Bullet lists and numbered lists are
not part of `man(7)`.

MAN DOWN! does supports definition lists which are common in man pages.
Nesting is not univeral, yet. A definition list in an argument description
will nest, but there's no way to create that double nesteing in the main body.

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
`zshctl` programs have a command path where real operations take place at the
leaves of the commands. You're going to find that at branch commands you tend
to write general purpose documentation and users are going to have to scroll
past it to see the available commands. This bothers you and you think you want
to have a shorter description and then an addendum, but that goes against the
recommendations of
[`man-page(7)`](https://man7.org/linux/man-pages/man7/man-pages.7.html).
Describe your program, it's purpose, it's rationale, and it's caveats with
some examples in the *DESCRIPTION*. Use sub-sections for outlining.

For the leaves, the commands that actually do something, you can get straght
to the point and keep the *DESCRIPTION* focused having covered the reasoning
in the branch command help.

When the user is using completion, they can get the gist from the completion
system. The user ought to be able to tab complete and run any command to see
the help. For mutating commands, display help. If a command is a listing or
report then display the listing or report, which may be all the discovery the
user needs.

## Standard library

### `warn`

Warn will print a formatted message to standard error. It does not prefix the
message with `warn:` or `warning:`, that's up to you. We prefer the format:

```
warn: message type: message details.
```

For example:

```
warn: invalid argument: `abend -c` requires an argument.
```

The message is either printf formatted or heredoc formatted based on the
arguments.

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

When called without one of the above switches or with `--` the arguments are
`printf`  formatted.

```
function {
    typeset greeting=hello
    warn -q <<'    EOF'
        warn: greeting: %s, world.
    EOF
}
```

Caveat: Like `heredoc`, you cannot use the positional array parameters in the
double-quoted heredoc.

### `catch`

The `catch` function will gather the standard out and standard err of a command
into variables specified by the user. In doing so, it will use `coproc` so you
must make sure that you have duplicated any `coproc` handles you'll need after
the call, because the `coproc` redirection operators `>&p` and `<&p` will be
closed when `catch` returns.

```
function {
    typeset out err
    catch out err echo 1
    [[ $out = 1 ]] && echo woot || echo bummer
}
```

This is useful when working with an external utility translating its error
messages into known error states.

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

*Caveat*: The `catch` function will use `coproc` so you must make sure that you
have duplicated any `coproc` handles you'll need after the call, because the
`coproc` redirection operators `>&p` and `<&p` will be closed when `catch`
returns.

Note: In for a penny, in for a pound. On occasion you think you should just
capture standard error and have standard out work normally, but you wouldn't
be able to encapsulate that into a function. If you gather standard out into a
variable, you fork a subshell and that subshell is unable to write to a
variable in the parent process. This example prints `>><<`:

```
function {
    typeset err
    typeset out=$(catch err print -u 2 warning)
    print ">>$err<<"
}
```

### `struct`

The `struct` function adds shell escaped arrays and associative arrays to an
associative array creating a struct of sorts, you can even create trees of structs.

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

The `struct` function can be used as a wire format. You can create structured
messages that include arrays and associative arrays and then serialize them
using shell quoting. You can deserialize them with word splitting.

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

The shell escaping can be used elsewhere in your code if you need to pass
arrays around, but don't want to build an associative array as a tree root.

### `splat`

When you get into the habit of using the `zshctl` argument parser in your
program functions, you run into the annoyance of calling one function from
another and having to build complicated argument lists. It's nice to be able
to call the functions with options, but it's no fun trying to pass those
arguments onto another function programmatically.

`splat` will construct a command invocation with options where the option
values are pulled from the current dynamic scope.

Caveat: As with the other utilities that expand variables in the current
dynamic scope, you cannot use the the positional arguments `$1`, `$2`, `$3`,
etc. nor `$@.`

## Zsh-isms

Here are some Zsh-isms for used by `zshctl` that you can use in your own
`zshctl` and Zsh programs.

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

Returning values from functions, how nice it would be to have `typeset -n` but
Zsh does not. Zsh programmers avoid forks and especially avoid subshells.

I don't, because I love `coproc` best of all. I do avoid command substitution
and process substitution, though.

#### What does level four look like?

"Doctor is hurts when I do this." You can put aside whatever safety fetishes
you're carrying from the language you last saw. The dynamic scope, you can see
it in your mind's eye, that's all that matters.

You will write functions. There is no way to pass an anonymous function
around, so you're going to find yourself writing named functions with throw
away names and global scope. You will resign yourself to this.

#### `autoload -zU`

I can understand an aversion to `autoload -zU`. Every little function, even
one liners, in their own file. It doesn't seem worth it, but it is.

It is worth it because then you get a dependency mechanism. In the case of
`zshctl`, `pocket` uses `slurp` now, whereas before there was an aversion to
loading `slurp` just for `pocket` so it used `$(...)`. Don't have to think
about it.

Consider them to be programs, if that helps, and recall all the shell programs
you wrote that were just a one liner you got tired of fishing out of shell
history.

### `zslurp`

8 kilobyte buffer reads and pipes.

### `REPLY/reply`

One way of many to return from a function.

### Scope Assertions

Just like result assertions, just assert that local variables used by your
program will not be shadowed by the caller.

```
function foo {
    [[ -v _foo ]] && print -u 2 'warn: "_foo" is reserved for "foo" in the dynamic scope"
}
```

### `coproc`

Why I no longer go running off to Perl for child process handling.

### Indirection

Show that you can write to arrays and associative arrays with printf, and how
to set associative array values with `typeset` and how to read them all with

#### `${(e)}`

#### `eval` considered helpful

I'd gotten some JavaScript through `XMLHttpRequest` and I wanted to `eval` it,
but no, you're not supposed to do that, so instead I created a dynamic
endpoint and added `<script>` to the DOM that would call the endpoint and
source that. (Please don't think this is what I do for a living today.) Upon
completion I was kind of bewildered to what safety I had achived. After
meditating on it a bit, this much younger version of me realized I had achived
nothing in regards to safety other than to keep from having to explain an
`eval`.

### Day-to-day

#### `printf`

I've lost track of all the ways in which the shell will append a newline when
you don't want one.

 * `<<<` &mdash; Always appends a new line to the string value.
 * `print` &mdash; Appends a newline by default.
 * `echo` &mdash; Appends a newline by default, `echo -n` will suppress.

When in doubt, use `printf %s $value`.

#### `${(j: :)${(@qq)}}` wire format

#### `jq` tapes

Used to be that whenever I'd set out to munge JSON, I'd reach for `node`
because JSON is becomes JavaScript and I could just write recursive descent to
get through it all. Whatever objets I created I could just `JSON.stringify`
them back to the caller.

But, for these programs I'd want to use the synchronous input/output and when
you look at that it looks I don't know how to asynchronous programming in
Node.js, but that's not the case. I do know how, I just don't like Node.js.

As far as serialization goes, `jo` is going to require more typeing that
`JSON.stringify`, but it does not require more reasoning, which is what
matters.

As far as deserialization goes, once you have your JSON object in Node.js, you
have to prune it, switch on it, and so on, and that usually means writing a
handleThing, handleChildOfThing, handleChildOfTheThingThatIsAChildOfThing
where each of those may filter or reject.

I'm here to tell you, that unless your JSON is an abstract syntax tree, if it
just ordinary objects coming off the wire, then using `jq` to filter and
structure JSON into shell escaped words is six-of-one to the
half-dozen-the-other of switch statements and if/else if ladders in
JavaScript.

## Opportunties

Considering adding a logging library. There is one `barnyard` but it is
probably overreach, or else I need to develop an appreciation for
`journalctl`, as it attempts to log structured Linux messages, but what goods
is that to OS X? Real world use is greping container logs. A logging library
would simply log to standard out as logfmt or JSON, but I've never really had
a once and for all opinion about logging.

## Outgoing

Compiling, for one. Used to imagine that you could have a `zshctl` program
compile and it probably is still possible, but as an extension. There are
places where it is nice to have a complicated multi-command program in a
single file. And yet, with all the installers, I don't see why you wouldn't
just install `zshctl` and make it a single file `zshctl` program. Let us wait
for the desire before fulfilling it.
