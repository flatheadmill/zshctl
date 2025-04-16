# https://github.com/jarro2783/cxxopts/issues/120#issuecomment-437709167
function resource {
    typeset name=${1:-} file=${2:-${ZSHCTL_ARGZERO:A}}
    awk '
        /^(# )?___ '$name' ___/ { flag=1; next }
        flag && /^(# )?___/ { exit }
        flag && /^#$/ { print ""; next }
        flag && /^# / { print substr($0, 3); next }
        flag
    ' $file
}

# Extracts a string using `resource` and runs it through `groff` on Linux or
# `mandoc` on OS X to create a man page when the user requests help.
#
# `usage` -- underbar delimited name of command.

# TODO Rabbit hole. I'm trying to find a way to edit and preview with the
# formatting which leads me to comment out `| less` and run
#
# ```
# while true; do zshctl gce key | less -XE; sleep 1; done
# ```
#
# Perhaps an enviroment variable?

#
function usage {
    setopt localoptions extendedglob
    typeset usage=${1:-$funcstack[2]} man=${2:-0} cols="$(tput cols)"
    typeset release_date=$(date --date=@$zshctl[release_date] +'%B %-d, %Y')
    typeset capitalized=$zshctl[program]:${usage#*:}
    capitalized=${${capitalized//:/-}:u}
    typeset mandoc=() lines=() split=() line cmd src
    integer dirty=1
    mandoc=( "${(@Af)"$(resource "$usage _ man" $functions_source[$usage])"}" )
    while (( dirty )); do
        dirty=0
        lines=( "${(@)mandoc}" )
        mandoc=()
        for line in "${(@)lines}"; do
            case $line in
                .PG\ * )
                    line=${line//__program__/$zshctl[program]}
                    line=${line#.PG }
                    mandoc+=( "$line" )
                    ;;
                .ZC\ * )
                    line=${line#.ZC }
                    case $line in
                        commands )
                            for cmd in "${(@o)${(@k)COMMANDS}}"; do
                                if [[ $cmd = $usage:[^:]## ]]; then
                                    if [[ $COMMANDS[$cmd] = ':' ]]; then
                                        src=$functions_source[$cmd]
                                    else
                                        src=$COMMANDS[$cmd]
                                    fi
                                    src=$(resource "$cmd _ description" $src)
                                    if [[ -n $src ]]; then
                                        dirty=1
                                        split=( "${(@ps:\n:)src}" )
                                        mandoc+=( .TP ".B ${cmd##*:}" .br "${(@)split}" )
                                    fi
                                fi
                            done
                            ;;
                    esac
                    ;;
                * )
                    mandoc+=( "$line" )
                    ;;
            esac
        done
    done
    if (( man )); then
        print -rl "${(@)mandoc}"
        return
    fi
    function {
        if (( cols > 120 )); then
            cols=120
        else
            cols=$(( cols - 7 ))
        fi
        if (( $zshctl[osx] )); then
            mandoc -O width=${cols}  -T utf8 $1
        else
            GROFF_NO_SGR=1 groff -rLL=${cols}n -rLT=${cols}n -Wall -mtty-char -Tutf8 -man -c "$1"
        fi
    } =(
        printf '.TH %s 1 %s %s %s\n' \
            ${(qqq)capitalized} \
            ${(qqq)release_date} \
            ${(qqq)zshctl[version]} \
            ${(qqq)zshctl[man_title]}
        print -rl "${(@)mandoc}"
    ) | less
    exit
}

function completion {
    zparseopts -D -F -K -- \
        {w,-waiting}=o_waiting \
        {s,-suffix}:=o_suffix \
        {f,-files}=o_files \
        {o,-ordered}=o_ordered \
        {p,-prefixed}=o_prefixed \
        {m,-message}:=o_message || abend 'fatal: invalid arguments'
    parse[flags]=$(( parse[flags] | 4 ))
    if (( ${#o_wating} && ! parse[waiting] )); then
        parse[waiting]=1
        print ':progress'
    fi
    if (( ${#o_prefixed} )); then
        parse[flags]=$(( parse[flags] | 512 ))
    fi
    if (( ${#o_ordered} )); then
        parse[flags]=$(( parse[flags] | 32 ))
    fi
    if (( ${#o_suffix} == 2 )); then
        parse[flags]=$(( parse[flags] | 2 ))
        case $o_suffix[2] in
            (/) parse[flags]=$(( parse[flags] | 64 ));;
            (=) parse[flags]=$(( parse[flags] | 128 ));;
            (:) parse[flags]=$(( parse[flags] | 256 ));;
        esac
        parse[flags]=$(( parse[flags] | 4 ))
    fi
    if (( ${#o_files} )); then
        print -u 2 files
        parse[flags]=$(( parse[flags] & (~4) ))
    fi
    if [[ -n ${o_message[2]} ]]; then
        parse[message]=$o_message[2]
        parse[flags]=$(( parse[flags] | 4 ))
    fi
    if (( $# )); then
        completion_match+=( ${1:-} )
        if (( $# == 2 )); then
            completions+=( ${1:-} ${2:-} )
        fi
    fi
}

function completions {
    typeset lines=() line
    lines=( "${(@Af)$(usage $parse[func] 1)}" )
    typeset state=seek mandoc=( '.TH Ignore 1 "Manuals" "STOP" "Manuals"' )
    for line in "${(@Af)lines}"; do
        case $state:$line in
            *:.SH\ OPTIONS | *:.SH\ COMMANDS )
                mandoc+=( "$line" )
                state=tp
                ;;
            tp:.TP | desc:.TP )
                mandoc+=( "$line" )
                state=br
                ;;
            br:* )
                state=desc
                mandoc+=( "$line" .br )
                ;;
            desc:.SH* )
                state=none
                ;;
            desc:'' )
                state=tp
                ;;
            desc:?* )
                mandoc+=( "$line" )
                ;;
        esac
    done
    mandoc+=( '' )
    lines=( "${(@Af)"$(
        GROFF_NO_SGR=1 groff -rLL=999n -rLT=999n -Wall -mtty-char -Tutf8 -man -c <(printf '%s' "${(pj:\n:)mandoc}")
    )"}" )
    # Underscroe followed by backspace.
    typeset italicized='_'$'\b'
    # Anything followed by a backspace.
    typeset backspaced='?'$'\b'
    # Regexen.
    typeset -A regex=(
        # capture 1:
        #   Match anything that is not a backspace followed by...
        # capture 2:
        #   capture 3:
        #     a backspace followed by non-space...
        #        at least once followed by...
        #   capture 4:
        #     at least one space followed by...
        #     capture 5:
        #       backspace followed by non-space...
        #         at least once...
        #     zero or more times...
        # capture -1:
        #   and then grab the remainder.
        bold '^([^'$'\b'']*)(('$'\b''[^ ])+( +('$'\b''[^ ])+)*)(.*)'
    )
    typeset key split=() stripped quoted=()
    state=seek
    for line in "${(@)lines}"; do
        case ${${:-$state:$line}//$~backspaced/} in
            *:STOP* )
                state=
                ;;
            *:OPTIONS | *:COMMANDS )
                print -u 2 also hit $line
                state=key
                ;;
            key:?* )
                print -u 2 super hit $line
                # Trim whitespace.
                key=${(MS)line##[[:graph:]]*[[:graph:]]}
                # Strip all formatting.
                key=${key//$~backspaced/}
                # Look for our value.
                state=value
                ;;
            value:* )
                # Reset accumulator.
                quoted=()
                # Trim whitespace.
                line=${(MS)line##[[:graph:]]*[[:graph:]]}
                # Remove the first strike of the character.
                line=${line//$~backspaced/$'\b'}
                # While we have a string remaining.
                while [[ -n $line ]]; do
                    # If we match...
                    if [[ $line =~ $regex[bold] ]]; then
                        # Strip our bolded text of all backspaces.
                        stripped=${match[2]//$~backspaced[2]/}
                        # Lead up and quoted bolded text.
                        quoted+=( $match[1]\`$stripped\` )
                        # Remainder.
                        line=$match[-1]
                    else
                        # ...otherwise, the line segement has no bold text.
                        quoted+=( "$line" )
                        # Break loop.
                        line=''
                    fi
                done
                line=${(j::)quoted}
                if [[ $key = -* ]]; then
                    split=( "${(@Os:, :)key}" )
                else
                    split=( $key )
                fi
                for key in "${(@)split}"; do
                    completions+=( $key $line )
                    completion_match+=( $key )
                done
                state=key
                ;;
        esac
    done
}

function _parser_print_error {
    printf '%s %s %s %q %s\n' "$@"
}

function _parser_stash_error {
    typeset func=${1:-} reason=${3:-}
    __complete[reason]=$reason
    printf '__complete=( %s )\n' ${(j: :)"${(@qq)${(@kv)__complete}}"}
}

# What if we called this something other than error, something like helper,
# but, of course, not helper, like controller. It could be the patch that
# let's us separate the parser from completions.
function args:error {
    typeset func=${1:-} reason=${2:-} flag=${3:-}
    shift 3
    case $reason in
        complete )
            if (( ${+functions[complete:${func#execute:}]} )); then
                printf 'parse[completed]=1\n'
                printf 'complete:%s %s\n' ${func#execute:} "${(j: :)${(@qq)@}}"
            else
                printf 'delegate %s\n' "${(j: :)${(qq)@}}"
            fi
            ;;
        unknown )
            printf 'unknown argument `%s`.\n' $flag 1>&2
            exit 1
            ;;
        required )
            printf '`%s` is a required argument.\n' $flag 1>&2
            exit 1
            ;;
        execute )
            if [[ $flag = --help ]]; then
                usage $func
            else
                abend 'unknown execute directive on `%s` flag `%s`.' $func $flag
            fi
    esac
}

function args:user:error {
    args:error "$@"
}

function args {
    parser args:user:error 3 "$@"
}

function parser {
    setopt localoptions extendedglob
    typeset error=$1 depth=$2
    shift 2

    # TODO Make a note of this.
    # zshctl <(print 'program')

    [[ -v parse ]] || typeset -A parse=( complete 0 flags 0 )
    typeset err=_parser_print_error
    if (( parse[complete] )); then
        typeset err=_parser_stash_error
    fi
    typeset -A completions=()
    typeset completion_match=()
    parse[func]=$funcstack[$depth]

    typeset is_number='
        (){
            case ${1#[-+]} in
                *[!0-9]* | "" )
                    %s %s integer %s
                    ;;
            esac
        } %s
    '

    # Initial loop to grab the definition and to define the variables to which
    # arguments will be assigned.
    typeset -A option=( kind scalar defined 0 required 0 ) short options missing
    typeset split=() long=() declared=() stack=( "${(@Oa)@}" )
    typeset popped on_zeroed state=option typesets
    integer top=${#stack} intersperse=0 usage=0 completable=0
    while (( top )); do
        popped=$stack[$top]
        case $state:$popped in
            *:-- )
                ((top--))
                break
                ;;
            *:-* )
                state=option
                case $popped in
                    -C* )
                        completable=1
                        ;;
                    -U* )
                        usage=1
                        ;;
                    -@* )
                        intersperse=1
                        ;;
                    -!* )
                        option[negatable]=1
                        ;;
                    -a* )
                        option[kind]=array
                        ;;
                    -A* )
                        option[kind]=map
                        ;;
                    -b* )
                        option[kind]=boolean
                        ;;
                    -c* )
                        option[kind]=counter
                        ;;
                    -d* )
                        option[defined]=1
                        ;;
                    -i* )
                        option[kind]=number
                        ;;
                    -r* )
                        option[required]=1
                        ;;
                    -s* )
                        option[kind]=scalar
                        ;;
                    -t* )
                        option[kind]=toggle
                        ;;
                    -x* )
                        option[execute]=1
                        ;;
                esac
                if (( ${#popped} > 2 )); then
                    stack[$top]="-${popped[3,-1]}"
                else
                    ((top--))
                fi
                ;;
            option:[a-zA-Z0-9]#,[a-zA-Z][a-zA-Z-]#[a-z] )
                split=( "${(@s:,:)popped}" )
                if [[ -n $split[1] ]]; then
                    short[$split[1]]=$split[2]
                fi
                option[short]=$split[1]
                option[long]=$split[2]
                options[$split[2]]=${(j: :)${(@qqkv)option}}
                long+=( $split[2] )
                if (( ! $option[defined] && ! parse[complete] )); then
                    case $option[kind] in
                        counter | boolean | toggle )
                            printf -v typesets 'integer o_%s=0\n' ${option[long]//-/_}
                            ;;
                        array )
                            printf -v typesets 'typeset o_%s=()\n' ${option[long]//-/_}
                            ;;
                        map )
                            printf -v typesets 'typeset -A o_%s=()\n' ${option[long]//-/_}
                            ;;
                        * )
                            printf -v typesets 'typeset o_%s\n' ${option[long]//-/_}
                            printf -v typesets 'unset o_%s\n' ${option[long]//-/_}
                            ;;
                    esac
                fi
                if (( $option[required] )); then
                    missing[$option[long]]=1
                fi
                option=( kind $option[kind] defined 0 required 0 )
                ((top--))
                ;;
            * )
                print -u 2 "unable to interpret $popped"
                $err $error $funcstack[$depth] compile - 0
                exit 1
                ;;
        esac
    done

    if [[ $funcstack[$depth] != *:* && ${stack[$top]:-} = __complete ]]; then
        ((top--))
        parse[complete]=1
        parse[incomplete]=$stack[1]
        (( ${#completion_match} )) && abend 'should be empty'
        $funcstack[$depth] "${(@Oa)stack[2,$top]}"
        # print -u 2 ${(j: :)"${(@qq)${(@kv)parse}}"}
        if (( ! parse[completed] )) then
            print -u 2 hit
            completions
            (( parse[flags] = parse[flags] | 4 ))
        fi
        typeset hit
        for hit in ${(@M)completion_match:#${stack[1]}*}; do
            [[ $stack[1] = '' && $hit[1] = - ]] && continue
            if (( ${+completions[$hit]} )); then
                printf 'printf -- '\''%%s\\t%%s\\n'\'' %s %s\n' \
                    ${(qqq)hit} ${(qqq)completions[$hit]}
            else
                printf 'printf -- '\''%%s\\n'\'' %s %s\n' ${(qqq)hit}
            fi
        done
        if [[ -n $parse[message] ]]; then
            printf 'printf '\''_activeHelp_ %s\\n'\''\n' $parse[message]
        fi
        printf 'print -- :%d\n' $parse[flags]
        print 'return'
        return
    fi

    if [[ -n $typesets ]]; then
        printf $typesets
    fi

    long=( ${(@o)long} ) # TODO What does this do?
    state=switch

    parse[flag]=''
    integer last
    typeset index key interspersed=() flag truth=1
    while (( top )); do
        popped=$stack[$top]
        last=$(( top == 1 ))
        case $state:$popped in
            switch:-- )
                ((top--))
                break
                ;;
            switch:--* )
                # First determine the flag name so we can look up the options definition.
                case $popped in
                    (#b)--no-([^=]##) )
                        flag=$match[1]
                        ((top--))
                        ;;
                    (#b)--([^=]##)=(*) )
                        flag=$match[1]
                        stack[$top]=$match[2]
                        ;;
                    (#b)--(*) )
                        flag=$match[1]
                        ((top--))
                esac
                # Should we complain if the argument is ambiguous? Currently, we are
                # just accepting the first match in alphabetical order.
                index=$long[(Ie)$flag]
                if (( ! index )); then
                    $err $error $funcstack[$depth] unknown $flag $last
                    return
                fi
                option=( "${(@QA)${(z)options[$long[$index]]}}" )
                missing[$option[long]]=0
                # Go back over our poppped argument to determine if it is a negated
                # boolean or an assignment.
                case $popped in
                    (#b)--no-([^=]##) )
                        if (( ! $option[negatable] )); then
                            printf '%s %s unknown %s %s\n' $error $funcstack[$depth] --$match[1] $last
                        fi
                        truth=0
                        ;;
                    (#b)--([^=]##)=* )
                        case $option[kind] in
                            boolean | counter )
                                printf '%s %s unassignable %s %s\n' $error $funcstack[$depth] --$match[1] $last
                                return
                                ;;
                        esac
                        ;;
                esac
                ;;
            switch:-?* )
                flag=${popped[2,2]}
                if [[ $flag = '!' ]]; then
                    truth=0
                    if (( ${#popped} == 2 )); then
                        printf '%s %s unknown %s %s\n' $error $funcstack[$depth] $popped[1,2] $last
                        return
                    fi
                    stack[$top]=-${popped[3,-1]}
                    continue
                elif (( ! ${+short[${popped[2,2]}]} )); then
                    printf '%s %s unknown %s %s\n' $error $funcstack[$depth] $popped[1,2] $last
                    return
                else
                    index=$long[(Ie)$short[$popped[2,2]]]
                    option=( "${(@QA)${(z)options[$long[$index]]}}" )
                    missing[$option[long]]=0
                    case $option[kind] in
                        boolean | counter )
                            if (( ${#popped} == 2 )); then
                                ((top--))
                            else
                                stack[$top]=-${popped[3,-1]}
                            fi
                            ;;
                        * )
                            if (( ${#popped} == 2 )); then
                                ((top--))
                            else
                                stack[$top]=${popped[3,-1]}
                            fi
                            ;;
                    esac
                fi
                ;;
            switch:* )
                (( intersperse )) || break
                interspersed+=( $popped )
                ((top--))
                continue
                ;;
            key:* )
                if [[ $popped = (#b)([^=]##)=(*) ]]; then
                    key=$match[1]
                    stack[$top]=$match[2]
                else
                    key=$popped
                    ((top--))
                fi
                state=value
                continue
                ;;
            value:* )
                case $option[kind] in
                    array )
                        printf 'o_%s+=( %s )\n' ${option[long]//-/_} ${(qq)popped}
                        ;;
                    map )
                        printf '(){ typeset key=%s; o_%s[$key]=%s; }\n' ${(qq)key} ${option[long]//-/_} ${(qq)popped}
                        ;;
                    scalar )
                        printf 'o_%s=%s\n' ${option[long]//-/_} ${(qq)popped}
                        ;;
                    boolean )
                        printf 'o_%s=%d\n' ${option[long]//-/_} $popped
                        ;;
                    counter )
                        printf '((++o_%s))\n' ${option[long]//-/_}
                        ;;
                    toggle )
                        printf 'o_%s=$(( ! o_%s ))\n' ${option[long]//-/_} ${option[long]//-/_}
                        ;;
                esac
                stack[$top]=0
                state=execute
                continue
                ;;
            execute:0 )
                if (( ${option[execute]:-0} && ! $parse[complete]  )); then
                    printf '%s %s %s %s\n' $error $funcstack[$depth] execute "--$option[long]"
                    return
                fi
                truth=1
                state=switch
                ((top--))
                continue
                ;;
            * )
                print derp
                exit 1
                ;;
        esac
        parse[long]=$option[long]
        case $option[kind] in
            boolean | counter | toggle )
                ((top++))
                stack[$top]=$(( truth ))
                state=value
                ;;
            map )
                state=key
                ;;
            * )
                state=value
                ;;
        esac
    done
    parse[state]=$state
    if (( ! parse[complete] )); then
        # TODO Assert we did not stop mid argument.
        case $state in
            key )
                ;;
            value )
                ;;
        esac
        for flag in ${(@k)missing}; do
            if (( $missing[$flag] )); then
                printf '%s %s %s %s\n' $error $funcstack[$depth] required "--$flag"
            fi
        done
    fi
    typeset combined=( "${(@)interspersed}" "${(@Oa)stack[1,$top]}" )
    if (( parse[complete] )); then
        printf 'parse=( %s )\n' ${(j: :)"${(@qq)${(@kv)parse}}"}
        if (( completable )); then
            args:user:error $funcstack[$depth] complete '' "${(@)combined}"
        fi
        print return
    else
        if (( ${#combined} )); then
            printf 'set -- %s\n' ${(j: :)${(@qq)combined}}
        elif (( usage )); then
            print usage $funcstack[$depth]
            print return
        else
            printf 'set --\n'
        fi
    fi
}
