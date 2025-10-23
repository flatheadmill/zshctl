function warn {
    if (( ! $# )); then
        warn -
        return
    fi
    case $1 in
    (-f | -q | -)
        heredoc "$@" 1>&2
        ;;
    (--)
        shift
        ;&
    (*)
        printf -- "$@" 1>&2
        printf '\n' 1>&2
        ;;
    esac
}

function abend {
    if [[ $# -ne 0 && $1 = -c ]]; then
        shift
        if (( $# )); then
            set $1 "$@"
            shift
        else
            set -- 1 "$@"
            print -u 'warn: invalid arguments: `abend -c` requires a value'
        fi
    else
        set -- 1 "$@"
    fi
    warn "$@[2,-1]"
    exit $1
}

function _abend {
    # Create a frame by finding an undefined variable.
    set -- 0 "$@"
    while true; do
        if [[ ! -v "__abend_$1__" ]]; then
            break
        fi
        set -- $(( $1 + 1 )) "$@[2,-1]"
    done
    # Set to actual variable name.
    set -- "__abend_${1}__" "$@[2,-1]"
    function {
        typeset params=${1:-}
        shift
        typeset vargs=()
        integer code=1
        if [[ $# -ne 0 && $1 = -c ]]; then
            shift
            if (( $# )); then
                code=$1
                shift
            else
                print -u 'warn: invalid arguments: `abend -c` requires a value'
            fi
        fi
        integer is_heredoc
        case $1 in
        (-f)
            vargs=( "$@" )
            shift $#
            break
            ;;
        (-q)
            shift
            if (( $# )); then
                print -u 'warn: invalid arguments: `abend -q` takes no arguments'
            fi
            shift $#
            vargs=( -q )
            ;;
        (-)
            shift
            if (( $# )); then
                print -u 'warn: invalid arguments: `abend -` takes no arguments'
            fi
            shift $#
            vargs=( - )
            ;;
        (--)
            ;;
        esac
        typeset emit=() src
        if (( $# )); then
            printf -v src 'printf -v %s -- %s\n' $params "${(j: :)${(@qq)vargs}}"
            emit+=( $src )
            printf -v src 'printf '\''%s\n'\'' %s 1>&2\n' $params
            emit+=( $src )
        else
            printf -v src 'heredoc %s 1>&2\n' "${(j: :)${(@qq)vargs}}"
        fi
        printf -v src 'exit %q\n' $code
        : ${(P)params::=${(j::)emit}}
    } "$@"
    set -- "${(P)1}"
    unset $1
    print eval $1
}

function heredoc {
    # Create a frame by finding an undefined variable.
    set -- 0 "$@"
    while true; do
        if [[ ! -v "__heredoc_$1__" ]]; then
            break
        fi
        set -- $(( $1 + 1 )) "$@[2,-1]"
    done
    # Set to actual variable name.
    set -- "__heredoc_${1}__" "$@[2,-1]"
    function {
        typeset match=() lines=() chomped=()
        typeset spaces=65536 leading='^( *)([^[:space:]])' line heredoc
        IFS= read -rd '' heredoc
        for line in "${(@Af)heredoc}"; do
            lines+=( "$line" ) # remove the double quotes and blank lines disappear
            if [[ $line =~ $leading && ${#match[1]} -lt $spaces ]]; then
                spaces=${#match[1]}
            fi
        done
        for line in "${(@)lines}"; do
            # remove the double quotes and blank lines disappear
            chomped+=( "${line[spaces + 1,-1]}" )
        done
        printf -v heredoc '%s' ${(pj:\n:)chomped[1,-2]}$'\n'
        typeset parameters=${1:-}
        shift
        typeset mode=- variable=() vargs=() emit=()
        while (( $# )); do
            case $1 in
            (-v)
                variable=( $1 $2 )
                shift 2
                ;;
            (-)
                mode=-
                shift
                ;;
            (-q)
                mode=$1
                shift
                ;;
            (-f)
                mode=$1
                shift
                ;;
            (--)
                shift
                vargs=( "$@" )
                break
                ;;
            (*)
                [[ $mode = -f ]] || {
                    print -u 2 'positional parameters are only for -f mode'
                    exit 1
                }
                vargs=( "$@" )
                break
                ;;
            esac
        done
        typeset src emit=()
        case $mode in
        (-)
            emit=( 'printf' "${(@)variable}" '%s' '$3' )
            src=${(j: :)${(@qq)emit}}
            ;;
        (-f)
            emit=( 'printf' "${(@)variable}" -- '$3' "${(@)vargs}" )
            src=${(j: :)${(@qq)emit}}
            ;;
        (-q)
            printf -v heredoc '%s' $'\t'${(pj:\n\t:)chomped[1,-2]}$'\n'
            if (( ${#variable} )); then
                printf -v src "IFS= read -rd '' %s " $variable[2]
            else
                src='cat '
            fi
            printf -v src '%s <<-EOT\n%sEOT\n' "$src" "$heredoc"
            src=${(qq)src}
            heredoc=
            ;;
        esac
        typeset frame=( $parameters $src $heredoc )
        : ${(PA)parameters::=${(j: :)${(@qq)frame}}}
    } "$@"
    # Set our positional parameters from out one local variable.
    set -- "${(@QA)${(z)${(P)1}}}"
    unset $1
    # Evaluate heredoc in the current process with the current set of variables.
    eval "${(@QA)${(z)2}}"
}
