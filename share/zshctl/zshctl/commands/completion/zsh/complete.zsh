#compdef zshctl
compdef _zshctl zshctl

# zsh completion for zshctl                                  -*- shell-script -*-

__zshctl_debug()
{
    local file="$BASH_COMP_DEBUG_FILE" message
    if [[ -n ${file} ]]; then
        printf -v message "$@"
        print -r "$message" >> "$BASH_COMP_DEBUG_FILE"
    fi
}

_zshctl()
{
    unsetopt localoptions MONITOR

    local out line
    local -a completions

    __zshctl_debug "\n========= starting completion logic =========="
    __zshctl_debug "CURRENT: ${CURRENT}, words[*]: ${words[*]}"

    integer code
    exec 3>&1
    coproc {
        coproc :
        local spin='⣾⣽⣻⢿⡿⣟⣯⣷' line
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
        printf '%s\b' $putback 1>&3
        printf '\e[?25h' 1>&3
    }
    __zshctl_debug "ALL WORDS: ${(j: :)${(@qq)words}}"
    __zshctl_debug "About to call: ${(qq)words[1]} __complete zsh $CURRENT ${(j: :)${(@qq)${(@)words}}}"
    typeset spin=$!
    __zshctl_debug $spin
    out=$("${words[1]}" __complete zsh $CURRENT "${(@)words}" 2>/dev/null)
    code=$?
    print -p close
    wait $spin
    exec 3>&-

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
            for completion in "{(@)result_completions}"; do
                completions+=( "$completion:$result_descriptions[$completion]" )
            done
        else
            completions=( "${(@)result_completions}" )
        fi
        __zshctl_debug "Calling _describe"
        #__zshctl_debug eval _describe $keepOrder "completions" completions $flagPrefix $noSpace
        if eval _describe "${(@)args_args}" "completions" completions "${(@)comp_args}"; then
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
if [ "$funcstack[1]" = "_zshctl" ]; then
    _zshctl
fi
