#compdef _completer completer
compdef _completely completely

function _completely {
    print called2 >> ~/foo.txt
    typeset foo=( 'a:hello' 'b:world' )
    #zle -R "Completing..."
    typeset foo=( able alfa bravo baker )
    foo=()
    #_describe -t commands 'command' foo -x hello "$@"
    #compadd -x "No matches found." 2>>~/.hello.txt ||
    #    print errored >> ~/.hello.txt
    #compadd -x "No matches found."
    #compadd -x "No matches found."
    #compadd -x "No matches found."
    #compadd -x "No matches found."
    print $curcontext >> ~/foo.txt
    _message -r 'Not logged into `op`. Run `eval "$(op signin)"`.'
    #builtin compadd -x 'Not logged into `op`. Run `eval "$(op signin)"`.'
    #_comp_mesg=yes
    #if ! eval _describe foo foo -x hello; then
    #    return 1
    #fi
}

if [ "$funcstack[1]" = "_completely" ]; then
    _completely
fi
