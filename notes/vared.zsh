function {
    # Check for alternate screen support
    typeset smcup=$(tput smcup 2>/dev/null)
    typeset rmcup=$(tput rmcup 2>/dev/null)
    if [[ -z $smcup || -z $rmcup ]]; then
        print -u 2 "fatal: terminal does not support alternate screen buffer"
        return 1
    fi

    bindkey -e
    if ! bindkey -M sticky >& /dev/null
    then
      bindkey -N sticky emacs
      bindkey -M sticky ^X^W accept-line
      bindkey -M sticky ^M^M accept-line	# Two quick RETs ends note
      bindkey -M sticky ^D delete-char
      bindkey -M sticky ^M self-insert-unmeta
    fi
    if ! bindkey -M sticky-vicmd >& /dev/null
    then
      bindkey -N sticky-vicmd vicmd
      bindkey -M sticky-vicmd ZZ accept-line
    fi

    typeset sticky

    # Enter alternate screen
    print -n $smcup

    {
        printf '(quick double enter to save, Ctl+C to cancel all)\n'
        for sticky in hello world; do
            printf 'editing: %s\n' $sticky
            printf -- '---\n'
            vared -h -M sticky -m sticky-vicmd sticky
            printf '>>%s<<\n' $sticky
        done
    } always {
        # Always restore original screen
        print -n $rmcup
    }
}
