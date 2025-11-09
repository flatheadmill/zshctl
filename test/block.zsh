fpath=( share/zshctl/functions $fpath )
autoload -zU warn abend heredoc slurp block show

function bad {
    print something bad is about to happen
    print something bad happend 1>&2
    print bad 1>&2
    print very bad 1>&2
    return 8
}

function {
    if false; then
    block -i 0
    {
        try print hello || tried
    } always {
        caught
    }
    (
        block -i 0
        {
            try bad || tried 'bad error: something bad happened'
        } always {
            caught
        }
    )
    (
        block -i 0
        {
            typeset json
            try && json=$(print '{}') || tried 'bad error: something bad happened'
            print $json
        } always {
            caught
        }
    )
    fi
    (
        block -i 0
        {
            typeset try
            try -v try && json=$(bad 2>&$try) ||
                tried -c 99 'bad error: something bad happened'
        } always {
            caught
        }
    )
    print $?
    block 'hello'
    {
        try show print 'hello' || tried
    } always {
        caught
    } > >(indent)
}
