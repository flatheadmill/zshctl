function {
    fpath=( ${${(%):-%x}:A:h:h}'/share/zshctl/functions' $fpath )
    autoload -zU heredoc show abend slurp warn
    show print -l 1 '' 2
    show <<'    EOF'
        print hello
    EOF
    show eval 'print -l 1 "" 2'
    show -f a b <<'    EOF'
        print %s %s
    EOF
    typeset url='https://tekton.acreops.org/#/namespaces/tekton-kubernetes/pipelineruns/kubernetes-plan-3452-gtj77-r-cr5qr?number=3452'
    print $url
    show -f "$url" <<'    EOF'
        print %q
    EOF
}
