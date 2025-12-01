function :help:completion:zsh {
    heredoc -v help -q <<'    EOF'
        # desc -- generate Zsh shell completions
        Generate Zsh completions for \`${zshctl[program]}\`.
        # opt help
        Display help for \`${zshctl[program]} completions bash\`.
        # man
        ## DESCRIPTION
        Generates Zsh completions for \`${zshctl[program]}\`.
        ## OPTIONS
        > options
    EOF
}

function :args:completion:zsh {
    eval "$(args -bx h,help -- "$@")"
}

function :execute:completion:zsh {
    sed -e 's/zshctl/'$zshctl[program]'/g' \
        "${functions_source[:execute:completion:zsh]:A:h}/complete.zsh"
}
