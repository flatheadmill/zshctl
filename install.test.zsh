#!/usr/bin/env zsh

function {
    typeset zshctl_previous_version=0.0.2 zshctl_version=0.0.3 platform
    for platform in alpine archlinux fedora gentoo homebrew ubuntu; do
    #for platform in gentoo ; do
        #docker pull harbor.acreops.org/zshctl/$platform:v$acrectl_previous_version
        docker build \
            --progress plain \
            --build-arg ZSHCTL_VERSION=$zshctl_version \
            --build-arg ZSHCTL_PREVIOUS_VERSION=$zshctl_previous_version \
            -t harbor.acreops.org/zshctl/$platform:v$zshctl_version \
            -f Dockerfile.install.$platform . || exit 1
        docker push harbor.acreops.org/zshctl/$platform:v$zshctl_version
    done
}
