#!/usr/bin/env zsh
emulate -L zsh

typeset root=${${(%):-%x}:A:h:h}
fpath=( $root/share/zshctl/functions $fpath )
autoload -zU abend block heredoc show slurp

if [[ $1 = --case ]]; then
    case $2 in
    (skip)
        block 'skip an unneeded operation'
        {
            { try show || tried; } <<'            EOF'
                (( 0 )) || stop
            EOF
            print body-after-stop
        } always {
            caught
        } > >(indent)
        print resumed
        ;;
    (continue)
        block 'perform a needed operation'
        {
            { try show || tried; } <<'            EOF'
                (( 1 )) || stop
            EOF
            print body-completed
        } always {
            caught
        } > >(indent)
        print resumed
        ;;
    (failure)
        block 'report a failed operation'
        {
            try zsh -fc 'exit 23' || tried
        } always {
            caught
        } > >(indent)
        print resumed
        ;;
    esac
    exit
fi

typeset output
integer code
output=$(zsh -f "$0" --case skip 2>&1)
code=$?
if (( code )) || [[ $output != *resumed* || $output = *body-after-stop* ]]; then
    print -u2 -r -- "stop did not skip the block successfully (exit $code):"
    print -u2 -r -- "$output"
    exit 1
fi
print 'ok: stop skips the block and resumes successfully'

output=$(zsh -f "$0" --case continue 2>&1)
code=$?
if (( code )) || [[ $output != *body-completed* || $output != *resumed* ]]; then
    print -u2 -r -- "needed operation did not complete (exit $code):"
    print -u2 -r -- "$output"
    exit 1
fi
print 'ok: a satisfied condition continues through the block'

output=$(zsh -f "$0" --case failure 2>&1)
code=$?
if (( code != 23 )) || [[ $output = *resumed* ]]; then
    print -u2 -r -- "failed operation did not preserve its exit status (exit $code):"
    print -u2 -r -- "$output"
    exit 1
fi
print 'ok: an actual failure still exits with its original status'
