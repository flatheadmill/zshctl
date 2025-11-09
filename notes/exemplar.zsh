fpath=( share/zshctl/functions $fpath )
autoload -zU warn abend heredoc slurp block show

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
}

# You can put %s or %q in most places in Zsh code and it will compile as string
# literal, so if you do want to interpolate strings, we suggest doing so with
# `sprintf`, which may make getting pretty code examples more difficult than
# using `{ try show || tried; } <<'    EOF'`.
function example {
    # TODO Why won't this report at all?
    _() {
{
        cat <<EOF
hello
EOF
}
    }
    typeset value
    _(){ value=nurse }
    _(){ echo 'hello/%s/world' } && -f $nurse
}

function @ {
}

function _ {
}

function _exemplar_printf {
    if (( ${#chunk} )); then
        printf -v "code[i++]" 'try show eval %s || tried\n' ${(qqpj:\n:)chunk}
    fi
    chunk=()
}

function exemplar {
    setopt localoptions extendedglob
    typeset func=${1:-} state=scan chunk match=() code=()
    integer i=1
    for line in "${(@f)${functions[$func]}}"; do
        case $state:$line in
        (*:$'\t'_\ \(\)[[:space:]]#{)
            state=underbar
            ;;
        (underbar:(#b)$'\t'}(*))
            print $match[1]
            _exemplar_printf
            state=scan
            ;;
        (underbar:*)
            # Drop back the two tabs added by Zsh.
            line=${line#$'\t'$'\t'}
            chunk+=( $line )
            ;;
        esac
    done
    _exemplar_printf
    printf -v func %s "${(j::)code}"
    print ">>$func<<"
    return
    block 'hello world'
    {
        eval $func
    } always {
        caught
    } > >(indent)
}

function {
    exemplar example
}
