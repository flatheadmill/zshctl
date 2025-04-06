# ___ execute:version ___
# .SH NAME
# .PG __program__\ version \- display version
# .SH SYNOPSIS
# .PG .SY __program__\ version
# .I command
# .RI [ arguments ]
# .PG .SY __program__\ version
# .RB [ \-h | \-\-help ]
# .YS
# .SH DESCRIPTION
# .PG .B __program__\ completion
# generates completions for Zsh and Bash.
# .SH OPTIONS
# .TP
# .BR \-h ,\  \-\-help
# Help for
# .PG .BR __program__\ version .
# .SH COMMANDS
# You can learn more about the each command by invoking the command with the
# .B --help
# option.
# .TP
# .B bash
# .br
# Generate shell compltions for Bash.
# .TP
# .B zsh
# .br
# Generate shell compltions for Zsh.
# ___
function execute:version {
    typeset o_output=terse
    eval "$(args -d o,output -bx h,help -- "$@")"
    case $o_output in
        terse )
            print $zshctl[version]
            ;;
        verbose )
            print "$zshctl[version] $zshctl[release_date]"
            ;;
        shell )
            print "${(qq)zshctl[version]} ${(qq)zshctl[release_date]}"
            ;;
    esac
}
