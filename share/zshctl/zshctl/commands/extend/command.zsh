# ___ :execute:extend _ man ___
# .SH NAME
# .PG __program__\ extend \-
# extend
# .PG .B __program__
# with additional commands
# .SH SYNOPSIS
# .PG .SY __program__\ extend
# .I command
# .RI [ arguments ]
# .PG .SY __program__\ extend
# .RB [ \-h | \-\-help ]
# .YS
# .DC Extend
# .PG .B __program__
# with additional commands.
# .SH DESCRIPTION
# Extends
# .PG __program__
# with additional commands.
# .SH OPTIONS
# .TP
# .BR \-h ,\  \-\-help
# .DC Help for
# .PG .BR __program__\ extend .
# .SH COMMANDS
# The following command can be invoked to extend
# .PG __program__ with additional commands.
# You can learn more about the each command by invoking the command with the
# .B --help
# option.
# .ZC commands
# ___
function :args:extend {
    eval "$(args -UC -bx h,help -- "$@")"
}

function :execute:extend {
    delegate "$@"
}
