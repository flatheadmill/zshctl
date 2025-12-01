fpath=( share/zshctl/functions $fpath )
autoload -zU exemplar block try tried heredoc slurp show tryable showe

zmodload zsh/parameter


function example {
    (){ cat }
}

function {
    exemplar -c example
    print "${functions[example]}"
}
