# ___ execute:version _ description ___
# Display the current version of
# .PG .BR __program__ .
# ___ execute:version _ man ___
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
# .PG .B __program__\ version
# display the current version of
# .PG .BR __program__ .
# .SH OPTIONS
# .TP
# .BR \-h ,\  \-\-help
# Help for
# .PG .BR __program__\ version .
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
