#!/usr/bin/env zsh
emulate -L zsh

typeset root=${${(%):-%x}:A:h:h}
fpath=( $root/share/zshctl/functions $fpath )
autoload -zU \
    _zshctl_help \
    _zshctl_help_lines \
    _zshctl_mandown \
    _zshctl_pushf \
    _zshctl_synopsis \
    abend \
    args \
    trim \
    usage

typeset -gA zshctl=(
    program usagectl
    release_date ${EPOCHSECONDS:-0}
    version test
    man_title USAGECTL
    help:mode __man
    :execute:terse :
    :execute:verbose :
)
export ZSHCTL_HELP_TEXT=1

function :args {
    eval "$(args -UC -b h,help -- "$@")"
}

function :help {
    help=$'# desc -- Exercise command summaries.\n# man\n## DESCRIPTION\nTest command summaries.\n\n## COMMANDS\n> commands\n'
}

function :execute {
    usage
}

function :help:terse {
    help=$'# desc -- Terse-only summary.\n# man\n'
}

function :help:verbose {
    help=$'# desc -- Short summary.\nVerbose summary.\n# man\n'
}

typeset out=$( ( :execute ) )
[[ $out = *$'.B terse\n.br\nTerse-only summary.'* ]] || {
    print -u2 -- 'terse-only command missing from help'
    print -u2 -r -- "$out"
    exit 1
}
[[ $out = *$'.B verbose\n.br\nVerbose summary.'* ]] || {
    print -u2 -- 'verbose command missing from help'
    print -u2 -r -- "$out"
    exit 1
}
print 'ok: parent help lists terse-only and verbose commands'
