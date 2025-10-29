function {
    typeset -A map
    typeset var=map
    typeset "${var}[greeting]=hello"
    print -l $map[greeting]
}
