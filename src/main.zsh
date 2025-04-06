zshctl[version]=0.0.0
zshctl[release_date]=$(date +%s)
zshctl[man_title]='Zshctl Manuals'

# ___ execute:completion ___
# .SH NAME
# zshctl\ completion \- generate shell completions
# .SH SYNOPSIS
# .SY zshctl\ completion
# .I command
# .RI [ arguments ]
# .SY zshctl\ completion
# .RB [ \-h | \-\-help ]
# .YS
# .SH DESCRIPTION
# .B zshctl\ completions
# generates completions for Zsh and Bash.
# .SH OPTIONS
# .TP
# .BR \-h ,\  \-\-help
# Help for
# .BR zshctl\ completions .
# .SH COMMANDS
# The following command can be invoked to perform 1Password operations. You can
# learn more about the each command by invoking the command with the
# .B --help
# option.
# .TP
# .B zsh
# .br
# Generate shell compltions for Bash.
# .TP
# .B zsh
# .br
# Generate shell compltions for Zsh.
# ___
function execute:completion {
    eval "$(args -F -bx h,help -- "$@")"
    (( $# || parse[complete] )) || usage
    delegate "$@"
}

function execute:completion:bash {
    { heredoc | sed -e 's/zshctl/'$zshctl[program]'/'; } <<'    EOF'
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
        local requestComp lastParam lastChar args

        # Prepare the command to request completions for the program.
        # Calling ${words[0]} instead of directly zshctl allows to handle aliases
        args=("${words[@]:1}")
        requestComp="${words[0]} __complete ${args[*]}"

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

        __zshctl_debug "Calling ${requestComp}"
        # Use eval to handle any environment variables and such
        out=$(eval "${requestComp}" 2>/dev/null)

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

        if (((directive & shellCompDirectiveError) != 0)); then
            # Error code.  No completion.
            __zshctl_debug "Received error from custom completion go code"
            return
        else
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

        # Call _init_completion from the bash-completion package
        # to prepare the arguments properly
        if declare -F _init_completion >/dev/null 2>&1; then
            _init_completion -n =: || return
        else
            __zshctl_init_completion -n =: || return
        fi

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
    EOF
}

function execute:completion:zsh {
    { heredoc | sed -e 's/zshctl/'$zshctl[program]'/'; } <<'    EOF'
    #compdef zshctl
    compdef _zshctl zshctl

    # zsh completion for zshctl                                  -*- shell-script -*-

    __zshctl_debug()
    {
        local file="$BASH_COMP_DEBUG_FILE"
        if [[ -n ${file} ]]; then
            echo "$*" >> "${file}"
        fi
    }

    _zshctl()
    {
        local shellCompDirectiveError=1
        local shellCompDirectiveNoSpace=2
        local shellCompDirectiveNoFileComp=4
        local shellCompDirectiveFilterFileExt=8
        local shellCompDirectiveFilterDirs=16
        local shellCompDirectiveKeepOrder=32

        local lastParam lastChar flagPrefix requestComp out directive comp lastComp noSpace keepOrder
        local -a completions

        __zshctl_debug "\n========= starting completion logic =========="
        __zshctl_debug "CURRENT: ${CURRENT}, words[*]: ${words[*]}"

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
        requestComp="${words[1]} __complete ${words[2,-1]}"
        if [ "${lastChar}" = "" ]; then
            # If the last parameter is complete (there is a space following it)
            # We add an extra empty parameter so we can indicate this to the go completion code.
            __zshctl_debug "Adding extra empty parameter"
            requestComp="${requestComp} \"\""
        fi

        __zshctl_debug "About to call: eval ${requestComp}"

        # Use eval to handle any environment variables and such
        out=$(eval ${requestComp} 2>/dev/null)
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
                    compadd -x "${comp}"
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

        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            __zshctl_debug "Activating nospace."
            noSpace="-S ''"
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
    EOF
}

typeset -xgA zshctl

function execute {
    eval "$(args -F -bx h,help -- "$@")"
    delegate "$@"
}

function shebang {
    typeset shebang=${1:-} match=()
    [[
        ( $shebang =~ ^\. || $shebang =~ / ) &&
        -f $shebang &&
        (
            (
                "$(head -c 14 $shebang)" = '#!/usr/bin/env' &&
                "$(head -n 1 $shebang)" =~ ^#!/usr/bin/env\ +([^ ]+)\ *$ &&
                $match[1] = ${zshctl[argzero]:t}
            ) ||
            (
                "$(head -n 1 $shebang)" =~ ^#!(/[^ ]+)\ *$ &&
                $match[1] = $zshctl[argzero]
            )
        )
    ]]
}

zshctl[shebangable]=1
zshctl[commandable]=1
zshctl[main]=zshctl

function include {
    typeset func path=foo src
    while (( $# )); do
        func=${1:-}
        shift
        for path in "${(@)include_path}"; do
            src="${${:-"$path/include/$func.zsh"}:A}"
            if [[ -f $src && $functions_source[$func] != $src ]]; then
                source $src
            fi
        done
    done
}

function {
    typeset -A COMMANDS=() AUTO_COMMANDS=()
    typeset commands=() func src pattern
    integer seek=1
    typeset include_path=() command_path=() base dir
    typeset argzero=$ZSH_ARGZERO ZSHCTL_ARGZERO
    zshctl[argzero]=$ZSH_ARGZERO
    while
        include_path+=( ${zshctl[argzero]:A:h:h} )
        if (( $zshctl[commandable] )); then
            command_path+=( "${zshctl[argzero]:A:h:h}/share/${zshctl[argzero]:t}" )
        fi
        commands+=( "${zshctl[argzero]:t}:*" )
        zshctl[program]=${zshctl[argzero]:t}
        if (( $# && zshctl[shebangable] )) && shebang $1; then
            zshctl[argzero]=$1
            shift
            zshctl[shebangable]=0
            source ${zshctl[argzero]:A}
            true
        else
            false
        fi
    do; :; done
    # The value for uncompiled functions is the path to the source, so we use
    # ":" functions because it is not a popular file name.
    for dir in "${(@)command_path}"; do
        base=${zshctl[argzero]:A:h:h}/share/${zshctl[argzero]:t}
        for cmd in "$base"/*/commands/**/command.zsh(N); do
            func=${${cmd#$base/*/commands/}%/command.zsh}
            # TODO Apply filter.
            for pattern in "${(@)commands}"; do
                COMMANDS[execute:$func]=$cmd
            done
        done
    done
    for func in "${(@k)functions_source}"; do
        [[ $func = execute:* ]] || continue
        COMMANDS[$func]=':'
    done
    execute "$@"
} "$@"
