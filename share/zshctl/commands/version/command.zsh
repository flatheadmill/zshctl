zmodload zsh/datetime

function :help:version {
    heredoc -v help -q <<'    EOF'
        # desc -- display version
        Display the current version of \`${zshctl[program]}\`.
        # opt format -- < terse | verbose | shell | json >
        Display a verbose version as test, JSON, or shell escaped.
            * terse -- Display version number only.
            * verbose -- Display version number and release date.
            * shell -- Display shell escaped version number and release date as UNIX epoch.
            * json -- Display version number and release date as UNIX epoch as JSON.
        # opt help
        Help for \`${zshctl[program]} version\`.
        # man
        ## DESCRIPTION
        Displays the current version of \`${zshctl[program]}\`.
        This is an \`acre\`<_project_>\_<_environment_> example.
        ## OPTIONS
        > options
    EOF
}

function :execute:version {
    case $o_format in
    (terse)
        print $zshctl[version]
        ;;
    (verbose)
        print "Version: $zshctl[version]"
        print "Release Date: $(strftime "%Y-%m-%dT%H:%M:%S:%z" $zshctl[release_date])"
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
