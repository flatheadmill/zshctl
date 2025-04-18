#compdef zshctl
compdef _zshctl zshctl

function cursorBack() {
  echo -en "\033[$1D"
  # Mac compatible, but goes back to first column always. See comments
  #echo -en "\r"
}

# zsh completion for zshctl                                  -*- shell-script -*-

__zshctl_debug()
{
    local file="$BASH_COMP_DEBUG_FILE"
    if [[ -n ${file} ]]; then
        echo "$*" >> "${file}"
    fi
}

function __zshctl_spinner {
    unsetopt localoptions MONITOR
    trap 'loop=0; print trapped >> ~/foo.txt' TERM
    local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
    tput civis
    sleep .2
    integer i=0 loop=1
    print ${#spin} >> ~/foo.txt
    while (( loop )); do
        i=$(( (i + 1) % ${#spin} ))
        printf $spin[$(( i + 1 ))]'\b'
        sleep .1
    done
    tput cnorm
}

_zshctl()
{
    unsetopt localoptions MONITOR
    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16
    local shellCompDirectiveKeepOrder=32
    local shellCompDirectiveSlash=64
    local shellCompDirectiveEquals=128
    local shellCompDirectiveColon=256
    local shellCompDirectivePrefix=512
    local shellCompDirectiveShortPrefix=1024

    local lastParam lastChar flagPrefix requestComp out directive comp lastComp noSpace keepOrder
    local line
    local -a completions

    __zshctl_debug "\n========= starting completion logic =========="
    __zshctl_debug "CURRENT: ${CURRENT}, words[*]: ${words[*]}"

    typeset w
    for  w in "${(@)words}"; do
        printf -v w '%q' $w
        __zshctl_debug "word: $w"
    done

    # The user could have moved the cursor backwards on the command-line.
    # We need to trigger completion from the $CURRENT location, so we need
    # to truncate the command-line ($words) up to the $CURRENT location.
    # (We cannot use $CURSOR as its value does not work when a command is an alias.)
    words=("${=words[1,CURRENT]}")
    __zshctl_debug "Truncated words[*]: ${words[*]},"

    lastParam=${words[-1]}
    lastChar=${lastParam[-1]}
    __zshctl_debug "lastParam: ${lastParam}, lastChar: ${lastChar}"

    # For zsh, when completing a flag with an = (e.g., zshctl -n=<TAB>)
    # completions must be prefixed with the flag
    setopt local_options BASH_REMATCH
    if [[ "${lastParam}" =~ '-.*=' ]]; then
        # We are dealing with a flag with an =
        flagPrefix="-P ${BASH_REMATCH}"
    fi

    # Prepare the command to obtain completions
    typeset putback=${${BUFFER#$LBUFFER}[1]:- }
    requestComp="${words[1]} __complete ${words[2,-1]}"
    if [ "${lastChar}" = "" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go completion code.
        __zshctl_debug "Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

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
    __zshctl_debug "About to call: eval <${requestComp}>"
    typeset spin=$!
    __zshctl_debug $spin
    out=$(eval ${requestComp} 2>/dev/null)
    print -p close
    wait $spin
    exec 3>&-
    zle -R

    # Use eval to handle any environment variables and such
    __zshctl_debug "completion output: ${out}"

    # Extract the directive integer following a : from the last line
    local lastLine
    while IFS='\n' read -r line; do
        lastLine=${line}
    done < <(printf "%s\n" "${out[@]}")
    __zshctl_debug "last line: ${lastLine}"

    if [ "${lastLine[1]}" = : ]; then
        directive=${lastLine[2,-1]}
        # Remove the directive including the : and the newline
        local suffix
        (( suffix=${#lastLine}+2))
        out=${out[1,-$suffix]}
    else
        # There is no directive specified.  Leave $out as is.
        __zshctl_debug "No directive found.  Setting do default"
        directive=0
    fi

    __zshctl_debug "directive: ${directive}"
    __zshctl_debug "completions: ${out}"
    __zshctl_debug "flagPrefix: ${flagPrefix}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        __zshctl_debug "Completion received error. Ignoring completions."
        return
    fi

    local activeHelpMarker="_activeHelp_ "
    local endIndex=${#activeHelpMarker}
    local startIndex=$((${#activeHelpMarker}+1))
    local hasActiveHelp=0
    while IFS='\n' read -r comp; do
        # Check if this is an activeHelp statement (i.e., prefixed with $activeHelpMarker)
        if [ "${comp[1,$endIndex]}" = "$activeHelpMarker" ];then
            __zshctl_debug "ActiveHelp found: $comp"
            comp="${comp[$startIndex,-1]}"
            if [ -n "$comp" ]; then
                _message -r "${comp}"
                __zshctl_debug "ActiveHelp will need delimiter"
                hasActiveHelp=1
            fi

            continue
        fi

        if [ -n "$comp" ]; then
            # If requested, completions are returned with a description.
            # The description is preceded by a TAB character.
            # For zsh's _describe, we need to use a : instead of a TAB.
            # We first need to escape any : as part of the completion itself.
            comp=${comp//:/\\:}

            local tab="$(printf '\t')"
            comp=${comp//$tab/:}

            __zshctl_debug "Adding completion: ${comp}"
            completions+=${comp}
            lastComp=$comp
        fi
    done < <(printf "%s\n" "${out[@]}")

    # Add a delimiter after the activeHelp statements, but only if:
    # - there are completions following the activeHelp statements, or
    # - file completion will be performed (so there will be choices after the activeHelp)
    if [ $hasActiveHelp -eq 1 ]; then
        if [ ${#completions} -ne 0 ] || [ $((directive & shellCompDirectiveNoFileComp)) -eq 0 ]; then
            __zshctl_debug "Adding activeHelp delimiter"
            compadd -x "--"
            hasActiveHelp=0
        fi
    fi

    if [ $((directive & shellCompDirectiveSlash)) -ne 0 ]; then
        __zshctl_debug "Activating slash."
        noSpace="-q -S '/'"
    elif [ $((directive & shellCompDirectiveEquals)) -ne 0 ]; then
        __zshctl_debug "Activating equals."
        noSpace="-q -S '='"
    elif [ $((directive & shellCompDirectiveColon)) -ne 0 ]; then
        __zshctl_debug "Activating colon."
        noSpace="-q -S ':'"
    elif [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
        __zshctl_debug "Activating nospace."
        noSpace="-S ''"
    fi

    if [ $((directive & shellCompDirectivePrefix)) -ne 0 ]; then
        # We are dealing with a flag with an =
        flagPrefix="-P ${lastParam%%=*}="
    elif [ $((directive & shellCompDirectiveShortPrefix)) -ne 0 ]; then
        flagPrefix="-P ${lastParam[1,2]}"
    fi

    if [ $((directive & shellCompDirectiveKeepOrder)) -ne 0 ]; then
        __zshctl_debug "Activating keep order."
        keepOrder="-V"
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
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
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
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
        __zshctl_debug "Calling _describe"
        #__zshctl_debug eval _describe $keepOrder "completions" completions $flagPrefix $noSpace
        if eval _describe $keepOrder "completions" completions $flagPrefix $noSpace; then
            __zshctl_debug "_describe found some completions"

            # Return the success of having called _describe
            return 0
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
                _arguments '*:filename:_files'" ${flagPrefix}"
            fi
        fi
    fi
}

# don't run the completion function when being source-ed or eval-ed
if [ "$funcstack[1]" = "_zshctl" ]; then
    _zshctl
fi
