# bash completion V2 for zshctl                                  -*- shell-script -*-

__zshctl_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE-} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Macs have bash3 for which the bash-completion package doesn't include
# _init_completion. This is a minimal version of that function.
__zshctl_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

# This function calls the zshctl program to obtain the completion
# results and the directive.  It fills the 'out' and 'directive' vars.
__zshctl_get_completion_results() {
    local -
    set +m
    local requestComp lastParam lastChar args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly zshctl allows to handle aliases
    args=("${words[@]:1}")
    requestComp="${words[0]} __complete ${args[*]}"

    local w
    for w in "${words[@]}"; do
        __zshctl_debug "word: $w"
    done

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __zshctl_debug "lastParam ${lastParam}, lastChar ${lastChar}"

    if [[ -z ${cur} && ${lastChar} != = ]]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __zshctl_debug "Adding extra empty parameter"
        requestComp="${requestComp} ''"
    fi

    # When completing a flag with an = (e.g., zshctl -n=<TAB>)
    # bash focuses on the part after the =, so we need to remove
    # the flag part from $cur
    if [[ ${cur} == -*=* ]]; then
        cur="${cur#*=}"
    fi

    __zshctl_debug "Calling <${requestComp}>"
    exec 3>&1
    {
        {
            coproc spinner {
                local LC_CTYPE=C
                local charwidth=3
                local spin='⣾⣽⣻⢿⡿⣟⣯⣷' line
                read -t 0.2 -r line
                [[ -z $line ]] || return
                printf '\e[?25l' 1>&3
                local i=0
                while [[ -z $line ]]; do
                    i=$(( (i + $charwidth ) % ${#spin} ))
                    printf "%s" ${spin:$i:$charwidth} 1>&3
                    echo -en "\033[1D" 1>&3
                    read -t 0.1 -r line
                done
                echo -en " \033[1D" 1>&3
                printf '\e[?25h' 1>&3
            }
        }
    } 2>/dev/null
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)
    echo close >&"${spinner[1]}"
    wait $spinner_PID
    exec 3>&-

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [[ ${directive} == "${out}" ]]; then
        # There is not directive specified
        directive=0
    fi
    __zshctl_debug "The completion directive is: ${directive}"
    __zshctl_debug "The completions are: ${out}"
}

__zshctl_process_completion_results() {
    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16
    local shellCompDirectiveKeepOrder=32
    local shellCompDirectiveSlash=64
    local shellCompDirectiveEquals=128
    local shellCompDirectiveColon=256

    if (((directive & shellCompDirectiveError) != 0)); then
        # Error code.  No completion.
        __zshctl_debug "Received error from custom completion go code"
        return
    else
        if (((directive & shellCompDirectiveSlash) != 0)); then
            out=$(awk -v suffix=/ '$0 != "" { print $0 suffix }' <<<"$out")
        elif (((directive & shellCompDirectiveEquals) != 0)); then
            out=$(awk -v suffix== '$0 != "" { print $0 suffix }' <<<"$out")
        elif (((directive & shellCompDirectiveColon) != 0)); then
            out=$(awk -v suffix=: '$0 != "" { print $0 suffix }' <<<"$out")
        fi
        if (((directive & shellCompDirectiveNoSpace) != 0)); then
            if [[ $(type -t compopt) == builtin ]]; then
                __zshctl_debug "Activating no space"
                compopt -o nospace
            else
                __zshctl_debug "No space directive not supported in this version of bash"
            fi
        fi
        if (((directive & shellCompDirectiveKeepOrder) != 0)); then
            if [[ $(type -t compopt) == builtin ]]; then
                # no sort isn't supported for bash less than < 4.4
                if [[ ${BASH_VERSINFO[0]} -lt 4 || ( ${BASH_VERSINFO[0]} -eq 4 && ${BASH_VERSINFO[1]} -lt 4 ) ]]; then
                    __zshctl_debug "No sort directive not supported in this version of bash"
                else
                    __zshctl_debug "Activating keep order"
                    compopt -o nosort
                fi
            else
                __zshctl_debug "No sort directive not supported in this version of bash"
            fi
        fi
        if (((directive & shellCompDirectiveNoFileComp) != 0)); then
            if [[ $(type -t compopt) == builtin ]]; then
                __zshctl_debug "Activating no file completion"
                compopt +o default
            else
                __zshctl_debug "No file completion directive not supported in this version of bash"
            fi
        fi
    fi

    # Separate activeHelp from normal completions
    local completions=()
    local activeHelp=()
    __zshctl_extract_activeHelp

    if (((directive & shellCompDirectiveFilterFileExt) != 0)); then
        # File extension filtering
        local fullFilter filter filteringCmd

        # Do not use quotes around the $completions variable or else newline
        # characters will be kept.
        for filter in ${completions[*]}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __zshctl_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif (((directive & shellCompDirectiveFilterDirs) != 0)); then
        # File completion for directories only

        local subdir
        subdir=${completions[0]}
        if [[ -n $subdir ]]; then
            __zshctl_debug "Listing directories in $subdir"
            pushd "$subdir" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
        else
            __zshctl_debug "Listing directories in ."
            _filedir -d
        fi
    else
        __zshctl_handle_completion_types
    fi

    __zshctl_handle_special_char "$cur" :
    __zshctl_handle_special_char "$cur" =

    # Print the activeHelp statements before we finish
    if ((${#activeHelp[*]} != 0)); then
        printf "\n";
        printf "%s\n" "${activeHelp[@]}"
        printf "\n"

        # The prompt format is only available from bash 4.4.
        # We test if it is available before using it.
        if (x=${PS1@P}) 2> /dev/null; then
            printf "%s" "${PS1@P}${COMP_LINE[@]}"
        else
            # Can't print the prompt.  Just print the
            # text the user had typed, it is workable enough.
            printf "%s" "${COMP_LINE[@]}"
        fi
    fi
}

# Separate activeHelp lines from real completions.
# Fills the $activeHelp and $completions arrays.
__zshctl_extract_activeHelp() {
    local activeHelpMarker="_activeHelp_ "
    local endIndex=${#activeHelpMarker}

    while IFS='' read -r comp; do
        if [[ ${comp:0:endIndex} == $activeHelpMarker ]]; then
            comp=${comp:endIndex}
            __zshctl_debug "ActiveHelp found: $comp"
            if [[ -n $comp ]]; then
                activeHelp+=("$comp")
            fi
        else
            # Not an activeHelp line but a normal completion
            completions+=("$comp")
        fi
    done <<<"${out}"
}

__zshctl_handle_completion_types() {
    __zshctl_debug "__zshctl_handle_completion_types: COMP_TYPE is $COMP_TYPE"

    case $COMP_TYPE in
    37|42)
        # Type: menu-complete/menu-complete-backward and insert-completions
        # If the user requested inserting one completion at a time, or all
        # completions at once on the command-line we must remove the descriptions.
        # https://github.com/spf13/cobra/issues/1508
        local tab=$'\t' comp
        while IFS='' read -r comp; do
            [[ -z $comp ]] && continue
            # Strip any description
            comp=${comp%%$tab*}
            # Only consider the completions that match
            if [[ $comp == "$cur"* ]]; then
                COMPREPLY+=("$comp")
            fi
        done < <(printf "%s\n" "${completions[@]}")
        ;;

    *)
        # Type: complete (normal completion)
        __zshctl_handle_standard_completion_case
        ;;
    esac
}

__zshctl_handle_standard_completion_case() {
    local tab=$'\t' comp

    # Short circuit to optimize if we don't have descriptions
    if [[ "${completions[*]}" != *$tab* ]]; then
        IFS=$'\n' read -ra COMPREPLY -d '' < <(compgen -W "${completions[*]}" -- "$cur")
        return 0
    fi
    __zshctl_debug "cur <$cur>"

    local longest=0
    local compline
    # Look for the longest completion so that we can format things nicely
    while IFS='' read -r compline; do
        [[ -z $compline ]] && continue
        # Strip any description before checking the length
        comp=${compline%%$tab*}
        # Only consider the completions that match
        [[ $comp == "$cur"* ]] || continue
        COMPREPLY+=("$compline")
        if ((${#comp}>longest)); then
            longest=${#comp}
        fi
    done < <(printf "%s\n" "${completions[@]}")

    # If there is a single completion left, remove the description text
    if ((${#COMPREPLY[*]} == 1)); then
        __zshctl_debug "COMPREPLY[0]: ${COMPREPLY[0]}"
        comp="${COMPREPLY[0]%%$tab*}"
        __zshctl_debug "Removed description from single completion, which is now: ${comp}"
        COMPREPLY[0]=$comp
    else # Format the descriptions
        __zshctl_format_comp_descriptions $longest
    fi
}

__zshctl_handle_special_char()
{
    local comp="$1"
    local char=$2
    if [[ "$comp" == *${char}* && "$COMP_WORDBREAKS" == *${char}* ]]; then
        local word=${comp%"${comp##*${char}}"}
        local idx=${#COMPREPLY[*]}
        __zshctl_debug "handle special char $word $idx"
        while ((--idx >= 0)); do
            COMPREPLY[idx]=${COMPREPLY[idx]#"$word"}
        done
    fi
}

__zshctl_format_comp_descriptions()
{
    local tab=$'\t'
    local comp desc maxdesclength
    local longest=$1

    local i ci
    for ci in ${!COMPREPLY[*]}; do
        comp=${COMPREPLY[ci]}
        # Properly format the description string which follows a tab character if there is one
        if [[ "$comp" == *$tab* ]]; then
            __zshctl_debug "Original comp: $comp"
            desc=${comp#*$tab}
            comp=${comp%%$tab*}

            # $COLUMNS stores the current shell width.
            # Remove an extra 4 because we add 2 spaces and 2 parentheses.
            maxdesclength=$(( COLUMNS - longest - 4 ))

            # Make sure we can fit a description of at least 8 characters
            # if we are to align the descriptions.
            if ((maxdesclength > 8)); then
                # Add the proper number of spaces to align the descriptions
                for ((i = ${#comp} ; i < longest ; i++)); do
                    comp+=" "
                done
            else
                # Don't pad the descriptions so we can fit more text after the completion
                maxdesclength=$(( COLUMNS - ${#comp} - 4 ))
            fi

            # If there is enough space for any description text,
            # truncate the descriptions that are too long for the shell width
            if ((maxdesclength > 0)); then
                if ((${#desc} > maxdesclength)); then
                    desc=${desc:0:$(( maxdesclength - 1 ))}
                    desc+="…"
                fi
                comp+="  ($desc)"
            fi
            COMPREPLY[ci]=$comp
            __zshctl_debug "Final comp: $comp"
        fi
    done
}

__start_zshctl()
{
    local cur prev words cword split

    COMPREPLY=()

    __zshctl_debug "========= before bash_compltion =========="
    local w
    for w in "${COMP_WORDS[@]}"; do
        __zshctl_debug "COMP_WORD: $w"
    done

    # We start off with `COMP_WORDS` and `COMP_CWORD`. The words in
    # `COMP_WORDS` are split on a colleciton of characters specified in
    # `COMP_WORDBREAKS` creating tokens that do not map to shell words at all.
    # `_init_completion` attempts to put everything back together again. It
    # matches the tokens with `COMP_LINE` and tries reassemble any tokens
    # split by the caracters given to `-n`. We give it all the characters.

    # Note that Bash doesn't handle redirections well itself and the
    # `COMP_WORDS` list is going to stop if you have a common redirection such
    # as `1>&2`. Bash is not evaluating this line as it would if it were a
    # command. If it were a command it would resolve expansions and
    # substitutions and then parse the words.

    # The Cobra code on which this is based would call the Cobra enabled
    # program using `eval` and thereby resolve all the substitutions. They
    # join the `words` array created by `bash_completion`, but this array
    # contains "words" that are still split on characters in
    # `$COMP_WORDBREAKS`, so the words passed to the program apt to be
    # differnt from the words passed to the program when the command line is
    # run.

    # We've resovled to do our best with Bash and give up early. If we can't
    # make sense of what we find in Zsh we give up.

    # We're also inclined skip `_init_compltion` altogether, since the only
    # thing that this Cobra code uses is file completion, we may be able to
    # duplicate that in our Zshctl code.

    __zshctl_debug "COMP_LINE<$COMP_LINE> COMP_POINT<$COMP_POINT> <${COMP_LINE:$COMP_POINT:3}>"

    # `_init_completion` is also going to attempt to remove redirections. It
    # accepts a list of characters that should be used


    _init_completion -n $COMP_WORDBREAKS=: || return

    __zshctl_debug
    __zshctl_debug "========= starting completion logic =========="
    __zshctl_debug "cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}, cword is $cword"

    # The user could have moved the cursor backwards on the command-line.
    # We need to trigger completion from the $cword location, so we need
    # to truncate the command-line ($words) up to the $cword location.
    words=("${words[@]:0:$cword+1}")
    __zshctl_debug "Truncated words[*]: ${words[*]},"

    local out directive
    __zshctl_get_completion_results
    __zshctl_process_completion_results
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_zshctl zshctl
else
    complete -o default -o nospace -F __start_zshctl zshctl
fi

# ex: ts=4 sw=4 et filetype=sh
