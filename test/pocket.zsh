fpath=( share/zshctl/functions $fpath )
autoload -zU pocket

function good {
    print "$@"
    print very good 1>&2
}

function bad {
    print "$@"
    print very bad 1>&2
    return 1
}

function {
    typeset out err
    pocket out err good hello
    printf 'code: %s\n' $?
    printf 'out: %s' $out
    printf 'err: %s' $err
    pocket out err bad hello
    printf 'code: %s\n' $?
    printf 'out: %s' $out
    printf 'err: %s' $err
}
