function foo {
    fpath=( ${${(%):-%x}:A:h:h}'/share/zshctl/functions' $fpath )
    autoload -zU args args_error args_error_default
    function {
        args -b h,help -- "$@"
    } --help
}

function {
    foo
}
