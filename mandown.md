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
