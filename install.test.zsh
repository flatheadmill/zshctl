#!/usr/bin/env zsh

function {
    typeset zshctl_previous_version=0.0.3 zshctl_version=0.0.4 platform
    for platform in alpine archlinux fedora gentoo homebrew ubuntu; do
        docker build \
            --progress plain \
            --build-arg ZSHCTL_VERSION=$zshctl_version \
            --build-arg ZSHCTL_PREVIOUS_VERSION=$zshctl_previous_version \
            -t ghcr.io/flatheadmill/zshctl-$platform:v$zshctl_version \
            -f Dockerfile.install.$platform . || exit 1
        docker push ghcr.io/flatheadmill/zshctl-$platform:v$zshctl_version
    done
}
