# bash completion V2 for zshctl                                  -*- shell-script -*-

__zshctl_debug()
{
    local message
    if [[ -n ${ZSHCTL_COMP_DEBUG_FILE-} ]]; then
        printf -v message -- "$@"
        echo "$message" >> "${ZSHCTL_COMP_DEBUG_FILE}"
    fi
}

# We run out actual introspection of `zshctl` and animate our spinner in a
# separate process so we can set signal handlers and have them reap, and
# duplicate file handles without changing them in the user's shell.
__zshctl_spinnered() {
    # Get the character that we'll put back when the spinner stops spinning.
    local putback=${COMP_LINE:$COMP_POINT:1}
    # Variables for the spinner and the invocation of our program.
    local spinner_PID=0 code spinner_fd=0 unspun=0
    local -a spinner
    # What follows is a discussion of the spinner, but more importantly of
    # interruption of background processes in Bash completion functions.
    #
    # There are many different behaviors you'll see, but the worst one by far is
    # the when hitting Ctl+C the cursor will move to the first characer of the
    # current line, leaving a ^C at it's previous position. If you press enter,
    # it will run the command but the first character will be stripped.
    # Therefore, you should never create a `zshctl` shebang program with
    # completions named `grm` or the like because it will get edited to `rm`.
    #
    # All of the tricks employed here are to prevent this alarming behavior and
    # to accept whatever other behaviors result. These may include leaving
    # spinner characters on the terminal, or displaying the default completion
    # as a result of pressing Ctl+L. It also means that we have to carefully
    # exit every path in our code, we can't have one tidy `trap` with a shutdown
    # function to do it all for us.
    #
    # What appears to be working, for now, is `kill -WINCH $$` which tells
    # readline that the window size changed, so it recalcuates its cursor
    # position, possibly redraws the line. This signal is not used any other
    # Bash completion on my Ubuntu instance, so it will our trade secret.
    #
    # As far as I can tell, this is a problem for any this is a problem for any
    # Bash completion that can be interrupted, as demonstrated by kubectl,
    # gcloud, and others. The `WINCH` signal forces `readline` to recalculate
    # cursor position and prevents the corruption.
    #
    #   alan@stuttgart:~/code/flatheadmill/zshctl$ kubectl get ns ^C
    #
    #   ubectl: command not found
    #   alan@stuttgart:~/code/flatheadmill/zshctl$
    #
    # The above is sending an interrupt to `kubectl` on Bash on Linux.
    #
    # Believing that this behavior was a product of the backspaces in the
    # spinner meant that I spent a lot of time suspecting the spinner.
    #
    # A final note to self to say that the line editing leaving a butchered
    # command in user's prompt was what you wanted to solve for, not for anthing
    # else and you are going to live with the redraws, default completions, and
    # whatever else.

    #
    unspin() {
        local signal=${1:-}
        shift
        # Stop the spinner and wait for it to finish. If we do not wait we might
        # exit this function and get job control spew on the terminal because our
        # local settings to hush the spew will be reset when we return.
        __zshctl_debug 'CALLED <%s> <%s> <%s> <%s>' $unspun $signal ${spinner[1]} $spinner_PID
        (( unspun )) && return
        __zshctl_debug 'STILL SPINNING'
        unspun=1
        local pid=$spinner_PID
        (( ${spinner[1]:-0} )) && echo $signal >&"${spinner[1]}" 2>/dev/null
        if [[ $signal = OVER ]]; then
            __zshctl_debug 'PUTBACK: <%s>\n' "${putback:- }"
            printf '%s\033[1D' "${putback:- }" 1>&2 # putback
            printf '\e[?25h' 1>&2 # normal cursor
            wait $pid
        elif [[ $signal = ERROR ]]; then
            printf '\e[?25h' 1>&2 # normal cursor
            wait $pid
        fi
    }
    # We do not actually want to exit immediately when we get Ctl+C (SIGINT) or
    # Ctl+\ (SIGQUIT) from the user, we want to reap the spinner and `zshctl`.
    trap 'true' INT QUIT

    if [[ $ZSHCTL_DISABLE_SPINNER -eq 1 ]]; then
        unspun=1
    else
    {
        {
            coproc spinner {
                local interrupted=0
                putback() {
                    # echo -en "${putback:- }\033[1D" 1>&2 # putback
                    interrupted=1
                    __zshctl_debug 'SPINNER INTERRUPT'
                }
                trap putback INT
                local LC_CTYPE=C    # important
                local charwidth=3   # also, important
                local spin='⣾⣽⣻⢿⡿⣟⣯⣷' line
                read -t 0.2 -r line # if we have a line we never start spinning
                [[ -z $line ]] || return
                printf '\e[?25l' 1>&2 # hide cursor
                local i=0
                while (( ! interrupted )) && [[ -z $line ]]; do
                    i=$(( (i + $charwidth ) % ${#spin} ))
                    # (( ! interrupted )) && printf '%s\033[1D' ${spin:$i:$charwidth} 1>&2
                    printf '%s\033[1D' ${spin:$i:$charwidth} 1>&2
                    read -t 0.1 -r line # snooze
                done
                if false && (( interrupted )); then
                    __zshctl_debug 'SPINNER SNOOZE'
                    read -t 1.5 -r line
                fi
                __zshctl_debug 'SPINNER DONE: <%s>' $line
                # Because spinner is scribbling on the terminal, if it is stopped by
                # an INT, it does not attempt to put back the character it overwrote
                # with its spinner characters. Leaves a spinner character.
            }
        }
    }
    fi

    local spinner_pid=$spinner_PID
    local -a zshctl zsh_words
    local zsh_quoted_words out code

    # We used to do this manipulation in `zshctl` because we wanted the Zsh
    # parsed shell words, but that came to an end with the caching
    # implementation. The cleanup side can't be invoked with the incomplete word
    # because it is being pulled from the cache, so we made a general rule that
    # defined the inputs and output. It is up to the completion code to convert
    # its word input into Zsh parsed input on its own.
    zsh_quoted_words=$(zsh -c '
        words=( "${(@QA)${(z)0}}" )
        (( ${#words} != ${#${(z)${:-${0}x}}} )) && words+=( "" )
        print "${(j: :)${(@qq)words}}"
    ' "${COMP_LINE:0:$COMP_POINT}")
    __zshctl_debug "QUOTED: <%s>" "$zsh_quoted_words"
    eval "zsh_words=( $zsh_quoted_words )"
    local incomplete=${zsh_words[-1]}

    # Start a spinner with a delay. Spinner animates by waiting on standard
    # input with a timeout. We cancel the timer by writing to its standard
    # input. Note that this is always the way we do a coproc, managing it
    # through standard input instead of trying to sort out singal handling.
    # Bonus is that we don't have to wait for a timer to expire and come back
    # around to break a loop, we awake immediately if sleeping on a read.

    # Calling ${COMP_WORD[0]} instead of zshctl directly allows to handle aliases.
    zshctl=(
        ${COMP_WORDS[0]}
        __complete
        "${ZSHCTL_COMP_DEBUG_FILE:-/dev/null}"
        "${#zsh_words[@]}" "${zsh_words[@]}" "${#zsh_words[@]}"
    )
    __zshctl_debug 'About to call: %s' "$(IFS=, ; echo "${zshctl[@]@Q}")"
    out=$( "${zshctl[@]}" 2>/dev/null )
    code=$?

    # We could display a cleaner error message using our error message display
    # below, but for now we just bail.
    if (( code )); then
        __zshctl_debug "EARLY RETURN: $code"
        printf '\e[?25h' 1>&2 # normal cursor
        wait $spinner_pid
        __zshctl_debug "EARLY RETURN WAIT DONE RETURNING: $code"
        return 1
    fi

    __zshctl_debug '%s' "$out"

    # Evaluate the output from our program.
    typeset -A result_settings result_descriptions
    typeset -a result_completions
    eval $out

    local key=${result_settings[key]} last mtime now=$(date +%s)
    if [[ -n $key ]]; then
        __zshctl_debug 'CACHE PROBE'
        if [[ ! -e $HOME/.local/state/zshctl/invalidate ]]; then
            mkdir -p $HOME/.local/state/zshctl
            touch $HOME/.local/state/zshctl/invalidate
        fi
        last=${__zshctl_cache[last:]:-0}
        mtime=$(stat -c %Y $HOME/.local/state/zshctl/invalidate)
        __zshctl_debug "CACHE AGE: $(( EPOCHSECONDS - last ))"
        if (( ${ZSHCTL_WIPE_CACHE:-0} || (EPOCHSECONDS - last) > 60 || last < mtime )); then
            __zshctl_debug 'WIPE CACHE'
            __zshctl_cache=()
        fi
        out=${__zshctl_cache[key:$key]}
        __zshctl_debug '%s' "$out"
        if [[ -z $out ]]; then
            __zshctl_debug 'CACHE MISS'
            zshctl=(
                "${COMP_WORDS[0]}" __encache ${ZSHCTL_COMP_DEBUG_FILE:-/dev/null}
            )
            # Because `zshctl` so so extensible, we won't always know who wrote
            # the command set the value of `encache`, if they did it correctly,
            # so we make a defensive parse and stringify using Zsh before we
            # evaluate. This will wrap `;` in a single quote, for example.
            local encache
            encache=$(
                zsh -c '
                    print "${(j: :)${(@qq)${(@QA)${(z)0}}}}"
                ' "${result_settings[encache]}"
            )
            __zshctl_debug 'ENCACHE: <%s>\n' "$encache"
            eval "zshctl+=( ${result_settings[encache]} )"

            # Invoke our call to retrieve the cachable completions.
            __zshctl_debug 'About to call: %s' "$(IFS=, ; echo "${zshctl[@]@Q}")"
            out=$( "${zshctl[@]}" 2>/dev/null )
            code=$?

            # We could display a cleaner error message using our error message
            # display below, but for now we just bail.
            if (( code )); then
                unspin OVER
                __zshctl_debug "Completion failed: $code"
                return
            fi
        else
            __zshctl_debug 'CACHE HIT'
        fi
        result_completions=()
        __zshctl_debug "$out"
        eval "$out"
        __zshctl_debug EVALED
        if [[ -z ${result_settings[message]} ]]; then
            __zshctl_cache[key:$key]=$out
            __zshctl_cache[last:]=$EPOCHSECONDS
            __zshctl_debug 'ENCACHE OUTPUT'
        fi
    fi
    unspin OVER
    echo "$out"
    return 0
}

# This function calls the zshctl program to obtain the completion
# results and the directive.  It fills the 'out' and 'directive' vars.
__zshctl_get_completion_results() {
    # Create a cache for long-running completions.
    declare -gA __zshctl_cache
    # Makes any changes made by `set` local to the current function.
    local -
    # Turn off job monitoring so we can use `coproc` without chattering.
    set +m
    local out code
    out=$(__zshctl_spinnered)
    code=$?
    __zshctl_debug 'FINAL OUT: <%s> <%s>\n' $code "$out"
    if (( code )); then
        kill -WINCH $$
        return 0
    fi
    return 0

    #echo close >&"${spinner[1]}" 2>/dev/null
    #wait $spinner_PID
    #exec {spinner_fd}>&- 2>/dev/null

    # Some complaints here, but we did manage to figure it out.

    # For Bash completions all we can do is append the prefix.
    #if [[ -n ${result_settings[prefix]} && ${result_settings[prefix]} != *= ]]; then
    #    result_completions=( "${result_completions[@]/#/${result_settings[prefix]}}" )
    #fi
    # For Bash completions all we can do is append the suffix. When we have
    # a suffix it means we want to keep building a word, that is it is `=` or
    # `/` and we are building an assignment or a path, so no space.
    #if [[ -n ${result_settings[suffix]} ]]; then
    #    result_settings[nospace]=1
    #    result_completions=( "${result_completions[@]/%/${result_settings[suffix]}}" )
    #fi

    # At the time of writing, it appears that Bash is unable to complete `!` nor
    # `>` so adding strings to `COMPREPLY` that lead with those characters
    # ensures that they are displayed, but they cannot be acted upon.
    if [[ -n "${result_settings[message]}" ]]; then
        __zshctl_debug ERROR
        COMPREPLY+=( "! ERROR" )
        COMPREPLY+=( "> ${result_settings[message]}" )
        return
    fi

    # An older comment.
    #
    # Bash creates "words" by splitting on `COMP_WORDBREAKS`. If `:` is one of
    # the characters in `COMP_WORDBREAKS` and we are completing
    # `administrator:pas` seeking the completion `administrator:password=`, then
    # the word that Bash believes it is completing is `pas` because it broke on
    # the `:`. As noted, we never really know what is going to be in
    # `COMP_WORDBREAKS` because anyone can add something to it. It is global to
    # the active shell.
    #
    # Currently, we address this by having our `zshctl` completion code set a
    # `zshctl[args:delimiter]=:` for the above case. It is a shim. `:` appears
    # to always be in `COMP_WORDBREAKS` now. Not sure if it is a default or if
    # someone is adding it, but it tends to be there. It is not onerous for the
    # `zshctl` code to add a delimiter. It is easy enough to spot a character
    # that might be a problem for Bash, a character that you are indeed using as
    # a delimiter, but the delimeter is not used by the Zsh code.
    #
    # We could check if the delimiter is actually in `COMP_WORDBREAKS`, but
    # we're currently in "works on my machine" mode until further notice.
    if [[ -n ${result_settings[delimiter]} &&
        (
            ${COMP_WORDS[${COMP_CWORD}]} = ${result_settings[delimiter]} ||
            ${COMP_WORDS[$(( COMP_CWORD - 1 ))]} = ${result_settings[delimiter]}
        )
    ]]; then
        result_settings[prefix]=${result_settings[prefix]#*${result_settings[delimiter]}}
        incomplete=${incomplete#*${result_settings[delimiter]}}
        result_completions=( "${result_completions[@]#*${result_settings[delimiter]}}" )
    fi

    __zshctl_debug 'result_settings[prefix] <%s>\n' ${result_settings[prefix]}

    # We are going to smoosh the way Zsh does.
    if [[ -n ${result_settings[suffix]} ]]; then
        result_settings[nospace]=1
    fi

    # Add the prefix to all completion matches.
    result_completions=( "${result_completions[@]/#/${result_settings[prefix]}}" )
    # Add the suffix to all completion matches.
    result_completions=( "${result_completions[@]/%/${result_settings[suffix]}}" )
    # Include only the completions that match our incomplete match.
    local -a filtered=()
    local comp
    for comp in "${result_completions[@]}"; do
        [[ $comp == ${incomplete}* ]] && filtered+=( "$comp" )
    done
    result_completions=( "${filtered[@]}" )


    # We will probably not set no space independent of a suffix.
    if (( ${result_settings[nospace]} )); then
        compopt -o nospace
    fi
    # We are completing a path and setting this will display only the last
    # part of the completed path. `foo/bar` and `foo/baz` will display `bar`
    # and `baz` if the user is completing `foo/`.
    if (( ${result_settings[filenames]} )); then
        compopt -o filenames -o noquote
    fi
    # ^ Problem with this is that it cannot be used for actual filenames
    # because we defeat quoting, which we would not want to do for actual
    # filenames because of spaces in file names. This is for when we're doing
    # something silly with our commnad line completions, when we've created a
    # little language like `vault/item/field=project/service-account`. We
    # really ought to do as `ytt` does and insist on a flag for everything,
    # but `ytt` does have funky file marks, so even there they take liberties.
    #
    # TODO Come back and make `noquote` a separate option.

    __zshctl_debug "$(IFS=$'\n'; echo "${result_completions[@]}")"

    # Outgoing, but we have to get to files.
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

    return

    # TODO Help message.

    compopt -o filenames -o noquote
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
            # TODO Claude, didnt' we already filter the above?
        done < <(printf "%s\n" "${result_completions[@]}")
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
        IFS=$'\n' read -ra COMPREPLY -d '' < <(compgen -W "${result_completions[*]}" -- "${incomplete}")
        __zshctl_debug "$(IFS=$'\n'; echo "${COMPREPLY[@]}")"
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

    # You can read all about the spinner, it's limitations and whether or not
    # you want to enable it.
    local ZSHCTL_DISABLE_SPINNER=0

    COMPREPLY=()

    __zshctl_debug "========= zshctl completion =========="
    __zshctl_debug 'COMP_LINE: %q' "$COMP_LINE"
    __zshctl_debug 'COMP_POINT: %q' "$COMP_POINT"
    __zshctl_debug 'COMP_WORDBREAKS: %q' "$COMP_WORDBREAKS"
    __zshctl_debug 'COMP_TYPE: %s' "$COMP_TYPE"
    __zshctl_debug 'COMP_KEY: %s' "$COMP_KEY"
    __zshctl_debug 'COMP_CWORD: %s' "$COMP_CWORD"

    local w
    for w in "${COMP_WORDS[@]}"; do
        __zshctl_debug 'COMP_WORD: %q' "$w"
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
    # "Tends to" include because it's a global. You cannot make changes that are
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
    # expansion and substitution as a word of the future and makes it part of a
    # single word. The words you recive will have expansion and substitution
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

    trap >> $ZSHCTL_COMP_DEBUG_FILE
    __zshctl_debug 'TRAPS ABOVE'
    __zshctl_get_completion_results
}

complete -o default -F __start_zshctl zshctl

# ex: ts=4 sw=4 et
