# ___ execute:extend:link _ description ___
# Install an extension.
# ___ execute:extend:link _ man ___
# .SH NAME
# .PB __program__\ extend \link \- install a
# .PG __program__
# extension.
# .SH SYNOPSIS
# .PG .SY __program__\ extend\ link
# .I extension-path
# .PG .SY __program__\ extend\ link
# .RB [ \-h | \-\-help ]
# .YS
# .SH DESCRIPTION
# Installs a
# .PG __program__
# extension.
# .SH OPTIONS
# .TP
# .BR \-h ,\  \-\-help
# Help for
# .BR zshctl\ extend\ link .
# ___
function execute:extend:link {
    eval "$(args -U -bx h,help -- "$@")"
    typeset subdirectory=.
    (( $# )) && subdirectory=${1:-}
    typeset found=()
    found=( $subdirectory/**/$zshctl[program].extension.zsh(N) )
    case ${#found} in
    (0)
        abend 'fatal: not found'
        ;;
    (1)
        ;;
    (*)
        abend 'fatal: multiple extension configurations found'
        ;;
    esac
    typeset -A extend
    source $found[1]
    mkdir -p ~/.local/share/$zshctl[program]
    ln -s ${found[1]:A:h} ~/.local/share/$zshctl[program]/${extend[link_as]}
    ls -la ~/.local/share/$zshctl[program]/${extend[link_as]}
}
