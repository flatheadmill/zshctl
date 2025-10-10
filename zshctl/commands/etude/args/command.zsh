:args:etude:args {
    eval "$(args -- -a array -- "$@")"
}

:execute:etude:args {
    print "${(@)o_array}"
}

:complete:etude:args {
}
