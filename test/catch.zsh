source share/zshctl/zshctl/include/catch.zsh

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
    catch out err good hello
    printf 'code: %s\n' $?
    printf 'out: %s' $out
    printf 'err: %s' $err
    catch out err bad hello
    printf 'code: %s\n' $?
    printf 'out: %s' $out
    printf 'err: %s' $err
}
