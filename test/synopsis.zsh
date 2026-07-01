fpath=( ${${(%):-%x}:A:h:h}'/share/zshctl/functions' $fpath )
autoload -zU _zshctl_synopsis abend warn heredoc slurp

function {
    typeset synopsis
    for synopsis in \
        '[<file>...]' \
        '[(-a | --all)]' \
        '(direct|inherit)' \
        '--track[=(direct|inherit)]' \
        '--fixup=[(amend|reword):]<commit>' \
        '.control' \
        "'control" \
        'path\name' \
        'git commit [-a] [-m <msg>] [--fixup=[(amend|reword):]<commit>] [<file>...]'
    do
        print -r -- "--- $synopsis"
        _zshctl_synopsis --dump "$synopsis"
        _zshctl_synopsis "$synopsis"
        print
    done

    print -r -- '--- malformed: git commit [--fixup=<commit>'
    ( _zshctl_synopsis 'git commit [--fixup=<commit>' )
    print "code: $?"
}
