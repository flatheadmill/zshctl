# ___ execute:completion:bash _ description ___
# Generate Bash completions for
# .PG .BR __program__ .
# ___ execute:completion:bash _ man ___
# .PG __program__\ completion \- generate Bash shell completions
# .SH SYNOPSIS
# .PG .SY __program__\ completion\ bash
# .PG .SY __program__\ completion\ bash
# .RB [ \-h | \-\-help ]
# .YS
# .SH DESCRIPTION
# Generates Bash compltions for
# .PG .BR __program__ .
# .SH OPTIONS
# .TP
# .BR \-h ,\  \-\-help
# Help for
# .PG .BR __program__\ completions\ bash .
# ___
function execute:completion:bash {
    eval "$(args -bx h,help -- "$@")"
    sed -e 's/zshctl/'$zshctl[program]'/g' \
        "${functions_source[execute:completion:bash]:A:h}/complete.bash"
}
