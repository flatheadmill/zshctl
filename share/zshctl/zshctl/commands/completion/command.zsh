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
