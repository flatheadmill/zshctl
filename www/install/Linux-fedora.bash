#!/bin/bash

if [[ -z "$BASH_VERSION" ]]; then
    echo 'error: installer must be run with `bash`, not `sh`' 1>&2
    exit 1
fi

set -e

if [[ "$(id -u)" != 0 ]]; then
    echo 'error: installer must be run as root on Fedora.' 1>&2
    exit 1
fi

cat <<EOF > /etc/yum.repos.d/zshctl.repo
[zshctl]
name=zshctl
baseurl=https://zshctl.sh/yum/repo
enabled=1
metadata_expire=1d
repo_gpgcheck=0
type=rpm
gpgcheck=1
gpgkey=https://zshctl.sh/keys/gpg
skip_if_unavailable=False
EOF

dnf install -y zshctl

type zshctl
/usr/bin/zshctl version
