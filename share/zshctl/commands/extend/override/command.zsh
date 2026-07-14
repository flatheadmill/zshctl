function :help:extend:override {
    heredoc -v help -q <<'    EOF'
        # desc
        Redirect \`${zshctl[program]}\` at a working-copy extension for this shell session.
        # arg -- [ directory ]
        # opt help
        Display help for \`${zshctl[program]} extend override\`.
        # opt clear
        Emit an \`unset\` for the override variable instead of an \`export\`.
        # opt show
        Print the current override value, if any, and exit.
        # man
        ## DESCRIPTION
        Finds the \`${zshctl[program]}\` extension under the current git worktree (or under
        DIRECTORY) and prints an \`export <PROGRAM>\_OVERRIDE=<dir>\` line. Eval it to point
        THIS shell session's \`${zshctl[program]}\` at that working copy: its commands and
        functions win over the installed extension, while the shared \`~/.local/share\`
        symlinks — and every other shell session — are left untouched. Clear with \`--clear\`.

        \`<PROGRAM>\_OVERRIDE\` is a colon-separated list of extension directories, so it
        composes if you eval more than one.
        ## USAGE
            eval "\$(${zshctl[program]} extend override)"
            eval "\$(${zshctl[program]} extend override --clear)"
        ## OPTIONS
        > options
    EOF
}

function :args:extend:override {
    eval "$(args -bx h,help ,clear ,show -- "$@")"
}

function :execute:extend:override {
    typeset variable=${(U)zshctl[program]}
    variable=${variable//[^A-Za-z0-9]/_}_OVERRIDE

    if (( ${o_clear:-0} )); then
        print -r -- "unset $variable"
        print -u 2 -P "%F{8}→ ${zshctl[program]} override cleared for this session%f"
        return
    fi
    if (( ${o_show:-0} )); then
        print -r -- ${(P)variable:-}
        return
    fi

    # Detect the extension the way `extend link` does — the directory holding the
    # program's extension marker — but search from the git worktree root so it
    # works from anywhere inside the checkout, not just its top.
    typeset root=${1:-$(git rev-parse --show-toplevel 2>/dev/null)}
    : ${root:=.}
    typeset found=( $root/**/$zshctl[program].extension.zsh(N) )
    case ${#found} in
    (0) abend 'fatal: no %s.extension.zsh found under %s' $zshctl[program] ${(qqq)root} ;;
    (1) ;;
    (*) abend 'fatal: multiple extension configurations found under %s' ${(qqq)root} ;;
    esac
    typeset -A extend
    source $found[1]
    typeset dir=${found[1]:A:h}
    print -r -- "export $variable=${(q)dir}"
    print -u 2 -P "%F{8}→ ${zshctl[program]} now overrides \`${extend[link_as]}\` from ${dir} (this session)%f"
}

function :complete:extend:override {
    [[ $zshctl[args:incomplete] = -* ]] && return
    [[ $zshctl[args:state] = arguments ]] && completion directories
}
