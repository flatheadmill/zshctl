# ___ :execute:completion:zsh _ man ___
# .PG __program__\ completion \- generate Zsh shell completions
# .SH SYNOPSIS
# .PG .SY __program__\ completion\ zsh
# .PG .SY __program__\ completion\ zsh
# .RB [ \-h | \-\-help ]
# .YS
# .DC Generate Zsh completions for
# .PG .BR __program__ .
# .SH DESCRIPTION
# Generates Zsh compltions for
# .PG .BR __program__ .
# .SH OPTIONS
# .TP
# .BR \-h ,\  \-\-help
# Help for
# .PG .BR __program__\ completions\ zsh .
# ___
function :args:completion:zsh {
    eval "$(args -bx h,help -- "$@")"
}

function :execute:completion:zsh {
    sed -e 's/zshctl/'$zshctl[program]'/g' \
        "${functions_source[:execute:completion:zsh]:A:h}/complete.zsh"
}
