## Help authoring
`zshctl` includes a help system that will display man formatted context
sensitive help.

Help is written using a markup language I call MAN DOWN!, which is a subset of
Markdown. MAN DOWN! only supports bold, which expressed as backticks instead
of asterisks, italic, and a single heading, using Markdown's heading 2.

Bold is a backtick because bold is used to indicate program or command names,
which is what the backtick generally does, so really it's the same as
Markdown, backticks means inline keywords, but that means that there is no
room for bold. If you want to emphasize something, you should use italics.

Heading 1 is used to divide the sections of the MAN DOWN! file. Heading 3 is
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

# `warn`

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

Caveat: Like `heredoc`, you cannot use the positional array parameters in the double-quoted heredoc.

# `catch`

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

Note: In for a penny, in for a pound. On occasion you think you should just capture standard error and have standard out work normally, but you wouldn't be able to encapsulate that into a function. If you gather standard out into a variable, you fork a subshell and that subshell is unable to write to a variable in the parent process. This example prints `>><<`:

```
function {
    typeset err
    typeset out=$(catch err print -u 2 warning)
    print ">>$err<<"
}
```

# `struct`

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

# `splat`

When you get into the habit of using the `zshctl` argument parser in your program functions, you run into the annoyance of calling one function from another and having to build complicated argument lists. It's nice to be able to call the functions with options, but it's no fun trying to pass those arguments onto another function programmatically.

`splat` structures calls pulling values from variables in the local scope,
