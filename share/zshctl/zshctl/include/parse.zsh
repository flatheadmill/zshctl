zmodload zsh/terminfo
zmodload zsh/datetime

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
    typeset usage=${1:-$funcstack[2]} man=${2:-0} cols="$(echoti cols)"
    typeset release_date=$(strftime '%B %-d, %Y' $zshctl[release_date])
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
        if [[ $(uname) = Darwin ]]; then
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
        {S,-short-prefix}=o_short_prefixed \
        {m,-message}:=o_message || abend 'fatal: invalid arguments'
    parse[flags]=$(( parse[flags] | 4 ))
    parse[completed]=1
    if (( ${#o_wating} && ! parse[waiting] )); then
        parse[waiting]=1
        print ':progress'
    fi
    if (( ${#o_short_prefixed} )); then
        parse[flags]=$(( parse[flags] | 2 ))
        parse[flags]=$(( parse[flags] | 1024 ))
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
            parse[descriptions]=1
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
    if false; then
        if [[ $(uname) = Darwin ]]; then
            mandoc -O width=999  -c -T utf8 <(printf '%s' "${(pj:\n:)mandoc}") > ~/.mandoced
        else
            GROFF_NO_SGR=1 groff -rLL=999n -rLT=999n -Wall -mtty-char -Tutf8 -man -c <(printf '%s' "${(pj:\n:)mandoc}")
        fi
    fi
    # for `mandoc` we have to replace non-breaking spaces with regular spaces
    lines=( "${(@Af)"$(
        if [[ $(uname) = Darwin ]]; then
            mandoc -O width=999  -T utf8 <(printf '%s' "${(pj:\n:)mandoc}") | sed $'s/\xC2\xA0/ /g'
        else
            GROFF_NO_SGR=1 groff -rLL=999n -rLT=999n -Wall -mtty-char -Tutf8 -man -c <(printf '%s' "${(pj:\n:)mandoc}")
        fi
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
                state=key
                ;;
            key:?* )
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
                    if [[ $key = *=* ]]; then
                        key=${key%=*}
                    fi
                    parse[descriptions]=1
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
    print -u 2 DO NOT CALL ME ANYMORE
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

# Completion annoyances.
# -f<value>
# -f <value>
# --flag=<value>
# --flag <value>
# --flag <key>
# --flag <key> <value>
# --flag <key>=<value>
# Did I offer -f<key>=<value>?

function parser {
    setopt localoptions extendedglob
    typeset error=$1 depth=$2
    shift 2

    # TODO Make a note of this.
    # zshctl <(print 'program')

    [[ -v parse ]] || typeset -A parse=( completed 0 filenames 0 descriptions 0 complete 0 flags 0 remainder '' )
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
            # Definitions finished.
            *:-- )
                ((top--))
                break
                ;;
            # Short flags to the argument parser itself. Captial letters
            # represent global options.Lower case letters are options that
            # apply the subsequent field defintions or a single next
            # defintiion depending on option.
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
                        option[defined]=1 # resets after a single defintion.
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
            # Optional short option followed by a long option.
            option:[a-zA-Z0-9]#,[a-zA-Z][a-zA-Z-]#[a-z] )
                split=( "${(@s:,:)popped}" )
                if [[ -n $split[1] ]]; then
                    short[$split[1]]=$split[2]
                fi
                option[short]=$split[1]
                option[long]=$split[2]
                options[$option[long]]=${(j: :)${(@qqkv)option}}
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
            # Error in parsing.
            * )
                print -u 2 "unable to interpret $popped"
                args:user:error $funcstack[$depth] compile - 0
                exit 1
                ;;
        esac
    done

    # When we complete, we descend the command path within this invocation of
    # args and print commands to our standard out that print configuration for
    # evaluation onstandard out. This is different from normal operation where
    # we print options to be evaluated standard out. The user then descends
    # the tree using `delegate`.

    # Our completion scripts are shims that delegate the completion logic to
    # this function. For Bash, especially, we want to take advantage of Zsh's
    # superior tokenization of shell words. Better than the the words that
    # Bash provides to a completion function.

    typeset shell words=() line maybe=() bwords=()
    integer point=0 size cword=0 i
    if [[ $funcstack[$depth] != *:* && ${stack[$top]:-} = __complete ]]; then
        ((top--))
        shell=$stack[$top]
        ((top--))
        if [[ $shell = bash ]]; then
            parse[debug]=$stack[$top]
            ((top--))
            line=$stack[$top]
            ((top--))
            point=$stack[$top]
            ((top--))
            ((top--)) # COMP_WORDBREAKS
            ((top--)) # COMP_TYPE
            ((top--)) # COMP_KEY (ASCII last keystroke?)
            cword=$stack[$top]
            ((cword++)) # Bash is zero indexed.
            ((top--))
            bwords=( "${(@Oa)${(@)stack[$top, -1]}}" )
            bwords=( "${(A@Oa)${(@)stack[1, $top]}}" )
            print -l -- "CWORD: $cword" >> $parse[debug]
            print -l -- "${(@)bwords}" >> $parse[debug]
            #  We clip for Bash. It doesn't seem to do mid-word completion
            #  anywhere. Not even `ls` can run with a file name that actually
            #  exists. We can be just as brutal.
            words=( "${(z)${line[1,$point]}}" )
            # We want to know if we are at the end of a complete word. We are
            # going to add a character to the end and see if we get a new
            # word.
            if (( ${#words} != ${#${(z)${:-${line[1,$point]}x}}} )); then
                parse[incomplete]=''
                words=( "${(@)words[2,-1]}" )
            else
                parse[incomplete]=$words[-1]
                words=( "${(@)words[2,-2]}" )
            fi
            print "<$line> <${line[1,$point]}> <${line[1,$i]}> <$point>" >> $parse[debug]
        else
            parse[debug]=$stack[$top]
            ((top--))
            point=$stack[$top]
            ((top--))
            ((top--))
            ((point-=2))
            while (( point-- )); do
                words+=( "$stack[$top]" )
                ((--top))
            done
            parse[incomplete]=$stack[$top]
        fi
        print -l -- "${(@)words}" "$parse[incomplete]" >> $parse[debug]
        parse[complete]=1
        print "parse[completed]<$parse[completed]>" >> $parse[debug]
        print $funcstack[$depth] "${(@)words}" >> $parse[debug]
        $funcstack[$depth] "${(@)words}"
        print "parse[completed]<$parse[completed]>" >> $parse[debug]
        # print -u 2 ${(j: :)"${(@qq)${(@kv)parse}}"}
        if (( ! parse[completed] )) then
            completions
            (( parse[flags] = parse[flags] | 4 ))
            parse[files]=none
        fi
        if [[ $shell = bash ]]; then
            # Bash creates "words" by splitting on all sorts of characters
            # that do not delineate shell words. If we are at an equals or our
            # previous character was an equals, we do not need the asignee
            # part of the prefix.
            print -u 2 ">> <$parse[delimiter]> $bwords[$cword]"
            if [[
                -n $parse[delimiter] &&
                (
                    $bwords[$cword] = $parse[delimiter] ||
                    $bwords[$(( cword - 1 ))] = $parse[delimiter]
                )
            ]]; then
                parse[prefix]=${parse[prefix]#*$parse[delimiter]}
                parse[incomplete]=${parse[incomplete]#*$parse[delimiter]}
                completion_match=( "${(@)completion_match#*$parse[delimiter]}" )
            fi
            if [[ -n $parse[suffix] ]]; then
                parse[nospace]=1
            fi
            completion_match=( "${(@)completion_match/#/$parse[prefix]}" )
            completion_match=( "${(@)^completion_match}$parse[suffix]" )
            completion_match=( "${(@M)completion_match:#$parse[incomplete]*}" )
        fi
        typeset hit key value
        for hit in nospace prefix suffix filenames incomplete files descriptions message; do
            printf 'printf '\''result_settings[%%s]=%%q\n'\'' %s %s\n' ${(qqq)hit} ${(qqq)parse[$hit]}
        done
        # TODO We could try grouping commands and options.
        #for hit in ${(@M)completion_match:#${stack[1]}*}; do
        for hit in ${completion_match}; do
            [[ ${parse[incomplete]} != -* && $hit = -* ]] && continue
            printf 'printf -- '\''result_completions+=( %%q )\\n'\'' %s\n' ${(qqq)hit}
            if (( ${+completions[$hit]} )); then
                printf 'printf -- '\''result_settings[key]=%%q; result_descriptions[${result_settings[key]}]=%%q\\n'\'' %s %s\n' \
                    ${(qqq)hit} ${(qqq)completions[$hit]}
            fi
        done
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
                (( parse[complete] )) || ((top--))
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
                # Check if the flag is valid.
                case $index:$parse[complete] in
                    # Display an error if the argument is not recognized.
                    0:0 )
                        args:user:error $error $funcstack[$depth] unknown $flag $last
                        return
                        ;;
                    # If we are completing and we do not match, we return to our
                    # default completion logic which will use the man page to
                    # match against available options.
                    0:1 )
                        printf 'parse=( %s )\n' ${(j: :)"${(@qq)${(@kv)parse}}"}
                        print return
                        return
                        ;;
                esac
                option=( "${(@QA)${(z)options[$long[$index]]}}" )
                option[matched]="--$flag"
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
                    option[matched]="-$popped[2,2]"
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
                                option[short_prefix]=1
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
        if [[ $state = value && ${#combined} -eq 0 ]]; then
            combined+=( '' )
        fi
        # TODO Come back and remove all the `true`.
        if (( completable )); then
            if [[ $combined = (-|--) ]]; then
                true
            else
                if (( ${+functions[complete${parse[func]#execute}]} )); then
                    printf 'parse[matched]=%s\n' ${(qqq)option[matched]}
                    print ${functions_source[complete:op:put]} >> $parse[debug]
                    printf 'complete%s %s\n' ${parse[func]#execute} "${(j: :)${(@qq)combined}}"
                else
                    printf 'delegate %s\n' "${(j: :)${(@qq)combined}}"
                fi
            fi
        else
            true
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
