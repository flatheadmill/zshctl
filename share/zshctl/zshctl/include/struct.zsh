function struct {
    case $1 in
    (put)
        if [[ ${(Pt)2} != association-local ]]; then
            print -u 2 'fatal: invalid argument: struct must be a local associative array.'
            return 1
        fi
        set -- $2 "${(PA@kv)2}" $3 ${${(j: :)${(@qq)@[4,-1]}}}
        : ${(PAA)1::=$@[2,-1]}
        ;;
    (push)
        if [[ ${(Pt)2} != association-local ]]; then
            print -u 2 'fatal: invalid argument: struct must be a local associative array.'
            return 1
        fi
        if [[ ${(e):-\${+${2}[\$3]}} -eq 1 ]]; then
            set -- $2 "${(PA@kv)2}" $3 "${${(P)2}[$3]} ${${(j: :)${(@qq)@[4,-1]}}}"
            : ${(PAA)1::=$@[2,-1]}
        else
            struct put "${@[2,-1]}"
        fi
        ;;
    (get)
        case ${(Pt)4} in
        (association-local)
            if [[ -n "${${(P)2}[$3]}" ]]; then
                : ${(PAA)4::=${(@QA)${(@z)${(P)2}[$3]}}}
            else
                : ${(PAA)4::=$@[1,0]}
            fi
            ;;
        (array-local)
            if [[ -n "${${(P)2}[$3]}" ]]; then
                : ${(PA)4::=${(@QA)${(@z)${(P)2}[$3]}}}
            else
                : ${(PA)4::=$@[1,0]}
            fi
            ;;
        (*)
            abend 'fatal: output must be an associative array or an array'
            ;;
        esac
        ;;
    esac
}
