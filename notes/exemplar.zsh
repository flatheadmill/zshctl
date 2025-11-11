fpath=( share/zshctl/functions $fpath )
autoload -zU exemplar block try tried heredoc slurp show

zmodload zsh/parameter

# Exemplar is imperfect. It won't catch every possible error. You will have to
# use your Zsh knowledge to be certain you test for errors correctly.
function example {
    # The error is 'bad assignment' because neither `var` not `value` are not
    # defined, but exemplar will not error, because typeset does not return an
    # error.
    _(){ typeset -g $var=$value }
    # The error is `command not found: echo1`, but exemplar will not error
    # because the
    _(){ if true; then echo1; fi }
}

function stash {
    _(){ typeset -g var=foo value=1 }
    _(){ typeset -g $var=$value }
    _(){ print "${(Pqq)var}" }
    # TODO Why won't this report when it says `echo1` and not `echo 1`?
    _(){ echo 1 }
    # TODO Why won't this report when it says `echo1` and not `echo 1`?
    _(){ if true; then echo 1; fi }
    _(){ true && echo 1 }
    # Generic heredocs are incredibly ugly.
    _() {
        cat <<EOF
Now is the time for all good men to come to the aid of their country.

This is a test of the emergency broadcast system. This is only a test.
EOF
    }
    heredoc -v message <<'    EOF'
        Now is the time for all good men to come to the aid of their country.

        This is a test of the emergency broadcast system. This is only a test.
    EOF
    # We could accept standard input and then create an ugly internal heredoc.
    _() { cat } && <<'    EOF'
    EOF
    typeset value
    # This turns into 'value=nurse ' with an extra space, we're going to have to
    # learn to live with that.
    _(){ value=nurse }
    # We ought to be able to use %s and %q in most places.
    _(){ echo hello/%s/world } && $value
}

# You can put %s or %q in most places in Zsh code and it will compile as string
# literal, so if you do want to interpolate strings, we suggest doing so with
# `sprintf`, which may make getting pretty code examples more difficult than
# using `{ try show || tried; } <<'    EOF'`.
function _example {
    # We ought to be able to use %s and %q in most places.
    typeset value=nurse
    (){ % hello; function foo { print %s; true } }
    (){ foo }
    (){ % $value; echo hello/%s/world }
    { try show || tried; } <<'    EOF'
        print this to standard output, please && false
    EOF
    (){ print -u 2 bad && false }
    (){ % -n; cat %s } <<'    EOF'
        hello, world
    EOF
    { try show || tried; } <<< 'cat -n <<-EOF
    hello, world
    EOF'
}

function example {
    typeset switch=-n
    (){ % $switch; cat %s } <<'    EOF'
        hello, world
    EOF
}

function example {
    (){ cat -n } <<'    EOF'
        hello, world
    EOF
}

function example {
    (){
        slurp=$(cat -n)
        print $slurp
    } <<'    EOF'
        hello, world
    EOF
}

function example {
    typeset switch=-n
    (){
        % $switch
        slurp=$(cat %s)
        print $slurp
    } <<'    EOF'
        hello, world
    EOF
}

function example {
    typeset world=world
    (){ % -n; cat %s } <<"    EOF"
        hello, $world
    EOF
}

function _example {
    typeset world=world
    (){ % -n; cat %s } % $world <<"    EOF"
        hello, %s
    EOF
}
function _example {
    if true; then
        (){ % hello; print %s }
    fi
}
function _example {
    typeset world=world
print $(heredoc -f $world <<< 'hello, %s
')
#    {
   #     try show || tried
   # } <<<
    print "$(printf ' <<"EOF"
%s
EOF
) '  testing
)"
    print "$(printf ' <<"EOF"
%s
EOF
) ' "$(heredoc -f $world <<< 'hello, %s
')")"
}

function _example {
    typeset variable variables=()
    while (( $# )); do
        (){ % $1 $1 $1; [[ -v %s ]] && variables+=( -s "%s=${%s}" ) }
        shift
    done
    () { jo -- "${(@)variables}" < /dev/null | gojq --yaml-output }
    () { : }
}

function {
    print ">>${functions[example]}<<"
    exemplar example
    print ">>${functions[example]}<<"
    block environment
    {
        example USER HOME
    } always {
        caught
    } > >(indent)
}
