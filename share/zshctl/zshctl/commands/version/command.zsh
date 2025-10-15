zmodload zsh/datetime

function :help:version {
    heredoc -v help -q <<'    EOF'
    # terse
    display version
    # verbose
    Display the current version of \`${zshctl[program]}\`.
    # arg format -- < terse | verbose | shell | json >
    Display a verbose version as test, JSON, or shell escaped.
        * terse -- Display version number only.
        * verbose -- Display version number and release date.
        * shell -- Display shell esacped version number and release date as UNIX epoch.
        * json -- Display version number and release date as UNIX epoch as JSON.
    # arg help
    Help for \`${zshctl[program]} version\`.
    # man
    ## DESCRIPTION
    Displays the current version of \`${zshctl[program]}\`.
    ## OPTIONS
    ### options
    EOF
}

function :execute:version {
    case $o_format in
    (terse)
        print $zshctl[version]
        ;;
    (verbose)
        print "Version: $zshctl[version]\nRelease Date: $(strftime "%Y-%m-%dT%H:%M:%S:%z" $zshctl[release_date])"
        ;;
    (shell)
        print "${(qq)zshctl[version]} ${(qq)zshctl[release_date]}"
        ;;
    (json)
        printf '{"version":"%s","release_date":"%s"}\n' $zshctl[version] $zshctl[release_date]
        ;;
    esac
}

function :args:version {
    typeset o_format=terse
    eval "$(args -C -d f,format -bx h,help -- "$@")"
}

# TODO Want to organize the names for all these different objects used in the
# system. We have `INCLUDES` and `COMMANDS` all caps which are system
# variables, perhaps better expressed with a `_zshctl_` prefix, and we have this
# parse object, here which might be better expressed as `args` to be
# consistent or within the `zshctl` object as `zshctl[args:state]`, if we want
# to have one to rule them all.
function :complete:version {
    # TODO We can't do this now because $o_format will be defined, but not
    # assigned. We'd have to update the parser to only print the typedef once we
    # were certain we had value. Not difficult. Push the lines into a typedefs
    # array and print them when you hit the assignments.
    # [[ -v o_format ]] && return
    case $zshctl[args:state]:$zshctl[args:matched] in
    (value:(-f|--format))
        completion terse 'display version number only'
        completion verbose 'display version number and release date'
        completion shell 'shell esacped version number and release date as UNIX epoch'
        completion json 'version number and release date as UNIX epoch as JSON'
        ;;
    esac
}

<<EOF > /dev/null
    Display one of _terse_ for just the version number, _verbose_ for the
    version number and release date, _shell_ for the version number and release
    date as UNIX epoch shell quoted, or _json_ for the version number and
    release date as UNIX epoch as JSON.
EOF
