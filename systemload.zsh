zmodload zsh/parameter

function systemload {
    typeset func load
    while (( $# )); do
        func=$1
        shift
        printf -v load 'typeset fpath=( %s )\nautoload -UX\n' ${zshctl[fpath]}
        functions[$func]=$load
    done
}

function _systemload {
    typeset func found
    while (( $# )); do
        func=$1
        shift
        for dir in ${=${zshctl[fpath]}}; do
            if [[ -f $dir/$func ]]; then
                functions[$func]=$(<$dir/$func)
                continue 2
            fi
        done
        print -u 2 "warn: unable to find function ${(@qqq)func}"
    done
}

function {
    typeset -A zshctl=( fpath "${(j: :)${(@qq)fpath}}" )
    fpath=( $pwd/junk $fpath )
    systemload throw catch
    {
        {
            throw hello
        } always {
            (( TRY_BLOCK_ERROR = 0 ))
        }
        throw hello
    } always {
        print $TRY_BLOCK_ERROR
        if catch hello; then
            print caught
        fi
    }
    print ${functions[catch]}
}
