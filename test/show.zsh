function {
    fpath=( ${${(%):-%x}:A:h:h}'/share/zshctl/functions' $fpath )
    autoload -zU heredoc show
    show print -l 1 '' 2
    show <<'    EOF'
        print hello
    EOF
    show eval 'print -l 1 "" 2'
}
