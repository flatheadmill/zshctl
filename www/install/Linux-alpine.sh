#!/bin/sh

if [[ "$(id -u)" != 0 ]]; then
    echo 'error: installer must be run as root on Alpine Linux.' 1>&2
    exit 1
fi

if ! grep -q '^https://zshctl.sh/apk$' /etc/apk/repositories; then
    echo https://zshctl.sh/apk >> /etc/apk/repositories
fi

wget -qO /etc/apk/keys/alan@prettyrobots.com-67eee297.rsa.pub https://zshctl.sh/keys/alan@prettyrobots.com-67eee297.rsa.pub

apk --no-progress update
apk --no-progress add zshctl

type zshctl
/usr/bin/zshctl version --format verbose
