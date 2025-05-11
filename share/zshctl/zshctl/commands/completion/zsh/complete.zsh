#compdef zshctl
compdef _zshctl zshctl

# zsh completion for zshctl                                  -*- shell-script -*-

function __zshctl_debug {
    local file="$ZSHCTL_COMP_DEBUG_FILE" message
    if [[ -n ${file} ]]; then
        printf -v message "$@"
        print -r "$message" >> "$ZSHCTL_COMP_DEBUG_FILE"
    fi
}

function _zshctl {
    unsetopt localoptions MONITOR

    typeset out line completions=() executable=()

    # TODO What else do we get to play with.
    __zshctl_debug '========= starting completion logic =========='
    __zshctl_debug 'CURRENT: %d, words: %s' $CURRENT ${(j: :)${(@qq)words}}

    executable=(
        "${words[1]}" __complete zsh ${ZSHCTL_COMP_DEBUG_FILE:-/dev/null}
            $CURRENT "${(@)words}"
    )
    __zshctl_debug 'About to call: %s' "${(j: :)${(@qq)${(@)executable}}}"

    if [[ ! -v _autocomplete__func_opts ]]; then
        typeset putback=${${BUFFER#$LBUFFER}[1]:- }
        integer code spinner=0
        exec 3>&1
        coproc {
            coproc :
            typeset spin='⣾⣽⣻⢿⡿⣟⣯⣷' line
            read -t 0.2 -r line
            [[ -z $line ]] || return
            printf '\e[?25l' 1>&3
            integer i=0
            while [[ -z $line ]]; do
                i=$(( (i + 1) % ${#spin} ))
                printf $spin[$(( i + 1 ))] 1>&3
                echo -en "\033[1D" 1>&3
                read -t 0.1 -r line
            done
            printf '%s\b' ${putback:-} 1>&3
            printf '\e[?25h' 1>&3
        }
        spinner=$!
        trap '(( spinner )) && print -p close' EXIT INT TERM
        __zshctl_debug 'Spinner PID: %d' $spinner
        out=$( "${(@)executable}" )
        code=$?
        print -p close 2>/dev/null # Pipe may be broken.
        wait $spinner
        spinner=0
        exec 3>&-
    else
        __zshctl_debug "autocomplete detected"
        out=$( "${(@)executable}" )
        code=$?
    fi

    if (( code )); then
        __zshctl_debug "Completion received error. Ignoring completions."
        return
    fi

    # Use eval to handle any environment variables and such
    __zshctl_debug "completion output: ${out}"

    typeset result_completions=()
    typeset -A result_settings result_descriptions
    eval "$out"

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

    if false && [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local filteringCmd
        filteringCmd='_files'
        for filter in ${completions[@]}; do
            if [ ${filter[1]} != '*' ]; then
                # zsh requires a glob pattern to do file filtering
                filter="\*.$filter"
            fi
            filteringCmd+=" -g $filter"
        done
        filteringCmd+=" ${flagPrefix}"

        __zshctl_debug "File filtering command: $filteringCmd"
        _arguments '*:filename:'"$filteringCmd"
    elif false && [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subdir
        subdir="${completions[1]}"
        if [ -n "$subdir" ]; then
            __zshctl_debug "Listing directories in $subdir"
            pushd "${subdir}" >/dev/null 2>&1
        else
            __zshctl_debug "Listing directories in ."
        fi

        local result
        _arguments '*:dirname:_files -/'" ${flagPrefix}"
        result=$?
        if [ -n "$subdir" ]; then
            popd >/dev/null 2>&1
        fi
        return $result
    else
        if (( $result_settings[descriptions] )); then
            for completion in "${(@)result_completions}"; do
                completions+=( "$completion:$result_descriptions[$completion]" )
            done
        else
            completions=( "${(@)result_completions}" )
        fi
        executable=(
            _describe "${(@)args_args}" completions completions "${(@)comp_args}"
        )
        __zshctl_debug 'Calling _describe: %s' "${(j: :)${(@qq)executable}}"
        if "${(@)executable}"; then
            __zshctl_debug "_describe found some completions"

            # Return the success of having called _describe
            return 0
        else
                return 1
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
                _arguments '*:filename:_files'" ${flagPrefix}"
            fi
        fi
    fi
}

# don't run the completion function when being source-ed or eval-ed
if [[ "$funcstack[1]" = "_zshctl" ]]; then
    _zshctl
fi
