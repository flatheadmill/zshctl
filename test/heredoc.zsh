source share/zshctl/zshctl/include/heredoc.zsh

function {
    typeset hello
    heredoc - <<'    EOF'
        hello, world 1
    EOF
    heredoc <<'    EOF'
        hello, world 2
    EOF
    heredoc -v hello <<'    EOF'
        hello, world 3
    EOF
    printf $hello
    heredoc -f world <<'    EOF'
        hello, %s 4
    EOF
    heredoc -v hello -f world <<'    EOF'
        hello, %s 5
    EOF
    printf $hello
    typeset encounter=world
    heredoc -q <<'    EOF'
        hello, ${encounter} 6
    EOF
    heredoc -v hello -q <<'    EOF'
        hello, ${encounter} 7
    EOF
    printf $hello
    warn <<'    EOF'
        warn: greeting: hello, world 1
    EOF
    warn -f world <<'    EOF'
        warn: greeting: hello, %s 2
    EOF
    warn -q <<'    EOF'
        warn: greeting: hello, ${encounter} 3
    EOF
    warn 'warn: greeting: hello, %s 4' $encounter
    warn -- 'warn: greeting: hello, %s 5' $encounter
    (
    abend <<'    EOF'
        fatal: greeting: hello, world 1
    EOF
    )
    print "code: $?"
    (
    abend -c 2 <<'    EOF'
        fatal: greeting: hello, world 2
    EOF
    )
    print "code: $?"
    (
    abend -f world <<'    EOF'
        fatal: greeting: hello, %s 3
    EOF
    )
    print "code: $?"
    (
    abend -c 2 -f world <<'    EOF'
        fatal: greeting: hello, %s 4
    EOF
    )
    print "code: $?"
    (
    abend -q <<'    EOF'
        fatal: greeting: hello, ${encounter} 5
    EOF
    )
    print "code: $?"
    (
    abend -c 2 -q <<'    EOF'
        fatal: greeting: hello, ${encounter} 6
    EOF
    )
    print "code: $?"
    (abend 'fatal: greeting: hello, %s 7' $encounter)
    print "code: $?"
    (abend -c 2 'fatal: greeting: hello, %s 8' $encounter)
    print "code: $?"
    (abend -- 'fatal: greeting: hello, %s 9' $encounter)
    print "code: $?"
    (abend -c 2 -- 'fatal: greeting: hello, %s 10' $encounter)
    print "code: $?"
}
