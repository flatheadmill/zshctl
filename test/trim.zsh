fpath=( share/zshctl/functions $fpath )
autoload -zU trim

function {
    typeset str=$'\n\t    abc def      \t\n'
    typeset var=$str
    printf '>>%s<<\n' $var
    trim var
    printf '>>%s<<\n' $var
    var=$str
    trim var 0 1
    printf '>>%s<<\n' $var
    var=$str
    trim var 1 0
    printf '>>%s<<\n' $var
}
