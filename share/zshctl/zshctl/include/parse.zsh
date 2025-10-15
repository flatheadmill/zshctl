zmodload zsh/terminfo
zmodload zsh/datetime

function _zshctl_pushf {
    typeset array=${1:-} string
    shift
    printf -v string -- "$@"
    set -A $array "${(@P)array}" "$string"
}

function _zshctl_mandown {
    typeset array=${1:-} lines=( "${(@Af)2}" )
    shift 2
    if [[ -z $lines[-1] ]]; then
        lines=( "${(@)lines[1,-2]}" )
    fi
    setopt localoptions extendedglob
    typeset line mode=scan match=() pushf=_zshctl_pushf
    typeset -A regex=(
        quotes '^(([^`_]|\\`)*)([`_])(.*)$'
        backtick '^(([^`]|\\`)*)([`])(.*)$'
        underbar '^(([^_]|\\`)*)([_])(.*)$'
        list '^([[:space:]]+)\*[[:space:]]+(.*)[[:space:]]+--(.*)'
    )
    integer count=0 is_list=0
    typeset quoted=() list=() quote unquote font outer
    function _zshctl_markdown_debug {
        if (( count == 1 )) && [[ $array = man ]]; then
            printf 'mode >>%s<<\nline >>%s<<\nouter >>%s<<\n' $mode "$line" $outer
            printf '>>%s<<\n' "${(j::)${(@P)array}}"
            exit
        fi
    }
    for line in "${(@)lines}"; do
        outer=$line
        while
            (( count++ ))
            # _zshctl_markdown_debug
            case $mode:$line in
            (scan:\#\#\# *)
                [[ $line = (#b)\#\#\#\ #(*) ]]
                $pushf $array '%s' "${(j::)${(@P)match[1]}}"
                ;;
            (scan:\#\# *)
                [[ $line = (#b)\#\#\ #(*) ]]
                $pushf $array '.SH %s\n' ${match[1]:u}
                ;;
            (scan:\`\`\`*)
                mode=block
                $pushf $array '.EX\n'
                ;;
            (block:\`\`\`)
                mode=scan
                $pushf $array '.EE\n'
                ;;
            (block:*)
                if [[ -z $line ]]; then
                    $pushf $array '%s\n' "$line"
                else
                    $pushf $array '%s\n' "    $line"
                fi
                ;;
            (scan:*)
                if [[ is_list -eq 1 && $outer != '  '* ]]; then
                    is_list=0
                    $pushf $array '.RE\n'
                fi
                if [[ $line =~ $regex[quotes] ]]; then
                    quote="$match[1]"
                    quoted=()
                    mode=quoted
                    case $match[3] in
                    (\`) unquote=backtick font=B ;;
                    (_) unquote=underbar font=I ;;
                    esac
                    line="$match[4]"
                    continue
                elif [[ $line =~ $regex[list] ]]; then
                    if [[ is_list -eq 0 && ${#${match[1]}} > 1 ]]; then
                        is_list=1
                        $pushf $array '.RS\n'
                    fi
                    $pushf $array '.HP\n.B %s\n.br\n' $match[2]
                    line=$match[3]
                    continue
                else
                    $pushf $array '%s\n' "${line##[[:space:]]##}"
                fi
                ;;
            (quoted:*)
                if [[ $line =~ $regex[quotes] ]]; then
                    quoted+=( "$match[1]" )
                    line=$match[4]
                    mode=unquote
                    continue
                else
                    quoted+=( "$line" )
                fi
                ;;
            (unquote:*)
                if [[ -n $quote ]]; then
                    $pushf $array '%s\n' $quote
                fi
                if [[ "$line" =~ ^([^[:space:]])(.*) ]]; then
                    $pushf $array '.%sR %s %s\n' $font "${${(j: :)quoted}// /\\ }" "$line[1]"
                    line=${line##$line[1]}
                else
                    $pushf $array '.%s %s\n' $font "${(j: :)quoted}"
                fi
                line=${line##[[:space:]]##}
                mode=scan
                if [[ -n "$line" ]]; then
                    continue
                fi
                ;;
            esac
            false
        do; :; done;
    done
    if (( is_list )); then
        $pushf $array '.RE\n'
    fi
}

# One function to pretty much gather up everything needed to create a man page,
# to include commands from sub-commands, format a synopsis, format an options
# section, and gather up completions.
#
# Caller defines the following.
#
# lines=() - help definition split as lines with no newline
#
# Caller can opt-in to particular collection by defining one of the following.
#
# terse=() - array of terse description lines without newlines
# verbose=() - array of verbose description lines without newlines
# mandown=() - array of man page lines without newlines
# completions=() - gather completions as name and description pairs
# synopsis=() - array of synopsis section man with newlines
# options=() - array of options section man with newlines
function _zshctl_options {
    [[ -v mandown ]]     || typeset mandown=()
    [[ -v synopsis ]]    || typeset synopsis=()
    [[ -v commands ]]    || typeset commands=()
    [[ ${(t)options} == array-local ]]     || typeset options=()
    [[ -v completions ]] || typeset -A completions=()
    [[ -v completion_match ]] || typeset completion_match=()
    [[ -v terse ]]       || typeset terse=()
    [[ -v verbose ]]     || typeset verbose=()
    typeset -A option regex=(
        arg '^#[[:space:]]+arg[[:space:]]+([^[:space:]]+)(.*)'
        pair '^[[:space:]]+--[[:space:]]+([^=]+=.*)$'
        single '^[[:space:]]+--[[:space:]]+(.*)'
        escaped '^\\.'
    )
    # TODO Must fix.
    typeset split=() match=() markup=() joined=() boolean=() markup=()
    typeset pushf=_zshctl_pushf long mode=scan help trim
    $pushf synopsis '.SH SYNOPSIS\n'
    $pushf synopsis '.SY %s\n' "${(j:\ :)${(@)program_path}}"
    for line in "${(@)lines}"; do
        while
            case $mode:$line in
            (scan:\# terse)
                mode=terse
                ;;
            (terse:\# *)
                mode=scan
                continue
                ;;
            (terse:*)
                terse+=( "$line" )
                ;;
            (scan:\# verbose)
                mode=verbose
                ;;
            (verbose:\# *)
                mode=scan
                continue
                ;;
            (verbose:*)
                verbose+=( "$line" )
                ;;
            (scan:\# man)
                mode=mandown
                ;;
            (scan:\# arg *)
                [[ $line =~ $regex[arg] ]]
                long=$match[1]
                if [[ $match[2] =~ $regex[pair] ]]; then
                    option=( "${(@QA)${(z)_zshctl_options[$long]}}" )
                    $pushf options '.HP\n'
                    if [[ -n $option[short] ]]; then
                        $pushf options '.B \-%s\n' $option[short]
                        $pushf options '.RI %s,\n' $match[1]
                    fi
                    $pushf options '.B %s\n' '\-\-'$long # must put a backslash in front of
                    $pushf options '.RI %s\n' $match[1]
                    $pushf options '.br\n'
                    $pushf synopsis '.RB [ '
                    if [[ -n $option[short] ]]; then
                        $pushf synopsis '\-%s | ' $option[short]
                    fi
                    $pushf synopsis '%s\n' '\-\-'$long # must put a backslash in front of
                    $pushf synopsis '.RI %s]\n' $match[1]
                    mode=argdown
                    markup=()
                elif [[ $match[2] =~ $regex[single] ]]; then
                    option=( "${(@QA)${(z)_zshctl_options[$long]}}" )
                    match=( "${(@)${(@)match##[[:space:]]##}%%[[:space:]]##}" )
                    $pushf options '.HP\n'
                    if [[ -n $option[short] ]]; then
                        $pushf options '.BR \-%s ,\n' $option[short]
                    fi
                    $pushf options '.B \-\-%s\n' $long
                    $pushf options '.RI %s\n' $match[1]
                    $pushf options '.br\n'
                    $pushf synopsis '.RB [ '
                    if [[ -n $option[short] ]]; then
                        $pushf synopsis '\-%s | ' $option[short]
                    fi
                    $pushf synopsis '\-\-%s\n' $long
                    $pushf synopsis '.RI %s]\n' $match[1]
                    mode=argdown
                    markup=()
                else
                    option=( "${(@QA)${(z)_zshctl_options[$long]}}" )
                    $pushf options '.HP\n'
                    if [[ -n $option[short] ]]; then
                        $pushf options '.BR \-%s ,\n' $option[short]
                    fi
                    $pushf options '.B %s\n' '\-\-'$long # must put a backslash in front of
                    $pushf options '.br\n'
                    boolean=()
                    $pushf boolean '.RB [ '
                    if [[ -n $option[short] ]]; then
                        $pushf boolean '\-%s | ' $option[short]
                    fi
                    $pushf boolean '\-\-%s ]\n' $long
                    if [[ $long = help ]]; then
                        help=${(j::)boolean}
                    else
                        $pushf synopsis '%s\n' "${(j::)boolean}"
                    fi
                    mode=argdown
                    markup=()
                fi
                ;;
            (argdown:\# *)
                first=${markup[1]}
                joined="${(pj:\n:)markup}"
                if [[ $joined =~ $regex[escaped] ]]; then
                    joined=${joined#\\}
                    first=${first#\\}
                else
                    first=${first[1]:l}${first[2,-1]}
                fi
                first=${first%.}
                if [[ $zshctl[args:incomplete] = -* ]]; then
                    completion -- --$long $first
                    if [[ -n $option[short] ]]; then
                        completion -- -$option[short] $first
                    fi
                fi
                _zshctl_mandown options "$joined"
                mode=scan
                continue
                ;;
            (argdown:*)
                markup+=( "$line" )
                ;;
            (mandown:\# *)
                mode=scan
                continue
                ;;
            (mandown:*)
                mandown+=( "$line" )
                ;;
            (scan:*)
                ;;
            esac
            false
        do; :; done
    done
    if (( ${#commands} )); then
        $pushf synopsis '.I command\n.RI [ arguments ]\n'
    fi
    if [[ -n $help ]]; then
        $pushf synopsis '.SY %s\n' "${(j:\ :)${(@)program_path}}"
        $pushf synopsis '%s' $help
    fi
    $pushf synopsis '.YS\n'
}

# No longer used directly, and would probably now use function bodies for Zsh
# source and heredocs in functions for other nested files.
#
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

# I'm trying to find a way to edit and preview with the formatting which leads
# me to comment out `| less` and run
#
# ```
# while true; do zshctl gce key | less -XE; sleep 1; done
# ```
#
# Perhaps an enviroment variable?

function usage {
    setopt localoptions extendedglob
    integer top=2
    while [[ $funcstack[$top] != (:execute:*|:execute|:args:*|:args)  ]]; do
        ((top++))
        (( top <= ${#funcstack} )) || abend 'must be called from an :execute or :args function'
    done
    typeset usage=${funcstack[$top]} cols="$(echoti cols)" pushf=_zshctl_pushf
    typeset release_date=$(strftime '%B %-d, %Y' $zshctl[release_date])
    usage=${usage//#:args/:help}
    usage=${usage//#:execute/:help}
    if (( ! ${+functions[$usage]} )); then
        return
    fi
    include heredoc
    typeset execute=${usage//#:help/:execute}
    typeset commands=()
    function {
        typeset sub=() lines=() verbose=() help usage
        typeset -A regex=( escaped '^\\.')
        for cmd in "${(@o)${(@k)_zshctl_commands}}"; do
            [[ $cmd = $execute:[^:]## ]] || continue
            if [[ $_zshctl_commands[$cmd] != ':' ]]; then
                source $_zshctl_commands[$cmd]
            fi
            usage=${cmd//#:execute/:help}
            (( ${+functions[$usage]} )) || continue
            $usage
            lines=( "${(@Af)help}" ) verbose=()
            _zshctl_options
            (( ${#verbose} )) || continue
            if [[ $verbose[1] =~ $regex[escaped] ]]; then
                verbose[1]=${verbose[1]#\\}
            fi
            _zshctl_mandown sub "${(j::)verbose}"
            $pushf commands '.HP\n.B %s\n.br\n%s' ${usage##*:} "${(j::)sub}"
        done
    }
    typeset capitalized=$zshctl[program]${usage#:help}
    typeset program_path=( "${(@As,:,)capitalized}" )
    capitalized=${${capitalized//:/-}:u}
    typeset synopsis=() options=() mandown=() man=() mode=scan terse=() verbose=()
    typeset help joined
    $usage
    typeset lines=( "${(@Af)help}" )
    typeset -A _zshctl_options
    zshctl+=( args:mode help )
    ${usage//#:help/:args}
    zshctl+=( args:mode inline )
    _zshctl_options
    typeset -A regex=( escaped '^\\.')
    if (( ! ${#terse} && ${#verbose} )); then
        joined="${(j::)verbose}"
        if [[ $verbose[1] =~ $regex[escaped] ]]; then
            joined=${joined#\\}
        else
            joined=${joined[1]:l}${joined[2,-1]}
        fi
        joined=${joined%.}
        _zshctl_mandown terse "$joined"
    fi
    if false; then
        printf '.TH %s 1 %s %s %s\n' \
            ${(qqq)capitalized} \
            ${(qqq)release_date} \
            ${(qqq)zshctl[version]} \
            ${(qqq)zshctl[man_title]}
        printf '.SH NAME\n'
        printf '%s \- ' "${(j:\ :)program_path}"
        printf '%s' "${(j::)terse}"
        printf '\n'
        printf '%s' "${(j::)synopsis}"
        printf '>>%s<<\n' "${(pj:\n:)mandown}"
        _zshctl_mandown man "${(pj:\n:)mandown}"
        #printf '>>%s<<\n' "${(j:---:)man}"
        printf '%s' "${(j::)man}"
        exit
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
        printf '.SH NAME\n'
        printf '%s \- ' "${(j:\ :)program_path}"
        printf '%s' "${(j::)terse}"
        printf '\n'
        printf '%s' "${(j::)synopsis}"
        _zshctl_mandown man "${(pj:\n:)mandown}"
        printf '%s' ${(j::)man}
    ) | less
    exit
}

function completion:encache {
    eval "$(args k,key v,valid p,prefix s,suffix -- "$@")"
    zshctl[args:kind]=encache
    zshctl[args:key]=$o_key
    if [[ -v o_prefix ]]; then
        zshctl[args:prefix]=$o_prefix
    fi
    if [[ -v o_suffix ]]; then
        zshctl[args:suffix]=$o_suffix
    fi
    zshctl[args:invoke]=${(j: :)${(@qq)@}}
}

function completion:directories {
    zshctl[args:kind]=directories
    zshctl[args:filters]=${(j: :)${(@qq)@}}
}

function completion:files {
    zshctl[args:kind]=files
    zshctl[args:filters]=${(j: :)${(@qq)@}}
}

function completion {
    eval "$(args -b n,nothing o,ordered f,filenames -s d,delimiter t,tag k,key v,valid p,prefix s,suffix m,message -- "$@")"
    zshctl[args:kind]=completions
    if (( o_nothing )); then
        zshctl[args:state]=nothing
    fi
    if [[ -v o_delimiter ]]; then
        zshctl[args:delimiter]=$o_delimiter
    fi
    if [[ -v o_tag ]]; then
        zshctl[args:tag]=$o_tag
    fi
    if (( o_ordered )); then
        zshctl[args:ordered]=1
    fi
    if [[ -v o_suffix ]]; then
        zshctl[args:suffix]=$o_suffix
    fi
    if [[ -v o_prefix ]]; then
        zshctl[args:prefix]=$o_prefix
    fi
    if [[ -v o_valid ]]; then
        zshctl[args:valid]=$o_valid
    fi
    if [[ -v o_message ]]; then
        zshctl[args:message]=$o_message
    fi
    if (( o_filenames )); then
        zshctl[args:filenames]=1
    fi
    if (( $# )); then
        completion_match+=( ${1:-} )
        if (( $# == 2 )); then
            zshctl[args:descriptions]=1
            completions+=( ${1:-} ${2:-} )
        fi
    fi
}

function _zshctl_completions {
    integer top=2
    while [[ $funcstack[$top] != (:execute:*|:execute|:args:*|:args)  ]]; do
        ((top++))
        (( top <= ${#funcstack} )) || abend 'must be called from an :execute or :args function'
    done
    typeset usage=${funcstack[$top]} cols="$(echoti cols)"
    typeset release_date=$(strftime '%B %-d, %Y' $zshctl[release_date])
    usage=${usage//#:args/:help}
    usage=${usage//#:execute/:help}
    if (( ! ${+functions[$usage]} )); then
        return
    fi
    include heredoc
    typeset execute=${usage//#:help/:execute}
    function {
        setopt localoptions extendedglob
        [[ $zshctl[args:incomplete] = -* ]] && return
        typeset sub=() lines=() verbose=() help usage joined
        typeset -A regex=( escaped '^\\.')
        for cmd in "${(@o)${(@k)_zshctl_commands}}"; do
            [[ $cmd = ${execute}:[^:]## ]] || continue
            if [[ $_zshctl_commands[$cmd] != ':' ]]; then
                source $_zshctl_commands[$cmd]
            fi
            usage=${cmd//#:execute/:help}
            (( ${+functions[$usage]} )) || continue
            $usage
            lines=( "${(@Af)help}" ) verbose=()
            _zshctl_options
            (( ${#verbose} )) || continue
            joined="${(j::)verbose}"
            if [[ $verbose[1] =~ $regex[escaped] ]]; then
                joined=${joined#\\}
            else
                joined=${joined[1]:l}${joined[2,-1]}
            fi
            joined=${joined%.}
            completion ${cmd##*:} $joined
        done
    }
    $usage
    typeset lines=( "${(@Af)help}" ) flag description
    typeset -A _zshctl_options
    zshctl+=( args:mode help )
    ${usage//#:help/:args}
    zshctl+=( args:mode inline )
    _zshctl_options
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
            usage
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

    if [[ $zshctl[args:mode] = help ]]; then
        printf '_zshctl_options=( %s )\n' "${(j: :)${(@qqkv)options}}"
        return
    fi

    if [[ -n $typesets ]]; then
        printf '%s\n' ${(pj:\n:)typesets}
    fi

    if (( top )); then
        state=option
    else
        state=arguments
    fi
    zshctl[args:offset]=1

    integer last
    typeset extant key interspersed=() flag truth=1
    while (( top )); do
        popped=$stack[$top]
        last=$(( top == 1 ))
        case $state:$popped in
        (option:--)
            (( complete )) || ((top--))
            state=arguments
            break
            ;;
        (option:--*)
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
        (option:-?*)
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
        (option:*)
            if (( ! intersperse )); then
                state=arguments
                break
            fi
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
            state=option
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
            zshctl[args:offset]=1
            ;;
        (map)
            state=key
            zshctl[args:offset]=1
            ;;
        (*)
            zshctl[args:offset]=1
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
            printf 'usage\n'
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
        # Your set of provisional switches for your completions. We need to
        # rundown all the values used in the completions and all the values used
        # in our completion functions and determine a useful set.
        printf 'zshctl[args:matched]=%s\n' ${(qqq)option[matched]}
        printf 'zshctl[args:state]=%s\n' ${(qqq)zshctl[args:state]}
        printf 'zshctl[args:offset]=%s\n' ${(qqq)zshctl[args:offset]}
        printf 'zshctl+=( args:mode inline )\n'
        printf '_zshctl_descend_completion %s "$@"\n' $funcstack[$top]
    esac
}
