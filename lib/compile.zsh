function zshctl:compile {
    eval "$(args d,release-date v,version -bx h,help -- "$@")"
    typeset dir=${ZSH_ARGZERO:A:h:h}

    printf '#!/usr/bin/env zsh\n\n'

    cat $dir/src/header.zsh
    print
    typeset lib
    for lib in ${ZSH_ARGZERO:A:h:h}/lib/*.zsh; do
        [[ ${lib:t} = compile.zsh ]] && continue
        cat $lib
        print
    done

    cat $dir/src/main.zsh
    print

    printf 'zshctl[release_date]=%s\n' ${(q)o_release_date}
    printf 'zshctl[version]=%s\n' ${(q)o_version}
}
