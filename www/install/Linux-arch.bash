#!/bin/bash

if [ -z "$BASH_VERSION" ]; then
    echo 'error: installer must be run with `bash`, not `sh`' 1>&2
    exit 1
fi

if [[ "$(id -u)" != 0 ]]; then
    echo 'error: installer must be run as root on Arch Linux.' 1>&2
    exit 1
fi

if grep -q '^\[zshctl\]$' /etc/pacman.conf; then
    echo 'error: zshctl already in `/etc/pacman.conf`, giving up'
    exit 1
fi

cat <<EOF >> /etc/pacman.conf

[zshctl]
Server = https://zshctl.sh/aur
EOF

curl -s https://zshctl.sh/keys/gpg | pacman-key --add -
pacman-key --lsign-key 8262C8D6D0959C6F

pacman -Sy
pacman --noconfirm -S zshctl

type zshctl
/usr/bin/zshctl version
