# bash completion V2 for zshctl                                  -*- shell-script -*-

__zshctl_debug()
{
    local message
    if [[ -n ${ZSHCTL_COMP_DEBUG_FILE-} ]]; then
        printf -v message -- "$@"
        echo "$message" >> "${ZSHCTL_COMP_DEBUG_FILE}"
    fi
}

__zshctl_error_message() {
    local message=${1:-}
    # Notes on an earlier message display strategy.
    #
    # At the time of writing, it appears that Bash is unable to complete `!` nor
    # `>` so adding strings to `COMPREPLY` that lead with those characters
    # ensures that they are displayed, but they cannot be acted upon.
    #COMPREPLY+=( "$(printf '! ERROR %*s' $((${COLUMNS:-80} - 9)) '')" )
    #COMPREPLY+=( "> ${settings[message]}" )

    # But instead, we'll do like Cobra does and blather all over the user's
    # terminal with printf. The prompt format is only available from Bash 4.4.
    printf '\n%s\n\n%s' "$message" "${PS1@P}${COMP_LINE[@]}"

    # It's amazing that this works, scribbling all over the terminal like this,
    # especially with the `kill -WINCH $$` on SIGINT and SIGQUIT.

    # We do not want Bash to display anything other than our message.
    compopt +o default
    COMPREPLY=()
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

    # Spinner initialization.

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
    # it will run the command but the first character will be stripped. You will
    # not have seen that the first character has been deleted. It is effectively
    # a hidden edit, so if the user decided to press enter because the command
    # looks benign if incompleted, they will not run the program displayed in
    # the terminal. They will run a program with the same name less the frist
    # character. Therefore, you if you were to ever create a `zshctl` shebang
    # program with completions named `grm`, Bash completions would eventually
    # edit the name to `rm` and if you're lucky you'll just see an error
    # message from `rm`.
    #
    # Both `kubectl` and `gcloud` exhibit this behavior in response to Ctl+C.
    # You can see the user experience below, where the user has pressed Ctl+C
    # during a background process and then presses enter/return.
    #
    #   alan@stuttgart:~/code/flatheadmill/zshctl$ kubectl get ns ^C
    #
    #   ubectl: command not found
    #   alan@stuttgart:~/code/flatheadmill/zshctl$
    #
    # It is not a product of the backspaces printed during spinner animation.
    # `gcloud` does the same. It has a spinner animation, but `kubectl` does
    # not. The problem is reproducible in the completions of these other
    # programs.
    #
    # Believing that this behavior was a product of the backspaces in the
    # spinner meant that I spent a lot of time suspecting the spinner.
    #
    # All of the tricks employed here are to prevent this alarming behavior and
    # to accept whatever other behaviors result. These may include leaving
    # spinner characters on the terminal, or displaying the default completion
    # as a result of pressing Ctl+C. It also means that we have to carefully
    # exit every path in our code, we can't have one tidy `trap` with a shutdown
    # function to do it all for us.
    #
    # What appears to be working, for now, is `kill -WINCH $$` which tells
    # readline that the window size changed, so it recalcuates its cursor
    # position, possibly redraws the line. This signal is not used any other
    # Bash completion on my Ubuntu instance, so it will be our trade secret.
    #
    # As far as I can tell, this is a problem for any this is a problem for any
    # Bash completion that can be interrupted, as demonstrated by kubectl,
    # gcloud, and others. I assume that the `WINCH` signal forces `readline` to
    # recalculate cursor position and prevents the corruption. I have yet to see
    # a downside to sending the `WINCH`, which would only be sent in response to
    # Ctl+C or Ctl+\, not during normal, uninterrupted completion.
    #
    # A final note to self to say that the line editing leaving a butchered
    # command in user's prompt was what you wanted to solve for, not for
    # anything else and you are going to live with the redraws, default
    # completion spew, and whatever else.
    #
    # Note subsequent to the final note. These completions are working pretty
    # consistently, exhibiting our designed behavior for the most part,
    # occasionally you will catch it with a Ctl+C after the spinner has stopped
    # and then it will exhibit default Bash behavior for completions with no
    # background processes.

    # We always run the spinner. It won't start spinning until 200ms have
    # and will alter the input line if it does not actually spin. We listen on
    # standard in and we used to send it messages to stop it, but now we just
    # wait for the next iteration. We may restore message sending.
    local spinner_fd
    exec {spinner_fd}>&1    # Copy standard out.
    {
        # When error-free, the spinner is stopped by sending a message to break
        # it's loop. To handle Ctl+C and Ctl+\ we set a trap.
        coproc spinner {
            local interrupted=0
            # We set a trap to ensure that the spinner will stop, that it will
            # not continue to spin if other steps in this completion fail to
            # terminate it correctly. We set a flag and then we close standard
            # in.
            #
            # Closing standard in seems obvious now, but it was not always there
            # and I was having a problem where the reads would not wake up after
            # the signal and required a subsequent signal, the user would have
            # to press Ctl+C a second time. Closing standard in will wake any
            # reads with an EOF regardless of timers.
            #
            # Apparently, sending signals can cause Bash to lose track of its
            # read timer. This behavior is arbitrary. Most of the time the read
            # would timeout and leave the loop, but sometimes it be stuck on a
            # read. Not sure if this was a race between the loop and the trap,
            # or if a waiting read would just break on occasion.
            #
            # Closing standard in is better in any case. It means that the
            # spinner begins to stop immediately, not on a next tick.
            __zshctl_spinner_trap() {
                interrupted=1
                exec 0>&-
                __zshctl_debug 'SPINNER TRAP'
            }
            trap __zshctl_spinner_trap INT QUIT
            # Wait a bit before spinning, may not be necessary.
            local line
            read -t 0.2 -r line
            [[ $interrupted -eq 0 && -z $line ]] || return
            # From StackOverflow. https://unix.stackexchange.com/a/565551
            printf '\e[?25l' 1>&$spinner_fd # hide cursor
            local LC_CTYPE=C    # important
            local charwidth=3   # also, important
            local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
            local i=0
            while [[ $interrupted -eq 0 && -z $line ]]; do
                i=$(( (i + $charwidth ) % ${#spin} ))
                printf '%s\033[1D' ${spin:$i:$charwidth} 1>&$spinner_fd
                read -t 0.1 -r line # snooze
                __zshctl_debug 'snoozed <%s> <%s>' "$line" $interrupted
            done
            __zshctl_debug 'SPINNER DONE: <%s>' $line
            # Don't clean up here. We clean up outside and if we fail to clean
            # up properly, that's okay so long as the spinner is not spinning.
        }
    } 2> /dev/null
    exec {spinner_fd}>&-    # Close our copy, it has been inherited.

    # Keep in mind that your long-running completions within `zshctl` should
    # respond correctly to SIGINT and SIGQUIT or none of this works.
    __zshctl_spinner_shutdown() {
        typeset code=${1:-} tab=$'\t'
        shift
        __zshctl_debug 'SPINNER SHUTDOWN: code <%s>, spinner_PID <%s>, ${spinner[1]} <%s>, spinner_fd <%s>' $code $spinner_PID ${spinner[1]} $spinner_fd
        case $code in
        (130|131)
            # When `zshctl` ends with SIGINT or SIGQUIT, it means that our
            # spinner also got the same signal and it is now shutting down
            # because of its trap. The trap has closed standard input and marked
            # a flag that will cause the animation loop to exit.
            wait $spinner_PID
            printf '%s\033[1D\e[?25h' "${putback:- }" 1>&2 # putback and normal cursor

            # Respond to the user. Note that with Ctl+\ the cursor is supposed
            # to be left in the same position so that the user can keep typing.
            # With no background process, this will not redraw the line, but if
            # here is no backround process why press Ctl+\? Our implementation
            # will redraw for both Ctl+C and Ctl+\ and you will be able to
            # continue editing for both.
            __zshctl_error_message 'User interrupt.'

            # Our stupendous Readline kick.
            kill -WINCH $$
            ;;
        (*)
            # Otherwise, we can do a graceful shutdown down the spinner.
            #
            # We could try sending a signal to the spinner someday, but this
            # currently works and in all my fiddling I found so many things that
            # should work that didn't, writing to closed file handles should be
            # benign but it cased Ctl+\ to exit bash, for example. A simple
            # `kill -TERM` on the spinner made to that subseqent tab would
            # insert a tab instead of complete. When I'm ready to detect
            # side-effects, I may return to put a `kill -INT $spinner_PID` here.
            #
            # Appears to work, `kill -INT`.
            echo bye >&"${spinner[1]}" 2>/dev/null
            # kill -INT $spinner_PID 2>/dev/null
            wait $spinner_PID
            printf '%s\033[1D\e[?25h' "${putback:- }" 1>&2 # putback and normal cursor
            ;;
        esac
    }

    # Defensive copy of the spinner pid, because I've seen it get unset.
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

    # Return on an error from `zshctl`, possible Ctl+C or Ctl+\.
    if (( code )); then
        __zshctl_spinner_shutdown $code
        return 0
    fi

    __zshctl_debug '%s' "$out"

    # Evaluate the output from our program.
    typeset -A settings descriptions
    typeset -a completions
    eval $out

    local key=${settings[key]} last mtime now=$(date +%s)
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
                ' "${settings[invoke]}"
            )
            __zshctl_debug 'ENCACHE: <%s>\n' "$encache"
            eval "zshctl+=( $encache )"

            # Invoke our call to retrieve the cachable completions.
            __zshctl_debug 'About to call: %s' "$(IFS=, ; echo "${zshctl[@]@Q}")"
            out=$( "${zshctl[@]}" 2>/dev/null )
            code=$?

            # Return on an error from `zshctl`, possible Ctl+C or Ctl+\.
            if (( code )); then
                __zshctl_spinner_shutdown $code
                return 0
            fi
        else
            __zshctl_debug 'CACHE HIT'
        fi
        completions=()
        __zshctl_debug "$out"
        eval "$out"
        __zshctl_debug EVALED
        if [[ -z ${settings[message]} ]]; then
            __zshctl_cache[key:$key]=$out
            __zshctl_cache[last:]=$EPOCHSECONDS
            __zshctl_debug 'ENCACHE OUTPUT'
        fi
    fi

    # Graceful spinner shutdown.
    __zshctl_spinner_shutdown 0

    # From here on out you get the default behavior for Ctl+C and Ctl+\. This
    # means that the user will on rare occasion have a different experience when
    # interrupting a completion, but it will be one of only two experiences, our
    # custom experience, the default experience, and the line with the hidden
    # edit will not be experienced. We can tell you why you got one or the
    # other, so it is not so mysterious. Attempting to extend the spinner life
    # so that there is only one experience is futile, there will always be a
    # window and you're just reducing the odd, not eliminiating the case.
    #
    # Appears to have resolved the hidden edit. Apprached this with no
    # confidence that it could be resolved. Amazed that it works and works so
    # reliably, consistently. Struggled to find the proper concurrency.
    #
    # No one will ever use this code. Pity.

    # On to processing our completions.

    # Compare the following to the `activeHelp` implementation in the Cobra
    # completions of `kubectl` and determine if what they're doing actually
    # works. `kubectl` does have the chopped character problem, so this is
    # probably better if all we want to display is errors and not context help.
    #
    # Would require a better understaning of readline and WINCH.
    #
    if [[ -n "${settings[message]}" ]]; then
        # Print the error message, we do not offer a helper message option, just
        # an error message.
        __zshctl_debug 'MESSAGE <%s>' "${settings[message]}"
        __zshctl_error_message "${settings[message]}"
        # Please display out carefully constructed nothing.
        return 0
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
    if [[ -n ${settings[delimiter]} &&
        "$COMP_WORDBREAKS" = *${settings[delimiter]}* &&
        (
            ${COMP_WORDS[${COMP_CWORD}]} = ${settings[delimiter]} ||
            ${COMP_WORDS[$(( COMP_CWORD - 1 ))]} = ${settings[delimiter]}
        )
    ]]; then
        settings[prefix]=${settings[prefix]#*${settings[delimiter]}}
        incomplete=${incomplete#*${settings[delimiter]}}
        completions=( "${completions[@]#*${settings[delimiter]}}" )
    fi

    __zshctl_debug 'settings[prefix] <%s>\n' ${settings[prefix]}

    # We are going to smoosh the way Zsh does.
    if [[ -n ${settings[suffix]} ]]; then
        settings[nospace]=1
    fi

    # Add the prefix to all completion matches.
    completions=( "${completions[@]/#/${settings[prefix]}}" )
    # Add the suffix to all completion matches.
    completions=( "${completions[@]/%/${settings[suffix]}}" )
    # Include only the completions that match our incomplete match.
    local -a filtered=()
    local comp
    for comp in "${completions[@]}"; do
        [[ $comp == ${incomplete}* ]] && filtered+=( "$comp" )
    done
    completions=( "${filtered[@]}" )


    # We will probably not set no space independent of a suffix.
    if (( ${settings[nospace]} )); then
        compopt -o nospace
    fi
    # We are completing a path and setting this will display only the last
    # part of the completed path. `foo/bar` and `foo/baz` will display `bar`
    # and `baz` if the user is completing `foo/`.
    if (( ${settings[filenames]} )); then
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

    __zshctl_debug "$(IFS=$'\n'; echo "${completions[@]}")"

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

    if [[ ${settings[ordered]} -eq 1 ]]; then
        compopt -o nosort
    fi

    case "${settings[kind]}:${settings[state]}" in
    (completions:nothing)
        __zshctl_debug NOTHING
        compopt +o default
        COMPREPLY=()
        return 0
        ;;
    (directories:*)
        if [[ -n ${settings[prefix]} ]]; then
            # Filter results to add prefix
            local -a dirs
            while IFS= read -r dir; do
                dirs+=( "${settings[prefix]}${dir}" )
            done < <(compgen -d -- "${incomplete#${settings[prefix]}}")
            COMPREPLY=( "${dirs[@]}" )
        else
            compgen -d -W "${completions[*]}" -- "${incomplete}"
        fi
        return 0
        ;;
    (files:*)
        if [[ -n ${settings[prefix]} ]]; then
            local -a files
            while IFS= read -r file; do
                files+=( "${settings[prefix]}${file}" )
            done < <(compgen -f -- "${incomplete#${settings[prefix]}}")
            COMPREPLY=( "${files[@]}" )
        else
            compgen -f -- "${incomplete}"
        fi
        return 0
        ;;
    esac

    __zshctl_handle_completion_types
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
    if [[ "${settings[descriptions]}" -ne 1 ]]; then
        __zshctl_debug "trying the cheap reply"
        IFS=$'\n' read -ra COMPREPLY -d '' < <(compgen -W "${completions[*]}" -- "${incomplete}")
        __zshctl_debug "$(IFS=$'\n'; echo "${COMPREPLY[@]}")"
        return 0
    fi
    __zshctl_debug "cur <$cur>"
    __zshctl_debug "COLUMNS<$COLUMNS>"

    local longest=0
    local compline
    __zshctl_debug "completions<${#completions[@]}> incomplete<${settings[incomplete]}>"
    for comp in "${completions[@]}"; do
        __zshctl_debug "comp<${comp}>"
        [[ "$comp" = "${settings[incomplete]}"* ]] || continue
        compline="${comp}$tab${descriptions[$comp]}"
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
        __zshctl_debug 'WILL FORMAT'
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
    compopt >> "$ZSHCTL_COMP_DEBUG_FILE"
}

__start_zshctl()
{
    # Would work with 4.4 as well, probably. No way for me to support it.
    if (( BASH_VERSINFO[0] < 5 )); then
        printf '\nzshctl completion requires Bash 5+\n' >&2
        return 1
    fi

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
