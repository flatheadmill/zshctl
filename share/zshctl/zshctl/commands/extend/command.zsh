# ___ execute:extend _ description ___
# Extend
# .PG .B __program__
# with additional commands.
# ___ execute:extend _ man ___
# .SH NAME
# .PB __program__\ extend \- extend
# .PG __program__
# with additional commands
# .SH SYNOPSIS
# .PG .SY __program__\ completion
# .I command
# .RI [ arguments ]
# .PG .SY __program__\ completion
# .RB [ \-h | \-\-help ]
# .YS
# .SH DESCRIPTION
# Extends
# .PG __program__
# with additional commands.
# .SH OPTIONS
# .TP
# .BR \-h ,\  \-\-help
# Help for
# .BR zshctl\ completions .
# .SH COMMANDS
# The following command can be invoked to extend
# .PG __program__ with additional commands.
# You can learn more about the each command by invoking the command with the
# .B --help
# option.
# .ZC commands
# ___
function execute:extend {
    eval "$(args -UC -bx h,help -- "$@")"
    delegate "$@"
}
