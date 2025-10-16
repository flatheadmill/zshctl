function :help:completion:bash {
    heredoc -v help -q <<'    EOF'
        # terse
        generate Bash shell completions
        # verbose
        Generate Bash completions for \`${zshctl[program]}\`.
        # opt help
        Display help for \`${zshctl[program]} completions bash\`.
        # man
        ## DESCRIPTION
        Generates Bash completions for \`${zshctl[program]}\`.
        ## OPTIONS
        > options
    EOF
}

function :args:completion:bash {
    eval "$(args -bx h,help -- "$@")"
}

function :execute:completion:bash {
    sed -e 's/zshctl/'$zshctl[program]'/g' \
        "${functions_source[:execute:completion:bash]:A:h}/complete.bash"
}
