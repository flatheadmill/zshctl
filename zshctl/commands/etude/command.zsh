# ___ :execute:etude _ man ___
# .SH NAME
# .PG __program__\ etude \-
# a series of exercises for
# .PG .B __program__
# .SH SYNOPSIS
# .PG .SY __program__\ etude
# .I command
# .RI [ arguments ]
# .PG .SY __program__\ etude
# .RB [ \-h | \-\-help ]
# .YS
# .DC A series of exercises for
# .PG .BR __program__ .
# .SH DESCRIPTION
# A series of exercises for
# .PG BR __program__ .
#
# Exercises include the extension itself, to illustrate how to write an
# extention and a full example of an argument parser with full help.
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
function :args:etude {
    eval "$(args -UC -bx h,help -- "$@")"
}

function :execute:etude {
    delegate "$@"
}
