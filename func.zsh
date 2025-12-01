function example {
    typeset world=world
    {
        try show || tried
    } <<< "$(printf 'cat %s' -n)""$(printf ' <<"EOF"
%s
EOF
) ' $(heredoc -f $world <<< 'hello, %s
'))"
}

example
