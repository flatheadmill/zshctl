#!/usr/bin/env zsh
emulate -L zsh

typeset root=${${(%):-%x}:A:h:h}
fpath=( $root/share/zshctl/functions $fpath )
autoload -zU \
    _zshctl_completions \
    _zshctl_help \
    _zshctl_help_lines \
    _zshctl_mandown \
    _zshctl_pushf \
    _zshctl_synopsis \
    abend \
    args \
    completion \
    heredoc \
    slurp \
    trim \
    usage \
    warn

typeset -gA zshctl
export ZSHCTL_HELP_TEXT=1

function reset_zshctl {
    zshctl=(
        program commentctl
        release_date ${EPOCHSECONDS:-0}
        version test
        man_title COMMENTCTL
    )
}

function assert_contains {
    [[ $1 = *$2* ]] && return
    print -u2 -- "not found: $2"
    return 1
}

function assert_not_contains {
    [[ $1 != *$2* ]] && return
    print -u2 -- "unexpected: $2"
    return 1
}

function assert_equals {
    [[ $1 = "$2" ]] && return
    print -u2 -- "expected: ${(q+)2}"
    print -u2 -- "actual:   ${(q+)1}"
    return 1
}

function :args:comments:mode {
    eval "$(args -UC -b h,help -- "$@")"
}

function :help:comments:mode {
    help=$'<!-- vim: set ft=mandown: -->\n# desc -- Mode line proof.\n# man\n## DESCRIPTION\nBody.\n'
}

function :execute:comments:mode {
    usage
}

reset_zshctl
zshctl[help:mode]=__mandown
typeset out=$( ( :execute:comments:mode ) )
assert_not_contains $out '<!-- vim: set ft=mandown: -->' || exit
assert_contains $out '# desc -- Mode line proof.' || exit
print 'ok: mode-line comment stripped before raw MAN DOWN! dump'

function :args:comments:fence {
    eval "$(args -UC -b h,help -- "$@")"
}

function :help:comments:fence {
    help=$'# desc -- Fence proof.\n# man\n## DESCRIPTION\n```shell\n<!-- literal -->\n```\n'
}

function :execute:comments:fence {
    usage
}

reset_zshctl
zshctl[help:mode]=__man
out=$( ( :execute:comments:fence ) )
assert_contains $out '<!-- literal -->' || exit
print 'ok: comment-shaped text inside a shell fence stays literal'

function :args:comments:parent {
    eval "$(args -UC -b h,help -- "$@")"
}

function :help:comments:parent {
    help=$'# desc -- Parent command.\n# man\n## DESCRIPTION\nParent.\n'
}

function :execute:comments:parent {
    _zshctl_completions
}

function :help:comments:parent:child {
    help=$'# desc\n<!-- completion comment -->\nDisplay child command.\n# man\n## DESCRIPTION\nChild.\n'
}

reset_zshctl
zshctl+=(
    :execute:comments:parent:child :
    args:state arguments
    args:incomplete ''
)
typeset -g completion_match=()
typeset -gA completions=()
:execute:comments:parent
[[ $completions[child] = 'display child command' ]] || {
    print -u2 -- "completion description: $completions[child]"
    exit 1
}
print 'ok: # desc comment absent from completion description'

function :args:comments:unclosed {
    eval "$(args -UC -b h,help -- "$@")"
}

function :help:comments:unclosed {
    help=$'# desc\n```shell\nan unclosed fence in desc\n# man\n## DESCRIPTION\n<!-- reset comment -->\nVisible body.\n'
}

function :execute:comments:unclosed {
    usage
}

reset_zshctl
zshctl[help:mode]=__man
out=$( ( :execute:comments:unclosed ) )
assert_contains $out 'Visible body.' || exit
assert_not_contains $out '<!-- reset comment -->' || exit
print 'ok: unclosed fence state resets at the next help section'

# The lexer cases. Each asserts the whole stripped document through the
# `__mandown` dump, so the expected text is exact, not merely present.
# Command substitution eats the trailing newline, so the expectations end
# without one.

function :help:comments:inline {
    help=$'# desc -- Terse. <!-- trailing note -->\n# man\n## DESCRIPTION\nBody <!-- why --> text.\n'
}

function :execute:comments:inline {
    usage
}

reset_zshctl
zshctl[help:mode]=__mandown
out=$( ( :execute:comments:inline ) )
assert_equals $out $'# desc -- Terse. \n# man\n## DESCRIPTION\nBody  text.' || exit
print 'ok: inline comments stripped mid-line, on directive lines included'

function :help:comments:block {
    help=$'# desc -- Terse.\n<!--\n# opt retry\nSets the `retry` count.\n-->\n   <!-- gone -->   \n# man\n## DESCRIPTION\nBody.\n'
}

function :execute:comments:block {
    usage
}

reset_zshctl
zshctl[help:mode]=__mandown
out=$( ( :execute:comments:block ) )
assert_equals $out $'# desc -- Terse.\n# man\n## DESCRIPTION\nBody.' || exit
print 'ok: a comment gobbles a # opt block across the boundary, residue lines deleted'

function :help:comments:splice {
    help=$'# desc\nDisplay <!-- reason\nspans lines --> the thing.\n# man\n## DESCRIPTION\nBody.\n'
}

function :execute:comments:splice {
    usage
}

reset_zshctl
zshctl[help:mode]=__mandown
out=$( ( :execute:comments:splice ) )
assert_equals $out $'# desc\nDisplay  the thing.\n# man\n## DESCRIPTION\nBody.' || exit
print 'ok: a multi-line comment splices prefix and suffix onto one line'

function :help:comments:parent:spliced {
    help=$'# desc\nDisplay <!-- reason\nspans lines --> the thing.\n# man\n## DESCRIPTION\nChild.\n'
}

reset_zshctl
zshctl+=(
    :execute:comments:parent:spliced :
    args:state arguments
    args:incomplete ''
)
completion_match=()
completions=()
:execute:comments:parent
[[ $completions[spliced] = 'display  the thing' ]] || {
    print -u2 -- "completion description: $completions[spliced]"
    exit 1
}
print 'ok: spliced verbose first line reaches the completion description whole'

function :help:comments:escape {
    help=$'# man\n## DESCRIPTION\n\\<!-- literal -->\n\\\\<!-- live --> tail\n'
}

function :execute:comments:escape {
    usage
}

reset_zshctl
zshctl[help:mode]=__mandown
out=$( ( :execute:comments:escape ) )
assert_equals $out $'# man\n## DESCRIPTION\n\\<!-- literal -->\n\\\\ tail' || exit
print 'ok: backslash parity, escaped opener literal, doubled backslash live'

function :help:comments:midline {
    help=$'# man\n## DESCRIPTION\nfoo <!-- x --> ```shell\n<!-- stripped -->\ncode\n'
}

function :execute:comments:midline {
    usage
}

reset_zshctl
zshctl[help:mode]=__mandown
out=$( ( :execute:comments:midline ) )
assert_equals $out $'# man\n## DESCRIPTION\nfoo  ```shell\ncode' || exit
print 'ok: backticks after kept text open no fence, the next comment strips'

function :help:comments:linestart {
    help=$'# man\n## DESCRIPTION\n<!-- x -->```shell\n<!-- kept -->\n```\nAfter.\n'
}

function :execute:comments:linestart {
    usage
}

reset_zshctl
zshctl[help:mode]=__mandown
out=$( ( :execute:comments:linestart ) )
assert_equals $out $'# man\n## DESCRIPTION\n```shell\n<!-- kept -->\n```\nAfter.' || exit
print 'ok: backticks at output line start open a fence that protects comments'

function :help:comments:reset {
    help=$'# man\n## DESCRIPTION\n```shell\nexample\n# opt bogus <!-- half-open note\nstill note --> tail\nBody.\n'
}

function :execute:comments:reset {
    usage
}

reset_zshctl
zshctl[help:mode]=__mandown
out=$( ( :execute:comments:reset ) )
assert_equals $out $'# man\n## DESCRIPTION\n```shell\nexample\n# opt bogus  tail\nBody.' || exit
print 'ok: the fence reset line re-enters scan, its half-open comment gobbles'

function :help:comments:gobble {
    help=$'# desc -- Terse.\n# man\n## DESCRIPTION\nKept. <!-- oops\n# opt gone\nnever seen\n'
}

function :execute:comments:gobble {
    usage
}

reset_zshctl
zshctl[help:mode]=__mandown
out=$( ( :execute:comments:gobble ) )
assert_equals $out $'# desc -- Terse.\n# man\n## DESCRIPTION\nKept. ' || exit
print 'ok: an unclosed comment gobbles to the end of this help, prefix kept'
