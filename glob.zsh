function eof {
    case $1 in
    (${~glob[func]})
        print hit ">>${#match[1]}<<"
        ;;
    ($tabs${~glob[eof]})
        print hit $match[3] $match[4] $match[5] $match[6]
        ;;
    (*)
        print missed
        ;;
    esac
}

function {
    setopt extendedglob
    typeset -A glob=(
        func '(#b)('$'\t''##)\(\) {'
        # Matches `} <<'    EOF'` or `} <<"    EOF"` but might mismatch quotes.
        eof '}(#b)([[:space:]]##(%[[:space:]]##(*)[[:space:]]##|)<<[[:space:]]#(["'\''])(*)(["'\''])[[:space:]]#|)'
        eof '}(#b)([[:space:]]##(%[[:space:]]##(*)[[:space:]]##|)<<[[:space:]]#(["'\''])(*)(["'\''])[[:space:]]#|)'
    )
    typeset tabs=$'\t'
    eof $'\t''} <<"    EOF"'
    eof '} <<"    EOF"'
    eof $'\t''}'
    eof $'\t''} <<'\''    EOF'\'
    eof $'\t''} % $hello <<'\''    EOF'\'
    eof $'\t''} % "<<" <<'\''    EOF'\'
    eof $'\t''() {'
}
