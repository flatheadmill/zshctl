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

    printf 'ZSHCTL_CONFIGURATION[release_date]=%s\n' ${(q)o_release_date}
    printf 'ZSHCTL_CONFIGURATION[version]=%s\n' ${(q)o_version}

    print '\nmain "$@"; exit'
}
