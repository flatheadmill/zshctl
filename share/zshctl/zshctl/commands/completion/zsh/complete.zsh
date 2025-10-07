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
    # TODO What else do we get to play with.
    __zshctl_debug '========= starting completion logic =========='
    __zshctl_debug 'CURRENT: %d, words: %s' $CURRENT ${(j: :)${(@qq)words}}

    # What does this do?
    unsetopt localoptions MONITOR

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

    typeset result_completions=()
    typeset -A result_settings result_descriptions
    eval "$out"

    integer last mtime
    typeset key=$result_settings[key]
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
                    "${(@QA)${(z)result_settings[invoke]}}"
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
        result_completions=()
        eval "$out"
        if [[ -z $result_settings[message] ]]; then
            __zshctl_cache[key:$key]=$out
            __zshctl_cache[last:]=$EPOCHSECONDS
            __zshctl_debug "encache output: ${out}"
        fi
    fi

    __zshctl_spinner_shutdown

    if [[ -n $result_settings[message] ]]; then
        _message -r "${result_settings[message]}"
        return
    fi

    typeset comp_args=()
    if [[ -n $result_settings[suffix] ]]; then
        comp_args+=( -q -S "$result_settings[suffix]" )
    elif (( $result_settings[nospace] )); then
        comp_args+=( -S '' )
    fi

    if [[ -n $result_settings[prefix] ]]; then
        comp_args+=( -P "$result_settings[prefix]" )
    fi

    typeset args_args=()
    if [ $((directive & shellCompDirectiveKeepOrder)) -ne 0 ]; then
        __zshctl_debug "Activating keep order."
        args_args+=( -V )
    fi

    if (( $result_settings[descriptions] )); then
        for completion in "${(@)result_completions}"; do
            completions+=( "$completion:$result_descriptions[$completion]" )
        done
    else
        completions=( "${(@)result_completions}" )
    fi
    typeset describe=(
        _describe "${(@)args_args}" completions completions "${(@)comp_args}"
    )
    __zshctl_debug 'Calling _describe: %s' "${(j: :)${(@qq)describe}}"
    if "${(@)describe}"; then
        __zshctl_debug "_describe found some completions"
    else
        __zshctl_debug "_describe did not find completions."
        __zshctl_debug "Checking if we should do file completion."
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            __zshctl_debug "deactivating file completion"

            # We must return an error code here to let zsh know that there were no
            # completions found by _describe; this is what will trigger other
            # matching algorithms to attempt to find completions.
            # For example zsh can match letters in the middle of words.
            return 1
        else
            # Perform file completion
            __zshctl_debug "Activating file completion"

            # We must return the result of this command, so it must be the
            # last command, or else we must store its result to return it.
            if [[ -n $result_settings[prefix] ]]; then
                __zshctl_debug '*:filename:_files'" -P $result_settings[prefix]"
                # What is -P and how does it relate to -g?
                _arguments '*:filename:_files'" -P $result_settings[prefix]"
            else
                _arguments '*:filename:_files'
            fi
        fi
    fi
}

# don't run the completion function when being source-ed or eval-ed
if [[ "$funcstack[1]" = "_zshctl" ]]; then
    _zshctl
fi
