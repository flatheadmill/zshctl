function bar {
    typeset -gA reply=( one 1 )
    print bar ${(t)reply}
}

function foo {
    typeset -ga reply=( one two )
    print foo ${(t)reply}
    bar
    print foo ${(t)reply}
}

function {
    typeset reply='ehllo'
    reply=hello
    typeset reply='snert'
    typeset reply=()
    foo
    print foo ${(t)reply}
}
