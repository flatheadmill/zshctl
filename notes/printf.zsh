function {
    typeset -A assoc
    printf -v 'assoc[hello]' hello
    print $assoc[hello]
}
