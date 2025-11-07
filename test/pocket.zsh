fpath=( share/zshctl/functions $fpath )
autoload -zU pocket slurp

function good {
    print "$@"
    print -u 2 very good
}

function bad {
    print "$@"
    print -u 2 very bad
    return 9
}

function {
    typeset out err
    pocket out err good hello
    printf 'code: %s\n' $?
    printf 'out: %s' $out
    printf 'err: %s' $err
    pocket -s out err good hello
    printf 'code: %s\n' $?
    printf %s $out | hexdump -C
    out=$(good hello)
    printf %s $out | hexdump -C
    printf 'out: %s' $out
    printf 'err: %s' $err
    pocket out err bad hello
    printf 'code: %s\n' $?
    printf 'out: %s' $out
    printf 'err: %s' $err
}
