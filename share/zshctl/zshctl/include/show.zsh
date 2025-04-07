function show:eval {
}

function show:compile {
    typeset code
    printf -v code 'function show:eval {
        %s
    }' $1
    eval $code 2> /dev/null
}

# TODO for variables just use heredocs.
function show {
    [[ $1 = -v ]] && {
        print -u 2 -- '-v no longer supported'
        exit 1
    }
    function {
        typeset code
        if [[ $# -eq 0 || $1 = - || $1 = -f || $1 = -q ]]; then
            heredoc -v code "$@"
            printf '$ %s' "$code"
            show:compile $code || eval "$code"
        elif [[ $1 = eval ]]; then
            printf '$ %s\n' $2
            show:compile $2 || eval "$2"
        else
            code=$({
                typeset word words=()
                for word in "$@"; do
                    if [[ -z $word || ${(q)word} = *"\\"* ]]; then
                        words+=( ${(qqq)word} )
                    else
                        words+=( $word )
                    fi
                done
                printf '%s\n' ${(j: :)words}
            })
            printf '$ %s\n' $code
            show:compile $code || eval "$code"
        fi
    } "$@" && show:eval
}
