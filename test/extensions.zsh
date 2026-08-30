#!/usr/bin/env zsh
emulate -L zsh

typeset root=${${(%):-%x}:A:h:h}
typeset tmp=$(mktemp -d "${TMPDIR:-/tmp}/zshctl-extensions.XXXXXX")
trap 'rm -rf -- $tmp' EXIT

typeset home=$tmp/home program=$tmp/fixture
typeset extension=$home/.local/share/fixture/extensions/one
mkdir -p $extension/functions

cat > $program <<EOF
#!$root/bin/zshctl

function :extensions {
    integer count=0
    typeset dir extension=\$HOME/.local/share/fixture/extensions/one
    for dir in "\${(@)command_path}"; do
        [[ \${dir:A} = \${extension:A} ]] && (( count++ ))
    done
    zshctl[test:command_path]=\$count
}

function :execute {
    integer count=0
    typeset dir extension=\$HOME/.local/share/fixture/extensions/one/functions
    for dir in "\${(@)fpath}"; do
        [[ \${dir:A} = \${extension:A} ]] && (( count++ ))
    done
    print -- \$zshctl[test:command_path] \$count
}
EOF
chmod +x $program

typeset out=$(HOME=$home $program)
[[ $out = '1 1' ]] || {
    print -u2 -- "localized extension counts: $out"
    exit 1
}
print 'ok: localized extensions enter command_path and fpath once'
