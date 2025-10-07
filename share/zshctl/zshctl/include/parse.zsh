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

function _zshctl_options {
}

#
function usage {
    setopt localoptions extendedglob
    typeset usage=${1:-$funcstack[2]} man=${2:-0} cols="$(echoti cols)"
    typeset release_date=$(strftime '%B %-d, %Y' $zshctl[release_date])
    typeset capitalized=$zshctl[program]:${usage#*:} state=copy
    capitalized=${${capitalized//:/-}:u}
    typeset mandoc=() lines=() split=() line cmd src=()
    integer dirty=1
    usage=${usage//#:args/:execute}
    mandoc=( "${(@Af)"$(resource "$usage _ man" $functions_source[$usage])"}" )
    # Note that we process the mandoc in a dirty loop because the descriptions
    # we include from sub-commands may have .PG directives that need to be
    # expanded.
    while (( dirty )); do
        dirty=0
        lines=( "${(@)mandoc}" )
        mandoc=()
        for line in "${(@)lines}"; do
            case $state:$line in
            (skip:.SH*)
                mandoc+=( "$line" )
                state=copy
                ;;
            (skip:*)
                ;;
            (copy:.YS*)
                mandoc+=( "$line" )
                state=skip
                ;;
            (copy:.DC\ *)
                line=${line#.DC }
                (( man )) && line="${line[1]:l}${line[2,-1]}"
                mandoc+=( "$line" )
                ;;
            (copy:.PG\ *)
                line=${line//__program__/$zshctl[program]}
                line=${line#.PG }
                mandoc+=( "$line" )
                ;;
            (copy:.ZC\ *)
                line=${line#.ZC }
                case $line in
                    commands )
                        for cmd in "${(@o)${(@k)_zshctl_commands}}"; do
                            if [[ $cmd = $usage:[^:]## ]]; then
                                if [[ $_zshctl_commands[$cmd] = ':' ]]; then
                                    src=$functions_source[$cmd]
                                else
                                    src=$_zshctl_commands[$cmd]
                                fi
                                src=( "${(@Af)"$(resource "$cmd _ man" $src)"}" )
                                if [[ -n $src ]]; then
                                    function {
                                        typeset lines=( "${(@)src}" ) line gather=() state=scan
                                        for line in "${(@)lines}"; do
                                            case $state:$line in
                                            (scan:.YS*)
                                                state=gather
                                                ;;
                                            (gather:.SH*)
                                                break
                                                ;;
                                            (gather:*)
                                                gather+=( $line )
                                                ;;
                                            esac
                                        done
                                        dirty=1
                                        mandoc+=( .TP ".B ${cmd##*:}" .br "${(@)gather}" )
                                    }
                                fi
                            fi
                        done
                        ;;
                esac
                ;;
            (*)
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
    eval "$(args -b w,waiting f,files o,ordered p,prefixed S,short-prefixed -s v,valid s,suffix m,message -- "$@")"
    zshctl[args:flags]=$(( zshctl[args:flags] | 4 ))
    zshctl[args:completed]=1
    if (( o_wating && ! zshctl[args:waiting] )); then
        zshctl[args:waiting]=1
        print ':progress'
    fi
    if (( o_short_prefixed )); then
        zshctl[args:flags]=$(( zshctl[args:flags] | 2 ))
        zshctl[args:flags]=$(( zshctl[args:flags] | 1024 ))
    fi
    if (( o_prefixed )); then
        zshctl[args:flags]=$(( zshctl[args:flags] | 512 ))
    fi
    if (( o_ordered )); then
        zshctl[args:flags]=$(( zshctl[args:flags] | 32 ))
    fi
    if [[ -v o_suffix ]]; then
        zshctl[args:flags]=$(( zshctl[args:flags] | 2 ))
        case $o_suffix[2] in
        (/) zshctl[args:flags]=$(( zshctl[args:flags] | 64 ));;
        (=) zshctl[args:flags]=$(( zshctl[args:flags] | 128 ));;
        (:) zshctl[args:flags]=$(( zshctl[args:flags] | 256 ));;
        esac
        zshctl[args:flags]=$(( zshctl[args:flags] | 4 ))
    fi
    if (( o_files )); then
        print -u 2 files
        zshctl[args:flags]=$(( zshctl[args:flags] & (~4) ))
    fi
    if [[ -v o_valid ]]; then
        zshctl[args:valid]=$o_valid
    fi
    if [[ -v o_message ]]; then
        zshctl[args:message]=$o_message
        zshctl[args:flags]=$(( zshctl[args:flags] | 4 ))
    fi
    if (( $# )); then
        completion_match+=( ${1:-} )
        if (( $# == 2 )); then
            zshctl[args:descriptions]=1
            completions+=( ${1:-} ${2:-} )
        fi
    fi
}

function completions {
    typeset func=${1:-}
    shift
    typeset lines=() line
    lines=( "${(@Af)$(usage $func 1)}" )
    typeset state=seek mandoc=( '.TH Ignore 1 "Manuals" "STOP" "Manuals"' )
    for line in "${(@Af)lines}"; do
        case $state:$line in
        (*:.SH\ OPTIONS | *:.SH\ COMMANDS)
            mandoc+=( "$line" )
            state=tp
            ;;
        (tp:.HS)
            break
            ;;
        (tp:.TP | desc:.TP)
            mandoc+=( "$line" )
            state=br
            ;;
        (br:*)
            state=desc
            mandoc+=( "$line" .br )
            ;;
        (desc:.SH*)
            state=none
            ;;
        (desc:''|desc:.JN*)
            state=tp
            ;;
        (desc:?*)
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
        (*:STOP*)
            state=
            ;;
        (*:OPTIONS | *:COMMANDS)
            state=key
            ;;
        (key:?*)
            # Trim whitespace.
            key=${(MS)line##[[:graph:]]*[[:graph:]]}
            # Strip all formatting.
            key=${key//$~backspaced/}
            # Look for our value.
            state=value
            ;;
        (value:*)
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
                zshctl[args:descriptions]=1
                #completions+=( $key ${line[1]:l}$line[2,-1] )
                completions+=( $key ${line%.} )
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
    (complete)
        if (( ${+functions[complete:${func#execute:}]} )); then
            printf 'complete:%s %s\n' ${func#execute:} "${(j: :)${(@qq)@}}"
        else
            printf 'delegate %s\n' "${(j: :)${(qq)@}}"
        fi
        ;;
    (unknown)
        printf 'unknown argument `%s`.\n' $flag 1>&2
        exit 1
        ;;
    (required)
        printf '`%s` is a required argument.\n' $flag 1>&2
        exit 1
        ;;
    (execute)
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

    typeset -A completions=()
    typeset completion_match=()

    # Initial loop to grab the definition and to define the variables to which
    # arguments will be assigned.
    typeset -A option=( kind scalar defined 0 required 0 ) short options missing
    typeset split=() declared=() stack=( "${(@Oa)@}" )
    typeset popped on_zeroed state=option typesets=() tset
    integer top=${#stack} intersperse=0 usage=0 completable=0 delegated=0 complete=0
    [[ $zshctl[args:mode] = completion ]] && complete=1
    while (( top )); do
        popped=$stack[$top]
        case $state:$popped in
        # Definitions finished.
        (*:--)
            ((top--))
            break
            ;;
        # Short flags to the argument parser itself. Captial letters
        # represent global options.Lower case letters are options that
        # apply the subsequent field defintions or a single next
        # defintiion depending on option.
        (*:-*)
            state=option
            case $popped in
            (-D*)
                delegated=1
                ;;
            (-C*)
                completable=1
                ;;
            (-U*)
                usage=1
                ;;
            (-@*)
                intersperse=1
                ;;
            (-!*)
                option[negatable]=1
                if (( ${#popped} > 2 )); then
                    popped="-${popped[3,-1]}"
                    option[short_negation]=${popped[2,2]}
                fi
                ;;
            (-a*)
                option[kind]=array
                ;;
            (-A*)
                option[kind]=map
                ;;
            (-b*)
                option[kind]=boolean
                ;;
            (-c*)
                option[kind]=counter
                ;;
            (-d*)
                option[defined]=1 # resets after a single defintion.
                ;;
            (-i*)
                option[kind]=number
                ;;
            (-r*)
                option[required]=1
                ;;
            (-s*)
                option[kind]=scalar
                ;;
            (-t*)
                option[kind]=toggle
                ;;
            (-x*)
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
        (option:[a-zA-Z0-9]#,[a-zA-Z][a-zA-Z-]#[a-z])
            split=( "${(@s:,:)popped}" )
            if [[ -n $split[1] ]]; then
                short[$split[1]]=$split[2]
            fi
            option[short]=$split[1]
            option[long]=$split[2]
            option[var]=$split[2]
            options[$option[long]]=${(j: :)${(@qqkv)option}}
            if (( ! $option[defined] && ! complete )); then
                case $option[kind] in
                (counter | boolean | toggle)
                    printf -v tset 'integer o_%s=0' ${option[var]//-/_}
                    ;;
                (array)
                    printf -v tset 'typeset o_%s=()' ${option[var]//-/_}
                    ;;
                (map)
                    printf -v tset 'typeset -A o_%s=()' ${option[var]//-/_}
                    ;;
                (*)
                    printf -v tset 'typeset o_%s' ${option[var]//-/_}
                    typesets+=( $tset )
                    printf -v tset 'unset o_%s' ${option[var]//-/_}
                    ;;
                esac
                typesets+=( $tset )
            fi
            if (( $option[required] )); then
                missing[$option[long]]=1
            fi
            if (( $option[negatable] )); then
                if (( ${+option[short_negation]} )); then
                    short[$option[short_negation]]=no-$split[2]
                fi
                option[negate]=1
                option[short]=$option[short_negation]
                option[long]=no-$split[2]
                option[var]=$split[2]
                options[$option[long]]=${(j: :)${(@qqkv)option}}
            fi
            option=( kind $option[kind] defined 0 required 0 )
            ((top--))
            ;;
        # Error in parsing.
        (*)
            print -u 2 "unable to interpret $popped"
            args:user:error $funcstack[$depth] compile - 0
            exit 1
            ;;
        esac
    done

    if [[ -n $typesets ]]; then
        printf '%s\n' ${(pj:\n:)typesets}
    fi

    state=switch

    integer last
    typeset extant key interspersed=() flag truth=1
    while (( top )); do
        popped=$stack[$top]
        last=$(( top == 1 ))
        case $state:$popped in
        (switch:--)
            (( complete )) || ((top--))
            break
            ;;
        (switch:--*)
            # First determine the flag name so we can look up the options
            # definition. Note that this case statement has spaces in it
            # because the ViM Zsh syntax cannot parse it otherwise.
            case $popped in
            ( (#b)--([^=]##)=(*) )
                flag=$match[1]
                stack[$top]=$match[2]
                ;;
            ( (#b)--(*) )
                flag=$match[1]
                ((top--))
            esac
            # Should we complain if the argument is ambiguous? Currently, we are
            # just accepting the first match in alphabetical order.
            extant=${+options[$flag]} # 0 if missing, 1 if extant.
            # Check if the flag is valid.
            case $extant:$complete in
            # Display an error if the argument is not recognized.
            (0:0)
                args:user:error $error $funcstack[$depth] unknown $flag $last
                return
                ;;
            # If we are completing and we do not match, we return to our
            # default completion logic which will use the man page to
            # match against available options.
            (0:1)
                printf 'parse=( %s )\n' ${(j: :)"${(@qq)${(@kv)parse}}"}
                print return
                return
                ;;
            esac
            option=( "${(@QA)${(z)options[$flag]}}" )
            option[matched]=$popped
            missing[$option[long]]=0
            # Check if assignment syntax was used on non-assignable types
            case $popped in
            ( (#b)--([^=]##)=* )
                case $option[kind] in
                (boolean | counter)
                    printf '%s %s unassignable %s %s\n' $error $funcstack[$depth] --$match[1] $last
                    return
                    ;;
                esac
                ;;
            esac
            ;;
        (switch:-?*)
            flag=${popped[2,2]}
            if (( ! ${+short[${popped[2,2]}]} )); then
                printf '%s %s unknown %s %s\n' $error $funcstack[$depth] $popped[1,2] $last
                return
            else
                option=( "${(@QA)${(z)options[$short[$popped[2,2]]]}}" )
                option[matched]="-$popped[2,2]"
                missing[$option[long]]=0
                case $option[kind] in
                (boolean | counter)
                    if (( ${#popped} == 2 )); then
                        ((top--))
                    else
                        stack[$top]=-${popped[3,-1]}
                    fi
                    ;;
                (*)
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
        (switch:*)
            (( intersperse )) || break
            interspersed+=( $popped )
            ((top--))
            continue
            ;;
        (key:*)
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
        (value:*)
            case $option[kind] in
            (array)
                printf 'o_%s+=( %s )\n' ${option[var]//-/_} ${(qq)popped}
                ;;
            (map)
                printf '(){ typeset key=%s; o_%s[$key]=%s; }\n' ${(qq)key} ${option[var]//-/_} ${(qq)popped}
                ;;
            (scalar)
                printf 'o_%s=%s\n' ${option[var]//-/_} ${(qq)popped}
                ;;
            (number)
                printf 'o_%s=%s\n' ${option[var]//-/_} ${(qq)popped}
                ;;
            (boolean)
                printf 'o_%s=%d\n' ${option[var]//-/_} $popped
                ;;
            (counter)
                printf '((++o_%s))\n' ${option[var]//-/_}
                ;;
            (toggle)
                printf 'o_%s=$(( ! o_%s ))\n' ${option[var]//-/_} ${option[var]//-/_}
                ;;
            esac
            stack[$top]=0
            state=execute
            continue
            ;;
        (execute:0)
            if (( ${option[execute]:-0} && ! complete  )); then
                printf '%s %s %s %s\n' $error $funcstack[$depth] execute "--$option[long]"
                return
            fi
            truth=1
            state=switch
            ((top--))
            continue
            ;;
        (*)
            print derp
            exit 1
            ;;
        esac
        zshctl[args:long]=$option[long]
        case $option[kind] in
        (boolean | counter | toggle)
            ((top++))
            stack[$top]=$(( ! ${option[negate]:-0} ))
            state=value
            ;;
        (map)
            state=key
            ;;
        (*)
            state=value
            ;;
        esac
    done
    zshctl[args:state]=$state
    if (( ! complete )); then
        # TODO Assert we did not stop mid argument.
        case $state in
        (key)
            ;;
        (value)
            ;;
        esac
        for flag in ${(@k)missing}; do
            if (( $missing[$flag] )); then
                printf '%s %s %s %s\n' $error $funcstack[$depth] required "--$flag"
            fi
        done
    fi
    typeset combined=( "${(@)interspersed}" "${(@Oa)stack[1,$top]}" )
    if (( ${#combined} )); then
        printf 'set -- %s\n' ${(j: :)${(@qq)combined}}
    else
        printf 'set --\n'
    fi
    # If we are invoked from command descent, we must call the actual
    # execution function. In order to use `args` to parse internal
    # function arguments, we also have to reset `_zshctl`.
    case $zshctl[args:mode] in
    (execute)
        if (( usage && ! ${#combined} )); then
            printf 'usage %s\n' $funcstack[$depth]
        else
            printf 'zshctl[args:mode]=inline\n'
            printf '%s "$@"\n' $zshctl[args:func]
        fi
        ;;
    (completion)
        integer top=2
        while [[ $funcstack[$top] != (:args:*|:args) ]]; do
            ((top++))
            (( top <= ${#funcstack} )) || abend 'must be called from an args function'
        done
        printf 'zshctl[args:matched]=%s\n' ${(qqq)option[matched]}
        printf 'zshctl[args:state]=%s\n' ${(qqq)zshctl[args:state]}
        printf 'zshctl+=( args:mode inline )\n'
        printf '_zshctl_descend_completion %s "$@"\n' $funcstack[$top]
    esac
}
