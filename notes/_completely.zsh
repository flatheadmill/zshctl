#compdef _completer completer
compdef _completely completely

function _completely {
    local spin='⣾⣽⣻⢿⡿⣟⣯⣷'
    printf '\e[?25l'
    printf $spin[1]'\b'
    sleep .1
    printf $spin[2]'\b'
    sleep .1
    printf $spin[3]'\b'
    sleep .1
    printf $spin[4]'\b'
    sleep .1
    printf $spin[5]'\b'
    sleep .1
    printf $spin[6]'\b'
    sleep .1
    printf $spin[7]'\b'
    sleep .1
    printf $spin[8]'\b'
    printf '\e[?25h'
    _message -r 'Not logged into `op`. Run `eval "$(op signin)"`.'
}

if [ "$funcstack[1]" = "_completely" ]; then
    _completely
fi
