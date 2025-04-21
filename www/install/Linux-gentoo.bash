#!/bin/bash

if [[ -z "$BASH_VERSION" ]]; then
    echo 'error: installer must be run with `bash`, not `sh`' 1>&2
    exit 1
fi

set -e

if [[ "$(id -u)" != 0 ]]; then
    echo 'error: installer must be run as root on Gentoo.' 1>&2
    exit 1
fi

# The `FEATURES` environment variables lets `emerge` know that some features it
# may want to use are unavailable. We set this if we are running inside Docker.
# Curious to find out if the `/docker/` path is copied by other container
# engines like Podman. See: https://bugs.gentoo.org/680456
if cat /proc/1/cgroup | grep -q '^[0-9][0-9]*:[^:][^:]*:/docker/'; then
    export FEATURES="-ipc-sandbox -mount-sandbox -network-sandbox -pid-sandbox"
fi

if ! type git >/dev/null 2>&1; then
    emerge dev-vcs/git
fi

/usr/bin/wget -O /usr/share/openpgp-keys/zshctl.asc -q https://zshctl.sh/gpg

mkdir -p /etc/portage/repos.conf

cat <<'EOF' > /etc/portage/repos.conf/zshctl.conf
[zshctl]
location = /var/db/repos/zshctl
sync-type = git
sync-uri = https://zshctl.sh/ebuild.git
sync-git-verify-commit-signature = true
sync-openpgp-key-path = /usr/share/openpgp-keys/zshctl.asc
sync-depth = 0
clone-depth = 0
EOF

emaint --repo zshctl sync

ACCEPT_LICENSE="MIT" emerge app-misc/zshctl

/usr/bin/zshctl version
