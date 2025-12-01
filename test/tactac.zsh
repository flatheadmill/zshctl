fpath=( share/zshctl/functions $fpath )
autoload -zU tactac slurp

function {
    typeset stdin stdout
    tactac stdin stdout pid
    echo hello >&$stdin
    exec {stdin}>&-
    cat <&$stdout
    wait $pid
    print -- ---
    tactac stdin stdout
    echo hello >&$stdin
    exec {stdin}>&-
    cat <&$stdout
}
