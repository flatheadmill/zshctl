# The globs in the following function choke out syntax highlighting.
source <(cat <<'EOF'
function parse:unescape_man {
    typeset line=${1:-} quote=${2:-0}
    typeset gather=() mode=bold chunk match=()
    [[ $line = (#b).(BR|RI|IR)\ #(*) ]]
    line=$match[2]
    while [[ -n $line ]]; do
        [[ $line = (#b)(([^\\ ]|\\?)##)\ #(*) ]]
        chunk=$match[1]
        line=$match[-1]
        if [[ $mode = bold && $quote = 1 ]]; then
            gather+=( '`'${chunk//(#b)\\(?)/$match[1]}'`' )
            mode=regular
        else
            gather+=( ${chunk//(#b)\\(?)/$match[1]} )
            mode=bold
        fi
    done
    unescaped=${(j::)gather}
}
EOF
)

function completions {
    setopt localoptions extendedglob
    typeset lines=() line
    lines=( "${(@Af)$(usage $parse[func] 1)}" )
    typeset state unescaped key value=() split=() match=() word
    integer active=0
    lines+=( ".STOP" )
    for line in "${(@)lines}"; do
        word=$active:$state:$line
        case $word in
        (0:*:.SH (OPTIONS|COMMANDS))
            state=begin
            active=1
            ;;
        (1:begin:.TP)
            state=key
            key=
            value=()
            ;;
        (1:value:.(TP|SH|STOP)*|1:value:)
            if [[ $key = -* ]]; then
                split=( "${(@Os:, :)key}" )
            else
                split=( $key )
            fi
            for key in "${(@)split}"; do
                if [[ $key = *=* ]]; then
                    key=${key%=*}
                fi
                parse[descriptions]=1
                completions+=( $key ${(j: :)value} )
                completion_match+=( $key )
            done
            case $line in
            (.SH (OPTIONS|COMMANDS)|)
                state=begin
                ;;
            (.SH *)
                active=0
                ;;
            (.TP)
                state=key
                ;;
            esac
            key=
            value=()
            ;;
        (1:key:.B *)
            [[ $line = (#b).B\ #(*) ]]
            line=$match[1]
            key+=${line//(#b)\\(?)/$match[1]}
            state=value
            ;;
        (1:key:.(BR|RI) *)
            if [[ $line = (#b)(*)\\c ]]; then
                parse:unescape_man $match[1]
            else
                parse:unescape_man $line
                state=value
            fi
            key+=$unescaped
            ;;
        (1:value:.IR *)
            parse:unescape_man $line
            value+=( $unescaped )
            ;;
        (1:value:.I *)
            [[ $line = (#b).I\ #(*) ]]
            value+=( $match[1] )
            ;;
        (1:value:.B *)
            [[ $line = (#b).B\ #(*) ]]
            line=$match[1]
            value+=( '`'${line//(#b)\\(?)/$match[1]}'`' )
            ;;
        (1:value:.BR *)
            parse:unescape_man $line 1
            value+=( "$unescaped" )
            ;;
        (1:value:.br)
            ;;
        (1:value:*)
            value+=( "$line" )
            ;;
        esac
    done
}
