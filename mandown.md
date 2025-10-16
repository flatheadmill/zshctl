`zshctl` includes a help system that will display man formatted context
sensitive help.

Help is written using a markup language I call MAN DOWN!, which is a subset of
Markdown. MAN DOWN! only supports bold, which expressed as backticks instead
of asterisks, italic, and a single heading, using Markdown's heading 2.

Heading 1 is used to divide the sections of the MAN DOWN! file. Heading 3 is
used for an inclusion mechanism. This is much like the Markdown-as-XML format
that is so popular with today's AI slopmentation.

MAN DOWN! does not supprt bullet lists nor numbered lists. These are rarely
used in `man` pages. When you see them, someone has used a tool like Pandoc to
generate a `man` page that is mostly roff. Bullet lists and numbered lists are
not part of `man(7)`.

MAN DOWN! does supports definition lists which are common in man pages, but
without nesting. But, why not support nesting?

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
