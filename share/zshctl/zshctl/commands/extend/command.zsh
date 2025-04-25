function execute:extend {
    eval "$(args -C -bx h,help -- "$@")"
    delegate "$@"
}
