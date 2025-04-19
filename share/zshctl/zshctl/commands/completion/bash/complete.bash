# bash completion V2 for zshctl                                  -*- shell-script -*-

__zshctl_debug()
{
    local message
    if [[ -n ${ZSHCTL_COMP_DEBUG_FILE-} ]]; then
        printf -v message "$@"
        echo "$message" >> "${ZSHCTL_COMP_DEBUG_FILE}"
    fi
}

# This function calls the zshctl program to obtain the completion
# results and the directive.  It fills the 'out' and 'directive' vars.
__zshctl_get_completion_results() {
    # Makes any changes made by `set` local to the current function.
    local -
    # Turn off job monitoring so we can use `coproc` without chattering.
    set +m

    local requestComp lastParam lastChar args

    # Start a spinner with a delay. Spinner animates by waiting on standard
    # input with a timeout. We cancel the timer by writing to its standard
    # input. Note that this is always the way we do a coproc, managing it
    # through standard input instead of trying to sort out singal handling.
    local putback=${COMP_LINE:$COMP_POINT:1}
    __zshctl_debug "putback<$putback>"
    local spinner_PID code
    local -a spinner
    exec 3>&1
    {
        {
            coproc spinner {
                local LC_CTYPE=C
                local charwidth=3
                local spin='⣾⣽⣻⢿⡿⣟⣯⣷' line
                read -t 0.2 -r line
                [[ -z $line ]] || return
                printf '\e[?25l' 1>&3 # hide cursor
                local i=0
                while [[ -z $line ]]; do
                    i=$(( (i + $charwidth ) % ${#spin} ))
                    printf "%s" ${spin:$i:$charwidth} 1>&3
                    echo -en "\033[1D" 1>&3
                    read -t 0.1 -r line
                done
                echo -en "${putback:- }\033[1D" 1>&3
                printf '\e[?25h' 1>&3 # normal cursor
            }
        }
    } 2>/dev/null
    # Calling ${COMP_WORD[0]} instead of directly zshctl allows to handle aliases.
    out=$(${COMP_WORDS[0]} __complete bash "${ZSHCTL_COMP_DEBUG_FILE:-/dev/null}" \
        "$COMP_LINE" "$COMP_POINT" 2>>${ZSHCTL_COMP_DEBUG_FILE:-/dev/null})
    code=$?
    echo close >&"${spinner[1]}"
    wait $spinner_PID
    exec 3>&-

    if (( code )); then
        __zshctl_debug "Completion failed: $code"
        return
    fi
    typeset -A result_settings result_descriptions
    typeset -a result_completions
    eval $out

    if [[ -n ${result_settings[prefix]} ]]; then
        result_completions=( "${result_completions[@]/#/${result_settings[prefix]}}" )
    fi
    if [[ -n ${result_settings[suffix]} ]]; then
        result_settings[nospace]=1
        result_completions=( "${result_completions[@]/%/${result_settings[suffix]}}" )
    fi
    if (( ${result_settings[nospace]} )); then
        compopt -o nospace
    fi
    if (( ${result_settings[filenames]} )); then
        compopt -o filenames
    fi

    __zshctl_debug "The completion directive is: ${directive}"
    __zshctl_debug "The completions are: ${out}"

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

    local directive=0

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

    __zshctl_debug 'made it'
    return
    compopt -o filenames
    COMPREPLY=( baz/snert/ baz/super/ )
    return

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
    if [[ "${result_settings[descriptions]}" -ne 1 ]]; then
        __zshctl_debug "trying the cheap reply"
        IFS=$'\n' read -ra COMPREPLY -d '' < <(compgen -W "${result_completions[*]}" -- "${result_settings[incomplete]}")
        return 0
    fi
    __zshctl_debug "cur <$cur>"
    __zshctl_debug "COLUMNS<$COLUMNS>"

    local longest=0
    local compline
    __zshctl_debug "result_completions<${#result_completions}> incomplete<${result_settings[incomplete]}>"
    for comp in "${result_completions[@]}"; do
        __zshctl_debug "comp<${comp}>"
        [[ "$comp" = "${result_settings[incomplete]}"* ]] || continue
        compline="${comp}$tab${result_descriptions[$comp]}"
        COMPREPLY+=( "$compline" )
        if (( ${#comp} > longest )); then
            longest=${#comp}
        fi
    done

    __zshctl_debug "COMPREPLY<${#COMPREPLY}>"

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

    __zshctl_debug "========= zshctl completion =========="
    local w
    for w in "${COMP_WORDS[@]}"; do
        __zshctl_debug "COMP_WORD: $w"
    done

    # We start off with `COMP_WORDS` and `COMP_CWORD`. The words in
    # `COMP_WORDS` are split on a colleciton of characters specified in
    # `COMP_WORDBREAKS` creating tokens that do not map to shell words at all.
    # It's really a collection of tokens.
    #
    # Eventually you'll see it's because the completion mechanism can't
    # account for prefixes. If you are completing `--protocol=`, your
    # `COMPREPLY` must be filled with `--protocol=http`, `--protocol=https`,
    # `--protocol=ftp`, etc. You can only replace a specific "WORD" so
    # `COMP_WORDBREAKS` tends to include `=`.
    #
    # Tends to include because it's a global. You cannot make changes that are
    # local to a specific completion. The source for the `git` completion will
    # add the colon to `COMP_WORDBREAKS` if it is not already there.
    #
    # `bash_completion` attempts to put everything back together again with
    # its `_init_completion` function. It matches the tokens with `COMP_LINE`
    # and tries reassemble any tokens split by the caracters given to `-n`.
    #
    # These "words" come from Bash itself, which struggles because in shell,
    # you don't parse for words until you've resolved all expansions. It's not
    # doing what it normally does, evaulating the expansions and
    # substitutions. Bash appears to do an okay job with process expansion
    # `$(echo 1)`, but it does not recognize process substitution `<(echo 1)`.
    # It breaks that up into too many words.
    #
    # `bash_completion` also attempts to remove redirections such as
    # `2>/dev/null`, so when it gets the broken process substituion, it sees
    # it as redirections and deletes the "word" with the leading `<(` and
    # makes its `words` array of "words" worse off than `COMP_WORDS`. Only if
    # the process substitution is nestled next to an `=` as in `--file=<(echo
    # 1)` does the process substitution survive.
    #
    # Note that Bash doesn't handle redirections well itself and the
    # `COMP_WORDS` list is going to stop at the `&` if you have a common
    # redirection such as `1>&2`. Bash is not evaluating this line as it would
    # if it were a command. If it were a command it would resolve expansions
    # and substitutions and then parse the words.
    #
    # The Cobra code on which this is based would call the Cobra enabled
    # program using `eval` and thereby resolve all the expansions and any
    # surviving substitutions. They join the `words` array created by
    # `bash_completion`, but this array contains "words" that are still split
    # on characters in `$COMP_WORDBREAKS`, so the words passed to the program
    # apt to be different from the words passed to the program when the
    # command line is run.
    #
    # Note that Zsh does not have these problems. It recognizes process
    # expansion and substitution as a word of the future and makes it part of
    # a single word. The words you recive will have expansion and substitution
    # quoted and they will be split on space. Zsh has the ability to filter
    # completions with prefixes and append suffixes before display, so it can
    # work with full words.
    #
    # What's more, this robust word parsing is avialable to the user with the
    # `z` modifier, as in `${(z)line}`.
    #
    # So obviously, we just pass `COMP_LINE` and `COMP_POINT` into our
    # `zshctl` invocation and let `zshctl` parse the line with Zsh.
    #
    # We need to know about `COMP_WORDBREAKS`, we make assumptions about its
    # value, but we do not parse it.
    __zshctl_debug 'COMP_LINE<%s> COMP_POINT<%s> <%s>' \
        "$COMP_LINE" "$COMP_POINT" "${COMP_LINE:$COMP_POINT:3}"

    local out directive
    __zshctl_get_completion_results
    #__zshctl_process_completion_results
}

complete -o default -F __start_zshctl zshctl

# ex: ts=4 sw=4 et
