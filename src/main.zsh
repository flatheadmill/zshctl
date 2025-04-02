function {
    typeset shebang=${1:-}
    typeset COMMANDS=() CTL=zshctl CTL_ARGZERO=()
    typeset src include=()
    while (( ${#ZSHCTL_INCLUDE} )); do
        include=( "${(@)ZSHCTL_INCLUDE}" )
        ZSHCTL_INCLUDE=()
        for src in "${(@)include}"; do
            eval $src
        done
    done
    if [[
        ( $shebang =~ ^\. || $shebang =~ / ) &&
        -f $shebang &&
        "$(head -c 14 $shebang)" = '#!/usr/bin/env' &&
        "$(head -n 1 $shebang)" =~ ^#!/usr/bin/env\ +zshctl\ *$
    ]]; then
        ZSHCTL_ARGZERO=$shebang
        commands ${ZSHCTL_ARGZERO:A}
        source ${ZSHCTL_ARGZERO:A}
        print ${ZSHCTL_ARGZERO}
        if [[
            $(type ${shebang##*/} 2>/dev/null) != "${shebang##*/} is a shell function from ${ZSHCTL_ARGZERO:A}"
        ]]; then
            abend 'shell function not found'
        fi
        "${shebang##*/}" "$@"
    else
        print -u 2 'shebang only'
    fi
} "$@"
