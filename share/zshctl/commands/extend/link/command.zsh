function :help:extend:link {
    heredoc -v help -q <<'    EOF'
        # desc
        Install a \`${zshctl[program]}\` extension.
        # arg -- < directory >
        # opt help
        Display help for \`${zshctl[program]} extend link\`.
        # man
        ## DESCRIPTION
        Installs a \`${zshctl[program]}\` extension.
        ## OPTIONS
        > options
    EOF
}

function :args:extend:link {
    eval "$(args -U -bx h,help -- "$@")"
}

function :execute:extend:link {
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
        abend 'fatal: exception: multiple extension configurations found'
        ;;
    esac
    typeset -A extend
    source $found[1]
    mkdir -p ~/.local/share/$zshctl[program]/extensions
    ln -s ${found[1]:A:h} ~/.local/share/$zshctl[program]/extensions/${extend[link_as]}
    ls -la ~/.local/share/$zshctl[program]/extensions/${extend[link_as]}
}

function :complete:extend:link {
    [[ $zshctl[args:incomplete] = -* ]] && return
    [[ $zshctl[args:state] = arguments ]] && completion directories
}
