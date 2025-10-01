# ___ execute:completion _ description ___
# Install
# .PG .B __program__
# shell completions for Zsh or Bash.
# ___ execute:completion _ man ___
# .SH NAME
# .PG __program__\ completion \- generate shell completions
# .SH SYNOPSIS
# .PG .SY __program__\ completion
# .I command
# .RI [ arguments ]
# .PG .SY __program__\ completion
# .RB [ \-h | \-\-help ]
# .YS
# .SH DESCRIPTION
# Generates completions for Zsh and Bash.
# .SH OPTIONS
# .TP
# .BR \-h ,\  \-\-help
# Help for
# .PG .BR __program__\ completions .
# .SH COMMANDS
# .ZC commands
# ___
function :execute:completion {
    (( $# || parse[complete] )) || usage
    delegate "$@"
}

function :args:completion {
    eval "$(args -UC -bx h,help -- "$@")"
}
