# ___ :execute:completion:bash _ man ___
# .PG __program__\ completion \- generate Bash shell completions
# .SH SYNOPSIS
# .PG .SY __program__\ completion\ bash
# .PG .SY __program__\ completion\ bash
# .RB [ \-h | \-\-help ]
# .YS
# .DC Generate Bash completions for
# .PG .BR __program__ .
# .SH DESCRIPTION
# Generates Bash compltions for
# .PG .BR __program__ .
# .SH OPTIONS
# .TP
# .BR \-h ,\  \-\-help
# Help for
# .PG .BR __program__\ completions\ bash .
# ___
function :args:completion:bash {
    eval "$(args -bx h,help -- "$@")"
}

function :execute:completion:bash {
    sed -e 's/zshctl/'$zshctl[program]'/g' \
        "${functions_source[:execute:completion:bash]:A:h}/complete.bash"
}
