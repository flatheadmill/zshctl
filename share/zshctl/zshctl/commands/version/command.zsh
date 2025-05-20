zmodload zsh/datetime

# TODO Make the format options a bullet list under it's entry in OPTIONS.
# ___ execute:version _ description ___
# Display the current version of
# .PG .BR __program__ .
# ___ execute:version _ man ___
# .SH NAME
# .PG __program__\ version \- display version
# .SH SYNOPSIS
# .PG .SY __program__\ version
# .RB [ \-f | \-\-format = \fIterse\fR | \fIverbose\fR | \fIshell\fR | \fIjson\fR ]
# .PG .SY __program__\ version
# .RB [ \-h | \-\-help ]
# .YS
# .SH DESCRIPTION
# Displays the current version of
# .PG .BR __program__ .
# .SH OPTIONS
# .TP
# .BR \-f ,\  \-\-format =[ \fIterse\fR | \fIverbose\fR | \fIshell\fR | \fIjson\fR ]
# Display one of
# .I terse
# for just the version number,
# .I verbose
# for the version number and release date,
# .I shell
# for the version number and release date as UNIX epoch shell quoted, or
# .I json
# for the version number and release date as UNIX epoch as JSON.
# .TP
# .BR \-h ,\  \-\-help
# Help for
# .PG .BR __program__\ version .
# ___
function execute:version {
    typeset o_format=terse
    eval "$(args -C -d f,format -bx h,help -- "$@")"
    case $o_format in
        terse )
            print $zshctl[version]
            ;;
        verbose )
            print "Version: $zshctl[version]\nRelease Date: $(strftime "%Y-%m-%dT%H:%M:%S:%z" $zshctl[release_date])"
            ;;
        shell )
            print "${(qq)zshctl[version]} ${(qq)zshctl[release_date]}"
            ;;
        json )
            printf '{"version":"%s","release_date":"%s"}\n' $zshctl[version] $zshctl[release_date]
            ;;
    esac
}

function complete:version {
    case $parse[state]:$parse[matched] in
    (value:(-f|--format))
        completion terse 'display version number only'
        completion verbose 'display version number and release date'
        completion shell 'shell esacped version number and release date as UNIX epoch'
        completion json 'version number and release date as UNIX epoch as JSON'
        ;;
    esac
}
