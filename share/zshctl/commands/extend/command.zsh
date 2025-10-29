function :help:extend {
    heredoc -v help -q <<'    EOF'
        # verbose
        Extend \`${zshctl[program]}\` with additional commands.
        # opt help
        Display help for \`${zshctl[program]} extend\`.
        # man
        ## DESCRIPTION
        Extends \`${zshctl[program]}\` with additional commands.
        ## OPTIONS
        > options
        ## COMMANDS
        The following command can be invoked to extend \`${zshctl[program]}\`
        with additional commands. You can learn more about the each command by
        invoking the command with the \`--help\` option.
        > commands
    EOF
}

function :args:extend {
    eval "$(args -UC -bx h,help -- "$@")"
}

function :execute:extend {
    delegate "$@"
}
