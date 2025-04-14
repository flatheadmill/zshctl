__start_completely()
{
    echo -e "\nNot logged in, unable to list resources." >&2
    COMPREPLY=()  # Return no completions
    return 0
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_completely completely
else
    complete -o default -o nospace -F __start_completely completely
fi
