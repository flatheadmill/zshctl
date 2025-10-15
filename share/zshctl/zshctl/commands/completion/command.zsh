function :help:completion {
    heredoc -v help -q <<'    EOF'
        # terse
        generate shell completions
        # verbose
        Install \`${zshctl[program]}\` shell completions for Zsh or Bash.
        # arg help
        Display help for \`${zshctl[program]} completions\`.
        # man
        ## Description
        Generates completions for Zsh and Bash.
        ## OPTIONS
        ### options
        ## COMMANDS
        ### commands
    EOF
}

function :execute:completion {
    delegate "$@"
}

function :args:completion {
    eval "$(args -UC -bx h,help -- "$@")"
}
