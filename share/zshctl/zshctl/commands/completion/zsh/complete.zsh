#compdef zshctl
compdef _zshctl zshctl

# zsh completion for zshctl                                  -*- shell-script -*-

zmodload zsh/datetime
zmodload zsh/stat

function __zshctl_debug {
    local file="$ZSHCTL_COMP_DEBUG_FILE" message
    if [[ -n ${file} ]]; then
        printf -v message "$@"
        print -r "$message" >> "$ZSHCTL_COMP_DEBUG_FILE"
    fi
}

function _zshctl {
    integer start secs nsecs code
    for secs nsecs in "${(@)epochtime}"; do
        start=$(( (secs * 1000) + (nsecs / 1000000) ))
    done
    __zshctl_actual
    code=$?
    for secs nsecs in "${(@)epochtime}"; do
        __zshctl_debug "TOOK: msec <%s>" $(( (secs * 1000) + (nsecs / 1000000) - start ))
    done
    return $code
}

function __zshctl_actual {
    # Disable to restore to expected array expansion.
    setopt localoptions NO_rcexpandparam

    # Silence job control messages from the spinner coproc.
    unsetopt localoptions monitor

    # TODO What else do we get to play with.
    __zshctl_debug '========= starting completion logic =========='
    __zshctl_debug 'CURRENT: %d, words: %s, curcontext %s' $CURRENT ${(j: :)${(@qq)words}} $curcontext
    __zshctl_debug 'curcontext <%s>' $curcontext

    integer ret=1
    _call_function ret _zshctl-foo

    integer code spinner=0

    # Cannot display the spinner if the user is using the very popular
    # autocomplete plugin.
    if [[ ! -v _autocomplete__func_opts ]]; then
        typeset putback=${${BUFFER#$LBUFFER}[1]:- }
        # Zsh `coproc` will net noop traps for SIGINT and SIGQUIT so we are able
        # to always shutdown by sending a message.
        coproc {
            # Close the pipes-to-self we inherited.
            coproc :
            # From StackOverflow. https://unix.stackexchange.com/a/565551
            # Zsh has better unicode support, so LC_LOCALE doesn't matter.
            typeset spin='⣾⣽⣻⢿⡿⣟⣯⣷' line
            # Wait a bit before spinning, may not be necessary.
            read -t 0.2 -r line
            [[ -z $line ]] || return
            # Hide cursor.
            printf '\e[?25l' 1>&2
            # Spin until we get a non-empty line.
            integer i=0
            while [[ -z $line ]]; do
                i=$(( (i + 1) % ${#spin} ))
                printf '%s\033[1D' $spin[$(( i + 1 ))] 1>&2
                read -t 0.1 -r line
            done
            # Put back the character we overwrote.
            printf '%s\b\e[?25h' $putback 1>&2
            __zshctl_debug 'SPINNER EXIT'
        }
        spinner=$!
        function __zshctl_spinner_shutdown {
            print -p close 2>/dev/null # Pipe may be broken.
            wait $spinner
        }
        # Always stop the spinner, even if the reset of the completion code goes
        # haywire and we can't wait on the putback. Note that Zsh will unset
        # these traps when the completion function returns.
        trap 'print -p close 2>/dev/null' INT QUIT TERM EXIT
        __zshctl_debug 'Spinner PID: %d' $spinner
    else
        function __zshctl_spinner_shutdown {
        }
        __zshctl_debug "autocomplete detected"
    fi

    # Question, is there ever any sort of a race condition?

    # Our completion cache for two-part completions.
    typeset -gA __zshctl_cache

    # Our actual completions. TODO Using this?
    typeset completions=()


    typeset out zshctl=(
        "${words[1]}" __complete ${ZSHCTL_COMP_DEBUG_FILE:-/dev/null}
            ${#words} "${(@)words}" $CURRENT
    )
    __zshctl_debug 'About to call: %s' "${(j: :)${(@qq)${(@)zshctl}}}"
    out=$( "${(@)zshctl}" )
    code=$?

    if (( code )); then
        __zshctl_debug "Completion received error. Ignoring completions."
                (( spinner )) && wait $spinner
        return
    fi

    # Use eval to handle any environment variables and such
    __zshctl_debug "completion output: ${out}"

    typeset completions=()
    typeset -A settings descriptions
    eval "$out"

    integer last mtime
    typeset key=$settings[key]
    if [[ -n $key ]]; then
        if [[ ! -e $HOME/.local/state/zshctl/invalidate ]]; then
            mkdir -p $HOME/.local/state/zshctl
            touch $HOME/.local/state/zshctl/invalidate
        fi
        last=${__zshctl_cache[last:]:-0}
        mtime=$(zstat -F %s +mtime $HOME/.local/state/zshctl/invalidate)
        __zshctl_debug 'CACHE AGE: <%d>' $(( EPOCHSECONDS - last ))
        if (( ${ZSHCTL_WIPE_CACHE:-0} || (EPOCHSECONDS - last) > 60 || last < mtime )); then
            __zshctl_debug 'WIPE CACHE'
            __zshctl_cache=()
        fi
        out=$__zshctl_cache[key:$key]
        if [[ -z $out ]]; then
            zshctl=(
                "${words[1]}" __encache ${ZSHCTL_COMP_DEBUG_FILE:-/dev/null}
                    "${(@QA)${(z)settings[invoke]}}"
            )
            __zshctl_debug 'About to call: %s' "${(j: :)${(@qq)${(@)zshctl}}}"
            out=$( "${(@)zshctl}" )
            code=$?
            if (( code )); then
                __zshctl_debug "Completion received error. Ignoring completions."
                (( spinner )) && wait $spinner
                return 0
            fi
        else
            __zshctl_debug 'CACHE HIT'
        fi
        completions=()
        eval "$out"
        if [[ -z $settings[message] ]]; then
            __zshctl_cache[key:$key]=$out
            __zshctl_cache[last:]=$EPOCHSECONDS
            __zshctl_debug "encache output: ${out}"
        fi
    fi

    __zshctl_spinner_shutdown

    if [[ -n $settings[message] ]]; then
        _message -r "${settings[message]}"
        return
    fi

    typeset comp_args=()
    if [[ -n $settings[suffix] ]]; then
        comp_args+=( -q -S "$settings[suffix]" )
    elif (( $settings[nospace] )); then
        comp_args+=( -S '' )
    fi

    if [[ -n $settings[prefix] ]]; then
        comp_args+=( -P "$settings[prefix]" )
    fi

    typeset describe_args=()
    if [[ $settings[order] -eq 1 ]]; then
        __zshctl_debug "Activating keep order."
        describe_args+=( -V )
    fi

    typeset described
    if (( $settings[descriptions] )); then
        for completion in "${(@)completions}"; do
            described+=( "$completion:$descriptions[$completion]" )
        done
    else
        described=( "${(@)completions}" )
    fi

    typeset completer=${${curcontext#:}%%:*}
    __zshctl_debug 'original curcontext <%s>' $curcontext
    __zshctl_debug 'completer <%s>' $completer

    typeset filters=( "${(@QA)${(@z)settings[filters]}}" )
    typeset option describe=() curcontext
    case $settings[kind]:$settings[state] in
    (completions:command)
        describe_args+=( -t commands )
        curcontext=":_zshctl:$completer:${settings[command]}:argument-1"
        describe=(
            _describe "${(@)describe_args}" 'options' described "${(@)comp_args}"
        )
        __zshctl_debug 'curcontext <%s>' $curcontext
        __zshctl_debug 'Calling _describe: %s' "${(j: :)${(@qq)describe}}"
        "${(@)describe}"
        return
        ;;
    (completions:option)
        describe_args+=( -t options )
        curcontext=":_zshctl:$completer:${settings[command]}:"
        describe=(
            _describe "${(@)describe_args}" 'options' described "${(@)comp_args}"
        )
        __zshctl_debug 'curcontext <%s>' $curcontext
        __zshctl_debug 'Calling _describe: %s' "${(j: :)${(@qq)describe}}"
        "${(@)describe}"
        return
        ;;
    (completions:value)
        describe_args+=( -t values )
        option=option-${settings[matched]##*-}-${settings[offset]}
        typeset curcontext=":_zshctl:$completer:${settings[command]}:${option}"
        __zshctl_debug 'comp_args <%s>' "${(j: :)${(@qq)comp_args}}"
        __zshctl_debug 'describe_args <%s>' "${(j: :)${(@qq)describe_args}}"
        __zshctl_debug 'curcontext <%s>' $curcontext
        __zshctl_debug 'described <%s>' "${(j: :)${(@qq)described}}"
        describe=(
            _describe "${(@)describe_args}" 'value' described "${(@)comp_args}"
        )
        __zshctl_debug 'Calling _describe: %s' "${(j: :)${(@qq)describe}}"
        "${(@)describe}"
        __zshctl_debug 'curcontext <%s>' $curcontext
        return
        ;;
    (completions:nothing)
        ;;
    (directories:*)
        typeset curcontext=":_zshctl:$completer:${settings[command]}:argument-rest"
        __zshctl_debug 'curcontext <%s>' $curcontext
        __zshctl_debug 'filters <%s>'  ${#filters}
        __zshctl_debug 'filters <%s>'  ${(@qq)filters}
        __zshctl_debug 'filters <%s>'  ${settings[filters]}
        _directories
        return
        ;;
    (files:*)
        typeset curcontext=":_zshctl:$completer:${settings[command]}:argument-rest"
        __zshctl_debug 'curcontext <%s>' $curcontext
        _files
        return
        ;;
    esac
    return 1
}

# don't run the completion function when being source-ed or eval-ed
if [[ "$funcstack[1]" = "_zshctl" ]]; then
    _zshctl
fi
